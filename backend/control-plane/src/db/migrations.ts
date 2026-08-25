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
	{
		id: "0002_match_sessions_and_tickets",
		statements: [
			// 对局会话只存「这场对局的上游地址」。MatchHost 拉起进程后登记到这里；
			// 网关不读这张表（宪法第二十一条）。
			`CREATE TABLE match_sessions (
				match_id TEXT PRIMARY KEY,
				upstream_url TEXT NOT NULL,
				created_at TEXT NOT NULL
			) STRICT`,
			// 明文票据只在签发响应里出现一次。库里只留 sha256，校验时先哈希再查。
			`CREATE TABLE match_tickets (
				ticket_hash TEXT PRIMARY KEY,
				match_id TEXT NOT NULL,
				expires_at TEXT NOT NULL,
				consumed_at TEXT,
				created_at TEXT NOT NULL,
				FOREIGN KEY (match_id) REFERENCES match_sessions (match_id)
			) STRICT`,
			`CREATE INDEX match_tickets_match_id ON match_tickets (match_id)`,
		],
	},
	{
		id: "0003_match_rooms_and_seats",
		statements: [
			// 房间码只给匹配入口用。MatchHost 登记时可以没有码，控制面创建/快速游戏后再写。
			`ALTER TABLE match_sessions ADD COLUMN room_code TEXT`,
			// 未传 seats 的旧登记按 TRAPRUSH 上限 8 记，不是默认开局人数。
			`ALTER TABLE match_sessions ADD COLUMN seats INTEGER NOT NULL DEFAULT 8`,
			`CREATE UNIQUE INDEX match_sessions_room_code ON match_sessions (room_code) WHERE room_code IS NOT NULL`,
		],
	},
	{
		id: "0004_match_queue",
		statements: [
			// 容量满时的 FIFO。token 只存 sha256；就绪后暂存已签发票据明文，
			// 直到条目取消或对局注销。票据表本身仍只存哈希。
			`CREATE TABLE match_queue (
				token_hash TEXT PRIMARY KEY,
				kind TEXT NOT NULL CHECK (kind IN ('quick', 'create_room')),
				status TEXT NOT NULL CHECK (status IN ('waiting', 'ready', 'failed', 'cancelled')),
				created_at TEXT NOT NULL,
				expires_at TEXT NOT NULL,
				match_id TEXT,
				ticket TEXT,
				ticket_expires_at TEXT,
				error TEXT
			) STRICT`,
			`CREATE INDEX match_queue_waiting ON match_queue (status, created_at, token_hash)`,
			`CREATE INDEX match_queue_match_id ON match_queue (match_id)`,
		],
	},
	{
		id: "0005_match_settlements",
		statements: [
			// 单局名次记录。不挂 FK：注销对局会话后记录仍在（CD-13 / CD-14）。
			// 不写 MMR。未全员冲线的限时结算仍待。
			`CREATE TABLE match_settlements (
				match_id TEXT PRIMARY KEY,
				tick INTEGER NOT NULL,
				state_hash TEXT NOT NULL,
				pad_total INTEGER NOT NULL,
				mvp_slot INTEGER NOT NULL,
				rows_json TEXT NOT NULL,
				created_at TEXT NOT NULL
			) STRICT`,
		],
	},
];
