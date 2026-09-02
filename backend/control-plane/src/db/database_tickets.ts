import type { DatabaseSync } from "node:sqlite";

import {
	RECONNECT_TICKET_ERRORS,
	TICKET_REJECT_REASONS,
} from "../../../contracts/src/match_ticket.ts";
import { generateTicket, hashTicket } from "../tickets.ts";
import type { ControlPlaneSessionStore } from "./database_sessions.ts";
import {
	MatchSessionFullError,
	MatchSessionNotFoundError,
	type ConsumeTicketResult,
	type IssuedTicket,
	type ReconnectTicketResult,
} from "./database.ts";

export class ControlPlaneTicketStore {
	readonly db: DatabaseSync;
	readonly sessions: ControlPlaneSessionStore;

	constructor(db: DatabaseSync, sessions: ControlPlaneSessionStore) {
		this.db = db;
		this.sessions = sessions;
	}

	countTickets(matchId: string): number {
		const row = this.db
			.prepare(
				`SELECT COUNT(DISTINCT seat) AS ticket_count
				 FROM match_tickets
				 WHERE match_id = ? AND superseded_at IS NULL`,
			)
			.get(matchId);
		return row === undefined ? 0 : Number(row["ticket_count"]);
	}

	readSeatByTicket(ticket: string): number | undefined {
		const row = this.db
			.prepare(
				`SELECT seat AS seat
				 FROM match_tickets
				 WHERE ticket_hash = ? AND superseded_at IS NULL`,
			)
			.get(hashTicket(ticket));
		return row === undefined ? undefined : Number(row["seat"]);
	}

	issueTicket(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		this.db.exec("BEGIN");
		try {
			const issued = this.issueTicketUnlocked(matchId, now, ttlMs);
			this.db.exec("COMMIT");
			return issued;
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
	}

	consumeTicket(ticket: string, now: Date): ConsumeTicketResult {
		const hash = hashTicket(ticket);
		const nowIso = now.toISOString();

		this.db.exec("BEGIN");
		try {
			const row = this.db
				.prepare(
					`SELECT t.expires_at AS expires_at, t.consumed_at AS consumed_at, t.seat AS seat,
					        s.upstream_url AS upstream_url
					 FROM match_tickets t
					 INNER JOIN match_sessions s ON s.match_id = t.match_id
					 WHERE t.ticket_hash = ?`,
				)
				.get(hash);

			if (row === undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.unknownTicket };
			}
			if (row["consumed_at"] !== null && row["consumed_at"] !== undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.consumedTicket };
			}
			if (String(row["expires_at"]) <= nowIso) {
				this.db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.expiredTicket };
			}

			const updated = this.db
				.prepare(
					"UPDATE match_tickets SET consumed_at = ? WHERE ticket_hash = ? AND consumed_at IS NULL",
				)
				.run(nowIso, hash);
			if (updated.changes !== 1) {
				this.db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.consumedTicket };
			}

			this.db.exec("COMMIT");
			return {
				ok: true,
				upstreamUrl: String(row["upstream_url"]),
				seat: Number(row["seat"]),
			};
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
	}

	/**
	 * 用已消费票据补发同一席位的新票。旧票标为 superseded，不占额外席位。
	 * 过期窗口只约束新票；已消费旧票即使过了 expires_at 仍可补发。
	 */
	reconnectTicket(matchId: string, ticket: string, now: Date, ttlMs: number): ReconnectTicketResult {
		const hash = hashTicket(ticket);
		const nowIso = now.toISOString();

		this.db.exec("BEGIN");
		try {
			const session = this.sessions.getMatchSession(matchId);
			if (session === undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.matchNotFound };
			}

			const row = this.db
				.prepare(
					`SELECT match_id, consumed_at, superseded_at, seat
					 FROM match_tickets
					 WHERE ticket_hash = ?`,
				)
				.get(hash);

			if (row === undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.unknownTicket };
			}
			if (String(row["match_id"]) !== matchId) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.matchMismatch };
			}
			if (row["consumed_at"] === null || row["consumed_at"] === undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.ticketNotConsumed };
			}
			if (row["superseded_at"] !== null && row["superseded_at"] !== undefined) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.supersededTicket };
			}

			const superseded = this.db
				.prepare(
					"UPDATE match_tickets SET superseded_at = ? WHERE ticket_hash = ? AND superseded_at IS NULL",
				)
				.run(nowIso, hash);
			if (superseded.changes !== 1) {
				this.db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.supersededTicket };
			}

			const issued = this.insertTicketUnlocked(matchId, Number(row["seat"]), now, ttlMs);
			this.db.exec("COMMIT");
			return { ok: true, ...issued };
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
	}

	issueTicketUnlocked(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		const session = this.sessions.getMatchSession(matchId);
		if (session === undefined) {
			throw new MatchSessionNotFoundError(matchId);
		}

		const seat = this.nextSeat(matchId, session.seats);
		if (seat === undefined) {
			throw new MatchSessionFullError(matchId);
		}

		return this.insertTicketUnlocked(matchId, seat, now, ttlMs);
	}

	nextSeat(matchId: string, seats: number): number | undefined {
		const rows = this.db
			.prepare(
				`SELECT DISTINCT seat AS seat
				 FROM match_tickets
				 WHERE match_id = ? AND superseded_at IS NULL`,
			)
			.all(matchId);
		const used = new Set(rows.map((row) => Number(row["seat"])));
		for (let seat = 0; seat < seats; seat += 1) {
			if (!used.has(seat)) {
				return seat;
			}
		}
		return undefined;
	}

	insertTicketUnlocked(matchId: string, seat: number, now: Date, ttlMs: number): IssuedTicket {
		const ticket = generateTicket();
		const createdAt = now.toISOString();
		const expiresAt = new Date(now.getTime() + ttlMs).toISOString();

		this.db
			.prepare(
				`INSERT INTO match_tickets
				 (ticket_hash, match_id, expires_at, consumed_at, created_at, seat, superseded_at)
				 VALUES (?, ?, ?, NULL, ?, ?, NULL)`,
			)
			.run(hashTicket(ticket), matchId, expiresAt, createdAt, seat);

		return { ticket, matchId, expiresAt, seat };
	}
}
