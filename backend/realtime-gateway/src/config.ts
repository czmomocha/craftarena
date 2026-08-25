import { readFileSync } from "node:fs";

export interface GatewayTlsFiles {
	readonly certPath: string;
	readonly keyPath: string;
}

export interface GatewayTlsCredentials {
	readonly key: string;
	readonly cert: string;
}

export interface GatewayConfig {
	readonly host: string;
	readonly port: number;
	/** 控制面基址。网关只通过它做票据校验，绝不直接碰数据库（宪法第二十一条）。 */
	readonly controlPlaneUrl: string;
	/**
	 * 开发期显式旁路：设置后网关改用 DevTicketVerifier，所有非空票据代理到这个地址。
	 * 未设置时走控制面 `POST /tickets/verify`。
	 */
	readonly devUpstreamUrl?: string | undefined;
	readonly version: string;
	readonly logLevel: string;
	/**
	 * 进程内 TLS。两个路径必须成对出现；未设置时仍明文 ws（仅本机开发）。
	 * 对局进程上游始终是内网明文 ws（宪法第二十二条：MatchServer 不暴露公网）。
	 */
	readonly tls?: GatewayTlsFiles | undefined;
}

const DEFAULT_PORT = 8090;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): GatewayConfig {
	return {
		host: env["GATEWAY_HOST"] ?? "127.0.0.1",
		port: parsePort(env["GATEWAY_PORT"], DEFAULT_PORT),
		controlPlaneUrl: (env["CONTROL_PLANE_URL"] ?? "http://127.0.0.1:8080").replace(/\/+$/, ""),
		devUpstreamUrl: emptyToUndefined(env["GATEWAY_DEV_UPSTREAM"]),
		version: env["CRAFTARENA_VERSION"] ?? "0.0.0-dev",
		logLevel: env["GATEWAY_LOG_LEVEL"] ?? "info",
		tls: parseTls(env),
	};
}

/**
 * 读 PEM。调用方必须已经通过 `loadConfig` 确认两条路径成对。
 */
export function readTlsCredentials(tls: GatewayTlsFiles): GatewayTlsCredentials {
	return {
		cert: readFileSync(tls.certPath, "utf8"),
		key: readFileSync(tls.keyPath, "utf8"),
	};
}

function parseTls(env: NodeJS.ProcessEnv): GatewayTlsFiles | undefined {
	const certPath = emptyToUndefined(env["GATEWAY_TLS_CERT"]);
	const keyPath = emptyToUndefined(env["GATEWAY_TLS_KEY"]);
	if (certPath === undefined && keyPath === undefined) {
		return undefined;
	}
	if (certPath === undefined || keyPath === undefined) {
		throw new Error("GATEWAY_TLS_CERT and GATEWAY_TLS_KEY must be set together");
	}
	return { certPath, keyPath };
}

function emptyToUndefined(raw: string | undefined): string | undefined {
	const trimmed = raw?.trim();
	return trimmed === undefined || trimmed === "" ? undefined : trimmed;
}

function parsePort(raw: string | undefined, fallback: number): number {
	if (raw === undefined || raw.trim() === "") {
		return fallback;
	}

	const parsed = Number.parseInt(raw, 10);
	if (!Number.isInteger(parsed) || parsed < 0 || parsed > 65535) {
		throw new Error(`GATEWAY_PORT must be an integer in [0, 65535], received: ${raw}`);
	}

	return parsed;
}
