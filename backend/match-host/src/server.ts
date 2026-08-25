import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	isReady,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
} from "../../contracts/src/index.ts";
import { MatchCapacityError, type MatchRecord, type MatchRegistry } from "./registry.ts";
import { MatchListenError } from "./listen_probe.ts";
import { MatchSessionRegisterError } from "./registrar.ts";

export interface BuildMatchHostOptions {
	readonly registry: MatchRegistry;
	readonly maxConcurrentMatches: number;
	readonly version: string;
	readonly logger: boolean | { readonly level: string };
}

interface MatchIdParams {
	readonly id: string;
}

/** 兜底解析器用它标记"收到了非空 body"，由路由决定怎么回。 */
const UNEXPECTED_BODY = Symbol("unexpected_body");

function hasRequestBody(body: unknown): boolean {
	if (body === UNEXPECTED_BODY) {
		return true;
	}
	if (body === undefined || body === null) {
		return false;
	}
	if (typeof body === "string") {
		return body.trim() !== "";
	}
	// 空对象按"没传"处理：客户端发 `{}` 太常见，为它报错只是噪音。
	if (typeof body === "object") {
		return Object.keys(body).length > 0;
	}
	return true;
}

export function buildMatchHost(options: BuildMatchHostOptions): FastifyInstance {
	const startedAt = Date.now();
	const app = Fastify({ logger: options.logger });

	const uptimeSeconds = (): number => Math.max(0, Math.floor((Date.now() - startedAt) / 1000));

	// 本服务的 POST 端点目前都不接受请求体。Fastify 默认对未注册的 Content-Type 直接回 415，
	// 于是 `curl -X POST`（会带上默认 Content-Type）这种最常见的调用方式会失败。
	// 这里兜底接受空 body；带内容的请求交给路由统一拒绝，避免悄悄吞掉调用方以为已生效的参数。
	app.addContentTypeParser("*", (_request, payload, done) => {
		let size = 0;
		payload.on("data", (chunk: Buffer) => {
			size += chunk.length;
		});
		payload.on("end", () => {
			done(null, size === 0 ? {} : UNEXPECTED_BODY);
		});
		payload.on("error", done);
	});

	app.get("/healthz", async (): Promise<HealthPayload> => {
		return {
			service: SERVICE_IDS.matchHost,
			status: "ok",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
		};
	});

	app.get("/readyz", async (_request, reply): Promise<ReadinessPayload> => {
		const occupied = options.registry.occupiedCount();
		const hasCapacity = occupied < options.maxConcurrentMatches;
		const checks: ReadinessCheck[] = [
			{
				name: "match_capacity",
				ok: hasCapacity,
				detail: hasCapacity ? undefined : `all ${options.maxConcurrentMatches} slots in use`,
			},
		];
		const ready = isReady(checks);
		reply.code(ready ? 200 : 503);

		return {
			service: SERVICE_IDS.matchHost,
			status: ready ? "ready" : "not_ready",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
			checks,
		};
	});

	app.get("/matches", async () => ({ matches: options.registry.list().map(toWire) }));

	app.post("/matches", async (request, reply) => {
		// M0 的创建接口还没有参数。与其静默忽略调用方传来的内容，不如明确拒绝——
		// 否则等这个端点将来真的接受玩法与内容版本时，早期调用方会以为自己一直传对了。
		if (hasRequestBody(request.body)) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "POST /matches does not accept a request body yet",
			};
		}

		try {
			const record = await options.registry.start();
			reply.code(201);
			return toWire(record);
		} catch (error) {
			if (error instanceof MatchCapacityError) {
				// 容量满按 CD-44 §2 是排队场景，不是服务故障，所以用 503 而不是 500。
				reply.code(503);
				return { error: "capacity_exhausted", message: error.message };
			}
			if (error instanceof MatchListenError) {
				reply.code(502);
				return { error: "session_listen_failed", message: error.message };
			}
			if (error instanceof MatchSessionRegisterError) {
				// 控制面不可达或拒绝登记：进程已杀掉，对调用方是上游失败，不是本机容量问题。
				reply.code(502);
				return { error: "session_register_failed", message: error.message };
			}
			throw error;
		}
	});

	app.get<{ Params: MatchIdParams }>("/matches/:id", async (request, reply) => {
		const record = options.registry.get(request.params.id);
		if (record === undefined) {
			reply.code(404);
			return { error: "match_not_found" };
		}
		return toWire(record);
	});

	/**
	 * 续租入口。
	 *
	 * M0 只提供骨架：真正的续租应当由权威侧在确认"通过校验且改变权威状态的真人命令"
	 * 之后触发（CD-44 §3），而不是由任何客户端直接调用。等 M3 接入权威对局后，
	 * 这个端点必须收敛到内网并加上调用方身份校验。
	 */
	app.post<{ Params: MatchIdParams }>("/matches/:id/renew", async (request, reply) => {
		const record = options.registry.renew(request.params.id);
		if (record === undefined) {
			reply.code(404);
			return { error: "match_not_found_or_stopped" };
		}
		return toWire(record);
	});

	app.delete<{ Params: MatchIdParams }>("/matches/:id", async (request, reply) => {
		const record = options.registry.stop(request.params.id);
		if (record === undefined) {
			reply.code(404);
			return { error: "match_not_found" };
		}
		return toWire(record);
	});

	return app;
}

function toWire(record: MatchRecord): Record<string, unknown> {
	return {
		matchId: record.matchId,
		port: record.port,
		pid: record.pid,
		state: record.state,
		upstreamUrl: record.upstreamUrl,
		startedAt: new Date(record.startedAt).toISOString(),
		leaseExpiresAt: new Date(record.lease.expiresAt).toISOString(),
		lastValidInputAt: new Date(record.lease.lastValidInputAt).toISOString(),
		stopReason: record.stopReason,
	};
}
