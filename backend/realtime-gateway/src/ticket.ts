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
 * M0 阶段控制面还没有票据签发与校验接口，先用它把连接握手链路跑通。
 * **上线前必须替换**，相关风险已记在 CD-62。
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
