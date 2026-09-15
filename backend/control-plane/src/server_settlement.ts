import type { FastifyInstance } from "fastify";

import {
	recordMatchSettlementBodySchema,
	type MatchSettlementResponse,
	type RecordMatchSettlementRequest,
} from "../../contracts/src/index.ts";
import { MatchSessionNotFoundError, MatchSettlementExistsError } from "./db/database.ts";
import { isValidSettlementSemantics, settlementRowsFromUnknown, settlementTeamsFromUnknown } from "./settlement.ts";
import { isMatchId } from "./tickets.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import type { BuildServerOptions, MatchIdParams } from "./server.ts";

export function registerSettlementRoutes(
	app: FastifyInstance,
	options: BuildServerOptions,
	now: () => Date,
): void {
	app.post<{ Params: MatchIdParams; Body: RecordMatchSettlementRequest }>(
		"/match-sessions/:matchId/settlement",
		{ schema: { body: recordMatchSettlementBodySchema } },
		async (request, reply) => {
			if (
				hasUnexpectedKeys(request.body, ["tick", "stateHash", "padTotal", "mvpSlot", "rows", "teams"])
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
			const teams = settlementTeamsFromUnknown(request.body.teams);
			try {
				const record = options.database.insertMatchSettlement({
					matchId: request.params.matchId,
					tick: request.body.tick,
					stateHash: request.body.stateHash,
					padTotal: request.body.padTotal,
					mvpSlot: request.body.mvpSlot,
					rowsJson: JSON.stringify(rows),
					teamsJson: teams === undefined ? undefined : JSON.stringify(teams),
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
					...(teams === undefined ? {} : { teams }),
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
		if (record.teamsJson !== undefined) {
			try {
				const teamsUnknown: unknown = JSON.parse(record.teamsJson);
				if (!Array.isArray(teamsUnknown)) {
					reply.code(500);
					return { error: "settlement_corrupt" };
				}
				return { ...body, teams: teamsUnknown as NonNullable<MatchSettlementResponse["teams"]> };
			} catch {
				reply.code(500);
				return { error: "settlement_corrupt" };
			}
		}
		return body;
	});
}
