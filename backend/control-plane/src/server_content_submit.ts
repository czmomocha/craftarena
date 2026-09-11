import { randomBytes } from "node:crypto";
import type { FastifyInstance } from "fastify";

import {
	ACCOUNT_ERRORS,
	CONTENT_SUBMIT_BUNDLE_SCHEMA_MAX,
	CONTENT_SUBMIT_BUNDLE_SCHEMA_MIN,
	CONTENT_SUBMIT_ERRORS,
	contentSubmitBodySchema,
	isOfficialTraprushCourseId,
	type ContentSubmitRequest,
	type ContentSubmitView,
} from "../../contracts/src/index.ts";
import { CONTENT_SIGN_DEV_KEY, isContentHex, signContentMessage } from "./content_sign.ts";
import {
	GuestClaimedError,
	GuestNotFoundError,
	type ContentOwnerKind,
} from "./db/database.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import { bearer, guestPair, readAccount } from "./server_accounts.ts";
import type { BuildServerOptions } from "./server.ts";

const SUBMIT_KEYS = ["bundle", "content_hash"] as const;
const DEMO_COURSE_ID = "course_f_playable";

interface Identity {
	readonly ownerKind: ContentOwnerKind;
	readonly ownerId: string;
}

export function registerContentSubmitRoutes(
	app: FastifyInstance,
	options: BuildServerOptions,
): void {
	const key = options.contentSignKey ?? CONTENT_SIGN_DEV_KEY;
	const now = options.now ?? (() => new Date());

	app.post<{ Body: ContentSubmitRequest }>(
		"/content/submit",
		{ schema: { body: contentSubmitBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, SUBMIT_KEYS)) {
				reply.code(400);
				return { error: CONTENT_SUBMIT_ERRORS.unexpectedRequestBody };
			}
			const identity = readIdentity(options, request);
			if ("error" in identity) {
				reply.code(identity.status);
				return { error: identity.error };
			}
			const body = request.body;
			if (!isContentHex(body.content_hash)) {
				reply.code(400);
				return { error: CONTENT_SUBMIT_ERRORS.hashInvalid };
			}
			if (!bundleShapeOk(body.bundle)) {
				reply.code(400);
				return { error: CONTENT_SUBMIT_ERRORS.bundleInvalid };
			}
			const contentId = mintPlayerContentId(options);
			if (isReservedContentId(contentId)) {
				reply.code(400);
				return { error: CONTENT_SUBMIT_ERRORS.idOfficial };
			}
			const version = 1;
			const signature = signContentMessage(key, contentId, version, body.content_hash);
			const stored = options.database.publishContent({
				contentId,
				version,
				contentHash: body.content_hash,
				signature,
				bundle: body.bundle,
				now: now(),
				ownerKind: identity.ownerKind,
				ownerId: identity.ownerId,
			});
			reply.code(201);
			const view: ContentSubmitView = {
				id: stored.contentId,
				version: stored.version,
				content_hash: stored.contentHash,
				latest: stored.version,
			};
			return view;
		},
	);
}

function readIdentity(
	options: BuildServerOptions,
	request: Parameters<typeof bearer>[0],
): Identity | { error: string; status: number } {
	if (bearer(request) !== undefined) {
		const account = readAccount(options, request);
		if ("error" in account) {
			return { error: account.error, status: 401 };
		}
		return { ownerKind: "account", ownerId: account.accountId };
	}
	const guest = guestPair(request);
	if (guest === undefined) {
		return { error: CONTENT_SUBMIT_ERRORS.sessionInvalid, status: 401 };
	}
	try {
		options.database.guestByRecovery(guest.guestId, guest.recoveryKey);
		return { ownerKind: "guest", ownerId: guest.guestId };
	} catch (error) {
		if (error instanceof GuestNotFoundError) {
			return { error: ACCOUNT_ERRORS.guestNotFound, status: 404 };
		}
		if (error instanceof GuestClaimedError) {
			return { error: ACCOUNT_ERRORS.guestClaimed, status: 409 };
		}
		throw error;
	}
}

function bundleShapeOk(bundle: Record<string, unknown>): boolean {
	if (bundle === null || typeof bundle !== "object" || Array.isArray(bundle)) {
		return false;
	}
	const version = bundle["schema_version"];
	return (
		typeof version === "number" &&
		Number.isInteger(version) &&
		version >= CONTENT_SUBMIT_BUNDLE_SCHEMA_MIN &&
		version <= CONTENT_SUBMIT_BUNDLE_SCHEMA_MAX
	);
}

function isReservedContentId(contentId: string): boolean {
	return isOfficialTraprushCourseId(contentId) || contentId === DEMO_COURSE_ID;
}

function mintPlayerContentId(options: BuildServerOptions): string {
	for (let attempt = 0; attempt < 8; attempt += 1) {
		const contentId = `ugc_${randomBytes(16).toString("hex")}`;
		if (isReservedContentId(contentId)) {
			continue;
		}
		if (options.database.getContentLatest(contentId) !== undefined) {
			continue;
		}
		return contentId;
	}
	throw new Error("failed to allocate a player content id");
}
