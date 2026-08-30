import type { FastifyInstance } from "fastify";

import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	officialTraprushCourseIdFromPath,
} from "../../contracts/src/official_courses.ts";
import { loadConfig } from "./config.ts";
import { GodotProcessLauncher } from "./launcher.ts";
import { TcpMatchListenProbe } from "./listen_probe.ts";
import { ControlPlaneMatchSessionRegistrar } from "./registrar.ts";
import { MatchRegistry } from "./registry.ts";
import { buildMatchHost } from "./server.ts";

const config = loadConfig();

// registry 的事件要写进 app 的日志，而 app 又要拿到 registry。先声明后赋值打破这个环；
// onEvent 只可能在 start/stop 之后触发，那时 app 一定已经存在。
let app: FastifyInstance | undefined;

const registry = new MatchRegistry({
	launcher: new GodotProcessLauncher({
		executable: config.godotExecutable,
		projectPath: config.godotProjectPath,
		scene: config.matchScene,
		course: config.matchCourse,
		players: config.matchPlayers,
	}),
	registrar: new ControlPlaneMatchSessionRegistrar(config.controlPlaneUrl),
	listenProbe: new TcpMatchListenProbe({
		timeoutMs: config.listenTimeoutMs,
		intervalMs: config.listenPollMs,
		host: config.listenProbeHost,
	}),
	upstreamHost: config.upstreamHost,
	seats: config.matchPlayers,
	defaultCourse:
		officialTraprushCourseIdFromPath(config.matchCourse) ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	portRangeMin: config.portRangeMin,
	portRangeMax: config.portRangeMax,
	leaseDurationMs: config.leaseDurationMs,
	idleTimeoutMs: config.idleTimeoutMs,
	maxConcurrentMatches: config.maxConcurrentMatches,
	onEvent: (event) => {
		if (event.type === "stopped") {
			// CD-44 §3 要求进程异常时尽力保留最后的日志。
			app?.log.info(
				{
					matchId: event.matchId,
					port: event.port,
					reason: event.reason,
					recentOutput: event.recentOutput,
				},
				"match stopped",
			);
			return;
		}
		if (event.type === "start_failed") {
			// 拉起失败对调用方只是一个 502，原因必须留在这里，否则排查时无从下手。
			app?.log.error(
				{
					matchId: event.matchId,
					port: event.port,
					godot: config.godotExecutable,
					godotSource: config.godotExecutableSource,
					reason: event.message,
					recentOutput: event.recentOutput,
				},
				"match failed to start",
			);
			return;
		}
		app?.log.info({ matchId: event.matchId, port: event.port }, "match started");
	},
});

app = buildMatchHost({
	registry,
	maxConcurrentMatches: config.maxConcurrentMatches,
	version: config.version,
	logger: { level: config.logLevel },
});

const server = app;

const reclaimTimer = setInterval(() => {
	void (async () => {
		try {
			await registry.flushSettlements();
		} catch (error: unknown) {
			server.log.error({ error }, "failed to flush live settlements");
		}
		try {
			registry.renewFromValidInput();
		} catch (error: unknown) {
			server.log.error({ error }, "failed to renew from valid input");
		}
		try {
			const reclaimed = await registry.reclaimExpired();
			if (reclaimed.length > 0) {
				server.log.info({ count: reclaimed.length }, "reclaimed expired matches");
			}
		} catch (error: unknown) {
			server.log.error({ error }, "failed to reclaim expired matches");
		}
	})();
}, config.reclaimIntervalMs);

let shuttingDown = false;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
	process.on(signal, () => {
		if (shuttingDown) {
			return;
		}
		shuttingDown = true;
		server.log.info({ signal }, "shutting down match host");
		clearInterval(reclaimTimer);
		// 先杀子进程并注销控制面会话，再退出；否则 Godot 会变成孤儿，票据也会指向已死场。
		void registry
			.shutdown()
			.then(() => server.close())
			.then(() => process.exit(0))
			.catch((error: unknown) => {
				server.log.error({ error }, "failed to shut down cleanly");
				process.exit(1);
			});
	});
}

try {
	await server.listen({ host: config.host, port: config.port });
	server.log.info(
		{
			godot: config.godotExecutable,
			godotSource: config.godotExecutableSource,
			scene: config.matchScene,
			portRange: [config.portRangeMin, config.portRangeMax],
			controlPlaneUrl: config.controlPlaneUrl,
			upstreamHost: config.upstreamHost,
		},
		"match host ready",
	);
} catch (error) {
	server.log.error({ error }, "match host failed to start");
	process.exit(1);
}
