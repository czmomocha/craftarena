import type { FastifyInstance } from "fastify";

import {
	CONTENT_PATCH_ERRORS,
	CONTENT_PUBLISH_ERRORS,
	CONTENT_PUBLISH_SCHEMA_VERSION,
	classifyPatchOps,
	contentPatchBodySchema,
	contentPublishBodySchema,
	contentRollbackBodySchema,
	livePatchAllowed,
	patchRank,
	type ContentPatchRequest,
	type ContentPatchView,
	type ContentPublishRequest,
	type ContentRollbackRequest,
	type ContentVersionView,
} from "../../contracts/src/index.ts";
import {
	CONTENT_SIGN_DEV_KEY,
	isContentId,
	isContentVersion,
	verifyContentEnvelope,
	verifyPatchEnvelope,
} from "./content_sign.ts";
import {
	ContentAlreadyLatestError,
	ContentPatchSeqNotNextError,
	ContentVersionExistsError,
	ContentVersionMissingError,
	ContentVersionNotNextError,
	type ContentPatchRecord,
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

const PATCH_KEYS = [
	"schema_version",
	"content_id",
	"base_version",
	"seq",
	"level",
	"patch_hash",
	"signature",
	"ops",
] as const;

const ROLLBACK_KEYS = ["schema_version", "target_version"] as const;

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

	app.post<{ Body: ContentPatchRequest }>(
		"/content/patch",
		{ schema: { body: contentPatchBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, PATCH_KEYS)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.unexpectedRequestBody };
			}
			const body = request.body;
			const classified = classifyPatchOps(body.ops);
			if (classified === "invalid") {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.opsInvalid };
			}
			if (!livePatchAllowed(classified)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.levelForbidden };
			}
			if (patchRank(body.level) < patchRank(classified)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.levelUnderreported };
			}
			const verdict = verifyPatchEnvelope(body, key);
			if (verdict !== "ok") {
				reply.code(400);
				return { error: verdict };
			}
			try {
				const stored = options.database.publishContentPatch({
					contentId: body.content_id,
					baseVersion: body.base_version,
					seq: body.seq,
					level: body.level,
					patchHash: body.patch_hash,
					signature: body.signature,
					ops: body.ops,
					now: now(),
				});
				reply.code(201);
				return patchViewOf(stored);
			} catch (error) {
				if (error instanceof ContentVersionMissingError) {
					reply.code(404);
					return { error: CONTENT_PATCH_ERRORS.versionNotFound };
				}
				if (error instanceof ContentPatchSeqNotNextError) {
					reply.code(409);
					return { error: CONTENT_PATCH_ERRORS.seqNotNext };
				}
				throw error;
			}
		},
	);

	app.get<{ Params: ContentIdParams; Querystring: { base_version?: string } }>(
		"/content/:contentId/patches",
		async (request, reply) => {
			const contentId = request.params.contentId;
			if (!isContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.idInvalid };
			}
			const raw = request.query.base_version;
			const baseVersion = raw === undefined ? Number.NaN : Number.parseInt(raw, 10);
			if (!isContentVersion(baseVersion) || String(baseVersion) !== raw) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.versionInvalid };
			}
			const base = options.database.getContentVersion(contentId, baseVersion);
			if (base === undefined) {
				reply.code(404);
				return { error: CONTENT_PATCH_ERRORS.versionNotFound };
			}
			return {
				content_id: contentId,
				base_version: baseVersion,
				patches: options.database.listContentPatches(contentId, baseVersion).map(patchViewOf),
			};
		},
	);

	app.post<{ Params: ContentIdParams; Body: ContentRollbackRequest }>(
		"/content/:contentId/rollback",
		{ schema: { body: contentRollbackBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, ROLLBACK_KEYS)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.unexpectedRequestBody };
			}
			const contentId = request.params.contentId;
			if (!isContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_PATCH_ERRORS.idInvalid };
			}
			try {
				const stored = options.database.rollbackContentLatest(
					contentId,
					request.body.target_version,
				);
				return viewOf(stored);
			} catch (error) {
				if (error instanceof ContentAlreadyLatestError) {
					reply.code(409);
					return { error: CONTENT_PATCH_ERRORS.alreadyLatest };
				}
				if (error instanceof ContentVersionMissingError) {
					reply.code(404);
					return { error: CONTENT_PATCH_ERRORS.versionNotFound };
				}
				throw error;
			}
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

function patchViewOf(record: ContentPatchRecord): ContentPatchView {
	return {
		schema_version: CONTENT_PUBLISH_SCHEMA_VERSION,
		content_id: record.contentId,
		base_version: record.baseVersion,
		seq: record.seq,
		level: record.level,
		patch_hash: record.patchHash,
		signature: record.signature,
		ops: record.ops,
	};
}
