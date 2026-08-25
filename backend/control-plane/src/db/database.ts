import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

import { TICKET_REJECT_REASONS, type TicketRejectReason } from "../../../contracts/src/match_ticket.ts";
import { generateTicket, hashTicket } from "../tickets.ts";
import { MIGRATIONS, SCHEMA_MIGRATIONS_TABLE } from "./migrations.ts";

export interface MatchSessionRecord {
	readonly matchId: string;
	readonly upstreamUrl: string;
	readonly createdAt: string;
}

export interface IssuedTicket {
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
}

export type ConsumeTicketResult =
	| { readonly ok: true; readonly upstreamUrl: string }
	| { readonly ok: false; readonly reason: TicketRejectReason };

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
	}): MatchSessionRecord {
		const matchId = input.matchId ?? randomUUID();
		const createdAt = input.now.toISOString();

		try {
			this.#db
				.prepare("INSERT INTO match_sessions (match_id, upstream_url, created_at) VALUES (?, ?, ?)")
				.run(matchId, input.upstreamUrl, createdAt);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new MatchSessionExistsError(matchId);
			}
			throw error;
		}

		return { matchId, upstreamUrl: input.upstreamUrl, createdAt };
	}

	getMatchSession(matchId: string): MatchSessionRecord | undefined {
		const row = this.#db
			.prepare("SELECT match_id, upstream_url, created_at FROM match_sessions WHERE match_id = ?")
			.get(matchId);
		if (row === undefined) {
			return undefined;
		}

		return {
			matchId: String(row["match_id"]),
			upstreamUrl: String(row["upstream_url"]),
			createdAt: String(row["created_at"]),
		};
	}

	issueTicket(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		if (this.getMatchSession(matchId) === undefined) {
			throw new MatchSessionNotFoundError(matchId);
		}

		const ticket = generateTicket();
		const createdAt = now.toISOString();
		const expiresAt = new Date(now.getTime() + ttlMs).toISOString();

		this.#db
			.prepare(
				"INSERT INTO match_tickets (ticket_hash, match_id, expires_at, consumed_at, created_at) VALUES (?, ?, ?, NULL, ?)",
			)
			.run(hashTicket(ticket), matchId, expiresAt, createdAt);

		return { ticket, matchId, expiresAt };
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
					`SELECT t.expires_at AS expires_at, t.consumed_at AS consumed_at, s.upstream_url AS upstream_url
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
			return { ok: true, upstreamUrl: String(row["upstream_url"]) };
		} catch (error) {
			this.#db.exec("ROLLBACK");
			throw error;
		}
	}

	close(): void {
		this.#db.close();
	}
}

function isUniqueConstraint(error: unknown): boolean {
	return error instanceof Error && error.message.includes("UNIQUE constraint failed");
}
