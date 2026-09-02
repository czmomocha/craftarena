import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

import type { MatchQueueKind } from "../../../contracts/src/match_room.ts";
import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	MAX_MATCH_SEATS,
	MIN_MATCH_SEATS,
	isValidMatchSeats,
	type OfficialTraprushCourseId,
} from "../../../contracts/src/official_courses.ts";
import {
	RECONNECT_TICKET_ERRORS,
	type ReconnectTicketError,
	type TicketRejectReason,
} from "../../../contracts/src/match_ticket.ts";
import { MIGRATIONS, SCHEMA_MIGRATIONS_TABLE } from "./migrations.ts";
import { ControlPlaneQueueStore } from "./database_queue.ts";
import { ControlPlaneSessionStore } from "./database_sessions.ts";
import { ControlPlaneTicketStore } from "./database_tickets.ts";

/** 运维 `POST /match-sessions` 省略 seats 时的列默认。不是匹配 HTTP 默认人数。 */
export const DEFAULT_MATCH_SEATS = 8;
export { MIN_MATCH_SEATS, MAX_MATCH_SEATS };
export const isValidSeatCount = isValidMatchSeats;

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
	readonly seats: number;
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
	readonly #sessions: ControlPlaneSessionStore;
	readonly #tickets: ControlPlaneTicketStore;
	readonly #queue: ControlPlaneQueueStore;

	constructor(databasePath: string) {
		if (databasePath !== ":memory:") {
			mkdirSync(dirname(databasePath), { recursive: true });
		}

		this.#db = new DatabaseSync(databasePath);
		this.#sessions = new ControlPlaneSessionStore(this.#db);
		this.#tickets = new ControlPlaneTicketStore(this.#db, this.#sessions);
		this.#queue = new ControlPlaneQueueStore(this.#db, this.#sessions, this.#tickets);
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
		return this.#sessions.insertMatchSession(input);
	}

	deleteMatchSession(matchId: string): MatchSessionRecord {
		return this.#sessions.deleteMatchSession(matchId);
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
		return this.#sessions.insertMatchSettlement(input);
	}

	getMatchSettlement(matchId: string): MatchSettlementRecord | undefined {
		return this.#sessions.getMatchSettlement(matchId);
	}

	getMatchSession(matchId: string): MatchSessionRecord | undefined {
		return this.#sessions.getMatchSession(matchId);
	}

	getMatchSessionByRoomCode(roomCode: string): MatchSessionRecord | undefined {
		return this.#sessions.getMatchSessionByRoomCode(roomCode);
	}

	findOldestOpenRoom(
		course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
	): MatchSessionRecord | undefined {
		return this.#sessions.findOldestOpenRoom(course, seats);
	}

	assignRoomCode(matchId: string, roomCode: string): string {
		return this.#sessions.assignRoomCode(matchId, roomCode);
	}

	assignGeneratedRoomCode(matchId: string, generate: () => string, attempts = 8): string {
		return this.#sessions.assignGeneratedRoomCode(matchId, generate, attempts);
	}

	countTickets(matchId: string): number {
		return this.#tickets.countTickets(matchId);
	}

	readSeatByTicket(ticket: string): number | undefined {
		return this.#tickets.readSeatByTicket(ticket);
	}

	issueTicket(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		return this.#tickets.issueTicket(matchId, now, ttlMs);
	}

	enqueue(
		kind: MatchQueueKind,
		now: Date,
		ttlMs: number,
		course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
	): EnqueuedMatch {
		return this.#queue.enqueue(kind, now, ttlMs, course, seats);
	}

	getQueueByToken(token: string, now: Date): MatchQueueRecord | undefined {
		return this.#queue.getQueueByToken(token, now);
	}

	listWaiting(now: Date): readonly MatchQueueRecord[] {
		return this.#queue.listWaiting(now);
	}

	waitingPosition(tokenHash: string, now: Date): number {
		return this.#queue.waitingPosition(tokenHash, now);
	}

	fulfillWaiter(tokenHash: string, matchId: string, now: Date, ticketTtlMs: number): IssuedTicket {
		return this.#queue.fulfillWaiter(tokenHash, matchId, now, ticketTtlMs);
	}

	markQueueFailed(tokenHash: string, error: string): boolean {
		return this.#queue.markQueueFailed(tokenHash, error);
	}

	cancelQueue(token: string, now: Date): CancelQueueResult {
		return this.#queue.cancelQueue(token, now);
	}

	consumeTicket(ticket: string, now: Date): ConsumeTicketResult {
		return this.#tickets.consumeTicket(ticket, now);
	}

	reconnectTicket(matchId: string, ticket: string, now: Date, ttlMs: number): ReconnectTicketResult {
		return this.#tickets.reconnectTicket(matchId, ticket, now, ttlMs);
	}

	close(): void {
		this.#db.close();
	}
}
