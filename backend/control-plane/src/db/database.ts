import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

import type { ContentPatchOp } from "../../../contracts/src/content_patch.ts";
import type { MatchQueueKind } from "../../../contracts/src/match_room.ts";
import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	MAX_MATCH_SEATS,
	MIN_MATCH_SEATS,
	isValidMatchSeats,
	type OfficialTraprushCourseId,
} from "../../../contracts/src/official_courses.ts";
import {
	RECONNECT_TICKET_ERRORS,
	type ReconnectTicketError,
	type TicketRejectReason,
} from "../../../contracts/src/match_ticket.ts";
import { MIGRATIONS, SCHEMA_MIGRATIONS_TABLE } from "./migrations.ts";
import {
	ControlPlaneContentStore,
	ContentAlreadyLatestError,
	ContentPatchSeqNotNextError,
	ContentVersionExistsError,
	ContentVersionMissingError,
	ContentVersionNotNextError,
	type ContentOwnerRecord,
	type ContentOwnerKind,
	type ContentPatchRecord,
	type ContentVersionRecord,
} from "./database_content.ts";
import {
	ControlPlanePlazaStore,
	PlazaPlayExistsError,
	PlazaRatingExistsError,
	type PlazaListingRecord,
} from "./database_plaza.ts";
import {
	ControlPlaneAccountStore,
	AccountCredentialsError,
	AccountSessionInvalidError,
	AccountUsernameTakenError,
	DraftConflictError,
	DraftMissingError,
	DraftTooLargeError,
	GuestClaimedError,
	GuestNotFoundError,
	type AccountRecord,
	type AccountSessionRecord,
	type DraftRecord,
	type GuestRecord,
} from "./database_accounts.ts";
import type { PlazaTab } from "../../../contracts/src/content_plaza.ts";
import { ControlPlaneQueueStore } from "./database_queue.ts";
import { ControlPlaneSessionStore } from "./database_sessions.ts";
import { ControlPlaneTicketStore } from "./database_tickets.ts";

export {
	ContentAlreadyLatestError,
	ContentPatchSeqNotNextError,
	ContentVersionExistsError,
	ContentVersionMissingError,
	ContentVersionNotNextError,
	PlazaPlayExistsError,
	PlazaRatingExistsError,
	AccountCredentialsError,
	AccountSessionInvalidError,
	AccountUsernameTakenError,
	DraftConflictError,
	DraftMissingError,
	DraftTooLargeError,
	GuestClaimedError,
	GuestNotFoundError,
	type ContentOwnerKind,
	type ContentOwnerRecord,
	type ContentPatchRecord,
	type ContentVersionRecord,
	type PlazaListingRecord,
	type AccountRecord,
	type AccountSessionRecord,
	type DraftRecord,
	type GuestRecord,
};

export const DEFAULT_MATCH_SEATS = 8;
export { MIN_MATCH_SEATS, MAX_MATCH_SEATS };
export const isValidSeatCount = isValidMatchSeats;

export interface MatchSessionRecord {
	readonly matchId: string;
	readonly upstreamUrl: string;
	readonly createdAt: string;
	readonly roomCode: string | undefined;
	readonly seats: number;
	readonly course: OfficialTraprushCourseId | null;
	readonly contentId?: string | undefined;
	readonly contentVersion?: number | undefined;
	readonly contentHash?: string | undefined;
}

export interface IssuedTicket {
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
	readonly seat: number;
}

export type ConsumeTicketResult =
	| { readonly ok: true; readonly upstreamUrl: string; readonly seat: number }
	| { readonly ok: false; readonly reason: TicketRejectReason };

export type ReconnectTicketResult =
	| { readonly ok: true } & IssuedTicket
	| { readonly ok: false; readonly error: ReconnectTicketError };

export { RECONNECT_TICKET_ERRORS };

export class MatchSessionExistsError extends Error {
	constructor(matchId: string) { super(`match session already exists: ${matchId}`); this.name = "MatchSessionExistsError"; }
}
export class MatchSessionNotFoundError extends Error {
	constructor(matchId: string) { super(`match session not found: ${matchId}`); this.name = "MatchSessionNotFoundError"; }
}
export class MatchSessionFullError extends Error {
	constructor(matchId: string) { super(`match session is full: ${matchId}`); this.name = "MatchSessionFullError"; }
}
export class RoomCodeConflictError extends Error {
	constructor(roomCode: string) { super(`room code already exists: ${roomCode}`); this.name = "RoomCodeConflictError"; }
}
export class MatchQueueNotWaitingError extends Error {
	constructor(tokenHash: string) { super(`match queue entry is not waiting: ${tokenHash}`); this.name = "MatchQueueNotWaitingError"; }
}
export class MatchSettlementExistsError extends Error {
	constructor(matchId: string) { super(`match settlement already exists: ${matchId}`); this.name = "MatchSettlementExistsError"; }
}

export interface MatchSettlementRecord {
	readonly matchId: string;
	readonly tick: number;
	readonly stateHash: string;
	readonly padTotal: number;
	readonly mvpSlot: number;
	readonly rowsJson: string;
	readonly createdAt: string;
}

export type MatchQueueRowStatus = "waiting" | "ready" | "failed" | "cancelled";

export interface MatchQueueRecord {
	readonly rowid: number;
	readonly tokenHash: string;
	readonly kind: MatchQueueKind;
	readonly status: MatchQueueRowStatus;
	readonly createdAt: string;
	readonly expiresAt: string;
	readonly matchId: string | undefined;
	readonly ticket: string | undefined;
	readonly ticketExpiresAt: string | undefined;
	readonly error: string | undefined;
	readonly course: OfficialTraprushCourseId | null;
	readonly seats: number;
	readonly contentId?: string | undefined;
	readonly contentVersion?: number | undefined;
}

export interface EnqueuedMatch {
	readonly token: string;
	readonly createdAt: string;
	readonly expiresAt: string;
}

export type CancelQueueResult = "cancelled" | "ready" | "missing";

/** SQLite 唯一入口（宪法第二十一条）。只允许 control-plane 内部导入。 */
export class ControlPlaneDatabase {
	readonly #db: DatabaseSync;
	readonly #sessions: ControlPlaneSessionStore;
	readonly #tickets: ControlPlaneTicketStore;
	readonly #queue: ControlPlaneQueueStore;
	readonly #content: ControlPlaneContentStore;
	readonly #plaza: ControlPlanePlazaStore;
	readonly #accounts: ControlPlaneAccountStore;

	constructor(databasePath: string) {
		if (databasePath !== ":memory:") {
			mkdirSync(dirname(databasePath), { recursive: true });
		}

		this.#db = new DatabaseSync(databasePath);
		this.#sessions = new ControlPlaneSessionStore(this.#db);
		this.#tickets = new ControlPlaneTicketStore(this.#db, this.#sessions);
		this.#queue = new ControlPlaneQueueStore(this.#db, this.#sessions, this.#tickets);
		this.#content = new ControlPlaneContentStore(this.#db);
		this.#plaza = new ControlPlanePlazaStore(this.#db);
		this.#accounts = new ControlPlaneAccountStore(this.#db);
		this.#db.exec("PRAGMA journal_mode = WAL");
		this.#db.exec("PRAGMA foreign_keys = ON");
	}

	migrate(): readonly string[] {
		this.#db.exec(SCHEMA_MIGRATIONS_TABLE);

		const applied = new Set(
			this.#db
				.prepare("SELECT id FROM schema_migrations")
				.all()
				.map((row) => String(row["id"])),
		);

		const newlyApplied: string[] = [];
		const record = this.#db.prepare(
			"INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?)",
		);

		for (const migration of MIGRATIONS) {
			if (applied.has(migration.id)) {
				continue;
			}

			this.#db.exec("BEGIN");
			try {
				for (const statement of migration.statements) {
					this.#db.exec(statement);
				}
				record.run(migration.id, new Date().toISOString());
				this.#db.exec("COMMIT");
			} catch (error) {
				this.#db.exec("ROLLBACK");
				throw error;
			}

			newlyApplied.push(migration.id);
		}

		return newlyApplied;
	}

	probeReadWrite(now: Date): boolean {
		const stamp = now.toISOString();
		this.#db
			.prepare("UPDATE readiness_probe SET last_checked_at = ? WHERE id = 1")
			.run(stamp);

		const row = this.#db
			.prepare("SELECT last_checked_at FROM readiness_probe WHERE id = 1")
			.get();

		return row !== undefined && String(row["last_checked_at"]) === stamp;
	}

	insertMatchSession(input: {
		readonly matchId?: string | undefined;
		readonly upstreamUrl: string;
		readonly now: Date;
		readonly seats?: number | undefined;
		readonly course?: OfficialTraprushCourseId | undefined;
		readonly contentId?: string | undefined;
		readonly contentVersion?: number | undefined;
		readonly contentHash?: string | undefined;
	}): MatchSessionRecord {
		return this.#sessions.insertMatchSession(input);
	}

	deleteMatchSession(matchId: string): MatchSessionRecord {
		return this.#sessions.deleteMatchSession(matchId);
	}

	insertMatchSettlement(input: {
		readonly matchId: string;
		readonly tick: number;
		readonly stateHash: string;
		readonly padTotal: number;
		readonly mvpSlot: number;
		readonly rowsJson: string;
		readonly now: Date;
	}): MatchSettlementRecord {
		return this.#sessions.insertMatchSettlement(input);
	}

	getMatchSettlement(matchId: string): MatchSettlementRecord | undefined {
		return this.#sessions.getMatchSettlement(matchId);
	}

	getMatchSession(matchId: string): MatchSessionRecord | undefined {
		return this.#sessions.getMatchSession(matchId);
	}

	getMatchSessionByRoomCode(roomCode: string): MatchSessionRecord | undefined {
		return this.#sessions.getMatchSessionByRoomCode(roomCode);
	}
	findOldestOpenRoom(
		course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
	): MatchSessionRecord | undefined { return this.#sessions.findOldestOpenRoom(course, seats); }
	findOldestOpenContentRoom(
		contentId: string, version: number, seats: number = DEFAULT_MATCHMAKING_SEATS,
	): MatchSessionRecord | undefined {
		return this.#sessions.findOldestOpenContentRoom(contentId, version, seats);
	}
	assignRoomCode(matchId: string, roomCode: string): string { return this.#sessions.assignRoomCode(matchId, roomCode); }
	assignGeneratedRoomCode(matchId: string, generate: () => string, attempts = 8): string {
		return this.#sessions.assignGeneratedRoomCode(matchId, generate, attempts);
	}
	countTickets(matchId: string): number { return this.#tickets.countTickets(matchId); }
	readSeatByTicket(ticket: string): number | undefined { return this.#tickets.readSeatByTicket(ticket); }
	issueTicket(matchId: string, now: Date, ttlMs: number): IssuedTicket {
		return this.#tickets.issueTicket(matchId, now, ttlMs);
	}
	enqueue(
		kind: MatchQueueKind, now: Date, ttlMs: number,
		course: OfficialTraprushCourseId | "" = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
		contentId?: string, contentVersion?: number,
	): EnqueuedMatch { return this.#queue.enqueue(kind, now, ttlMs, course, seats, contentId, contentVersion); }
	getQueueByToken(token: string, now: Date): MatchQueueRecord | undefined {
		return this.#queue.getQueueByToken(token, now);
	}
	listWaiting(now: Date): readonly MatchQueueRecord[] { return this.#queue.listWaiting(now); }
	waitingPosition(tokenHash: string, now: Date): number { return this.#queue.waitingPosition(tokenHash, now); }
	fulfillWaiter(tokenHash: string, matchId: string, now: Date, ticketTtlMs: number): IssuedTicket {
		return this.#queue.fulfillWaiter(tokenHash, matchId, now, ticketTtlMs);
	}
	markQueueFailed(tokenHash: string, error: string): boolean { return this.#queue.markQueueFailed(tokenHash, error); }
	cancelQueue(token: string, now: Date): CancelQueueResult { return this.#queue.cancelQueue(token, now); }
	consumeTicket(ticket: string, now: Date): ConsumeTicketResult { return this.#tickets.consumeTicket(ticket, now); }
	reconnectTicket(matchId: string, ticket: string, now: Date, ttlMs: number): ReconnectTicketResult {
		return this.#tickets.reconnectTicket(matchId, ticket, now, ttlMs);
	}
	publishContent(input: {
		readonly contentId: string; readonly version: number; readonly contentHash: string;
		readonly signature: string; readonly bundle: Record<string, unknown>; readonly now: Date;
		readonly ownerKind?: ContentOwnerKind; readonly ownerId?: string;
	}): ContentVersionRecord { return this.#content.publish(input); }
	getContentLatest(contentId: string): ContentVersionRecord | undefined { return this.#content.getLatest(contentId); }
	getContentOwner(contentId: string): ContentOwnerRecord | undefined { return this.#content.getOwner(contentId); }
	getContentVersion(contentId: string, version: number): ContentVersionRecord | undefined {
		return this.#content.getVersion(contentId, version);
	}
	publishContentPatch(input: {
		readonly contentId: string; readonly baseVersion: number; readonly seq: number;
		readonly level: "p0" | "p1"; readonly patchHash: string; readonly signature: string;
		readonly ops: readonly ContentPatchOp[]; readonly now: Date;
	}): ContentPatchRecord { return this.#content.publishPatch(input); }
	listContentPatches(contentId: string, baseVersion: number): readonly ContentPatchRecord[] {
		return this.#content.listPatches(contentId, baseVersion);
	}
	rollbackContentLatest(contentId: string, targetVersion: number): ContentVersionRecord {
		return this.#content.rollbackLatest(contentId, targetVersion);
	}
	listPlaza(tab: PlazaTab): readonly PlazaListingRecord[] { return this.#plaza.list(tab); }
	getPlazaListing(contentId: string): PlazaListingRecord | undefined { return this.#plaza.get(contentId); }
	recordPlazaPlay(contentId: string, matchId: string, now: Date): PlazaListingRecord {
		return this.#plaza.recordPlay(contentId, matchId, now);
	}
	ratePlaza(input: {
		readonly contentId: string; readonly rater: string; readonly stars: number;
		readonly tags: readonly string[]; readonly now: Date;
	}): PlazaListingRecord { return this.#plaza.rate(input); }
	mintGuest(): GuestRecord { return this.#accounts.mintGuest(); }
	guestByRecovery(guestId: string, recoveryKey: string): void {
		this.#accounts.guestByRecovery(guestId, recoveryKey);
	}
	putGuestDraft(guestId: string, document: Record<string, unknown>, now: Date): DraftRecord {
		return this.#accounts.putDraft("guest", guestId, document, now);
	}
	putAccountDraft(accountId: string, document: Record<string, unknown>, now: Date): DraftRecord {
		return this.#accounts.putDraft("account", accountId, document, now);
	}
	getGuestDraft(guestId: string): DraftRecord { return this.#accounts.getDraft("guest", guestId); }
	getAccountDraft(accountId: string): DraftRecord { return this.#accounts.getDraft("account", accountId); }
	registerAccount(input: {
		readonly username: string; readonly password: string; readonly guestId?: string;
		readonly recoveryKey?: string; readonly now: Date;
	}): Promise<AccountSessionRecord> { return this.#accounts.register(input); }
	loginAccount(username: string, password: string): Promise<AccountSessionRecord> {
		return this.#accounts.login(username, password);
	}
	accountBySession(session: string): AccountRecord { return this.#accounts.accountBySession(session); }
	claimGuest(accountId: string, guestId: string, recoveryKey: string): { readonly hadDraft: boolean } {
		return this.#accounts.claim(accountId, guestId, recoveryKey);
	}

	close(): void {
		this.#db.close();
	}
}
