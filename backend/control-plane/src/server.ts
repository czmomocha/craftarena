import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	TICKET_REJECT_REASONS,
	isReady,
	verifyMatchTicketBodySchema,
	readOfficialMatchBody,
	type CancelMatchQueueResponse,
	type HealthPayload,
	type ReadinessCheck,
	type ReadinessPayload,
	type VerifyMatchTicketRequest,
} from "../../contracts/src/index.ts";
import {
	MatchSessionFullError,
	type ControlPlaneDatabase,
} from "./db/database.ts";
import { type MatchLauncher } from "./match_host.ts";
import { DEFAULT_QUEUE_SLOT_ESTIMATE_MS, DEFAULT_QUEUE_TTL_MS } from "./queue.ts";
import { normalizeRoomCode } from "./rooms.ts";
import { DEFAULT_TICKET_TTL_MS } from "./tickets.ts";
import {
	admitToRoom,
	databaseCheck,
	drainQueue,
	hasRequestBody,
	hasUnexpectedKeys,
	launchOrEnqueue,
	viewQueue,
} from "./server_matchmaking.ts";
import { registerSessionRoutes } from "./server_sessions.ts";

export interface BuildServerOptions {
	readonly database: ControlPlaneDatabase;
	readonly version: string;
	/** 传 false 可以让测试输出保持干净。 */
	readonly logger: boolean | { readonly level: string };
	/** 允许测试注入固定时钟。 */
	readonly now?: () => Date;
	/** 一次性票据过期窗口。省略时用开发期占位默认值。 */
	readonly ticketTtlMs?: number;
	/** 匹配队列过期窗口。省略时用开发期占位默认值。 */
	readonly queueTtlMs?: number;
	/** 预计等待位次间隔。省略时用开发期占位默认值。 */
	readonly queueSlotEstimateMs?: number;
	/** 省略时匹配入口回 503。生产路径由 main 注入 HTTP 客户端。 */
	readonly matchLauncher?: MatchLauncher;
}

export interface MatchIdParams {
	readonly matchId: string;
}

interface RoomCodeParams {
	readonly roomCode: string;
}

interface QueueTokenParams {
	readonly queueToken: string;
}

/**
 * 构建 Fastify 实例但不监听端口，这样测试可以用 `inject()` 走完整的路由与序列化，
 * 不必抢占真实端口，也不会在 CI 上因端口冲突随机失败。
 */
export function buildServer(options: BuildServerOptions): FastifyInstance {
	const now = options.now ?? (() => new Date());
	const ticketTtlMs = options.ticketTtlMs ?? DEFAULT_TICKET_TTL_MS;
	const queueTtlMs = options.queueTtlMs ?? DEFAULT_QUEUE_TTL_MS;
	const queueSlotEstimateMs = options.queueSlotEstimateMs ?? DEFAULT_QUEUE_SLOT_ESTIMATE_MS;
	const startedAt = now();
	let drainChain: Promise<void> = Promise.resolve();

	const runDrain = (): Promise<void> => {
		drainChain = drainChain.then(() => drainQueue(options, now, ticketTtlMs)).catch(() => undefined);
		return drainChain;
	};
	const app = Fastify({
		logger: options.logger,
		// 默认会 silently 丢掉 additionalProperties。票据契约必须把多出来的字段打回去，
		// 否则调用方会以为 playerId 之类已经生效。
		ajv: {
			customOptions: {
				removeAdditional: false,
				coerceTypes: false,
			},
		},
	});

	const uptimeSeconds = (): number =>
		Math.max(0, Math.floor((now().getTime() - startedAt.getTime()) / 1000));

	app.get("/healthz", async (): Promise<HealthPayload> => {
		return {
			service: SERVICE_IDS.controlPlane,
			status: "ok",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
		};
	});

	app.get("/readyz", async (_request, reply): Promise<ReadinessPayload> => {
		const checks: ReadinessCheck[] = [databaseCheck(options.database, now())];
		const ready = isReady(checks);

		// 未就绪必须是 503。返回 200 会让上游以为这个实例可以接流量。
		reply.code(ready ? 200 : 503);

		return {
			service: SERVICE_IDS.controlPlane,
			status: ready ? "ready" : "not_ready",
			version: options.version,
			uptimeSeconds: uptimeSeconds(),
			checks,
		};
	});

	registerSessionRoutes(app, options, now, ticketTtlMs, runDrain);

	app.post("/matchmaking/quick", async (request, reply) => {
		const matchResult = readOfficialMatchBody(request.body);
		if (!matchResult.ok) {
			reply.code(400);
			return { error: matchResult.error };
		}

		const open = options.database.findOldestOpenRoom(matchResult.course, matchResult.seats);
		if (open !== undefined) {
			try {
				reply.code(201);
				return admitToRoom(options, open.matchId, now(), ticketTtlMs);
			} catch (error) {
				if (!(error instanceof MatchSessionFullError)) {
					throw error;
				}
			}
		}

		return launchOrEnqueue(
			options,
			reply,
			now,
			ticketTtlMs,
			queueTtlMs,
			queueSlotEstimateMs,
			"quick",
			matchResult.course,
			matchResult.seats,
			runDrain,
		);
	});

	app.post("/matchmaking/rooms", async (request, reply) => {
		const matchResult = readOfficialMatchBody(request.body);
		if (!matchResult.ok) {
			reply.code(400);
			return { error: matchResult.error };
		}

		return launchOrEnqueue(
			options,
			reply,
			now,
			ticketTtlMs,
			queueTtlMs,
			queueSlotEstimateMs,
			"create_room",
			matchResult.course,
			matchResult.seats,
			runDrain,
		);
	});

	app.post<{ Params: RoomCodeParams }>(
		"/matchmaking/rooms/:roomCode/join",
		async (request, reply) => {
			if (hasRequestBody(request.body)) {
				reply.code(400);
				return {
					error: "unexpected_request_body",
					message: "POST /matchmaking/rooms/:roomCode/join does not accept a request body yet",
				};
			}

			const roomCode = normalizeRoomCode(request.params.roomCode);
			if (roomCode === undefined) {
				reply.code(400);
				return { error: "invalid_room_code" };
			}

			const session = options.database.getMatchSessionByRoomCode(roomCode);
			if (session === undefined) {
				reply.code(404);
				return { error: "room_not_found" };
			}

			try {
				reply.code(201);
				return admitToRoom(options, session.matchId, now(), ticketTtlMs);
			} catch (error) {
				if (error instanceof MatchSessionFullError) {
					reply.code(409);
					return { error: "room_full" };
				}
				throw error;
			}
		},
	);

	app.get<{ Params: QueueTokenParams }>("/matchmaking/queue/:queueToken", async (request, reply) => {
		if (hasRequestBody(request.body)) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "GET /matchmaking/queue/:queueToken does not accept a request body",
			};
		}

		const queueToken = request.params.queueToken.trim();
		if (queueToken === "") {
			reply.code(400);
			return { error: "invalid_queue_token" };
		}

		const view = viewQueue(options, queueToken, now(), queueSlotEstimateMs);
		if (view === undefined) {
			reply.code(404);
			return { error: "queue_not_found" };
		}
		return view;
	});

	app.delete<{ Params: QueueTokenParams }>("/matchmaking/queue/:queueToken", async (request, reply) => {
		if (hasRequestBody(request.body)) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "DELETE /matchmaking/queue/:queueToken does not accept a request body",
			};
		}

		const queueToken = request.params.queueToken.trim();
		if (queueToken === "") {
			reply.code(400);
			return { error: "invalid_queue_token" };
		}

		const result = options.database.cancelQueue(queueToken, now());
		if (result === "ready") {
			reply.code(409);
			return { error: "queue_already_ready" };
		}
		if (result === "missing") {
			reply.code(404);
			return { error: "queue_not_found" };
		}

		const body: CancelMatchQueueResponse = { ok: true };
		return body;
	});

	app.post<{ Body: VerifyMatchTicketRequest }>(
		"/tickets/verify",
		{ schema: { body: verifyMatchTicketBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["ticket"])) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}

			const ticket = request.body.ticket.trim();
			if (ticket === "") {
				reply.code(401);
				return { ok: false, reason: TICKET_REJECT_REASONS.missingTicket };
			}

			const result = options.database.consumeTicket(ticket, now());
			if (!result.ok) {
				reply.code(401);
				return { ok: false, reason: result.reason };
			}

			return { ok: true, upstreamUrl: result.upstreamUrl, seat: result.seat };
		},
	);

	return app;
}
