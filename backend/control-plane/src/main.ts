import { loadConfig } from "./config.ts";
import { ControlPlaneDatabase } from "./db/database.ts";
import { MatchHostHttpLauncher } from "./match_host.ts";
import { buildServer } from "./server.ts";

const config = loadConfig();
const database = new ControlPlaneDatabase(config.databasePath);
const applied = database.migrate();

const app = buildServer({
	database,
	version: config.version,
	logger: { level: config.logLevel },
	ticketTtlMs: config.ticketTtlMs,
	queueTtlMs: config.queueTtlMs,
	queueSlotEstimateMs: config.queueSlotEstimateMs,
	matchLauncher: new MatchHostHttpLauncher(config.matchHostUrl, config.matchHostLaunchTimeoutMs),
});

if (applied.length > 0) {
	app.log.info({ appliedMigrations: applied }, "applied database migrations");
}

// 收到停止信号后先停止接受新请求，再关数据库；顺序反过来会让在途请求
// 撞上已关闭的连接，日志里出现一批与真实故障无法区分的错误。
let shuttingDown = false;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
	process.on(signal, () => {
		if (shuttingDown) {
			return;
		}
		shuttingDown = true;
		app.log.info({ signal }, "shutting down control plane");

		void app
			.close()
			.then(() => {
				database.close();
				process.exit(0);
			})
			.catch((error: unknown) => {
				app.log.error({ error }, "failed to shut down cleanly");
				process.exit(1);
			});
	});
}

try {
	await app.listen({ host: config.host, port: config.port });
	app.log.info({ databasePath: config.databasePath }, "control plane ready");
} catch (error) {
	app.log.error({ error }, "control plane failed to start");
	database.close();
	process.exit(1);
}
