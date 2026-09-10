import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

import { DRAFT_JSON_MAX, isAccountPassword, isAccountUsername } from "../../../contracts/src/account.ts";
import { generateTicket, hashTicket } from "../tickets.ts";
import { isUniqueConstraint } from "./database_rows.ts";

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEYLEN = 32;

function derivePassword(password: string, salt: Buffer, n: number, r: number, p: number): Buffer {
	return scryptSync(password, salt, SCRYPT_KEYLEN, { N: n, r, p, maxmem: 64 * 1024 * 1024 });
}

export class AccountUsernameTakenError extends Error {
	constructor(username: string) {
		super(`account username taken: ${username}`);
		this.name = "AccountUsernameTakenError";
	}
}
export class AccountCredentialsError extends Error {
	constructor() {
		super("account credentials invalid");
		this.name = "AccountCredentialsError";
	}
}
export class GuestNotFoundError extends Error {
	constructor(guestId: string) {
		super(`guest not found: ${guestId}`);
		this.name = "GuestNotFoundError";
	}
}
export class GuestClaimedError extends Error {
	constructor(guestId: string) {
		super(`guest already claimed: ${guestId}`);
		this.name = "GuestClaimedError";
	}
}
export class AccountSessionInvalidError extends Error {
	constructor() {
		super("account session invalid");
		this.name = "AccountSessionInvalidError";
	}
}
export class DraftConflictError extends Error {
	constructor() {
		super("account and guest both have drafts");
		this.name = "DraftConflictError";
	}
}
export class DraftMissingError extends Error {
	constructor() {
		super("draft missing");
		this.name = "DraftMissingError";
	}
}
export class DraftTooLargeError extends Error {
	constructor() {
		super("draft too large");
		this.name = "DraftTooLargeError";
	}
}

export interface GuestRecord {
	readonly guestId: string;
	readonly recoveryKey: string;
}
export interface AccountRecord {
	readonly accountId: string;
	readonly username: string;
}
export interface AccountSessionRecord extends AccountRecord {
	readonly session: string;
}
export interface DraftRecord {
	readonly ownerKind: "guest" | "account";
	readonly ownerId: string;
	readonly document: Record<string, unknown>;
	readonly updatedAt: string;
}

function mintPrefixedId(prefix: "gst" | "acc"): string {
	return `${prefix}_${randomBytes(16).toString("hex")}`;
}

function hashPassword(password: string): string {
	const salt = randomBytes(16);
	const derived = derivePassword(password, salt, SCRYPT_N, SCRYPT_R, SCRYPT_P);
	return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt.toString("hex")}$${derived.toString("hex")}`;
}

function passwordMatches(password: string, stored: string): boolean {
	const parts = stored.split("$");
	const kind = parts[0];
	const nText = parts[1];
	const rText = parts[2];
	const pText = parts[3];
	const saltHex = parts[4];
	const hashHex = parts[5];
	if (parts.length !== 6 || kind !== "scrypt" || saltHex === undefined || hashHex === undefined) {
		return false;
	}
	if (nText === undefined || rText === undefined || pText === undefined) {
		return false;
	}
	const derived = derivePassword(password, Buffer.from(saltHex, "hex"), Number(nText), Number(rText), Number(pText));
	const expected = Buffer.from(hashHex, "hex");
	return derived.length === expected.length && timingSafeEqual(derived, expected);
}

function documentJson(document: Record<string, unknown>): string {
	const text = JSON.stringify(document);
	if (text.length > DRAFT_JSON_MAX) {
		throw new DraftTooLargeError();
	}
	return text;
}

export class ControlPlaneAccountStore {
	readonly #db: DatabaseSync;

	constructor(db: DatabaseSync) {
		this.#db = db;
	}

	mintGuest(): GuestRecord {
		const guestId = mintPrefixedId("gst");
		const recoveryKey = generateTicket();
		this.#db.prepare(
			"INSERT INTO account_guests (guest_id, recovery_hash, claimed_account_id, created_at) VALUES (?, ?, NULL, ?)",
		).run(guestId, hashTicket(recoveryKey), new Date().toISOString());
		return { guestId, recoveryKey };
	}

	putDraft(ownerKind: "guest" | "account", ownerId: string, document: Record<string, unknown>, now: Date): DraftRecord {
		if (ownerKind === "guest") {
			this.#requireOpenGuest(ownerId);
		}
		const updatedAt = now.toISOString();
		const json = documentJson(document);
		this.#db.prepare(
			`INSERT INTO account_drafts (owner_kind, owner_id, document_json, updated_at) VALUES (?, ?, ?, ?)
			ON CONFLICT (owner_kind, owner_id) DO UPDATE SET document_json = excluded.document_json, updated_at = excluded.updated_at`,
		).run(ownerKind, ownerId, json, updatedAt);
		return { ownerKind, ownerId, document, updatedAt };
	}

	getDraft(ownerKind: "guest" | "account", ownerId: string): DraftRecord {
		const row = this.#db.prepare(
			"SELECT owner_kind, owner_id, document_json, updated_at FROM account_drafts WHERE owner_kind = ? AND owner_id = ?",
		).get(ownerKind, ownerId);
		if (row === undefined) {
			throw new DraftMissingError();
		}
		const parsed: unknown = JSON.parse(String(row["document_json"]));
		if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
			throw new DraftMissingError();
		}
		return {
			ownerKind: String(row["owner_kind"]) === "account" ? "account" : "guest",
			ownerId: String(row["owner_id"]),
			document: parsed as Record<string, unknown>,
			updatedAt: String(row["updated_at"]),
		};
	}

	async register(input: {
		readonly username: string; readonly password: string;
		readonly guestId?: string; readonly recoveryKey?: string; readonly now: Date;
	}): Promise<AccountSessionRecord> {
		if (!isAccountUsername(input.username) || !isAccountPassword(input.password)) {
			throw new AccountCredentialsError();
		}
		const accountId = mintPrefixedId("acc");
		const passwordHash = hashPassword(input.password);
		const createdAt = input.now.toISOString();
		try {
			this.#db.prepare(
				"INSERT INTO accounts (account_id, username, password_hash, created_at) VALUES (?, ?, ?, ?)",
			).run(accountId, input.username, passwordHash, createdAt);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new AccountUsernameTakenError(input.username);
			}
			throw error;
		}
		if (input.guestId !== undefined && input.recoveryKey !== undefined) {
			this.claim(accountId, input.guestId, input.recoveryKey);
		}
		return this.#issueSession(accountId, input.username);
	}

	async login(username: string, password: string): Promise<AccountSessionRecord> {
		const row = this.#db.prepare(
			"SELECT account_id, username, password_hash FROM accounts WHERE username = ?",
		).get(username);
		if (row === undefined || !passwordMatches(password, String(row["password_hash"]))) {
			throw new AccountCredentialsError();
		}
		return this.#issueSession(String(row["account_id"]), String(row["username"]));
	}

	accountBySession(session: string): AccountRecord {
		const row = this.#db.prepare(
			`SELECT a.account_id, a.username FROM account_sessions s
			JOIN accounts a ON a.account_id = s.account_id WHERE s.token_hash = ?`,
		).get(hashTicket(session));
		if (row === undefined) {
			throw new AccountSessionInvalidError();
		}
		return { accountId: String(row["account_id"]), username: String(row["username"]) };
	}

	guestByRecovery(guestId: string, recoveryKey: string): void {
		const row = this.#db.prepare(
			"SELECT recovery_hash, claimed_account_id FROM account_guests WHERE guest_id = ?",
		).get(guestId);
		if (row === undefined) {
			throw new GuestNotFoundError(guestId);
		}
		if (String(row["recovery_hash"]) !== hashTicket(recoveryKey)) {
			throw new GuestNotFoundError(guestId);
		}
		if (row["claimed_account_id"] !== null) {
			throw new GuestClaimedError(guestId);
		}
	}

	claim(accountId: string, guestId: string, recoveryKey: string): { readonly hadDraft: boolean } {
		this.guestByRecovery(guestId, recoveryKey);
		const guestDraft = this.#db.prepare(
			"SELECT owner_id FROM account_drafts WHERE owner_kind = 'guest' AND owner_id = ?",
		).get(guestId);
		const accountDraft = this.#db.prepare(
			"SELECT owner_id FROM account_drafts WHERE owner_kind = 'account' AND owner_id = ?",
		).get(accountId);
		if (guestDraft !== undefined && accountDraft !== undefined) {
			throw new DraftConflictError();
		}
		this.#db.prepare("UPDATE account_guests SET claimed_account_id = ? WHERE guest_id = ?").run(accountId, guestId);
		if (guestDraft !== undefined) {
			this.#db.prepare(
				"UPDATE account_drafts SET owner_kind = 'account', owner_id = ? WHERE owner_kind = 'guest' AND owner_id = ?",
			).run(accountId, guestId);
		}
		return { hadDraft: guestDraft !== undefined };
	}

	#requireOpenGuest(guestId: string): void {
		const row = this.#db.prepare(
			"SELECT claimed_account_id FROM account_guests WHERE guest_id = ?",
		).get(guestId);
		if (row === undefined) {
			throw new GuestNotFoundError(guestId);
		}
		if (row["claimed_account_id"] !== null) {
			throw new GuestClaimedError(guestId);
		}
	}

	#issueSession(accountId: string, username: string): AccountSessionRecord {
		const session = generateTicket();
		this.#db.prepare(
			"INSERT INTO account_sessions (token_hash, account_id, created_at) VALUES (?, ?, ?)",
		).run(hashTicket(session), accountId, new Date().toISOString());
		return { accountId, username, session };
	}
}
