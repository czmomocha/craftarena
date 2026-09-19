import type { FastifyRequest } from "fastify";

import { ACCOUNT_ERRORS, CONTENT_SUBMIT_ERRORS } from "../../contracts/src/index.ts";
import {
	GuestClaimedError,
	GuestNotFoundError,
	type ContentOwnerKind,
	type TicketOwner,
} from "./db/database.ts";
import { bearer, guestPair, readAccount } from "./server_accounts.ts";
import type { BuildServerOptions } from "./server.ts";

export type IdentityResult = TicketOwner | { error: string; status: number };

export function readIdentityOptional(
	options: BuildServerOptions,
	request: FastifyRequest,
): TicketOwner | undefined {
	const result = readIdentity(options, request);
	if ("error" in result) {
		return undefined;
	}
	return result;
}

export function readIdentity(
	options: BuildServerOptions,
	request: FastifyRequest,
): IdentityResult {
	if (bearer(request) !== undefined) {
		const account = readAccount(options, request);
		if ("error" in account) {
			return { error: account.error, status: 401 };
		}
		return { ownerKind: "account" as ContentOwnerKind, ownerId: account.accountId };
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
