import { createConnection } from "node:net";

/**
 * 对局进程 listen 探测。
 *
 * MatchHost 必须在控制面登记上游之前确认本场端口已经在接受 TCP 连接，
 * 否则签发的票据会指向还没 bind 的地址。抽成接口是为了让租约测试不必真开
 * socket，也避免有人把广告主机（可能是给网关看的 DNS 名）拿来探测。
 *
 * 生产实现是短暂 TCP connect 后立刻 destroy，不是 WebSocket，也不会带票据。
 * 对局进程对非升级连接走 `accept_stream` 失败路径，不占玩家槽。
 */

export interface MatchListenWaitSpec {
	readonly port: number;
	readonly signal: AbortSignal;
}

export interface MatchListenProbe {
	waitUntilListening(spec: MatchListenWaitSpec): Promise<void>;
}

export class MatchListenError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "MatchListenError";
	}
}

/** 探测永远打本机回环。广告主机只用于拼给控制面的 ws URL，MatchHost 跟子进程同机。 */
export const MATCH_LISTEN_PROBE_HOST = "127.0.0.1";

export interface TcpMatchListenProbeOptions {
	readonly timeoutMs: number;
	readonly intervalMs: number;
	readonly host?: string;
}

export class TcpMatchListenProbe implements MatchListenProbe {
	readonly #host: string;
	readonly #timeoutMs: number;
	readonly #intervalMs: number;

	constructor(options: TcpMatchListenProbeOptions) {
		if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 1) {
			throw new MatchListenError(`invalid listen timeout: ${options.timeoutMs}`);
		}
		if (!Number.isInteger(options.intervalMs) || options.intervalMs < 1) {
			throw new MatchListenError(`invalid listen poll interval: ${options.intervalMs}`);
		}
		this.#host = options.host ?? MATCH_LISTEN_PROBE_HOST;
		this.#timeoutMs = options.timeoutMs;
		this.#intervalMs = options.intervalMs;
	}

	async waitUntilListening(spec: MatchListenWaitSpec): Promise<void> {
		if (!Number.isInteger(spec.port) || spec.port < 1 || spec.port > 65535) {
			throw new MatchListenError(`invalid listen probe port: ${spec.port}`);
		}

		const deadline = Date.now() + this.#timeoutMs;
		while (true) {
			if (spec.signal.aborted) {
				throw new MatchListenError("listen wait aborted");
			}
			if (Date.now() >= deadline) {
				throw new MatchListenError(`timed out waiting for TCP listen on ${this.#host}:${spec.port}`);
			}

			const open = await tryConnect(this.#host, spec.port, spec.signal);
			if (open) {
				return;
			}

			if (spec.signal.aborted) {
				throw new MatchListenError("listen wait aborted");
			}

			const remaining = deadline - Date.now();
			if (remaining <= 0) {
				throw new MatchListenError(`timed out waiting for TCP listen on ${this.#host}:${spec.port}`);
			}

			await delay(Math.min(this.#intervalMs, remaining), spec.signal);
		}
	}
}

function tryConnect(host: string, port: number, signal: AbortSignal): Promise<boolean> {
	return new Promise((resolve) => {
		if (signal.aborted) {
			resolve(false);
			return;
		}

		let settled = false;
		const socket = createConnection({ host, port, family: 4 });
		const finish = (ok: boolean): void => {
			if (settled) {
				return;
			}
			settled = true;
			signal.removeEventListener("abort", onAbort);
			socket.removeAllListeners();
			socket.on("error", () => {
				// destroy() 之后的 ECONNRESET 不该变成未处理异常。
			});
			socket.destroy();
			resolve(ok);
		};
		const onAbort = (): void => finish(false);

		socket.once("connect", () => finish(true));
		socket.once("error", () => finish(false));
		signal.addEventListener("abort", onAbort);
	});
}

function delay(ms: number, signal: AbortSignal): Promise<void> {
	return new Promise((resolve, reject) => {
		if (signal.aborted) {
			reject(new MatchListenError("listen wait aborted"));
			return;
		}

		const timer = setTimeout(resolve, ms);
		signal.addEventListener(
			"abort",
			() => {
				clearTimeout(timer);
				reject(new MatchListenError("listen wait aborted"));
			},
			{ once: true },
		);
	});
}
