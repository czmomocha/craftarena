import type { FastifyInstance } from "fastify";

import {
	CONTENT_PUBLISH_ERRORS,
	CONTENT_PUBLISH_SCHEMA_VERSION,
	contentPublishBodySchema,
	type ContentPublishRequest,
	type ContentVersionView,
} from "../../contracts/src/index.ts";
import {
	CONTENT_SIGN_DEV_KEY,
	isContentId,
	isContentVersion,
	verifyContentEnvelope,
} from "./content_sign.ts";
import {
	ContentVersionExistsError,
	ContentVersionNotNextError,
	type ContentVersionRecord,
} from "./db/database.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import type { BuildServerOptions } from "./server.ts";

const PUBLISH_KEYS = [
	"schema_version",
	"content_id",
	"version",
	"content_hash",
	"signature",
	"bundle",
] as const;

interface ContentIdParams {
	readonly contentId: string;
}

interface ContentVersionParams extends ContentIdParams {
	readonly version: string;
}

export function registerContentRoutes(app: FastifyInstance, options: BuildServerOptions): void {
	const key = options.contentSignKey ?? CONTENT_SIGN_DEV_KEY;
	const now = options.now ?? (() => new Date());

	app.post<{ Body: ContentPublishRequest }>(
		"/content/publish",
		{ schema: { body: contentPublishBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, PUBLISH_KEYS)) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.unexpectedRequestBody };
			}

			const body = request.body;
			if (typeof body.bundle !== "object" || body.bundle === null || Array.isArray(body.bundle)) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.envelopeKeys };
			}

			const verdict = verifyContentEnvelope(body, key);
			if (verdict !== "ok") {
				reply.code(400);
				return { error: verdict };
			}

			try {
				const stored = options.database.publishContent({
					contentId: body.content_id,
					version: body.version,
					contentHash: body.content_hash,
					signature: body.signature,
					bundle: body.bundle,
					now: now(),
				});
				reply.code(201);
				return viewOf(stored);
			} catch (error) {
				if (error instanceof ContentVersionExistsError) {
					reply.code(409);
					return { error: CONTENT_PUBLISH_ERRORS.versionExists };
				}
				if (error instanceof ContentVersionNotNextError) {
					reply.code(409);
					return { error: CONTENT_PUBLISH_ERRORS.versionNotNext };
				}
				throw error;
			}
		},
	);

	app.get<{ Params: ContentIdParams }>("/content/:contentId/latest", async (request, reply) => {
		const contentId = request.params.contentId;
		if (!isContentId(contentId)) {
			reply.code(400);
			return { error: CONTENT_PUBLISH_ERRORS.idInvalid };
		}
		const stored = options.database.getContentLatest(contentId);
		if (stored === undefined) {
			reply.code(404);
			return { error: CONTENT_PUBLISH_ERRORS.contentNotFound };
		}
		return viewOf(stored);
	});

	app.get<{ Params: ContentVersionParams }>(
		"/content/:contentId/versions/:version",
		async (request, reply) => {
			const contentId = request.params.contentId;
			if (!isContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.idInvalid };
			}
			const version = Number.parseInt(request.params.version, 10);
			if (!isContentVersion(version) || String(version) !== request.params.version) {
				reply.code(400);
				return { error: CONTENT_PUBLISH_ERRORS.versionInvalid };
			}
			const stored = options.database.getContentVersion(contentId, version);
			if (stored === undefined) {
				reply.code(404);
				return { error: CONTENT_PUBLISH_ERRORS.versionNotFound };
			}
			return viewOf(stored);
		},
	);
}

function viewOf(record: ContentVersionRecord): ContentVersionView {
	return {
		schema_version: CONTENT_PUBLISH_SCHEMA_VERSION,
		content_id: record.contentId,
		version: record.version,
		content_hash: record.contentHash,
		signature: record.signature,
		bundle: record.bundle,
	};
}
