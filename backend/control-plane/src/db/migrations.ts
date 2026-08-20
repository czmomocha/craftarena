export interface Migration {
	readonly id: string;
	readonly statements: readonly string[];
}

/**
 * 迁移只追加、不修改历史条目。已经在任何环境执行过的迁移一旦被改写，
 * 各环境的实际 schema 就会悄悄分叉，而 `schema_migrations` 仍然显示一切正常。
 *
 * 破坏性变更属于宪法第十八条的人类门禁，不允许 AI 自行加入。
 */
/**
 * 迁移记录表自己不能是一条迁移——总得先有地方记录"哪些迁移跑过了"。
 * 它单独 bootstrap，且必须保持 `IF NOT EXISTS` 语义永远可重复执行。
 */
export const SCHEMA_MIGRATIONS_TABLE = `CREATE TABLE IF NOT EXISTS schema_migrations (
	id TEXT PRIMARY KEY,
	applied_at TEXT NOT NULL
) STRICT`;

export const MIGRATIONS: readonly Migration[] = [
	{
		id: "0001_readiness_probe",
		statements: [
			// 单行表。/readyz 每次对它做一次真实的写—读往返，用来证明
			// SQLite 文件确实可写，而不只是"能打开"。
			`CREATE TABLE IF NOT EXISTS readiness_probe (
				id INTEGER PRIMARY KEY CHECK (id = 1),
				last_checked_at TEXT NOT NULL
			) STRICT`,
			`INSERT OR IGNORE INTO readiness_probe (id, last_checked_at) VALUES (1, '')`,
		],
	},
];
