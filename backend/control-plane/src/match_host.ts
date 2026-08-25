import { isMatchId } from "./tickets.ts";
import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	type OfficialTraprushCourseId,
} from "../../contracts/src/official_courses.ts";

export interface MatchLaunchResult {
	readonly matchId: string;
}

export interface MatchLaunchRequest {
	readonly course?: OfficialTraprushCourseId;
	readonly seats?: number;
}

export interface MatchLauncher {
	launch(request?: MatchLaunchRequest): Promise<MatchLaunchResult>;
}

export class MatchHostCapacityError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "MatchHostCapacityError";
	}
}

export class MatchHostLaunchError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "MatchHostLaunchError";
	}
}

const DEFAULT_TIMEOUT_MS = 20_000;

/**
 * 控制面只通过 HTTP 让 MatchHost 拉起一场，自己不 spawn Godot，
 * MatchHost 也不查库（宪法第二十一条）。
 */
export class MatchHostHttpLauncher implements MatchLauncher {
	readonly #baseUrl: string;
	readonly #timeoutMs: number;

	constructor(baseUrl: string, timeoutMs = DEFAULT_TIMEOUT_MS) {
		this.#baseUrl = baseUrl.replace(/\/+$/, "");
		this.#timeoutMs = timeoutMs;
	}

	async launch(request: MatchLaunchRequest = {}): Promise<MatchLaunchResult> {
		const course = request.course ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
		const seats = request.seats ?? DEFAULT_MATCHMAKING_SEATS;
		let response: Response;
		try {
			response = await fetch(`${this.#baseUrl}/matches`, {
				method: "POST",
				headers: { "content-type": "application/json" },
				body: JSON.stringify({ course, seats }),
				signal: AbortSignal.timeout(this.#timeoutMs),
			});
		} catch (error) {
			throw new MatchHostLaunchError(error instanceof Error ? error.message : String(error));
		}

		if (response.status === 503) {
			throw new MatchHostCapacityError("match host is at capacity");
		}
		if (response.status !== 201) {
			throw new MatchHostLaunchError(`match host launch returned HTTP ${response.status}`);
		}

		let body: unknown;
		try {
			body = await response.json();
		} catch {
			throw new MatchHostLaunchError("match host launch returned a non-JSON body");
		}

		if (typeof body !== "object" || body === null) {
			throw new MatchHostLaunchError("match host launch returned an invalid body");
		}

		const matchId = (body as { matchId?: unknown }).matchId;
		if (typeof matchId !== "string" || !isMatchId(matchId)) {
			throw new MatchHostLaunchError("match host launch returned an invalid match id");
		}

		return { matchId };
	}
}
