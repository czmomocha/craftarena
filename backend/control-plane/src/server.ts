import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	TICKET_REJECT_REASONS,
	isReady,
	registerMatchSessionBodySchema,
	verifyMatchTicketBodySchema,
	type HealthPayload,
	type IssueMatchTicketResponse,
	type MatchmakingJoinResponse,
	type ReadinessCheck,
	type ReadinessPayload,
	type RegisterMatchSessionRequest,
	type RegisterMatchSessionResponse,
	type UnregisterMatchSessionResponse,
	type VerifyMatchTicketRequest,
} from "../../contracts/src/index.ts";
import {
	MatchSessionExistsError,
	MatchSessionFullError,
	MatchSessionNotFoundError,
	isValidSeatCount,
	type ControlPlaneDatabase,
} from "./db/database.ts";
import {
	MatchHostCapacityError,
	MatchHostLaunchError,
	type MatchLauncher,
} from "./match_host.ts";
import { generateRoomCode, normalizeRoomCode } from "./rooms.ts";
import { DEFAULT_TICKET_TTL_MS, isMatchId, parseUpstreamUrl } from "./tickets.ts";

export interface BuildServerOptions {
	readonly database: ControlPlaneDatabase;
	readonly version: string;
	/** 传 false 可以让测试输出保持干净。 */
	readonly logger: boolean | { readonly level: string };
	/** 允许测试注入固定时钟。 */
	readonly now?: () => Date;
	/** 一次性票据过期窗口。省略时用开发期占位默认值。 */
	readonly ticketTtlMs?: number;
	/** 省略时匹配入口回 503。生产路径由 main 注入 HTTP 客户端。 */
	readonly matchLauncher?: MatchLauncher;
}

interface MatchIdParams {
	readonly matchId: string;
}

interface RoomCodeParams {
	readonly roomCode: string;
}

/**
 * 构建 Fastify 实例但不监听端口，这样测试可以用 `inject()` 走完整的路由与序列化，
 * 不必抢占真实端口，也不会在 CI 上因端口冲突随机失败。
 */
export function buildServer(options: BuildServerOptions): FastifyInstance {
	const now = options.now ?? (() => new Date());
	const ticketTtlMs = options.ticketTtlMs ?? DEFAULT_TICKET_TTL_MS;
	const startedAt = now();
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

	app.post<{ Body: RegisterMatchSessionRequest }>(
		"/match-sessions",
		{ schema: { body: registerMatchSessionBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["upstreamUrl", "matchId", "seats"])) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}

			const upstreamUrl = parseUpstreamUrl(request.body.upstreamUrl);
			if (upstreamUrl === undefined) {
				reply.code(400);
				return { error: "invalid_upstream_url" };
			}

			const requestedMatchId = request.body.matchId;
			if (requestedMatchId !== undefined && !isMatchId(requestedMatchId)) {
				reply.code(400);
				return { error: "invalid_match_id" };
			}

			const requestedSeats = request.body.seats;
			if (requestedSeats !== undefined && !isValidSeatCount(requestedSeats)) {
				reply.code(400);
				return { error: "invalid_seats" };
			}

			try {
				const record = options.database.insertMatchSession({
					matchId: requestedMatchId,
					upstreamUrl,
					now: now(),
					seats: requestedSeats,
				});
				reply.code(201);
				const body: RegisterMatchSessionResponse = {
					matchId: record.matchId,
					upstreamUrl: record.upstreamUrl,
					seats: record.seats,
				};
				return body;
			} catch (error) {
				if (error instanceof MatchSessionExistsError) {
					reply.code(409);
					return { error: "match_already_exists" };
				}
				throw error;
			}
		},
	);

	app.delete<{ Params: MatchIdParams }>(
		"/match-sessions/:matchId",
		async (request, reply) => {
			if (hasRequestBody(request.body)) {
				reply.code(400);
				return {
					error: "unexpected_request_body",
					message: "DELETE /match-sessions/:matchId does not accept a request body",
				};
			}
			if (!isMatchId(request.params.matchId)) {
				reply.code(400);
				return { error: "invalid_match_id" };
			}

			try {
				const record = options.database.deleteMatchSession(request.params.matchId);
				const body: UnregisterMatchSessionResponse = { matchId: record.matchId };
				return body;
			} catch (error) {
				if (error instanceof MatchSessionNotFoundError) {
					reply.code(404);
					return { error: "match_not_found" };
				}
				throw error;
			}
		},
	);

	app.post<{ Params: MatchIdParams }>(
		"/match-sessions/:matchId/tickets",
		async (request, reply) => {
			// 签发暂不接受字段（没有账号绑定）。有 body 就拒绝，避免调用方以为
			// playerId 已经生效。
			if (hasRequestBody(request.body)) {
				reply.code(400);
				return {
					error: "unexpected_request_body",
					message: "POST /match-sessions/:matchId/tickets does not accept a request body yet",
				};
			}
			if (!isMatchId(request.params.matchId)) {
				reply.code(400);
				return { error: "invalid_match_id" };
			}

			try {
				const issued = options.database.issueTicket(request.params.matchId, now(), ticketTtlMs);
				reply.code(201);
				const body: IssueMatchTicketResponse = {
					ticket: issued.ticket,
					matchId: issued.matchId,
					expiresAt: issued.expiresAt,
				};
				return body;
			} catch (error) {
				if (error instanceof MatchSessionNotFoundError) {
					reply.code(404);
					return { error: "match_not_found" };
				}
				if (error instanceof MatchSessionFullError) {
					reply.code(409);
					return { error: "match_full" };
				}
				throw error;
			}
		},
	);

	app.post("/matchmaking/quick", async (request, reply) => {
		if (hasRequestBody(request.body)) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "POST /matchmaking/quick does not accept a request body yet",
			};
		}

		const open = options.database.findOldestOpenRoom();
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

		return launchRoom(options, reply, now, ticketTtlMs);
	});

	app.post("/matchmaking/rooms", async (request, reply) => {
		if (hasRequestBody(request.body)) {
			reply.code(400);
			return {
				error: "unexpected_request_body",
				message: "POST /matchmaking/rooms does not accept a request body yet",
			};
		}

		return launchRoom(options, reply, now, ticketTtlMs);
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

			return { ok: true, upstreamUrl: result.upstreamUrl };
		},
	);

	return app;
}

function databaseCheck(database: ControlPlaneDatabase, now: Date): ReadinessCheck {
	try {
		const ok = database.probeReadWrite(now);
		return ok
			? { name: "sqlite_read_write", ok: true }
			: { name: "sqlite_read_write", ok: false, detail: "write succeeded but read back mismatched" };
	} catch (error) {
		return {
			name: "sqlite_read_write",
			ok: false,
			detail: error instanceof Error ? error.message : String(error),
		};
	}
}

function hasUnexpectedKeys(body: unknown, allowed: readonly string[]): boolean {
	if (typeof body !== "object" || body === null) {
		return false;
	}
	return Object.keys(body).some((key) => !allowed.includes(key));
}

async function launchRoom(
	options: BuildServerOptions,
	reply: { code(status: number): void },
	now: () => Date,
	ticketTtlMs: number,
): Promise<MatchmakingJoinResponse | { error: string; message?: string }> {
	if (options.matchLauncher === undefined) {
		reply.code(503);
		return { error: "match_host_unavailable" };
	}

	let launched;
	try {
		launched = await options.matchLauncher.launch();
	} catch (error) {
		if (error instanceof MatchHostCapacityError) {
			reply.code(503);
			return { error: "capacity_exhausted", message: error.message };
		}
		if (error instanceof MatchHostLaunchError) {
			reply.code(502);
			return { error: "session_launch_failed", message: error.message };
		}
		throw error;
	}

	if (options.database.getMatchSession(launched.matchId) === undefined) {
		reply.code(502);
		return { error: "session_not_registered" };
	}

	options.database.assignGeneratedRoomCode(launched.matchId, generateRoomCode);
	reply.code(201);
	return admitToRoom(options, launched.matchId, now(), ticketTtlMs);
}

function admitToRoom(
	options: BuildServerOptions,
	matchId: string,
	now: Date,
	ticketTtlMs: number,
): MatchmakingJoinResponse {
	const issued = options.database.issueTicket(matchId, now, ticketTtlMs);
	const session = options.database.getMatchSession(matchId);
	if (session === undefined || session.roomCode === undefined) {
		throw new MatchSessionNotFoundError(matchId);
	}

	return {
		roomCode: session.roomCode,
		ticket: issued.ticket,
		matchId: issued.matchId,
		expiresAt: issued.expiresAt,
		seats: session.seats,
		issued: options.database.countTickets(matchId),
	};
}

/** 兜底：空对象按「没传」处理，和 MatchHost 的 POST /matches 同一口径。 */
function hasRequestBody(body: unknown): boolean {
	if (body === undefined || body === null) {
		return false;
	}
	if (typeof body === "string") {
		return body.trim() !== "";
	}
	if (typeof body === "object") {
		return Object.keys(body).length > 0;
	}
	return true;
}
