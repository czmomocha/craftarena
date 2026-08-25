/**
 * 对局上游登记边界。
 *
 * MatchHost 拉起进程后必须把 `ws` 上游交给控制面（CD-44 §3），自己**不碰数据库**
 * （宪法第二十一条）。抽成接口是为了让租约/端口测试不必起控制面，也避免有人图方便
 * 在 MatchHost 里加一句 SQL。
 */

export interface MatchSessionRegisterSpec {
	readonly matchId: string;
	readonly upstreamUrl: string;
}

export interface MatchSessionRegistrar {
	register(spec: MatchSessionRegisterSpec): Promise<void>;
}

export class MatchSessionRegisterError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "MatchSessionRegisterError";
	}
}

const DEFAULT_TIMEOUT_MS = 2000;

/**
 * 把本场对局端口拼成控制面要的 `ws` 上游。TLS 在网关侧终结，对局进程讲明文 ws。
 * host 只接受主机名或 IPv4，拒绝 scheme / userinfo / 端口混写。
 */
export function buildMatchUpstreamUrl(host: string, port: number): string {
	const trimmed = host.trim();
	if (
		trimmed === "" ||
		trimmed.includes("/") ||
		trimmed.includes("@") ||
		trimmed.includes("#") ||
		trimmed.includes(":")
	) {
		throw new MatchSessionRegisterError(`invalid match upstream host: ${host}`);
	}
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		throw new MatchSessionRegisterError(`invalid match upstream port: ${port}`);
	}

	return `ws://${trimmed}:${port}`;
}

/**
 * 生产路径：`POST /match-sessions` 登记同一 matchId 与上游。
 * 网关仍只调校验接口；MatchHost 也不查库。
 */
export class ControlPlaneMatchSessionRegistrar implements MatchSessionRegistrar {
	readonly #baseUrl: string;
	readonly #timeoutMs: number;

	constructor(baseUrl: string, timeoutMs = DEFAULT_TIMEOUT_MS) {
		this.#baseUrl = baseUrl.replace(/\/+$/, "");
		this.#timeoutMs = timeoutMs;
	}

	async register(spec: MatchSessionRegisterSpec): Promise<void> {
		let response: Response;
		try {
			response = await fetch(`${this.#baseUrl}/match-sessions`, {
				method: "POST",
				headers: { "content-type": "application/json" },
				body: JSON.stringify({
					matchId: spec.matchId,
					upstreamUrl: spec.upstreamUrl,
				}),
				signal: AbortSignal.timeout(this.#timeoutMs),
			});
		} catch (error) {
			throw new MatchSessionRegisterError(
				error instanceof Error ? error.message : String(error),
			);
		}

		if (response.status !== 201) {
			throw new MatchSessionRegisterError(`control plane register returned HTTP ${response.status}`);
		}

		let body: unknown;
		try {
			body = await response.json();
		} catch {
			throw new MatchSessionRegisterError("control plane register returned a non-JSON body");
		}

		if (typeof body !== "object" || body === null) {
			throw new MatchSessionRegisterError("control plane register returned an invalid body");
		}

		const matchId = (body as { matchId?: unknown }).matchId;
		if (matchId !== spec.matchId) {
			throw new MatchSessionRegisterError("control plane register returned a mismatched match id");
		}
	}
}
