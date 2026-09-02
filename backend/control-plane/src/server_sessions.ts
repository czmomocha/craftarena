import type { FastifyInstance } from "fastify";

import {
	RECONNECT_TICKET_ERRORS,
	recordMatchSettlementBodySchema,
	registerMatchSessionBodySchema,
	verifyMatchTicketBodySchema,
	type IssueMatchTicketResponse,
	type MatchSettlementResponse,
	type RecordMatchSettlementRequest,
	type RegisterMatchSessionRequest,
	type RegisterMatchSessionResponse,
	type UnregisterMatchSessionResponse,
	isOfficialTraprushCourseId,
	type VerifyMatchTicketRequest,
} from "../../contracts/src/index.ts";
import {
	MatchSessionExistsError,
	MatchSessionFullError,
	MatchSessionNotFoundError,
	MatchSettlementExistsError,
	isValidSeatCount,
} from "./db/database.ts";
import { isValidSettlementSemantics, settlementRowsFromUnknown } from "./settlement.ts";
import { isMatchId, parseUpstreamUrl } from "./tickets.ts";
import { hasRequestBody, hasUnexpectedKeys } from "./server_matchmaking.ts";
import type { BuildServerOptions, MatchIdParams } from "./server.ts";

export function registerSessionRoutes(
	app: FastifyInstance,
	options: BuildServerOptions,
	now: () => Date,
	ticketTtlMs: number,
	runDrain: () => Promise<void>,
): void {
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

}
