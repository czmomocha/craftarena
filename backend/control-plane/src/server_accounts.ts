import type { FastifyInstance, FastifyRequest } from "fastify";

import {
	ACCOUNT_ERRORS,
	accountClaimBodySchema,
	accountLoginBodySchema,
	accountRegisterBodySchema,
	draftPutBodySchema,
	isAccountPassword,
	isAccountUsername,
	isGuestId,
	isRecoveryKey,
	isSessionToken,
	type AccountClaimRequest,
	type AccountLoginRequest,
	type AccountRegisterRequest,
	type DraftPutRequest,
	type DraftView,
} from "../../contracts/src/index.ts";
import {
	AccountCredentialsError,
	AccountSessionInvalidError,
	AccountUsernameTakenError,
	DraftConflictError,
	DraftMissingError,
	DraftTooLargeError,
	GuestClaimedError,
	GuestNotFoundError,
	type AccountRecord,
	type DraftRecord,
} from "./db/database.ts";
import { hasUnexpectedKeys } from "./server_matchmaking.ts";
import type { BuildServerOptions } from "./server.ts";

const REGISTER_KEYS = ["username", "password", "guest_id", "recovery_key"] as const;
const LOGIN_KEYS = ["username", "password"] as const;
const CLAIM_KEYS = ["guest_id", "recovery_key"] as const;
const DRAFT_KEYS = ["document"] as const;

export function bearer(request: FastifyRequest): string | undefined {
	const header = request.headers.authorization;
	if (typeof header !== "string" || !header.startsWith("Bearer ")) {
		return undefined;
	}
	const token = header.slice("Bearer ".length).trim();
	return isSessionToken(token) ? token : undefined;
}

export function guestPair(request: FastifyRequest): { readonly guestId: string; readonly recoveryKey: string } | undefined {
	const guestId = request.headers["x-guest-id"];
	const recoveryKey = request.headers["x-guest-key"];
	if (typeof guestId !== "string" || typeof recoveryKey !== "string") {
		return undefined;
	}
	if (!isGuestId(guestId) || !isRecoveryKey(recoveryKey)) {
		return undefined;
	}
	return { guestId, recoveryKey };
}

function draftView(record: DraftRecord): DraftView {
	return {
		owner_kind: record.ownerKind,
		owner_id: record.ownerId,
		document: record.document,
		updated_at: record.updatedAt,
	};
}

export function readAccount(options: BuildServerOptions, request: FastifyRequest): AccountRecord | { error: string } {
	const token = bearer(request);
	if (token === undefined) {
		return { error: ACCOUNT_ERRORS.sessionInvalid };
	}
	try {
		return options.database.accountBySession(token);
	} catch (error) {
		if (error instanceof AccountSessionInvalidError) {
			return { error: ACCOUNT_ERRORS.sessionInvalid };
		}
		throw error;
	}
}

export function registerAccountRoutes(app: FastifyInstance, options: BuildServerOptions): void {
	const now = options.now ?? (() => new Date());

	app.post("/accounts/guest", async (request, reply) => {
		if (request.body !== undefined && request.body !== null && Object.keys(request.body as object).length > 0) {
			reply.code(400);
			return { error: ACCOUNT_ERRORS.unexpectedRequestBody };
		}
		const minted = options.database.mintGuest();
		reply.code(201);
		return { guest_id: minted.guestId, recovery_key: minted.recoveryKey };
	});

	app.post<{ Body: AccountRegisterRequest }>(
		"/accounts/register",
		{ schema: { body: accountRegisterBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, REGISTER_KEYS)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.unexpectedRequestBody };
			}
			if (!isAccountUsername(request.body.username)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.usernameInvalid };
			}
			if (!isAccountPassword(request.body.password)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.passwordInvalid };
			}
			const guestId = request.body.guest_id;
			const recoveryKey = request.body.recovery_key;
			if ((guestId === undefined) !== (recoveryKey === undefined)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.guestIdInvalid };
			}
			if (guestId !== undefined && (!isGuestId(guestId) || !isRecoveryKey(recoveryKey))) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.guestIdInvalid };
			}
			try {
				const created = await options.database.registerAccount(
					guestId !== undefined && recoveryKey !== undefined
						? {
							username: request.body.username,
							password: request.body.password,
							guestId,
							recoveryKey,
							now: now(),
						}
						: {
							username: request.body.username,
							password: request.body.password,
							now: now(),
						},
				);
				reply.code(201);
				return { account_id: created.accountId, username: created.username, session: created.session };
			} catch (error) {
				if (error instanceof AccountUsernameTakenError) {
					reply.code(409);
					return { error: ACCOUNT_ERRORS.usernameTaken };
				}
				if (error instanceof GuestNotFoundError) {
					reply.code(404);
					return { error: ACCOUNT_ERRORS.guestNotFound };
				}
				if (error instanceof GuestClaimedError) {
					reply.code(409);
					return { error: ACCOUNT_ERRORS.guestClaimed };
				}
				if (error instanceof DraftConflictError) {
					reply.code(409);
					return { error: ACCOUNT_ERRORS.draftConflict };
				}
				throw error;
			}
		},
	);

	app.post<{ Body: AccountLoginRequest }>(
		"/accounts/login",
		{ schema: { body: accountLoginBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, LOGIN_KEYS)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.unexpectedRequestBody };
			}
			try {
				const opened = await options.database.loginAccount(request.body.username, request.body.password);
				return { account_id: opened.accountId, username: opened.username, session: opened.session };
			} catch (error) {
				if (error instanceof AccountCredentialsError) {
					reply.code(401);
					return { error: ACCOUNT_ERRORS.credentialsInvalid };
				}
				throw error;
			}
		},
	);

	app.get("/accounts/me", async (request, reply) => {
		const account = readAccount(options, request);
		if ("error" in account) {
			reply.code(401);
			return account;
		}
		return { account_id: account.accountId, username: account.username };
	});

	app.post<{ Body: AccountClaimRequest }>(
		"/accounts/claim",
		{ schema: { body: accountClaimBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, CLAIM_KEYS)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.unexpectedRequestBody };
			}
			const account = readAccount(options, request);
			if ("error" in account) {
				reply.code(401);
				return account;
			}
			if (!isGuestId(request.body.guest_id) || !isRecoveryKey(request.body.recovery_key)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.guestIdInvalid };
			}
			try {
				const claimed = options.database.claimGuest(
					account.accountId, request.body.guest_id, request.body.recovery_key,
				);
				return { claimed: true as const, had_draft: claimed.hadDraft };
			} catch (error) {
				if (error instanceof GuestNotFoundError) {
					reply.code(404);
					return { error: ACCOUNT_ERRORS.guestNotFound };
				}
				if (error instanceof GuestClaimedError) {
					reply.code(409);
					return { error: ACCOUNT_ERRORS.guestClaimed };
				}
				if (error instanceof DraftConflictError) {
					reply.code(409);
					return { error: ACCOUNT_ERRORS.draftConflict };
				}
				throw error;
			}
		},
	);

	app.put<{ Body: DraftPutRequest }>(
		"/drafts",
		{ schema: { body: draftPutBodySchema } },
		async (request, reply) => {
			if (hasUnexpectedKeys(request.body, DRAFT_KEYS)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.unexpectedRequestBody };
			}
			const document = request.body.document;
			if (document === null || typeof document !== "object" || Array.isArray(document)) {
				reply.code(400);
				return { error: ACCOUNT_ERRORS.documentInvalid };
			}
			try {
				const account = bearer(request) === undefined ? undefined : readAccount(options, request);
				if (account !== undefined && "error" in account) {
					reply.code(401);
					return account;
				}
				if (account !== undefined) {
					return draftView(options.database.putAccountDraft(account.accountId, document, now()));
				}
				const guest = guestPair(request);
				if (guest === undefined) {
					reply.code(401);
					return { error: ACCOUNT_ERRORS.sessionInvalid };
				}
				options.database.guestByRecovery(guest.guestId, guest.recoveryKey);
				return draftView(options.database.putGuestDraft(guest.guestId, document, now()));
			} catch (error) {
				return draftWriteError(reply, error);
			}
		},
	);

	app.get("/drafts", async (request, reply) => {
		try {
			const account = bearer(request) === undefined ? undefined : readAccount(options, request);
			if (account !== undefined && "error" in account) {
				reply.code(401);
				return account;
			}
			if (account !== undefined) {
				return draftView(options.database.getAccountDraft(account.accountId));
			}
			const guest = guestPair(request);
			if (guest === undefined) {
				reply.code(401);
				return { error: ACCOUNT_ERRORS.sessionInvalid };
			}
			options.database.guestByRecovery(guest.guestId, guest.recoveryKey);
			return draftView(options.database.getGuestDraft(guest.guestId));
		} catch (error) {
			if (error instanceof DraftMissingError) {
				reply.code(404);
				return { error: ACCOUNT_ERRORS.draftMissing };
			}
			if (error instanceof GuestNotFoundError) {
				reply.code(404);
				return { error: ACCOUNT_ERRORS.guestNotFound };
			}
			if (error instanceof GuestClaimedError) {
				reply.code(409);
				return { error: ACCOUNT_ERRORS.guestClaimed };
			}
			throw error;
		}
	});
}

function draftWriteError(reply: { code(status: number): unknown }, error: unknown): { error: string } {
	if (error instanceof DraftTooLargeError) {
		reply.code(413);
		return { error: ACCOUNT_ERRORS.draftTooLarge };
	}
	if (error instanceof GuestNotFoundError) {
		reply.code(404);
		return { error: ACCOUNT_ERRORS.guestNotFound };
	}
	if (error instanceof GuestClaimedError) {
		reply.code(409);
		return { error: ACCOUNT_ERRORS.guestClaimed };
	}
	throw error;
}
