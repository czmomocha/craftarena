import type { Duplex } from "node:stream";

import Fastify, { type FastifyInstance } from "fastify";
import { WebSocketServer, WebSocket } from "ws";

import {
	SERVICE_IDS,
	isReady,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
} from "../../contracts/src/index.ts";
import { appendSlotQuery, type TicketVerifier } from "./ticket.ts";

export const WEBSOCKET_PATH = "/ws";

export interface ControlPlaneProbe {
	check(): Promise<ReadinessCheck>;
}

export interface BuildGatewayOptions {
	readonly ticketVerifier: TicketVerifier;
	readonly controlPlaneProbe: ControlPlaneProbe;
	readonly version: string;
	readonly logger: boolean | { readonly level: string };
	/** 设置后 Fastify 用 https / 客户端走 wss。省略则明文 ws。 */
	readonly https?: { readonly key: string; readonly cert: string } | undefined;
}

export interface Gateway {
	readonly app: FastifyInstance;
	/** 当前已建立的 WebSocket 连接数，测试与运维日志都用它。 */
	connectionCount(): number;
	close(): Promise<void>;
}

/**
 * 实时网关。
 *
 * 宪法第二十二条要求客户端只能连 TLS WebSocket 网关。设置 `https` 后本进程
 * 在入口终结 TLS（wss）；未设置时仍明文 ws，只许本机开发，不得把明文端口
 * 暴露到公网。对局进程上游始终是内网明文 WebSocket。
 *
 * 代理语义：票据裁决携带上游地址（对局进程的内网 WebSocket），网关把升级后的
 * 连接与上游一对一绑定，双向原样转发帧（二进制/文本标志保留），任一侧关闭或
 * 出错即关闭另一侧。网关不解析帧内容——协议归对局进程与客户端（CD-43），
 * 网关只是宪法要求的唯一入口。M0 的 gateway_hello / gateway_not_implemented
 * 占位已退役：通道现在就是上游协议本身。
 */
export function buildGateway(options: BuildGatewayOptions): Gateway {
	const startedAt = Date.now();
	const app = Fastify({
		logger: options.logger,
		...(options.https === undefined ? {} : { https: options.https }),
	});
	const wss = new WebSocketServer({ noServer: true });
	const connections = new Set<WebSocket>();
	const upstreams = new Map<WebSocket, WebSocket>();

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
				if (verdict.upstreamUrl === undefined) {
					app.log.error("ticket verdict carried no upstream");
					rejectUpgrade(socket, 502, "Bad Gateway");
					return;
				}

				const upstreamUrl =
					typeof verdict.seat === "number"
						? appendSlotQuery(verdict.upstreamUrl, verdict.seat)
						: verdict.upstreamUrl;
				const upstream = new WebSocket(upstreamUrl, { perMessageDeflate: false });
				let upstreamOpen = false;
				upstream.once("open", () => {
					upstreamOpen = true;
					wss.handleUpgrade(request, socket, head, (ws) => {
						connections.add(ws);
						upstreams.set(ws, upstream);
						app.log.info({ connections: connections.size }, "websocket proxied");

						ws.on("message", (data: Buffer, isBinary: boolean) => {
							if (upstream.readyState === WebSocket.OPEN) {
								upstream.send(data, { binary: isBinary });
							}
						});
						upstream.on("message", (data: Buffer, isBinary: boolean) => {
							if (ws.readyState === WebSocket.OPEN) {
								ws.send(data, { binary: isBinary });
							}
						});

						ws.on("close", () => {
							connections.delete(ws);
							upstreams.delete(ws);
							upstream.close();
							app.log.info({ connections: connections.size }, "websocket closed");
						});
						upstream.on("close", () => {
							ws.close();
						});
						upstream.on("error", (error: Error) => {
							app.log.warn({ error }, "upstream websocket errored");
							ws.close(1011, "upstream error");
						});
					});
				});
				upstream.once("error", (error: Error) => {
					if (!upstreamOpen) {
						app.log.warn({ error }, "upstream unreachable");
						rejectUpgrade(socket, 502, "Bad Gateway");
					}
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
			for (const upstream of upstreams.values()) {
				upstream.close();
			}
			connections.clear();
			upstreams.clear();
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
