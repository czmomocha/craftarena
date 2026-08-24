export interface GatewayConfig {
	readonly host: string;
	readonly port: number;
	/** 控制面基址。网关只通过它做票据校验，绝不直接碰数据库（宪法第二十一条）。 */
	readonly controlPlaneUrl: string;
	/**
	 * 开发期占位上游：DevTicketVerifier 把所有合法票据代理到这个对局进程地址。
	 * 真票据的 票据→对局 解析在控制面（后续章节），生产路径不读这个值。
	 */
	readonly devUpstreamUrl?: string | undefined;
	readonly version: string;
	readonly logLevel: string;
}

const DEFAULT_PORT = 8090;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): GatewayConfig {
	return {
		host: env["GATEWAY_HOST"] ?? "127.0.0.1",
		port: parsePort(env["GATEWAY_PORT"], DEFAULT_PORT),
		controlPlaneUrl: (env["CONTROL_PLANE_URL"] ?? "http://127.0.0.1:8080").replace(/\/+$/, ""),
		devUpstreamUrl: env["GATEWAY_DEV_UPSTREAM"],
		version: env["CRAFTARENA_VERSION"] ?? "0.0.0-dev",
		logLevel: env["GATEWAY_LOG_LEVEL"] ?? "info",
	};
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
