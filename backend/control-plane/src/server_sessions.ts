import type { FastifyInstance } from "fastify";

import {
	RECONNECT_TICKET_ERRORS,
	registerMatchSessionBodySchema,
	verifyMatchTicketBodySchema,
	type IssueMatchTicketResponse,
	type RegisterMatchSessionRequest,
	type RegisterMatchSessionResponse,
	type UnregisterMatchSessionResponse,
	isOfficialTraprushCourseId,
	isOfficialBastionBlueprintId,
	isMatchGameplay,
	MATCH_GAMEPLAY_BASTION,
	MATCH_GAMEPLAY_TRAPRUSH,
	BASTION_MATCH_SEATS,
	DEFAULT_OFFICIAL_BASTION_BLUEPRINT,
	readMatchContentRef,
	type VerifyMatchTicketRequest,
} from "../../contracts/src/index.ts";
import {
	MatchSessionExistsError,
	MatchSessionFullError,
	MatchSessionNotFoundError,
	isValidSeatCount,
} from "./db/database.ts";
import { isMatchId, parseUpstreamUrl } from "./tickets.ts";
import { hasRequestBody, hasUnexpectedKeys } from "./server_matchmaking.ts";
import { registerSettlementRoutes } from "./server_settlement.ts";
import { readIdentityOptional } from "./server_identity.ts";
import type { BuildServerOptions, MatchIdParams } from "./server.ts";

export function registerSessionRoutes(
	app: FastifyInstance,
	options: BuildServerOptions,
	now: () => Date,
	ticketTtlMs: number,
	runDrain: () => Promise<void>,
): void {
	registerSettlementRoutes(app, options, now);
	app.post<{ Body: RegisterMatchSessionRequest }>(
		"/match-sessions",
		{ schema: { body: registerMatchSessionBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["upstreamUrl", "matchId", "seats", "course", "content", "content_hash", "gameplay", "blueprint"])) {
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
			const requestedContent = request.body.content;
			const requestedHash = request.body.content_hash;
			const requestedGameplay = request.body.gameplay;
			const requestedBlueprint = request.body.blueprint;
			if (requestedGameplay !== undefined && !isMatchGameplay(requestedGameplay)) {
				reply.code(400);
				return { error: "invalid_gameplay" };
			}
			const selectorCount =
				(requestedCourse !== undefined ? 1 : 0) +
				(requestedContent !== undefined ? 1 : 0) +
				(requestedBlueprint !== undefined ? 1 : 0);
			if (selectorCount > 1) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (requestedCourse !== undefined && requestedContent !== undefined) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (requestedGameplay === MATCH_GAMEPLAY_BASTION && (requestedCourse !== undefined || requestedContent !== undefined)) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (requestedGameplay === MATCH_GAMEPLAY_TRAPRUSH && requestedBlueprint !== undefined) {
				reply.code(400);
				return { error: "unexpected_request_body" };
			}
			if (requestedContent !== undefined || requestedHash !== undefined) {
				const content = readMatchContentRef(requestedContent);
				if (content === undefined || !isContentHash(requestedHash)) {
					reply.code(400);
					return { error: "invalid_content" };
				}
				const stored = options.database.getContentVersion(content.id, content.version);
				if (stored === undefined || stored.contentHash !== requestedHash) {
					reply.code(400);
					return { error: "invalid_content" };
				}
				try {
					const record = options.database.insertMatchSession({
						matchId: requestedMatchId,
						upstreamUrl,
						now: now(),
						seats: requestedSeats,
						contentId: content.id,
						contentVersion: content.version,
						contentHash: requestedHash,
					});
					reply.code(201);
					const body: RegisterMatchSessionResponse = {
						matchId: record.matchId,
						upstreamUrl: record.upstreamUrl,
						seats: record.seats,
						course: null,
						content,
						content_hash: requestedHash,
					};
					return body;
				} catch (error) {
					if (error instanceof MatchSessionExistsError) {
						reply.code(409);
						return { error: "match_already_exists" };
					}
					throw error;
				}
			}

			if (requestedBlueprint !== undefined || requestedGameplay === MATCH_GAMEPLAY_BASTION) {
				const blueprint = requestedBlueprint ?? DEFAULT_OFFICIAL_BASTION_BLUEPRINT;
				if (!isOfficialBastionBlueprintId(blueprint)) {
					reply.code(400);
					return { error: "invalid_blueprint" };
				}
				if (requestedSeats !== undefined && requestedSeats !== BASTION_MATCH_SEATS) {
					reply.code(400);
					return { error: "invalid_seats" };
				}
				try {
					const record = options.database.insertMatchSession({
						matchId: requestedMatchId,
						upstreamUrl,
						now: now(),
						seats: requestedSeats ?? BASTION_MATCH_SEATS,
						gameplay: MATCH_GAMEPLAY_BASTION,
						blueprint,
					});
					reply.code(201);
					const body: RegisterMatchSessionResponse = {
						matchId: record.matchId,
						upstreamUrl: record.upstreamUrl,
						seats: record.seats,
						course: null,
						gameplay: MATCH_GAMEPLAY_BASTION,
						blueprint,
					};
					return body;
				} catch (error) {
					if (error instanceof MatchSessionExistsError) {
						reply.code(409);
						return { error: "match_already_exists" };
					}
					throw error;
				}
			}

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
				const issued = options.database.issueTicket(
					request.params.matchId,
					now(),
					ticketTtlMs,
					readIdentityOptional(options, request),
				);
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

function isContentHash(value: unknown): value is string {
	return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}
