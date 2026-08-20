import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

import { MIGRATIONS, SCHEMA_MIGRATIONS_TABLE } from "./migrations.ts";

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

	close(): void {
		this.#db.close();
	}
}
