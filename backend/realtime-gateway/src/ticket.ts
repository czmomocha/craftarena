export interface TicketVerdict {
	readonly ok: boolean;
	readonly reason?: string | undefined;
	/**
	 * 票据通过时要代理到的对局进程 WebSocket 地址。裁决必须把它带回来：
	 * 网关不记账、不查库（宪法第二十一条），票据→对局的解析权在控制面。
	 */
	readonly upstreamUrl?: string | undefined;
}

/**
 * 票据校验的边界。
 *
 * 网关自己**不是**权威（宪法第二条），也不允许直接读数据库（第二十一条），
 * 因此真正的校验必须落到控制面。这里抽成接口，是为了让"谁是权威"在类型上就写死，
 * 而不是等到有人图方便在网关里加一句 SQL。
 */
export interface TicketVerifier {
	verify(ticket: string | null): Promise<TicketVerdict>;
}

/**
 * 开发期占位实现：只检查票据非空，不做任何真实校验；上游地址来自构造参数
 * （`GATEWAY_DEV_UPSTREAM`），即开发机上所有连接都代理到同一个对局进程。
 *
 * 仅当显式设置 `GATEWAY_DEV_UPSTREAM` 时使用。生产路径走
 * {@link ControlPlaneTicketVerifier}。**上线前不得把本类当默认校验**，相关风险见 CD-62。
 */
export class DevTicketVerifier implements TicketVerifier {
	readonly #upstreamUrl: string | undefined;

	constructor(upstreamUrl?: string) {
		const trimmed = upstreamUrl?.trim();
		this.#upstreamUrl = trimmed === "" ? undefined : trimmed;
	}

	async verify(ticket: string | null): Promise<TicketVerdict> {
		if (ticket === null || ticket.trim() === "") {
			return { ok: false, reason: "missing ticket" };
		}

		return { ok: true, upstreamUrl: this.#upstreamUrl };
	}
}

/**
 * 生产路径：把票据交给控制面消费校验。网关不记账、不查库，
 * 只把控制面返回的上游地址带进代理（宪法第二十一条）。
 */
export class ControlPlaneTicketVerifier implements TicketVerifier {
	readonly #baseUrl: string;
	readonly #timeoutMs: number;

	constructor(baseUrl: string, timeoutMs = 2000) {
		this.#baseUrl = baseUrl.replace(/\/+$/, "");
		this.#timeoutMs = timeoutMs;
	}

	async verify(ticket: string | null): Promise<TicketVerdict> {
		if (ticket === null || ticket.trim() === "") {
			return { ok: false, reason: "missing ticket" };
		}

		const response = await fetch(`${this.#baseUrl}/tickets/verify`, {
			method: "POST",
			headers: { "content-type": "application/json" },
			body: JSON.stringify({ ticket: ticket.trim() }),
			signal: AbortSignal.timeout(this.#timeoutMs),
		});

		if (response.status === 401) {
			const failure = await readVerifyBody(response);
			return { ok: false, reason: failure?.reason ?? "rejected" };
		}
		if (!response.ok) {
			throw new Error(`control plane verify returned HTTP ${response.status}`);
		}

		const body = await readVerifyBody(response);
		if (body === undefined || body.ok !== true) {
			return { ok: false, reason: body?.reason ?? "rejected" };
		}

		return {
			ok: true,
			upstreamUrl: typeof body.upstreamUrl === "string" ? body.upstreamUrl : undefined,
		};
	}
}

async function readVerifyBody(
	response: Response,
): Promise<{ ok?: unknown; reason?: string | undefined; upstreamUrl?: unknown } | undefined> {
	try {
		const body: unknown = await response.json();
		if (typeof body !== "object" || body === null) {
			return undefined;
		}
		const record = body as { ok?: unknown; reason?: unknown; upstreamUrl?: unknown };
		return {
			ok: record.ok,
			reason: typeof record.reason === "string" ? record.reason : undefined,
			upstreamUrl: record.upstreamUrl,
		};
	} catch {
		return undefined;
	}
}
