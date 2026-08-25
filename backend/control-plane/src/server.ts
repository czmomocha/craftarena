import Fastify, { type FastifyInstance } from "fastify";

import {
	SERVICE_IDS,
	RECONNECT_TICKET_ERRORS,
	TICKET_REJECT_REASONS,
	isReady,
	recordMatchSettlementBodySchema,
	registerMatchSessionBodySchema,
	verifyMatchTicketBodySchema,
	readOfficialMatchBody,
	isOfficialTraprushCourseId,
	type CancelMatchQueueResponse,
	type HealthPayload,
	type IssueMatchTicketResponse,
	type MatchQueueKind,
	type MatchmakingJoinResponse,
	type MatchmakingQueueStatusResponse,
	type MatchmakingQueueWaitingResponse,
	type OfficialTraprushCourseId,
	type ReadinessCheck,
	type ReadinessPayload,
	type MatchSettlementResponse,
	type RecordMatchSettlementRequest,
	type RegisterMatchSessionRequest,
	type RegisterMatchSessionResponse,
	type UnregisterMatchSessionResponse,
	type VerifyMatchTicketRequest,
} from "../../contracts/src/index.ts";
import {
	MatchQueueNotWaitingError,
	MatchSessionExistsError,
	MatchSessionFullError,
	MatchSessionNotFoundError,
	MatchSettlementExistsError,
	isValidSeatCount,
	type ControlPlaneDatabase,
} from "./db/database.ts";
import {
	MatchHostCapacityError,
	MatchHostLaunchError,
	type MatchLauncher,
} from "./match_host.ts";
import { DEFAULT_QUEUE_SLOT_ESTIMATE_MS, DEFAULT_QUEUE_TTL_MS } from "./queue.ts";
import { generateRoomCode, normalizeRoomCode } from "./rooms.ts";
import { isValidSettlementSemantics, settlementRowsFromUnknown } from "./settlement.ts";
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
	/** 匹配队列过期窗口。省略时用开发期占位默认值。 */
	readonly queueTtlMs?: number;
	/** 预计等待位次间隔。省略时用开发期占位默认值。 */
	readonly queueSlotEstimateMs?: number;
	/** 省略时匹配入口回 503。生产路径由 main 注入 HTTP 客户端。 */
	readonly matchLauncher?: MatchLauncher;
}

interface MatchIdParams {
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

	app.post<{ Body: RegisterMatchSessionRequest }>(
		"/match-sessions",
		{ schema: { body: registerMatchSessionBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["upstreamUrl", "matchId", "seats", "course"])) {
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

			const requestedCourse = request.body.course;
			if (requestedCourse !== undefined && !isOfficialTraprushCourseId(requestedCourse)) {
				reply.code(400);
				return { error: "invalid_course" };
			}

			try {
				const record = options.database.insertMatchSession({
					matchId: requestedMatchId,
					upstreamUrl,
					now: now(),
					seats: requestedSeats,
					course: requestedCourse,
				});
				reply.code(201);
				const body: RegisterMatchSessionResponse = {
					matchId: record.matchId,
					upstreamUrl: record.upstreamUrl,
					seats: record.seats,
					course: record.course,
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
				await runDrain();
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

	app.post<{ Params: MatchIdParams; Body: RecordMatchSettlementRequest }>(
		"/match-sessions/:matchId/settlement",
		{ schema: { body: recordMatchSettlementBodySchema } },
		async (request, reply) => {
			if (
				hasUnexpectedKeys(request.body, ["tick", "stateHash", "padTotal", "mvpSlot", "rows"])
			) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (!isMatchId(request.params.matchId)) {
				reply.code(400);
				return { error: "invalid_match_id" };
			}
			if (!isValidSettlementSemantics(request.body)) {
				reply.code(400);
				return { error: "invalid_settlement" };
			}

			const rows = settlementRowsFromUnknown(request.body.rows);
			try {
				const record = options.database.insertMatchSettlement({
					matchId: request.params.matchId,
					tick: request.body.tick,
					stateHash: request.body.stateHash,
					padTotal: request.body.padTotal,
					mvpSlot: request.body.mvpSlot,
					rowsJson: JSON.stringify(rows),
					now: now(),
				});
				reply.code(201);
				const body: MatchSettlementResponse = {
					matchId: record.matchId,
					tick: record.tick,
					stateHash: record.stateHash,
					padTotal: record.padTotal,
					mvpSlot: record.mvpSlot,
					rows,
					createdAt: record.createdAt,
				};
				return body;
			} catch (error) {
				if (error instanceof MatchSessionNotFoundError) {
					reply.code(404);
					return { error: "match_not_found" };
				}
				if (error instanceof MatchSettlementExistsError) {
					reply.code(409);
					return { error: "already_settled" };
				}
				throw error;
			}
		},
	);

	app.get<{ Params: MatchIdParams }>("/match-sessions/:matchId/settlement", async (request, reply) => {
		if (!isMatchId(request.params.matchId)) {
			reply.code(400);
			return { error: "invalid_match_id" };
		}
		const record = options.database.getMatchSettlement(request.params.matchId);
		if (record === undefined) {
			reply.code(404);
			return { error: "settlement_not_found" };
		}
		let rowsUnknown: unknown;
		try {
			rowsUnknown = JSON.parse(record.rowsJson);
		} catch {
			reply.code(500);
			return { error: "settlement_corrupt" };
		}
		if (!Array.isArray(rowsUnknown)) {
			reply.code(500);
			return { error: "settlement_corrupt" };
		}
		const body: MatchSettlementResponse = {
			matchId: record.matchId,
			tick: record.tick,
			stateHash: record.stateHash,
			padTotal: record.padTotal,
			mvpSlot: record.mvpSlot,
			rows: rowsUnknown as MatchSettlementResponse["rows"],
			createdAt: record.createdAt,
		};
		return body;
	});

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
					seat: issued.seat,
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

	app.post<{ Params: MatchIdParams; Body: VerifyMatchTicketRequest }>(
		"/match-sessions/:matchId/tickets/reconnect",
		{ schema: { body: verifyMatchTicketBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["ticket"])) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (!isMatchId(request.params.matchId)) {
				reply.code(400);
				return { error: "invalid_match_id" };
			}

			const ticket = request.body.ticket.trim();
			if (ticket === "") {
				reply.code(400);
				return { error: RECONNECT_TICKET_ERRORS.unknownTicket };
			}

			const result = options.database.reconnectTicket(
				request.params.matchId,
				ticket,
				now(),
				ticketTtlMs,
			);
			if (!result.ok) {
				reply.code(result.error === RECONNECT_TICKET_ERRORS.matchNotFound ? 404 : 400);
				return { error: result.error };
			}

			reply.code(201);
			const body: IssueMatchTicketResponse = {
				ticket: result.ticket,
				matchId: result.matchId,
				expiresAt: result.expiresAt,
				seat: result.seat,
			};
			return body;
		},
	);

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

async function launchOrEnqueue(
	options: BuildServerOptions,
	reply: { code(status: number): void },
	now: () => Date,
	ticketTtlMs: number,
	queueTtlMs: number,
	queueSlotEstimateMs: number,
	kind: MatchQueueKind,
	course: OfficialTraprushCourseId,
	seats: number,
	runDrain: () => Promise<void>,
): Promise<MatchmakingJoinResponse | MatchmakingQueueWaitingResponse | { error: string; message?: string }> {
	if (options.matchLauncher === undefined) {
		reply.code(503);
		return { error: "match_host_unavailable" };
	}

	try {
		const matchId = await launchRegisteredRoom(options, course, seats);
		reply.code(201);
		return admitToRoom(options, matchId, now(), ticketTtlMs);
	} catch (error) {
		if (error instanceof MatchHostCapacityError) {
			const queued = options.database.enqueue(kind, now(), queueTtlMs, course, seats);
			await runDrain();
			const view = viewQueue(options, queued.token, now(), queueSlotEstimateMs);
			if (view !== undefined && view.status === "ready") {
				reply.code(201);
				return readyToJoin(view);
			}
			if (view !== undefined && view.status === "failed") {
				reply.code(502);
				return { error: view.error };
			}
			reply.code(202);
			return (
				view ?? {
					status: "waiting",
					queueToken: queued.token,
					position: 1,
					estimatedWaitMs: queueSlotEstimateMs,
					expiresAt: queued.expiresAt,
					course,
					seats,
				}
			);
		}
		if (error instanceof MatchHostLaunchError) {
			reply.code(502);
			return {
				error: error.message === "session_not_registered" ? "session_not_registered" : "session_launch_failed",
				message: error.message,
			};
		}
		throw error;
	}
}

async function drainQueue(options: BuildServerOptions, now: () => Date, ticketTtlMs: number): Promise<void> {
	let progress = true;
	while (progress) {
		progress = false;
		const instant = now();

		for (const waiter of options.database.listWaiting(instant)) {
			if (waiter.kind !== "quick") {
				continue;
			}
			const open = options.database.findOldestOpenRoom(waiter.course, waiter.seats);
			if (open === undefined) {
				continue;
			}
			try {
				options.database.fulfillWaiter(waiter.tokenHash, open.matchId, now(), ticketTtlMs);
				progress = true;
			} catch (error) {
				if (error instanceof MatchSessionFullError || error instanceof MatchQueueNotWaitingError) {
					continue;
				}
				throw error;
			}
		}

		const head = options.database.listWaiting(now())[0];
		if (head === undefined) {
			return;
		}
		if (head.kind === "quick" && options.database.findOldestOpenRoom(head.course, head.seats) !== undefined) {
			progress = true;
			continue;
		}
		if (options.matchLauncher === undefined) {
			return;
		}

		try {
			const matchId = await launchRegisteredRoom(options, head.course, head.seats);
			try {
				options.database.fulfillWaiter(head.tokenHash, matchId, now(), ticketTtlMs);
			} catch (error) {
				if (!(error instanceof MatchQueueNotWaitingError)) {
					throw error;
				}
			}
			progress = true;
		} catch (error) {
			if (error instanceof MatchHostCapacityError) {
				return;
			}
			if (error instanceof MatchHostLaunchError) {
				options.database.markQueueFailed(
					head.tokenHash,
					error.message === "session_not_registered" ? "session_not_registered" : "session_launch_failed",
				);
				return;
			}
			throw error;
		}
	}
}

async function launchRegisteredRoom(
	options: BuildServerOptions,
	course: OfficialTraprushCourseId,
	seats: number,
): Promise<string> {
	if (options.matchLauncher === undefined) {
		throw new MatchHostLaunchError("match host is unavailable");
	}

	const launched = await options.matchLauncher.launch({ course, seats });
	if (options.database.getMatchSession(launched.matchId) === undefined) {
		throw new MatchHostLaunchError("session_not_registered");
	}

	options.database.assignGeneratedRoomCode(launched.matchId, generateRoomCode);
	return launched.matchId;
}

function viewQueue(
	options: BuildServerOptions,
	queueToken: string,
	now: Date,
	queueSlotEstimateMs: number,
): MatchmakingQueueStatusResponse | undefined {
	const record = options.database.getQueueByToken(queueToken, now);
	if (record === undefined) {
		return undefined;
	}
	if (record.status === "failed") {
		return { status: "failed", error: record.error ?? "session_launch_failed" };
	}
	if (record.status === "ready") {
		if (
			record.matchId === undefined ||
			record.ticket === undefined ||
			record.ticketExpiresAt === undefined
		) {
			return { status: "failed", error: "session_unregistered" };
		}
		const session = options.database.getMatchSession(record.matchId);
		if (session === undefined || session.roomCode === undefined) {
			return { status: "failed", error: "session_unregistered" };
		}
		const seat = options.database.readSeatByTicket(record.ticket);
		if (seat === undefined) {
			return { status: "failed", error: "session_unregistered" };
		}
		return {
			status: "ready",
			roomCode: session.roomCode,
			ticket: record.ticket,
			matchId: record.matchId,
			expiresAt: record.ticketExpiresAt,
			seats: session.seats,
			issued: options.database.countTickets(record.matchId),
			seat,
			course: session.course,
		};
	}

	const position = options.database.waitingPosition(record.tokenHash, now);
	return {
		status: "waiting",
		queueToken,
		position,
		estimatedWaitMs: position * queueSlotEstimateMs,
		expiresAt: record.expiresAt,
		course: record.course,
		seats: record.seats,
	};
}

function readyToJoin(
	view: Extract<MatchmakingQueueStatusResponse, { status: "ready" }>,
): MatchmakingJoinResponse {
	return {
		roomCode: view.roomCode,
		ticket: view.ticket,
		matchId: view.matchId,
		expiresAt: view.expiresAt,
		seats: view.seats,
		issued: view.issued,
		seat: view.seat,
		course: view.course,
	};
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
		seat: issued.seat,
		course: session.course,
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
