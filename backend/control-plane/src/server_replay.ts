import type { FastifyInstance } from "fastify";

import {
	TRAPRUSH_REPLAY_ERRORS,
	TRAPRUSH_REPLAY_MAX_BYTES,
	isOfficialTraprushCourseId,
	officialTraprushCoursePath,
	recordMatchReplayBodySchema,
	type RecordMatchReplayRequest,
	type RecordMatchReplayResponse,
	type TraprushReplayListItem,
	type TraprushReplayListResponse,
	type TraprushReplayTape,
	type TraprushReplayView,
} from "../../contracts/src/index.ts";
import { isContentHex } from "./content_sign.ts";
import { readIdentity } from "./server_identity.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import { isMatchId } from "./tickets.ts";
import type { BuildServerOptions, MatchIdParams } from "./server.ts";

interface ReplayIdParams {
	readonly replayId: string;
}

export function registerReplayRoutes(
	app: FastifyInstance,
	options: BuildServerOptions,
	now: () => Date,
): void {
	app.post<{ Params: MatchIdParams; Body: RecordMatchReplayRequest }>(
		"/match-sessions/:matchId/replay",
		{ schema: { body: recordMatchReplayBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ["tape"])) {
				reply.code(400);
				return { error: TRAPRUSH_REPLAY_ERRORS.unexpectedRequestBody };
			}
			if (!isMatchId(request.params.matchId)) {
				reply.code(400);
				return { error: TRAPRUSH_REPLAY_ERRORS.invalidMatchId };
			}
			if (!tapeOk(request.body.tape)) {
				reply.code(400);
				return { error: TRAPRUSH_REPLAY_ERRORS.invalidTape };
			}
			if (JSON.stringify(request.body.tape).length > TRAPRUSH_REPLAY_MAX_BYTES) {
				reply.code(400);
				return { error: TRAPRUSH_REPLAY_ERRORS.tapeTooLarge };
			}
			if (options.database.getMatchSession(request.params.matchId) === undefined) {
				reply.code(404);
				return { error: TRAPRUSH_REPLAY_ERRORS.matchNotFound };
			}
			const stored = options.database.recordTraprushReplay({
				matchId: request.params.matchId,
				tape: request.body.tape,
				now: now(),
			});
			reply.code(201);
			const body: RecordMatchReplayResponse = { matchId: request.params.matchId, stored };
			return body;
		},
	);

	app.get("/traprush-replays", async (request, reply) => {
		const identity = readIdentity(options, request);
		if ("error" in identity) {
			reply.code(identity.status);
			return { error: identity.error };
		}
		const records = options.database.listTraprushReplays(identity.ownerKind, identity.ownerId);
		const body: TraprushReplayListResponse = { items: records.map(listItem) };
		return body;
	});

	app.get<{ Params: ReplayIdParams }>("/traprush-replays/:replayId", async (request, reply) => {
		const identity = readIdentity(options, request);
		if ("error" in identity) {
			reply.code(identity.status);
			return { error: identity.error };
		}
		const record = options.database.getTraprushReplay(
			request.params.replayId,
			identity.ownerKind,
			identity.ownerId,
		);
		if (record === undefined) {
			reply.code(404);
			return { error: TRAPRUSH_REPLAY_ERRORS.notFound };
		}
		let tape: unknown;
		try {
			tape = JSON.parse(record.tapeJson);
		} catch {
			reply.code(500);
			return { error: "replay_corrupt" };
		}
		if (!tapeOk(tape)) {
			reply.code(500);
			return { error: "replay_corrupt" };
		}
		const body: TraprushReplayView = { ...listItem(record), tape };
		return body;
	});
}

function listItem(record: {
	readonly replayId: string;
	readonly matchId: string;
	readonly courseId: string;
	readonly tapeJson: string;
	readonly createdAt: string;
}): TraprushReplayListItem {
	let finishTicks: number[] = [];
	try {
		const parsed = JSON.parse(record.tapeJson) as { finish_ticks?: unknown };
		if (Array.isArray(parsed.finish_ticks)) {
			finishTicks = parsed.finish_ticks.map((value) => Number(value));
		}
	} catch {
		finishTicks = [];
	}
	return {
		replay_id: record.replayId,
		match_id: record.matchId,
		course_id: record.courseId,
		seats: finishTicks.length,
		finish_ticks: finishTicks,
		created_at: record.createdAt,
	};
}

function tapeOk(raw: unknown): raw is TraprushReplayTape {
	if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
		return false;
	}
	const tape = raw as TraprushReplayTape;
	if (!isOfficialTraprushCourseId(tape.course_id)) {
		return false;
	}
	if (tape.official_path !== officialTraprushCoursePath(tape.course_id)) {
		return false;
	}
	if (!isContentHex(tape.content_hash) || tape.content_hash.length !== 64) {
		return false;
	}
	if (!Array.isArray(tape.finish_ticks) || tape.finish_ticks.length !== tape.seats) {
		return false;
	}
	return true;
}
