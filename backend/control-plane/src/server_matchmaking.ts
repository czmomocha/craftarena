import {
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
	course: OfficialTraprushCourseId,
	seats: number,
	runDrain: () => Promise<void>,
): Promise<MatchmakingJoinResponse | MatchmakingQueueWaitingResponse | { error: string; message?: string }> {
	if (options.matchLauncher === undefined) {
		reply.code(503);
		return { error: "match_host_unavailable" };
	}

	try {
		const matchId = await launchRegisteredRoom(options, course, seats);
		reply.code(201);
		return admitToRoom(options, matchId, now(), ticketTtlMs);
	} catch (error) {
		if (error instanceof MatchHostCapacityError) {
			const queued = options.database.enqueue(kind, now(), queueTtlMs, course, seats);
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
			return (
				view ?? {
					status: "waiting",
					queueToken: queued.token,
					position: 1,
					estimatedWaitMs: queueSlotEstimateMs,
					expiresAt: queued.expiresAt,
					course,
					seats,
				}
			);
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
			const open = options.database.findOldestOpenRoom(waiter.course, waiter.seats);
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
		if (head.kind === "quick" && options.database.findOldestOpenRoom(head.course, head.seats) !== undefined) {
			progress = true;
			continue;
		}
		if (options.matchLauncher === undefined) {
			return;
		}

		try {
			const matchId = await launchRegisteredRoom(options, head.course, head.seats);
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

export async function launchRegisteredRoom(
	options: BuildServerOptions,
	course: OfficialTraprushCourseId,
	seats: number,
): Promise<string> {
	if (options.matchLauncher === undefined) {
		throw new MatchHostLaunchError("match host is unavailable");
	}

	const launched = await options.matchLauncher.launch({ course, seats });
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
			roomCode: session.roomCode,
			ticket: record.ticket,
			matchId: record.matchId,
			expiresAt: record.ticketExpiresAt,
			seats: session.seats,
			issued: options.database.countTickets(record.matchId),
			seat,
			course: session.course,
		};
	}

	const position = options.database.waitingPosition(record.tokenHash, now);
	return {
		status: "waiting",
		queueToken,
		position,
		estimatedWaitMs: position * queueSlotEstimateMs,
		expiresAt: record.expiresAt,
		course: record.course,
		seats: record.seats,
	};
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

	return {
		roomCode: session.roomCode,
		ticket: issued.ticket,
		matchId: issued.matchId,
		expiresAt: issued.expiresAt,
		seats: session.seats,
		issued: options.database.countTickets(matchId),
		seat: issued.seat,
		course: session.course,
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
