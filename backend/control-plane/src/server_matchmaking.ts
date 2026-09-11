import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	readMatchBody,
	type MatchContentRef,
	type MatchQueueKind,
	type MatchmakingJoinResponse,
	type MatchmakingQueueStatusResponse,
	type MatchmakingQueueWaitingResponse,
	type OfficialTraprushCourseId,
	type ReadinessCheck,
} from "../../contracts/src/index.ts";
import {
	MatchQueueNotWaitingError,
	MatchSessionFullError,
	MatchSessionNotFoundError,
	type ControlPlaneDatabase,
	type MatchQueueRecord,
	type MatchSessionRecord,
} from "./db/database.ts";
import {
	MatchHostCapacityError,
	MatchHostLaunchError,
} from "./match_host.ts";
import { generateRoomCode } from "./rooms.ts";
import type { BuildServerOptions } from "./server.ts";

export function databaseCheck(database: ControlPlaneDatabase, now: Date): ReadinessCheck {
	try {
		const ok = database.probeReadWrite(now);
		return ok
			? { name: "sqlite_read_write", ok: true }
			: { name: "sqlite_read_write", ok: false, detail: "write succeeded but read back mismatched" };
	} catch (error) {
		return {
			name: "sqlite_read_write",
			ok: false,
			detail: error instanceof Error ? error.message : String(error),
		};
	}
}

export type MatchPlaySpec =
	| { readonly kind: "official"; readonly course: OfficialTraprushCourseId; readonly seats: number }
	| { readonly kind: "content"; readonly content: MatchContentRef; readonly seats: number };

export function resolveMatchSpec(
	database: ControlPlaneDatabase,
	body: unknown,
): { readonly ok: true; readonly spec: MatchPlaySpec } | { readonly ok: false; readonly error: string } {
	const parsed = readMatchBody(body);
	if (!parsed.ok) {
		return { ok: false, error: parsed.error };
	}
	if (parsed.kind === "content") {
		const stored = database.getContentVersion(parsed.content.id, parsed.content.version);
		if (stored === undefined) {
			return { ok: false, error: "invalid_content" };
		}
		return { ok: true, spec: { kind: "content", content: parsed.content, seats: parsed.seats } };
	}
	return { ok: true, spec: { kind: "official", course: parsed.course, seats: parsed.seats } };
}

export function hasUnexpectedKeys(body: unknown, allowed: readonly string[]): boolean {
	if (typeof body !== "object" || body === null) {
		return false;
	}
	return Object.keys(body).some((key) => !allowed.includes(key));
}

export async function launchOrEnqueue(
	options: BuildServerOptions,
	reply: { code(status: number): void },
	now: () => Date,
	ticketTtlMs: number,
	queueTtlMs: number,
	queueSlotEstimateMs: number,
	kind: MatchQueueKind,
	spec: MatchPlaySpec,
	runDrain: () => Promise<void>,
): Promise<MatchmakingJoinResponse | MatchmakingQueueWaitingResponse | { error: string; message?: string }> {
	if (options.matchLauncher === undefined) {
		reply.code(503);
		return { error: "match_host_unavailable" };
	}

	try {
		const matchId = await launchRegisteredRoom(options, spec);
		reply.code(201);
		return admitToRoom(options, matchId, now(), ticketTtlMs);
	} catch (error) {
		if (error instanceof MatchHostCapacityError) {
			const queued =
				spec.kind === "content"
					? options.database.enqueue(kind, now(), queueTtlMs, "", spec.seats, spec.content.id, spec.content.version)
					: options.database.enqueue(kind, now(), queueTtlMs, spec.course, spec.seats);
			await runDrain();
			const view = viewQueue(options, queued.token, now(), queueSlotEstimateMs);
			if (view !== undefined && view.status === "ready") {
				reply.code(201);
				return readyToJoin(view);
			}
			if (view !== undefined && view.status === "failed") {
				reply.code(502);
				return { error: view.error };
			}
			reply.code(202);
			return view ?? waitingFromSpec(queued.token, queued.expiresAt, queueSlotEstimateMs, spec);
		}
		if (error instanceof MatchHostLaunchError) {
			reply.code(502);
			return {
				error: error.message === "session_not_registered" ? "session_not_registered" : "session_launch_failed",
				message: error.message,
			};
		}
		throw error;
	}
}

export async function drainQueue(options: BuildServerOptions, now: () => Date, ticketTtlMs: number): Promise<void> {
	let progress = true;
	while (progress) {
		progress = false;
		const instant = now();

		for (const waiter of options.database.listWaiting(instant)) {
			if (waiter.kind !== "quick") {
				continue;
			}
			const open = findOpenForWaiter(options, waiter);
			if (open === undefined) {
				continue;
			}
			try {
				options.database.fulfillWaiter(waiter.tokenHash, open.matchId, now(), ticketTtlMs);
				progress = true;
			} catch (error) {
				if (error instanceof MatchSessionFullError || error instanceof MatchQueueNotWaitingError) {
					continue;
				}
				throw error;
			}
		}

		const head = options.database.listWaiting(now())[0];
		if (head === undefined) {
			return;
		}
		if (head.kind === "quick" && findOpenForWaiter(options, head) !== undefined) {
			progress = true;
			continue;
		}
		if (options.matchLauncher === undefined) {
			return;
		}

		try {
			const matchId = await launchRegisteredRoom(options, playSpecFromQueue(head));
			try {
				options.database.fulfillWaiter(head.tokenHash, matchId, now(), ticketTtlMs);
			} catch (error) {
				if (!(error instanceof MatchQueueNotWaitingError)) {
					throw error;
				}
			}
			progress = true;
		} catch (error) {
			if (error instanceof MatchHostCapacityError) {
				return;
			}
			if (error instanceof MatchHostLaunchError) {
				options.database.markQueueFailed(
					head.tokenHash,
					error.message === "session_not_registered" ? "session_not_registered" : "session_launch_failed",
				);
				return;
			}
			throw error;
		}
	}
}

export async function launchRegisteredRoom(options: BuildServerOptions, spec: MatchPlaySpec): Promise<string> {
	if (options.matchLauncher === undefined) {
		throw new MatchHostLaunchError("match host is unavailable");
	}

	const launched =
		spec.kind === "content"
			? await options.matchLauncher.launch({ content: spec.content, seats: spec.seats })
			: await options.matchLauncher.launch({ course: spec.course, seats: spec.seats });
	if (options.database.getMatchSession(launched.matchId) === undefined) {
		throw new MatchHostLaunchError("session_not_registered");
	}

	options.database.assignGeneratedRoomCode(launched.matchId, generateRoomCode);
	return launched.matchId;
}

export function viewQueue(
	options: BuildServerOptions,
	queueToken: string,
	now: Date,
	queueSlotEstimateMs: number,
): MatchmakingQueueStatusResponse | undefined {
	const record = options.database.getQueueByToken(queueToken, now);
	if (record === undefined) {
		return undefined;
	}
	if (record.status === "failed") {
		return { status: "failed", error: record.error ?? "session_launch_failed" };
	}
	if (record.status === "ready") {
		if (
			record.matchId === undefined ||
			record.ticket === undefined ||
			record.ticketExpiresAt === undefined
		) {
			return { status: "failed", error: "session_unregistered" };
		}
		const session = options.database.getMatchSession(record.matchId);
		if (session === undefined || session.roomCode === undefined) {
			return { status: "failed", error: "session_unregistered" };
		}
		const seat = options.database.readSeatByTicket(record.ticket);
		if (seat === undefined) {
			return { status: "failed", error: "session_unregistered" };
		}
		return {
			status: "ready",
			...joinFields(options, session, {
				ticket: record.ticket,
				matchId: record.matchId,
				expiresAt: record.ticketExpiresAt,
				seat,
			}),
		};
	}

	const position = options.database.waitingPosition(record.tokenHash, now);
	return waitingFromQueue(queueToken, position, queueSlotEstimateMs, record);
}

export function readyToJoin(
	view: Extract<MatchmakingQueueStatusResponse, { status: "ready" }>,
): MatchmakingJoinResponse {
	return {
		roomCode: view.roomCode,
		ticket: view.ticket,
		matchId: view.matchId,
		expiresAt: view.expiresAt,
		seats: view.seats,
		issued: view.issued,
		seat: view.seat,
		course: view.course,
		...(view.content === undefined ? {} : { content: view.content }),
		...(view.content_hash === undefined ? {} : { content_hash: view.content_hash }),
	};
}

export function admitToRoom(
	options: BuildServerOptions,
	matchId: string,
	now: Date,
	ticketTtlMs: number,
): MatchmakingJoinResponse {
	const issued = options.database.issueTicket(matchId, now, ticketTtlMs);
	const session = options.database.getMatchSession(matchId);
	if (session === undefined || session.roomCode === undefined) {
		throw new MatchSessionNotFoundError(matchId);
	}

	return joinFields(options, session, issued);
}

function joinFields(
	options: BuildServerOptions,
	session: MatchSessionRecord,
	issued: { readonly ticket: string; readonly matchId: string; readonly expiresAt: string; readonly seat: number },
): MatchmakingJoinResponse {
	const body: MatchmakingJoinResponse = {
		roomCode: session.roomCode ?? "",
		ticket: issued.ticket,
		matchId: issued.matchId,
		expiresAt: issued.expiresAt,
		seats: session.seats,
		issued: options.database.countTickets(issued.matchId),
		seat: issued.seat,
		course: session.course,
	};
	return withSessionContent(body, session);
}

function withSessionContent(
	body: MatchmakingJoinResponse,
	session: MatchSessionRecord,
): MatchmakingJoinResponse {
	if (
		session.contentId === undefined ||
		session.contentVersion === undefined ||
		session.contentHash === undefined
	) {
		return body;
	}
	return {
		...body,
		course: null,
		content: { id: session.contentId, version: session.contentVersion },
		content_hash: session.contentHash,
	};
}

function waitingFromQueue(
	queueToken: string,
	position: number,
	queueSlotEstimateMs: number,
	record: MatchQueueRecord,
): MatchmakingQueueWaitingResponse {
	const body: MatchmakingQueueWaitingResponse = {
		status: "waiting",
		queueToken,
		position,
		estimatedWaitMs: position * queueSlotEstimateMs,
		expiresAt: record.expiresAt,
		course: record.course,
		seats: record.seats,
	};
	if (record.contentId === undefined || record.contentVersion === undefined) {
		return body;
	}
	return {
		...body,
		course: null,
		content: { id: record.contentId, version: record.contentVersion },
	};
}

function waitingFromSpec(
	queueToken: string,
	expiresAt: string,
	queueSlotEstimateMs: number,
	spec: MatchPlaySpec,
): MatchmakingQueueWaitingResponse {
	const body: MatchmakingQueueWaitingResponse = {
		status: "waiting",
		queueToken,
		position: 1,
		estimatedWaitMs: queueSlotEstimateMs,
		expiresAt,
		course: spec.kind === "official" ? spec.course : null,
		seats: spec.seats,
	};
	if (spec.kind !== "content") {
		return body;
	}
	return { ...body, content: spec.content };
}

function findOpenForWaiter(options: BuildServerOptions, waiter: MatchQueueRecord): MatchSessionRecord | undefined {
	if (waiter.contentId !== undefined && waiter.contentVersion !== undefined) {
		return options.database.findOldestOpenContentRoom(waiter.contentId, waiter.contentVersion, waiter.seats);
	}
	if (waiter.course === null) {
		return undefined;
	}
	return options.database.findOldestOpenRoom(waiter.course, waiter.seats);
}

function playSpecFromQueue(record: MatchQueueRecord): MatchPlaySpec {
	if (record.contentId !== undefined && record.contentVersion !== undefined) {
		return {
			kind: "content",
			content: { id: record.contentId, version: record.contentVersion },
			seats: record.seats,
		};
	}
	return {
		kind: "official",
		course: record.course ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: record.seats,
	};
}

/** 兜底：空对象按「没传」处理，和 MatchHost 的 POST /matches 同一口径。 */
export function hasRequestBody(body: unknown): boolean {
	if (body === undefined || body === null) {
		return false;
	}
	if (typeof body === "string") {
		return body.trim() !== "";
	}
	if (typeof body === "object") {
		return Object.keys(body).length > 0;
	}
	return true;
}
