import type { DatabaseSync } from "node:sqlite";

import type { OfficialTraprushCourseId } from "../../../contracts/src/official_courses.ts";
import type { MatchQueueKind } from "../../../contracts/src/match_room.ts";
import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
} from "../../../contracts/src/official_courses.ts";
import { generateQueueToken, hashQueueToken } from "../queue.ts";
import type { ControlPlaneSessionStore } from "./database_sessions.ts";
import type { ControlPlaneTicketStore } from "./database_tickets.ts";
import { queueFromRow } from "./database_rows.ts";
import {
	MatchQueueNotWaitingError,
	MatchSessionFullError,
	type CancelQueueResult,
	type EnqueuedMatch,
	type IssuedTicket,
	type MatchQueueRecord,
} from "./database.ts";

export class ControlPlaneQueueStore {
	readonly db: DatabaseSync;
	readonly sessions: ControlPlaneSessionStore;
	readonly tickets: ControlPlaneTicketStore;

	constructor(
		db: DatabaseSync,
		sessions: ControlPlaneSessionStore,
		tickets: ControlPlaneTicketStore,
	) {
		this.db = db;
		this.sessions = sessions;
		this.tickets = tickets;
	}

	enqueue(
		kind: MatchQueueKind,
		now: Date,
		ttlMs: number,
		course: OfficialTraprushCourseId | "" = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
		contentId?: string,
		contentVersion?: number,
	): EnqueuedMatch {
		const token = generateQueueToken();
		const createdAt = now.toISOString();
		const expiresAt = new Date(now.getTime() + ttlMs).toISOString();
		this.db
			.prepare(
				`INSERT INTO match_queue (
					token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error,
					course, seats, content_id, content_version
				) VALUES (?, ?, 'waiting', ?, ?, NULL, NULL, NULL, NULL, ?, ?, ?, ?)`,
			)
			.run(
				hashQueueToken(token),
				kind,
				createdAt,
				expiresAt,
				course,
				seats,
				contentId ?? null,
				contentVersion ?? null,
			);
		return { token, createdAt, expiresAt };
	}

	getQueueByToken(token: string, now: Date): MatchQueueRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course, seats, content_id, content_version
				 FROM match_queue WHERE token_hash = ?`,
			)
			.get(hashQueueToken(token));
		if (row === undefined) {
			return undefined;
		}

		const record = queueFromRow(row);
		if (record.status === "cancelled") {
			return undefined;
		}
		if (record.status === "waiting" && record.expiresAt <= now.toISOString()) {
			return undefined;
		}
		return record;
	}

	listWaiting(now: Date): readonly MatchQueueRecord[] {
		const nowIso = now.toISOString();
		return this.db
			.prepare(
				`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course, seats, content_id, content_version
				 FROM match_queue
				 WHERE status = 'waiting' AND expires_at > ?
				 ORDER BY rowid ASC`,
			)
			.all(nowIso)
			.map((row) => queueFromRow(row));
	}

	waitingPosition(tokenHash: string, now: Date): number {
		const nowIso = now.toISOString();
		const row = this.db
			.prepare(
				`SELECT rowid FROM match_queue WHERE token_hash = ? AND status = 'waiting' AND expires_at > ?`,
			)
			.get(tokenHash, nowIso);
		if (row === undefined) {
			return 0;
		}

		const counted = this.db
			.prepare(
				`SELECT COUNT(*) AS waiting_count FROM match_queue
				 WHERE status = 'waiting' AND expires_at > ? AND rowid <= ?`,
			)
			.get(nowIso, Number(row["rowid"]));
		return counted === undefined ? 0 : Number(counted["waiting_count"]);
	}

	fulfillWaiter(tokenHash: string, matchId: string, now: Date, ticketTtlMs: number): IssuedTicket {
		this.db.exec("BEGIN");
		try {
			const row = this.db
				.prepare(
					`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course, seats, content_id, content_version
					 FROM match_queue WHERE token_hash = ?`,
				)
				.get(tokenHash);
			if (row === undefined) {
				throw new MatchQueueNotWaitingError(tokenHash);
			}
			const record = queueFromRow(row);
			if (record.status !== "waiting" || record.expiresAt <= now.toISOString()) {
				throw new MatchQueueNotWaitingError(tokenHash);
			}
			const session = this.sessions.getMatchSession(matchId);
			if (
				session === undefined ||
				session.seats !== record.seats ||
				session.course !== record.course ||
				(session.contentId ?? "") !== (record.contentId ?? "") ||
				(session.contentVersion ?? 0) !== (record.contentVersion ?? 0)
			) {
				throw new MatchSessionFullError(matchId);
			}

			const issued = this.tickets.issueTicketUnlocked(matchId, now, ticketTtlMs);
			const updated = this.db
				.prepare(
					`UPDATE match_queue
					 SET status = 'ready', match_id = ?, ticket = ?, ticket_expires_at = ?
					 WHERE token_hash = ? AND status = 'waiting'`,
				)
				.run(matchId, issued.ticket, issued.expiresAt, tokenHash);
			if (updated.changes !== 1) {
				throw new MatchQueueNotWaitingError(tokenHash);
			}

			this.db.exec("COMMIT");
			return issued;
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
	}

	markQueueFailed(tokenHash: string, error: string): boolean {
		const updated = this.db
			.prepare("UPDATE match_queue SET status = 'failed', error = ? WHERE token_hash = ? AND status = 'waiting'")
			.run(error, tokenHash);
		return updated.changes === 1;
	}

	cancelQueue(token: string, now: Date): CancelQueueResult {
		const record = this.getQueueByToken(token, now);
		if (record === undefined) {
			return "missing";
		}
		if (record.status === "ready") {
			return "ready";
		}
		if (record.status !== "waiting") {
			return "missing";
		}

		const updated = this.db
			.prepare("UPDATE match_queue SET status = 'cancelled' WHERE token_hash = ? AND status = 'waiting'")
			.run(record.tokenHash);
		return updated.changes === 1 ? "cancelled" : "missing";
	}
}
