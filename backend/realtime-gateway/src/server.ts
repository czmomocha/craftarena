import type { Duplex } from "node:stream";

import Fastify, { type FastifyInstance } from "fastify";
import { WebSocketServer, type WebSocket } from "ws";

import {
	SERVICE_IDS,
	isReady,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
} from "../../contracts/src/index.ts";
import type { TicketVerifier } from "./ticket.ts";

export const WEBSOCKET_PATH = "/ws";

export interface ControlPlaneProbe {
	check(): Promise<ReadinessCheck>;
}

export interface BuildGatewayOptions {
	readonly ticketVerifier: TicketVerifier;
	readonly controlPlaneProbe: ControlPlaneProbe;
	readonly version: string;
	readonly logger: boolean | { readonly level: string };
}

export interface Gateway {
	readonly app: FastifyInstance;
	/** 当前已建立的 WebSocket 连接数，测试与运维日志都用它。 */
	connectionCount(): number;
	close(): Promise<void>;
}

/**
 * 实时网关骨架。
 *
 * 宪法第二十二条要求客户端只能连 TLS WebSocket 网关。本进程只讲明文 ws，
 * **TLS 由部署层反向代理终结**——直接把这个进程暴露到公网就违反了那一条。
 *
 * M0 只打通"握手 + 票据边界 + 健康检查"，不实现任何玩法协议：客户端发来的消息
 * 一律回 `gateway_not_implemented`，避免有人误把 echo 当成可用通道去对接。
 */
export function buildGateway(options: BuildGatewayOptions): Gateway {
	const startedAt = Date.now();
	const app = Fastify({ logger: options.logger });
	const wss = new WebSocketServer({ noServer: true });
	const connections = new Set<WebSocket>();

	const uptimeSeconds = (): number => Math.max(0, Math.floor((Date.now() - startedAt) / 1000));

	app.get("/healthz", async (): Promise<HealthPayload> => {
		return {
			service: SERVICE_IDS.realtimeGateway,
			status: "ok",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
		};
	});

	app.get("/readyz", async (_request, reply): Promise<ReadinessPayload> => {
		const checks: ReadinessCheck[] = [await options.controlPlaneProbe.check()];
		const ready = isReady(checks);
		reply.code(ready ? 200 : 503);

		return {
			service: SERVICE_IDS.realtimeGateway,
			status: ready ? "ready" : "not_ready",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
			checks,
		};
	});

	app.server.on("upgrade", (request, socket: Duplex, head: Buffer) => {
		// request.url 只含 path + query，需要一个基址才能用 URL 解析。
		const url = new URL(request.url ?? "/", "http://gateway.invalid");

		if (url.pathname !== WEBSOCKET_PATH) {
			rejectUpgrade(socket, 404, "Not Found");
			return;
		}

		void options.ticketVerifier
			.verify(url.searchParams.get("ticket"))
			.then((verdict) => {
				if (!verdict.ok) {
					app.log.warn({ reason: verdict.reason }, "rejected websocket upgrade");
					rejectUpgrade(socket, 401, "Unauthorized");
					return;
				}

				wss.handleUpgrade(request, socket, head, (ws) => {
					connections.add(ws);
					app.log.info({ connections: connections.size }, "websocket connected");

					ws.send(
						JSON.stringify({
							type: "gateway_hello",
							service: SERVICE_IDS.realtimeGateway,
							version: options.version,
						}),
					);

					ws.on("message", () => {
						ws.send(JSON.stringify({ type: "gateway_not_implemented" }));
					});

					ws.on("close", () => {
						connections.delete(ws);
						app.log.info({ connections: connections.size }, "websocket closed");
					});
				});
			})
			.catch((error: unknown) => {
				app.log.error({ error }, "ticket verification threw");
				rejectUpgrade(socket, 500, "Internal Server Error");
			});
	});

	return {
		app,
		connectionCount: () => connections.size,
		close: async () => {
			for (const ws of connections) {
				ws.close(1001, "gateway shutting down");
			}
			connections.clear();
			await new Promise<void>((resolvePromise) => wss.close(() => resolvePromise()));
			await app.close();
		},
	};
}

function rejectUpgrade(socket: Duplex, statusCode: number, statusText: string): void {
	socket.write(`HTTP/1.1 ${statusCode} ${statusText}\r\nConnection: close\r\n\r\n`);
	socket.destroy();
}

/** 通过控制面的 `/healthz` 判断它是否可达。网关不需要、也不允许知道数据库细节。 */
export class HttpControlPlaneProbe implements ControlPlaneProbe {
	readonly #baseUrl: string;
	readonly #timeoutMs: number;

	constructor(baseUrl: string, timeoutMs = 2000) {
		this.#baseUrl = baseUrl;
		this.#timeoutMs = timeoutMs;
	}

	async check(): Promise<ReadinessCheck> {
		try {
			const response = await fetch(`${this.#baseUrl}/healthz`, {
				signal: AbortSignal.timeout(this.#timeoutMs),
			});

			return response.ok
				? { name: "control_plane_reachable", ok: true }
				: {
						name: "control_plane_reachable",
						ok: false,
						detail: `control plane returned HTTP ${response.status}`,
					};
		} catch (error) {
			return {
				name: "control_plane_reachable",
				ok: false,
				detail: error instanceof Error ? error.message : String(error),
			};
		}
	}
}
