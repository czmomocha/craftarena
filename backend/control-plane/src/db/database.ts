import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

import type { MatchQueueKind } from "../../../contracts/src/match_room.ts";
import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isOfficialTraprushCourseId,
	type OfficialTraprushCourseId,
} from "../../../contracts/src/official_courses.ts";
import {
	RECONNECT_TICKET_ERRORS,
	TICKET_REJECT_REASONS,
	type ReconnectTicketError,
	type TicketRejectReason,
} from "../../../contracts/src/match_ticket.ts";
import { generateQueueToken, hashQueueToken } from "../queue.ts";
import { generateTicket, hashTicket } from "../tickets.ts";
import { MIGRATIONS, SCHEMA_MIGRATIONS_TABLE } from "./migrations.ts";

export const DEFAULT_MATCH_SEATS = 8;
export const MIN_MATCH_SEATS = 1;
export const MAX_MATCH_SEATS = 8;

export interface MatchSessionRecord {
	readonly matchId: string;
	readonly upstreamUrl: string;
	readonly createdAt: string;
	readonly roomCode: string | undefined;
	readonly seats: number;
	readonly course: OfficialTraprushCourseId;
}

export interface IssuedTicket {
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
	readonly seat: number;
}

export type ConsumeTicketResult =
	| { readonly ok: true; readonly upstreamUrl: string; readonly seat: number }
	| { readonly ok: false; readonly reason: TicketRejectReason };

export type ReconnectTicketResult =
	| { readonly ok: true } & IssuedTicket
	| { readonly ok: false; readonly error: ReconnectTicketError };

export { RECONNECT_TICKET_ERRORS };

export class MatchSessionExistsError extends Error {
	constructor(matchId: string) {
		super(`match session already exists: ${matchId}`);
		this.name = "MatchSessionExistsError";
	}
}

export class MatchSessionNotFoundError extends Error {
	constructor(matchId: string) {
		super(`match session not found: ${matchId}`);
		this.name = "MatchSessionNotFoundError";
	}
}

export class MatchSessionFullError extends Error {
	constructor(matchId: string) {
		super(`match session is full: ${matchId}`);
		this.name = "MatchSessionFullError";
	}
}

export class RoomCodeConflictError extends Error {
	constructor(roomCode: string) {
		super(`room code already exists: ${roomCode}`);
		this.name = "RoomCodeConflictError";
	}
}

export class MatchQueueNotWaitingError extends Error {
	constructor(tokenHash: string) {
		super(`match queue entry is not waiting: ${tokenHash}`);
		this.name = "MatchQueueNotWaitingError";
	}
}

export class MatchSettlementExistsError extends Error {
	constructor(matchId: string) {
		super(`match settlement already exists: ${matchId}`);
		this.name = "MatchSettlementExistsError";
	}
}

export interface MatchSettlementRecord {
	readonly matchId: string;
	readonly tick: number;
	readonly stateHash: string;
	readonly padTotal: number;
	readonly mvpSlot: number;
	readonly rowsJson: string;
	readonly createdAt: string;
}

export type MatchQueueRowStatus = "waiting" | "ready" | "failed" | "cancelled";

export interface MatchQueueRecord {
	readonly rowid: number;
	readonly tokenHash: string;
	readonly kind: MatchQueueKind;
	readonly status: MatchQueueRowStatus;
	readonly createdAt: string;
	readonly expiresAt: string;
	readonly matchId: string | undefined;
	readonly ticket: string | undefined;
	readonly ticketExpiresAt: string | undefined;
	readonly error: string | undefined;
	readonly course: OfficialTraprushCourseId;
}

export interface EnqueuedMatch {
	readonly token: string;
	readonly createdAt: string;
	readonly expiresAt: string;
}

export type CancelQueueResult = "cancelled" | "ready" | "missing";

/**
 * 控制面对 SQLite 的唯一入口。
 *
 * 宪法第二十一条：一期只有 Fastify 控制面可以直接读写数据库。网关、MatchHost 和
 * Godot MatchServer 必须走控制面 API。因此这个模块**只允许** control-plane 内部导入，
 * 不要把它提到 contracts 或任何共享位置——那样等于把边界让出去。
 */
export class ControlPlaneDatabase {
	readonly #db: DatabaseSync;

	constructor(databasePath: string) {
		if (databasePath !== ":memory:") {
			mkdirSync(dirname(databasePath), { recursive: true });
		}

		this.#db = new DatabaseSync(databasePath);
		// 崩溃后仍能保持一致性，且并发读不被写阻塞。
		this.#db.exec("PRAGMA journal_mode = WAL");
		this.#db.exec("PRAGMA foreign_keys = ON");
	}

	/** 按顺序执行尚未应用的迁移。可重复调用，已应用的会跳过。 */
	migrate(): readonly string[] {
		this.#db.exec(SCHEMA_MIGRATIONS_TABLE);

		const applied = new Set(
			this.#db
				.prepare("SELECT id FROM schema_migrations")
				.all()
				.map((row) => String(row["id"])),
		);

		const newlyApplied: string[] = [];
		const record = this.#db.prepare(
			"INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?)",
		);

		for (const migration of MIGRATIONS) {
			if (applied.has(migration.id)) {
				continue;
			}

			// 一个迁移内的所有语句要么全成功要么全回滚，否则会留下半应用的 schema
			// 却没有记录，下次启动无法自动修复。
			this.#db.exec("BEGIN");
			try {
				for (const statement of migration.statements) {
					this.#db.exec(statement);
				}
				record.run(migration.id, new Date().toISOString());
				this.#db.exec("COMMIT");
			} catch (error) {
				this.#db.exec("ROLLBACK");
				throw error;
			}

			newlyApplied.push(migration.id);
		}

		return newlyApplied;
	}

	/**
	 * 做一次真实的写—读往返。只 open 数据库不足以证明它可用：
	 * 磁盘满、文件只读、WAL 目录不可写这些情况都要等到真正写入才暴露。
	 */
	probeReadWrite(now: Date): boolean {
		const stamp = now.toISOString();
		this.#db
			.prepare("UPDATE readiness_probe SET last_checked_at = ? WHERE id = 1")
			.run(stamp);

		const row = this.#db
			.prepare("SELECT last_checked_at FROM readiness_probe WHERE id = 1")
			.get();

		return row !== undefined && String(row["last_checked_at"]) === stamp;
	}

	insertMatchSession(input: {
		readonly matchId?: string | undefined;
		readonly upstreamUrl: string;
		readonly now: Date;
		readonly seats?: number | undefined;
		readonly course?: OfficialTraprushCourseId | undefined;
	}): MatchSessionRecord {
		const matchId = input.matchId ?? randomUUID();
		const createdAt = input.now.toISOString();
		const seats = input.seats ?? DEFAULT_MATCH_SEATS;
		const course = input.course ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE;

		try {
			this.#db
				.prepare(
					"INSERT INTO match_sessions (match_id, upstream_url, created_at, room_code, seats, course) VALUES (?, ?, ?, NULL, ?, ?)",
				)
				.run(matchId, input.upstreamUrl, createdAt, seats, course);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new MatchSessionExistsError(matchId);
			}
			throw error;
		}

		return { matchId, upstreamUrl: input.upstreamUrl, createdAt, roomCode: undefined, seats, course };
	}

	deleteMatchSession(matchId: string): MatchSessionRecord {
		const existing = this.getMatchSession(matchId);
		if (existing === undefined) {
			throw new MatchSessionNotFoundError(matchId);
		}

		this.#db.exec("BEGIN");
		try {
			this.#db.prepare("DELETE FROM match_tickets WHERE match_id = ?").run(matchId);
			this.#db
				.prepare(
					`UPDATE match_queue
					 SET status = 'failed', error = 'session_unregistered', ticket = NULL, ticket_expires_at = NULL
					 WHERE match_id = ? AND status = 'ready'`,
				)
				.run(matchId);
			this.#db.prepare("DELETE FROM match_sessions WHERE match_id = ?").run(matchId);
			this.#db.exec("COMMIT");
		} catch (error) {
			this.#db.exec("ROLLBACK");
			throw error;
		}

		return existing;
	}

	insertMatchSettlement(input: {
		readonly matchId: string;
		readonly tick: number;
		readonly stateHash: string;
		readonly padTotal: number;
		readonly mvpSlot: number;
		readonly rowsJson: string;
		readonly now: Date;
	}): MatchSettlementRecord {
		if (this.getMatchSession(input.matchId) === undefined) {
			throw new MatchSessionNotFoundError(input.matchId);
		}
		const createdAt = input.now.toISOString();
		try {
			this.#db
				.prepare(
					`INSERT INTO match_settlements
					 (match_id, tick, state_hash, pad_total, mvp_slot, rows_json, created_at)
					 VALUES (?, ?, ?, ?, ?, ?, ?)`,
				)
				.run(
					input.matchId,
					input.tick,
					input.stateHash,
					input.padTotal,
					input.mvpSlot,
					input.rowsJson,
					createdAt,
				);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new MatchSettlementExistsError(input.matchId);
			}
			throw error;
		}
		return {
			matchId: input.matchId,
			tick: input.tick,
			stateHash: input.stateHash,
			padTotal: input.padTotal,
			mvpSlot: input.mvpSlot,
			rowsJson: input.rowsJson,
			createdAt,
		};
	}

	getMatchSettlement(matchId: string): MatchSettlementRecord | undefined {
		const row = this.#db
			.prepare(
				`SELECT match_id, tick, state_hash, pad_total, mvp_slot, rows_json, created_at
				 FROM match_settlements WHERE match_id = ?`,
			)
			.get(matchId);
		return row === undefined ? undefined : settlementFromRow(row);
	}

	getMatchSession(matchId: string): MatchSessionRecord | undefined {
		const row = this.#db
			.prepare(
				"SELECT match_id, upstream_url, created_at, room_code, seats, course FROM match_sessions WHERE match_id = ?",
			)
			.get(matchId);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	getMatchSessionByRoomCode(roomCode: string): MatchSessionRecord | undefined {
		const row = this.#db
			.prepare(
				"SELECT match_id, upstream_url, created_at, room_code, seats, course FROM match_sessions WHERE room_code = ?",
			)
			.get(roomCode);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	/**
	 * 最旧的未满公开房。没有房间码的登记（只走 MatchHost 运维入口）不进快速游戏。
	 * 快速游戏只进同一官方赛道的房。
	 */
	findOldestOpenRoom(course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE): MatchSessionRecord | undefined {
		const row = this.#db
			.prepare(
				`SELECT s.match_id, s.upstream_url, s.created_at, s.room_code, s.seats, s.course
				 FROM match_sessions s
				 WHERE s.room_code IS NOT NULL
				 AND s.course = ?
				 AND (
					SELECT COUNT(DISTINCT t.seat) FROM match_tickets t
					WHERE t.match_id = s.match_id AND t.superseded_at IS NULL
				 ) < s.seats
				 ORDER BY s.created_at ASC
				 LIMIT 1`,
			)
			.get(course);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	assignRoomCode(matchId: string, roomCode: string): string {
		try {
			const updated = this.#db
				.prepare("UPDATE match_sessions SET room_code = ? WHERE match_id = ? AND room_code IS NULL")
				.run(roomCode, matchId);
			if (updated.changes !== 1) {
				if (this.getMatchSession(matchId) === undefined) {
					throw new MatchSessionNotFoundError(matchId);
				}
				throw new MatchSessionExistsError(matchId);
			}
		} catch (error) {
			if (error instanceof MatchSessionNotFoundError || error instanceof MatchSessionExistsError) {
				throw error;
			}
			if (isUniqueConstraint(error)) {
				throw new RoomCodeConflictError(roomCode);
			}
			throw error;
		}

		return roomCode;
	}

	assignGeneratedRoomCode(matchId: string, generate: () => string, attempts = 8): string {
		for (let attempt = 0; attempt < attempts; attempt += 1) {
			try {
				return this.assignRoomCode(matchId, generate());
			} catch (error) {
				if (error instanceof RoomCodeConflictError) {
					continue;
				}
				throw error;
			}
		}

		throw new RoomCodeConflictError("exhausted");
	}

	countTickets(matchId: string): number {
		const row = this.#db
			.prepare(
				`SELECT COUNT(DISTINCT seat) AS ticket_count
				 FROM match_tickets
				 WHERE match_id = ? AND superseded_at IS NULL`,
			)
			.get(matchId);
		return row === undefined ? 0 : Number(row["ticket_count"]);
	}

	issueTicket(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		this.#db.exec("BEGIN");
		try {
			const issued = this.#issueTicketUnlocked(matchId, now, ttlMs);
			this.#db.exec("COMMIT");
			return issued;
		} catch (error) {
			this.#db.exec("ROLLBACK");
			throw error;
		}
	}

	enqueue(kind: MatchQueueKind, now: Date, ttlMs: number, course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE): EnqueuedMatch {
		const token = generateQueueToken();
		const createdAt = now.toISOString();
		const expiresAt = new Date(now.getTime() + ttlMs).toISOString();
		this.#db
			.prepare(
				`INSERT INTO match_queue (
					token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course
				) VALUES (?, ?, 'waiting', ?, ?, NULL, NULL, NULL, NULL, ?)`,
			)
			.run(hashQueueToken(token), kind, createdAt, expiresAt, course);
		return { token, createdAt, expiresAt };
	}

	getQueueByToken(token: string, now: Date): MatchQueueRecord | undefined {
		const row = this.#db
			.prepare(
				`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course
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
		return this.#db
			.prepare(
				`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course
				 FROM match_queue
				 WHERE status = 'waiting' AND expires_at > ?
				 ORDER BY rowid ASC`,
			)
			.all(nowIso)
			.map((row) => queueFromRow(row));
	}

	waitingPosition(tokenHash: string, now: Date): number {
		const nowIso = now.toISOString();
		const row = this.#db
			.prepare(
				`SELECT rowid FROM match_queue WHERE token_hash = ? AND status = 'waiting' AND expires_at > ?`,
			)
			.get(tokenHash, nowIso);
		if (row === undefined) {
			return 0;
		}

		const counted = this.#db
			.prepare(
				`SELECT COUNT(*) AS waiting_count FROM match_queue
				 WHERE status = 'waiting' AND expires_at > ? AND rowid <= ?`,
			)
			.get(nowIso, Number(row["rowid"]));
		return counted === undefined ? 0 : Number(counted["waiting_count"]);
	}

	fulfillWaiter(tokenHash: string, matchId: string, now: Date, ticketTtlMs: number): IssuedTicket {
		this.#db.exec("BEGIN");
		try {
			const row = this.#db
				.prepare(
					`SELECT rowid, token_hash, kind, status, created_at, expires_at, match_id, ticket, ticket_expires_at, error, course
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
			const session = this.getMatchSession(matchId);
			if (session === undefined || session.course !== record.course) {
				throw new MatchSessionFullError(matchId);
			}

			const issued = this.#issueTicketUnlocked(matchId, now, ticketTtlMs);
			const updated = this.#db
				.prepare(
					`UPDATE match_queue
					 SET status = 'ready', match_id = ?, ticket = ?, ticket_expires_at = ?
					 WHERE token_hash = ? AND status = 'waiting'`,
				)
				.run(matchId, issued.ticket, issued.expiresAt, tokenHash);
			if (updated.changes !== 1) {
				throw new MatchQueueNotWaitingError(tokenHash);
			}

			this.#db.exec("COMMIT");
			return issued;
		} catch (error) {
			this.#db.exec("ROLLBACK");
			throw error;
		}
	}

	markQueueFailed(tokenHash: string, error: string): boolean {
		const updated = this.#db
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

		const updated = this.#db
			.prepare("UPDATE match_queue SET status = 'cancelled' WHERE token_hash = ? AND status = 'waiting'")
			.run(record.tokenHash);
		return updated.changes === 1 ? "cancelled" : "missing";
	}

	/**
	 * 一次性消费。同一票据第二次调用必须失败。
	 * 明文从不入库：先哈希再查。
	 */
	consumeTicket(ticket: string, now: Date): ConsumeTicketResult {
		const hash = hashTicket(ticket);
		const nowIso = now.toISOString();

		this.#db.exec("BEGIN");
		try {
			const row = this.#db
				.prepare(
					`SELECT t.expires_at AS expires_at, t.consumed_at AS consumed_at, t.seat AS seat,
					        s.upstream_url AS upstream_url
					 FROM match_tickets t
					 INNER JOIN match_sessions s ON s.match_id = t.match_id
					 WHERE t.ticket_hash = ?`,
				)
				.get(hash);

			if (row === undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.unknownTicket };
			}
			if (row["consumed_at"] !== null && row["consumed_at"] !== undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.consumedTicket };
			}
			if (String(row["expires_at"]) <= nowIso) {
				this.#db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.expiredTicket };
			}

			const updated = this.#db
				.prepare(
					"UPDATE match_tickets SET consumed_at = ? WHERE ticket_hash = ? AND consumed_at IS NULL",
				)
				.run(nowIso, hash);
			if (updated.changes !== 1) {
				this.#db.exec("ROLLBACK");
				return { ok: false, reason: TICKET_REJECT_REASONS.consumedTicket };
			}

			this.#db.exec("COMMIT");
			return {
				ok: true,
				upstreamUrl: String(row["upstream_url"]),
				seat: Number(row["seat"]),
			};
		} catch (error) {
			this.#db.exec("ROLLBACK");
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

		this.#db.exec("BEGIN");
		try {
			const session = this.getMatchSession(matchId);
			if (session === undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.matchNotFound };
			}

			const row = this.#db
				.prepare(
					`SELECT match_id, consumed_at, superseded_at, seat
					 FROM match_tickets
					 WHERE ticket_hash = ?`,
				)
				.get(hash);

			if (row === undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.unknownTicket };
			}
			if (String(row["match_id"]) !== matchId) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.matchMismatch };
			}
			if (row["consumed_at"] === null || row["consumed_at"] === undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.ticketNotConsumed };
			}
			if (row["superseded_at"] !== null && row["superseded_at"] !== undefined) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.supersededTicket };
			}

			const superseded = this.#db
				.prepare(
					"UPDATE match_tickets SET superseded_at = ? WHERE ticket_hash = ? AND superseded_at IS NULL",
				)
				.run(nowIso, hash);
			if (superseded.changes !== 1) {
				this.#db.exec("ROLLBACK");
				return { ok: false, error: RECONNECT_TICKET_ERRORS.supersededTicket };
			}

			const issued = this.#insertTicketUnlocked(matchId, Number(row["seat"]), now, ttlMs);
			this.#db.exec("COMMIT");
			return { ok: true, ...issued };
		} catch (error) {
			this.#db.exec("ROLLBACK");
			throw error;
		}
	}

	close(): void {
		this.#db.close();
	}

	#issueTicketUnlocked(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		const session = this.getMatchSession(matchId);
		if (session === undefined) {
			throw new MatchSessionNotFoundError(matchId);
		}

		const seat = this.#nextSeat(matchId, session.seats);
		if (seat === undefined) {
			throw new MatchSessionFullError(matchId);
		}

		return this.#insertTicketUnlocked(matchId, seat, now, ttlMs);
	}

	#nextSeat(matchId: string, seats: number): number | undefined {
		const rows = this.#db
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

	#insertTicketUnlocked(matchId: string, seat: number, now: Date, ttlMs: number): IssuedTicket {
		const ticket = generateTicket();
		const createdAt = now.toISOString();
		const expiresAt = new Date(now.getTime() + ttlMs).toISOString();

		this.#db
			.prepare(
				`INSERT INTO match_tickets
				 (ticket_hash, match_id, expires_at, consumed_at, created_at, seat, superseded_at)
				 VALUES (?, ?, ?, NULL, ?, ?, NULL)`,
			)
			.run(hashTicket(ticket), matchId, expiresAt, createdAt, seat);

		return { ticket, matchId, expiresAt, seat };
	}
}

function queueFromRow(row: Record<string, unknown>): MatchQueueRecord {
	const matchId = row["match_id"];
	const ticket = row["ticket"];
	const ticketExpiresAt = row["ticket_expires_at"];
	const error = row["error"];
	return {
		rowid: Number(row["rowid"]),
		tokenHash: String(row["token_hash"]),
		kind: row["kind"] === "create_room" ? "create_room" : "quick",
		status: queueStatusFromRow(row["status"]),
		createdAt: String(row["created_at"]),
		expiresAt: String(row["expires_at"]),
		matchId: matchId === null || matchId === undefined ? undefined : String(matchId),
		ticket: ticket === null || ticket === undefined ? undefined : String(ticket),
		ticketExpiresAt:
			ticketExpiresAt === null || ticketExpiresAt === undefined ? undefined : String(ticketExpiresAt),
		error: error === null || error === undefined ? undefined : String(error),
		course: officialCourseFromRow(row["course"]),
	};
}

function queueStatusFromRow(value: unknown): MatchQueueRowStatus {
	if (value === "ready" || value === "failed" || value === "cancelled" || value === "waiting") {
		return value;
	}
	return "waiting";
}

function settlementFromRow(row: Record<string, unknown>): MatchSettlementRecord {
	return {
		matchId: String(row["match_id"]),
		tick: Number(row["tick"]),
		stateHash: String(row["state_hash"]),
		padTotal: Number(row["pad_total"]),
		mvpSlot: Number(row["mvp_slot"]),
		rowsJson: String(row["rows_json"]),
		createdAt: String(row["created_at"]),
	};
}

function sessionFromRow(row: Record<string, unknown>): MatchSessionRecord {
	const roomCode = row["room_code"];
	return {
		matchId: String(row["match_id"]),
		upstreamUrl: String(row["upstream_url"]),
		createdAt: String(row["created_at"]),
		roomCode: roomCode === null || roomCode === undefined ? undefined : String(roomCode),
		seats: Number(row["seats"]),
		course: officialCourseFromRow(row["course"]),
	};
}

function officialCourseFromRow(value: unknown): OfficialTraprushCourseId {
	return isOfficialTraprushCourseId(value) ? value : DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
}

function isUniqueConstraint(error: unknown): boolean {
	return error instanceof Error && error.message.includes("UNIQUE constraint failed");
}

export function isValidSeatCount(value: unknown): value is number {
	return typeof value === "number" && Number.isInteger(value) && value >= MIN_MATCH_SEATS && value <= MAX_MATCH_SEATS;
}
