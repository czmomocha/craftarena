import { isMatchId } from "./tickets.ts";

export interface MatchLaunchResult {
	readonly matchId: string;
}

export interface MatchLauncher {
	launch(): Promise<MatchLaunchResult>;
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

	async launch(): Promise<MatchLaunchResult> {
		let response: Response;
		try {
			response = await fetch(`${this.#baseUrl}/matches`, {
				method: "POST",
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
