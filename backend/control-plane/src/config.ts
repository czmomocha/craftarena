import { resolve } from "node:path";

import { DEFAULT_TICKET_TTL_MS } from "./tickets.ts";

export interface ControlPlaneConfig {
	readonly host: string;
	readonly port: number;
	/** SQLite 文件的绝对路径，或 `:memory:`（仅测试使用）。 */
	readonly databasePath: string;
	/** 一次性票据过期窗口。开发期占位，不是产品锁定值。 */
	readonly ticketTtlMs: number;
	/** MatchHost 基址。控制面只通过它拉起对局，绝不让 MatchHost 查库。 */
	readonly matchHostUrl: string;
	/**
	 * 等 MatchHost `POST /matches` 的超时。须盖过 listen 探测，实现默认，
	 * 不是产品启动时限。
	 */
	readonly matchHostLaunchTimeoutMs: number;
	readonly version: string;
	readonly logLevel: string;
}

const DEFAULT_PORT = 8080;
const DEFAULT_MATCH_HOST_URL = "http://127.0.0.1:8100";
const DEFAULT_MATCH_HOST_LAUNCH_TIMEOUT_MS = 20_000;

/**
 * 只从环境变量读配置，没有配置文件。
 *
 * CD-51 §3 要求真实密钥留在进程外部，因此这里既不读也不落盘任何凭据；
 * 一旦将来引入密钥，必须继续走环境变量而不是提交到仓库的文件。
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): ControlPlaneConfig {
	const rawDatabasePath = env["CONTROL_PLANE_DB_PATH"] ?? "./data/control-plane.sqlite";

	return {
		host: env["CONTROL_PLANE_HOST"] ?? "127.0.0.1",
		port: parsePort(env["CONTROL_PLANE_PORT"], DEFAULT_PORT),
		databasePath: rawDatabasePath === ":memory:" ? rawDatabasePath : resolve(rawDatabasePath),
		ticketTtlMs: parsePositiveInt(env["CONTROL_PLANE_TICKET_TTL_MS"], DEFAULT_TICKET_TTL_MS, "CONTROL_PLANE_TICKET_TTL_MS"),
		matchHostUrl: (env["MATCH_HOST_URL"] ?? DEFAULT_MATCH_HOST_URL).replace(/\/+$/, ""),
		matchHostLaunchTimeoutMs: parsePositiveInt(
			env["CONTROL_PLANE_MATCH_HOST_LAUNCH_TIMEOUT_MS"],
			DEFAULT_MATCH_HOST_LAUNCH_TIMEOUT_MS,
			"CONTROL_PLANE_MATCH_HOST_LAUNCH_TIMEOUT_MS",
		),
		version: env["CRAFTARENA_VERSION"] ?? "0.0.0-dev",
		logLevel: env["CONTROL_PLANE_LOG_LEVEL"] ?? "info",
	};
}

function parsePort(raw: string | undefined, fallback: number): number {
	if (raw === undefined || raw.trim() === "") {
		return fallback;
	}

	const parsed = Number.parseInt(raw, 10);
	if (!Number.isInteger(parsed) || parsed < 0 || parsed > 65535) {
		throw new Error(`CONTROL_PLANE_PORT must be an integer in [0, 65535], received: ${raw}`);
	}

	return parsed;
}

function parsePositiveInt(raw: string | undefined, fallback: number, name: string): number {
	if (raw === undefined || raw.trim() === "") {
		return fallback;
	}

	const parsed = Number.parseInt(raw, 10);
	if (!Number.isInteger(parsed) || parsed <= 0) {
		throw new Error(`${name} must be a positive integer, received: ${raw}`);
	}

	return parsed;
}
