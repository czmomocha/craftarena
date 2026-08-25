import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	isReady,
	readOfficialCourseBody,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
} from "../../contracts/src/index.ts";
import { MatchCapacityError, type MatchRecord, type MatchRegistry } from "./registry.ts";
import { MatchListenError } from "./listen_probe.ts";
import { MatchSessionRegisterError, MatchSessionSettlementError, MatchSessionUnregisterError } from "./registrar.ts";

export interface BuildMatchHostOptions {
	readonly registry: MatchRegistry;
	readonly maxConcurrentMatches: number;
	readonly version: string;
	readonly logger: boolean | { readonly level: string };
}

interface MatchIdParams {
	readonly id: string;
}

/** 兜底解析器用它标记无法解析的非 JSON body。 */
const UNEXPECTED_BODY = Symbol("unexpected_body");

export function buildMatchHost(options: BuildMatchHostOptions): FastifyInstance {
	const startedAt = Date.now();
	const app = Fastify({ logger: options.logger });

	const uptimeSeconds = (): number => Math.max(0, Math.floor((Date.now() - startedAt) / 1000));

	// POST /matches 接受可选 `{ course }` JSON；空 body 视为默认官方赛道。
	// 未注册的 Content-Type 若走 Fastify 默认会 415，这里兜底读成 JSON 或拒绝。
	app.addContentTypeParser("*", (_request, payload, done) => {
		const chunks: Buffer[] = [];
		payload.on("data", (chunk: Buffer) => {
			chunks.push(chunk);
		});
		payload.on("end", () => {
			const raw = Buffer.concat(chunks);
			if (raw.length === 0) {
				done(null, {});
				return;
			}
			try {
				done(null, JSON.parse(raw.toString("utf8")));
			} catch {
				done(null, UNEXPECTED_BODY);
			}
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
		if (request.body === UNEXPECTED_BODY) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "POST /matches rejected a non-JSON body",
			};
		}
		const courseResult = readOfficialCourseBody(request.body);
		if (!courseResult.ok) {
			reply.code(400);
			return {
				error: courseResult.error,
				message:
					courseResult.error === "invalid_course"
						? "POST /matches only accepts official TRAPRUSH course ids"
						: "POST /matches rejected unexpected fields",
			};
		}

		try {
			const record = await options.registry.start(courseResult.course);
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
		try {
			const record = await options.registry.stop(request.params.id);
			if (record === undefined) {
				reply.code(404);
				return { error: "match_not_found" };
			}
			return toWire(record);
		} catch (error) {
			if (error instanceof MatchSessionUnregisterError) {
				reply.code(502);
				return { error: "session_unregister_failed", message: error.message };
			}
			if (error instanceof MatchSessionSettlementError) {
				reply.code(502);
				return { error: "session_settlement_failed", message: error.message };
			}
			throw error;
		}
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
		seats: record.seats,
		course: record.course,
		startedAt: new Date(record.startedAt).toISOString(),
		leaseExpiresAt: new Date(record.lease.expiresAt).toISOString(),
		lastValidInputAt: new Date(record.lease.lastValidInputAt).toISOString(),
		stopReason: record.stopReason,
	};
}
