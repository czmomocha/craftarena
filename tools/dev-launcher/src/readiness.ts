/** 一次探测的结果。失败时必须带原因，否则超时后只能报"不知道为什么没起来"。 */
export type ProbeResult = { readonly ok: true } | { readonly ok: false; readonly reason: string };

export interface WaitOptions {
	readonly timeoutMs: number;
	readonly intervalMs: number;
	/** 仅供测试注入，用来跳过真实等待。 */
	readonly now?: () => number;
	readonly sleep?: (ms: number) => Promise<void>;
}

const defaultSleep = (ms: number): Promise<void> => new Promise((done) => setTimeout(done, ms));

/**
 * 反复调用 `probe` 直到成功或超时。超时抛出的错误里带上最后一次失败原因，
 * 这样"端口没开"和"服务起来了但 /readyz 返回 503"在日志里就是两种可读的现象。
 */
export async function waitUntilReady(probe: () => Promise<ProbeResult>, options: WaitOptions): Promise<void> {
	const now = options.now ?? Date.now;
	const sleep = options.sleep ?? defaultSleep;
	const deadline = now() + options.timeoutMs;
	let lastReason = "no attempt made";

	// 先探一次再看时间，保证 timeoutMs 再小也至少尝试一次。
	for (;;) {
		const result = await probe();
		if (result.ok) {
			return;
		}
		lastReason = result.reason;

		if (now() >= deadline) {
			break;
		}
		await sleep(options.intervalMs);
	}

	throw new Error(`not ready within ${options.timeoutMs}ms: ${lastReason}`);
}

/** 对 `<baseUrl>/readyz` 发一次 GET，把非 2xx 和网络错误都归一化成失败原因。 */
export async function probeReadyEndpoint(baseUrl: string, timeoutMs = 1000): Promise<ProbeResult> {
	try {
		const response = await fetch(`${baseUrl}/readyz`, { signal: AbortSignal.timeout(timeoutMs) });
		if (response.ok) {
			return { ok: true };
		}
		return { ok: false, reason: `GET /readyz returned HTTP ${response.status}` };
	} catch (error) {
		return { ok: false, reason: error instanceof Error ? error.message : String(error) };
	}
}
