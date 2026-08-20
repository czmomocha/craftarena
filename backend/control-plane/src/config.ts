import { resolve } from "node:path";

export interface ControlPlaneConfig {
	readonly host: string;
	readonly port: number;
	/** SQLite 文件的绝对路径，或 `:memory:`（仅测试使用）。 */
	readonly databasePath: string;
	readonly version: string;
	readonly logLevel: string;
}

const DEFAULT_PORT = 8080;

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
