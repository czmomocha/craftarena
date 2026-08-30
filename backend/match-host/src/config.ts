import { resolve } from "node:path";

import { MATCH_LISTEN_PROBE_HOST } from "./listen_probe.ts";
import { buildMatchUpstreamUrl } from "./registrar.ts";

/** 引擎路径是从哪个环境变量来的。写进启动日志，免得排查时还要猜。 */
export type GodotExecutableSource = "GODOT4" | "GODOT4_CONSOLE";

export interface MatchHostConfig {
	readonly host: string;
	readonly port: number;
	readonly godotExecutable: string;
	readonly godotExecutableSource: GodotExecutableSource;
	readonly godotProjectPath: string;
	readonly matchScene: string;
	readonly portRangeMin: number;
	readonly portRangeMax: number;
	readonly leaseDurationMs: number;
	readonly idleTimeoutMs: number;
	readonly reclaimIntervalMs: number;
	readonly maxConcurrentMatches: number;
	readonly matchCourse: string;
	readonly matchPlayers: number;
	/** 控制面基址。MatchHost 只通过它登记/注销对局上游，绝不直接碰数据库（宪法第二十一条）。 */
	readonly controlPlaneUrl: string;
	/**
	 * 拼进 `ws://{host}:{port}` 的对局广告地址。默认回环；网关与 MatchHost
	 * 不在同一台机器时用 MATCH_HOST_UPSTREAM_HOST 覆盖。不是产品锁定值。
	 */
	readonly upstreamHost: string;
	/**
	 * 等待本场端口 TCP listen 的超时。实现默认，不是产品锁定值。
	 * 探测永远打 127.0.0.1，与广告主机无关。
	 */
	readonly listenTimeoutMs: number;
	readonly listenPollMs: number;
	readonly listenProbeHost: string;
	readonly version: string;
	readonly logLevel: string;
}

const DEFAULT_PORT = 8100;

/** CD-44 §3：默认会话租约 30 分钟。数值的所有者是那份文档，这里只是它的实现默认值。 */
const DEFAULT_LEASE_DURATION_MS = 30 * 60 * 1000;

/** CD-44 §3：连续 10 分钟没有有效输入就关闭进程。 */
const DEFAULT_IDLE_TIMEOUT_MS = 10 * 60 * 1000;

/**
 * 内网临时端口范围。CD-44 只要求"MatchHost 分配内网端口"，没有规定具体号段，
 * 因此这是实现层的默认值而不是产品参数，可以按部署环境覆盖。
 */
const DEFAULT_PORT_RANGE_MIN = 42000;
const DEFAULT_PORT_RANGE_MAX = 42099;

const DEFAULT_RECLAIM_INTERVAL_MS = 15 * 1000;

/** 等 Godot 对本场端口 listen 的实现默认超时，不是产品 Tick / 启动时限。 */
const DEFAULT_LISTEN_TIMEOUT_MS = 15 * 1000;
const DEFAULT_LISTEN_POLL_MS = 50;

/**
 * 开发期默认对局内容：控制面按场下发官方赛道 id 与人数后，本机把 id
 * 映射成 `res://content/official/traprush/{id}.json`，并把人数交给 `--players=`。
 * 空 POST /matches 仍用这些默认。人数上限 8 与 CD-21 的 TRAPRUSH 房间规模一致。
 */
const DEFAULT_MATCH_COURSE = "res://content/official/traprush/course_01.json";
const DEFAULT_MATCH_PLAYERS = 2;
const MAX_MATCH_PLAYERS = 8;

export function loadConfig(
	env: NodeJS.ProcessEnv = process.env,
	platform: NodeJS.Platform = process.platform,
): MatchHostConfig {
	const portRangeMin = parseInteger(env["MATCH_HOST_PORT_RANGE_MIN"], DEFAULT_PORT_RANGE_MIN, "MATCH_HOST_PORT_RANGE_MIN");
	const portRangeMax = parseInteger(env["MATCH_HOST_PORT_RANGE_MAX"], DEFAULT_PORT_RANGE_MAX, "MATCH_HOST_PORT_RANGE_MAX");

	// 并发上限默认等于端口容量：再多也分不到端口，不如在入口就明确拒绝。
	const portCapacity = portRangeMax - portRangeMin + 1;

	const godot = resolveGodotExecutable(env, platform);

	return {
		host: env["MATCH_HOST_HOST"] ?? "127.0.0.1",
		port: parseInteger(env["MATCH_HOST_PORT"], DEFAULT_PORT, "MATCH_HOST_PORT"),
		godotExecutable: godot.executable,
		godotExecutableSource: godot.source,
		godotProjectPath: resolve(env["MATCH_HOST_GODOT_PROJECT"] ?? "./game"),
		matchScene: env["MATCH_HOST_SCENE"] ?? "res://src/server/match_server.tscn",
		portRangeMin,
		portRangeMax,
		leaseDurationMs: parseInteger(env["MATCH_HOST_LEASE_MS"], DEFAULT_LEASE_DURATION_MS, "MATCH_HOST_LEASE_MS"),
		idleTimeoutMs: parseInteger(env["MATCH_HOST_IDLE_MS"], DEFAULT_IDLE_TIMEOUT_MS, "MATCH_HOST_IDLE_MS"),
		reclaimIntervalMs: parseInteger(env["MATCH_HOST_RECLAIM_MS"], DEFAULT_RECLAIM_INTERVAL_MS, "MATCH_HOST_RECLAIM_MS"),
		maxConcurrentMatches: parseInteger(env["MATCH_HOST_MAX_MATCHES"], portCapacity, "MATCH_HOST_MAX_MATCHES"),
		matchCourse: env["MATCH_HOST_COURSE"] ?? DEFAULT_MATCH_COURSE,
		matchPlayers: parsePlayers(env["MATCH_HOST_PLAYERS"]),
		controlPlaneUrl: (env["CONTROL_PLANE_URL"] ?? "http://127.0.0.1:8080").replace(/\/+$/, ""),
		upstreamHost: parseUpstreamHost(env["MATCH_HOST_UPSTREAM_HOST"]),
		listenTimeoutMs: parsePositiveInteger(
			env["MATCH_HOST_LISTEN_TIMEOUT_MS"],
			DEFAULT_LISTEN_TIMEOUT_MS,
			"MATCH_HOST_LISTEN_TIMEOUT_MS",
		),
		listenPollMs: parsePositiveInteger(
			env["MATCH_HOST_LISTEN_POLL_MS"],
			DEFAULT_LISTEN_POLL_MS,
			"MATCH_HOST_LISTEN_POLL_MS",
		),
		listenProbeHost: MATCH_LISTEN_PROBE_HOST,
		version: env["CRAFTARENA_VERSION"] ?? "0.0.0-dev",
		logLevel: env["MATCH_HOST_LOG_LEVEL"] ?? "info",
	};
}

function parseUpstreamHost(raw: string | undefined): string {
	const host = raw === undefined || raw.trim() === "" ? "127.0.0.1" : raw.trim();
	// 用同一套拼装规则预检，避免启动后再在 start() 里才发现 host 非法。
	buildMatchUpstreamUrl(host, 1);
	return host;
}

/**
 * 引擎路径只从环境变量取，不在代码里写死安装位置（与 README 命令表一致）。
 *
 * **没有 PATH 回退。** 以前 `GODOT4` 缺失时会静默退成 `"godot"`，于是配置错误一路
 * 潜伏到第一次 `POST /matches`，才以一个不带原因的 HTTP 502 冒出来（`spawn godot
 * ENOENT` 只留在子进程输出里，没人看得到）。配置缺失属于启动期错误，就在启动期报。
 * 想用 PATH 上的引擎也要显式写出来：`GODOT4=godot`。
 *
 * Windows 上多一层选择：普通 `godot.exe` 是 GUI 子系统程序，不会向父进程的管道写
 * stdout，于是 CD-44 §3 要求的"进程异常时尽力保留日志"会退化成一片空白，崩溃了
 * 也看不到原因。同版本的 `_console.exe` 没有这个问题，所以优先用它。
 * Linux 与 macOS 不存在这个区分，仍然直接用 GODOT4。
 *
 * 代价是 Windows 上会变成两级进程：`_console.exe` 自己再派生一个 `godot.exe`，
 * 因此 MatchHost 记录的 pid 是外层 wrapper 而不是引擎本体，按 pid 排查时要注意。
 * 已实测确认终止 wrapper 会连带回收内层引擎并释放对局端口，不会留下孤儿进程。
 */
function resolveGodotExecutable(
	env: NodeJS.ProcessEnv,
	platform: NodeJS.Platform,
): { readonly executable: string; readonly source: GodotExecutableSource } {
	if (platform === "win32") {
		const consoleExecutable = readNonBlank(env["GODOT4_CONSOLE"]);
		if (consoleExecutable !== undefined) {
			return { executable: consoleExecutable, source: "GODOT4_CONSOLE" };
		}
	}

	const executable = readNonBlank(env["GODOT4"]);
	if (executable === undefined) {
		const variables = platform === "win32" ? "GODOT4_CONSOLE or GODOT4" : "GODOT4";
		throw new Error(
			`${variables} must point at the Godot engine executable; MatchHost does not fall back to a "godot" ` +
				`on PATH, because a missing or mismatched engine would otherwise surface much later as an ` +
				`HTTP 502 with no reason. See CD-51 section 4 and README for the expected value; ` +
				`set GODOT4=godot to opt into a PATH lookup on purpose.`,
		);
	}

	return { executable, source: "GODOT4" };
}

function readNonBlank(raw: string | undefined): string | undefined {
	if (raw === undefined || raw.trim() === "") {
		return undefined;
	}
	return raw;
}

function parsePlayers(raw: string | undefined): number {
	const players = parseInteger(raw, DEFAULT_MATCH_PLAYERS, "MATCH_HOST_PLAYERS");
	if (players < 1 || players > MAX_MATCH_PLAYERS) {
		throw new Error(`MATCH_HOST_PLAYERS must be within [1, ${MAX_MATCH_PLAYERS}], received: ${players}`);
	}
	return players;
}

function parseInteger(raw: string | undefined, fallback: number, name: string): number {
	if (raw === undefined || raw.trim() === "") {
		return fallback;
	}

	const parsed = Number.parseInt(raw, 10);
	if (!Number.isInteger(parsed) || parsed < 0) {
		throw new Error(`${name} must be a non-negative integer, received: ${raw}`);
	}

	return parsed;
}

function parsePositiveInteger(raw: string | undefined, fallback: number, name: string): number {
	const parsed = parseInteger(raw, fallback, name);
	if (parsed < 1) {
		throw new Error(`${name} must be a positive integer, received: ${raw ?? String(fallback)}`);
	}
	return parsed;
}
