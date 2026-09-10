import type { FastifyInstance } from "fastify";

import {
	CONTENT_PLAZA_ERRORS,
	CONTENT_PUBLISH_ERRORS,
	DEFAULT_PLAZA_TAB,
	isPlazaMatchId,
	isPlazaRater,
	isPlazaStars,
	isPlazaTab,
	plazaPlayBodySchema,
	plazaRatingBodySchema,
	readPlazaTags,
	type PlazaItemView,
	type PlazaListView,
	type PlazaPlayRequest,
	type PlazaRatingRequest,
	type PlazaTab,
} from "../../contracts/src/index.ts";
import { isContentId } from "./content_sign.ts";
import {
	ContentVersionMissingError,
	PlazaPlayExistsError,
	PlazaRatingExistsError,
	type PlazaListingRecord,
} from "./db/database.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import type { BuildServerOptions } from "./server.ts";

const PLAY_KEYS = ["match_id"] as const;
const RATE_KEYS = ["rater", "stars", "tags"] as const;

interface ContentIdParams {
	readonly contentId: string;
}

interface PlazaQuery {
	readonly tab?: string;
}

export function registerPlazaRoutes(app: FastifyInstance, options: BuildServerOptions): void {
	const now = options.now ?? (() => new Date());

	app.get<{ Querystring: PlazaQuery }>("/content/plaza", async (request, reply) => {
		const raw = request.query.tab;
		let tab: PlazaTab = DEFAULT_PLAZA_TAB;
		if (raw !== undefined) {
			if (!isPlazaTab(raw)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.tabInvalid };
			}
			tab = raw;
		}
		const body: PlazaListView = {
			tab,
			items: options.database.listPlaza(tab).map(itemViewOf),
		};
		return body;
	});

	app.post<{ Params: ContentIdParams; Body: PlazaPlayRequest }>(
		"/content/:contentId/plays",
		{ schema: { body: plazaPlayBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, PLAY_KEYS)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.unexpectedRequestBody };
			}
			const contentId = request.params.contentId;
			if (!isContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.idInvalid };
			}
			if (!isPlazaMatchId(request.body.match_id)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.matchIdInvalid };
			}
			try {
				return itemViewOf(
					options.database.recordPlazaPlay(contentId, request.body.match_id, now()),
				);
			} catch (error) {
				if (error instanceof ContentVersionMissingError) {
					reply.code(404);
					return { error: CONTENT_PLAZA_ERRORS.contentNotFound };
				}
				if (error instanceof PlazaPlayExistsError) {
					reply.code(409);
					return { error: CONTENT_PLAZA_ERRORS.playExists };
				}
				throw error;
			}
		},
	);

	app.post<{ Params: ContentIdParams; Body: PlazaRatingRequest }>(
		"/content/:contentId/ratings",
		{ schema: { body: plazaRatingBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, RATE_KEYS)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.unexpectedRequestBody };
			}
			const contentId = request.params.contentId;
			if (!isContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.idInvalid };
			}
			if (!isPlazaRater(request.body.rater)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.raterInvalid };
			}
			if (!isPlazaStars(request.body.stars)) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.starsInvalid };
			}
			const tags = readPlazaTags(request.body.tags);
			if (tags === undefined) {
				reply.code(400);
				return { error: CONTENT_PLAZA_ERRORS.tagsInvalid };
			}
			try {
				return itemViewOf(
					options.database.ratePlaza({
						contentId,
						rater: request.body.rater,
						stars: request.body.stars,
						tags,
						now: now(),
					}),
				);
			} catch (error) {
				if (error instanceof ContentVersionMissingError) {
					reply.code(404);
					return { error: CONTENT_PLAZA_ERRORS.contentNotFound };
				}
				if (error instanceof PlazaRatingExistsError) {
					reply.code(409);
					return { error: CONTENT_PLAZA_ERRORS.ratingExists };
				}
				throw error;
			}
		},
	);
}

function itemViewOf(record: PlazaListingRecord): PlazaItemView {
	return {
		content_id: record.contentId,
		version: record.version,
		content_hash: record.contentHash,
		display_name: record.displayName,
		tags: record.tags,
		play_count: record.playCount,
		rating_sum: record.ratingSum,
		rating_count: record.ratingCount,
		verified: record.verified,
		listed_at: record.listedAt,
	};
}
