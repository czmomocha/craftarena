import { randomUUID } from "node:crypto";

import { createLease, evaluateLease, renewLease, type Lease, type LeaseExpiryReason } from "./lease.ts";
import { PortAllocator } from "./ports.ts";
import type { LaunchedProcess, MatchExit, ProcessLauncher } from "./launcher.ts";
import { MatchListenError, type MatchListenProbe } from "./listen_probe.ts";
import {
	MatchSessionRegisterError,
	buildMatchUpstreamUrl,
	type MatchSessionRegistrar,
} from "./registrar.ts";

export type MatchState = "running" | "stopped";

export type MatchStopReason = LeaseExpiryReason | "requested" | "process_exited";

export interface MatchRecord {
	readonly matchId: string;
	readonly port: number;
	readonly pid: number | undefined;
	readonly state: MatchState;
	readonly startedAt: number;
	readonly lease: Lease;
	/** 已交给控制面的对局 WebSocket 上游。listen 或登记失败的场次不会出现在注册表里。 */
	readonly upstreamUrl: string;
	readonly stopReason?: MatchStopReason | undefined;
	readonly exit?: MatchExit | undefined;
}

export interface MatchRegistryOptions {
	readonly launcher: ProcessLauncher;
	readonly registrar: MatchSessionRegistrar;
	/** 登记前确认本场端口已经在听。探测连回环，不查库。 */
	readonly listenProbe: MatchListenProbe;
	/** 拼 `ws://{host}:{port}` 用的广告主机名，默认由调用方从配置传入。 */
	readonly upstreamHost: string;
	readonly portRangeMin: number;
	readonly portRangeMax: number;
	readonly leaseDurationMs: number;
	readonly idleTimeoutMs: number;
	readonly maxConcurrentMatches: number;
	readonly now?: () => number;
	readonly onEvent?: (event: MatchEvent) => void;
}

export interface MatchEvent {
	readonly type: "started" | "stopped";
	readonly matchId: string;
	readonly port: number;
	readonly reason?: MatchStopReason | undefined;
	readonly recentOutput?: readonly string[] | undefined;
}

export class MatchCapacityError extends Error {
	constructor(limit: number) {
		super(`match host is at capacity (${limit} concurrent matches)`);
		this.name = "MatchCapacityError";
	}
}

interface MatchEntry {
	record: MatchRecord;
	readonly process: LaunchedProcess;
}

/**
 * 对局注册表：一场对局一个 Godot Headless 进程（CD-44 §3）。
 *
 * 这里管进程生命周期、端口、租约，以及 listen 可连后再经控制面 API 登记上游。
 * 它**不碰数据库**——宪法第二十一条规定只有控制面能直接读写 SQLite。
 */
export class MatchRegistry {
	readonly #options: MatchRegistryOptions;
	readonly #ports: PortAllocator;
	readonly #entries = new Map<string, MatchEntry>();
	readonly #now: () => number;
	/** 正在拉起、等待 listen 或登记、尚未写入注册表的场次。占容量，避免并发 POST 挤爆上限。 */
	#reservations = 0;

	constructor(options: MatchRegistryOptions) {
		this.#options = options;
		this.#ports = new PortAllocator(options.portRangeMin, options.portRangeMax);
		this.#now = options.now ?? (() => Date.now());
	}

	async start(): Promise<MatchRecord> {
		if (this.occupiedCount() >= this.#options.maxConcurrentMatches) {
			throw new MatchCapacityError(this.#options.maxConcurrentMatches);
		}

		this.#reservations += 1;
		try {
			return await this.#launchAndRegister();
		} finally {
			this.#reservations -= 1;
		}
	}

	async #launchAndRegister(): Promise<MatchRecord> {
		const matchId = randomUUID();
		const port = this.#ports.allocate();
		let process: LaunchedProcess | undefined;
		let upstreamUrl: string;
		try {
			upstreamUrl = buildMatchUpstreamUrl(this.#options.upstreamHost, port);
			process = this.#options.launcher.launch({ matchId, port });
			await this.#waitUntilListening(process, port);
			await this.#options.registrar.register({ matchId, upstreamUrl });
		} catch (error) {
			process?.kill();
			this.#ports.release(port);
			if (error instanceof MatchListenError || error instanceof MatchSessionRegisterError) {
				throw error;
			}
			if (process === undefined) {
				throw error;
			}
			throw new MatchSessionRegisterError(error instanceof Error ? error.message : String(error));
		}

		const now = this.#now();

		const record: MatchRecord = {
			matchId,
			port,
			pid: process.pid,
			state: "running",
			startedAt: now,
			lease: createLease(now, this.#options.leaseDurationMs),
			upstreamUrl,
		};

		this.#entries.set(matchId, { record, process });
		this.#options.onEvent?.({ type: "started", matchId, port });

		// 进程自己退出（崩溃或正常结束）时同步状态，不然注册表会一直显示 running。
		void process.exited.then((exit) => {
			this.#finalize(matchId, "process_exited", exit);
		});

		return record;
	}

	async #waitUntilListening(process: LaunchedProcess, port: number): Promise<void> {
		const abort = new AbortController();
		let settled = false;
		let processExit: MatchExit | undefined;

		type ListenRace =
			| { readonly kind: "listening" }
			| { readonly kind: "listen_failed"; readonly error: unknown }
			| { readonly kind: "exited"; readonly exit: MatchExit };

		const listenAttempt: Promise<ListenRace> = this.#options.listenProbe
			.waitUntilListening({ port, signal: abort.signal })
			.then(() => ({ kind: "listening" as const }))
			.catch((error: unknown) => ({ kind: "listen_failed" as const, error }));

		const exitAttempt: Promise<ListenRace> = process.exited.then((exit) => {
			if (!settled) {
				processExit = exit;
				abort.abort();
			}
			return { kind: "exited" as const, exit };
		});

		const outcome = await Promise.race([listenAttempt, exitAttempt]);
		settled = true;
		if (processExit !== undefined) {
			throw new MatchListenError(
				`match process exited before listen (code=${processExit.code}, signal=${processExit.signal})`,
			);
		}
		if (outcome.kind === "listening") {
			return;
		}

		if (outcome.kind === "listen_failed" && outcome.error instanceof MatchListenError) {
			throw outcome.error;
		}
		if (outcome.kind === "listen_failed") {
			throw new MatchListenError(
				outcome.error instanceof Error ? outcome.error.message : String(outcome.error),
			);
		}
		throw new MatchListenError(
			`match process exited before listen (code=${outcome.exit.code}, signal=${outcome.exit.signal})`,
		);
	}

	get(matchId: string): MatchRecord | undefined {
		return this.#entries.get(matchId)?.record;
	}

	list(): readonly MatchRecord[] {
		return [...this.#entries.values()].map((entry) => entry.record);
	}

	runningCount(): number {
		return [...this.#entries.values()].filter((entry) => entry.record.state === "running").length;
	}

	/** 已在跑的场次加上正在登记的预约。容量与 /readyz 都看这个数。 */
	occupiedCount(): number {
		return this.runningCount() + this.#reservations;
	}

	/**
	 * 续租。调用方必须已经确认这是一条通过校验且改变了权威状态的真人命令
	 * （CD-44 §3）；心跳、重复命令、被拒命令和 Bot 流量不得走到这里。
	 */
	renew(matchId: string): MatchRecord | undefined {
		const entry = this.#entries.get(matchId);
		if (entry === undefined || entry.record.state !== "running") {
			return undefined;
		}

		entry.record = {
			...entry.record,
			lease: renewLease(entry.record.lease, this.#now(), this.#options.leaseDurationMs),
		};

		return entry.record;
	}

	stop(matchId: string, reason: MatchStopReason = "requested"): MatchRecord | undefined {
		const entry = this.#entries.get(matchId);
		if (entry === undefined || entry.record.state !== "running") {
			return entry?.record;
		}

		entry.process.kill();
		return this.#finalize(matchId, reason);
	}

	/** 扫描并回收到期对局。由 MatchHost 定时调用。 */
	reclaimExpired(): readonly MatchRecord[] {
		const now = this.#now();
		const reclaimed: MatchRecord[] = [];

		for (const entry of this.#entries.values()) {
			if (entry.record.state !== "running") {
				continue;
			}

			const status = evaluateLease(entry.record.lease, now, this.#options.idleTimeoutMs);
			if (!status.expired || status.reason === undefined) {
				continue;
			}

			const stopped = this.stop(entry.record.matchId, status.reason);
			if (stopped !== undefined) {
				reclaimed.push(stopped);
			}
		}

		return reclaimed;
	}

	/** 关闭全部对局。进程退出时调用，避免留下孤儿 Godot 进程。 */
	shutdown(): void {
		for (const matchId of [...this.#entries.keys()]) {
			this.stop(matchId, "requested");
		}
	}

	#finalize(matchId: string, reason: MatchStopReason, exit?: MatchExit): MatchRecord | undefined {
		const entry = this.#entries.get(matchId);
		if (entry === undefined || entry.record.state === "stopped") {
			return entry?.record;
		}

		this.#ports.release(entry.record.port);
		entry.record = {
			...entry.record,
			state: "stopped",
			stopReason: reason,
			exit,
		};

		this.#options.onEvent?.({
			type: "stopped",
			matchId,
			port: entry.record.port,
			reason,
			recentOutput: entry.process.recentOutput(),
		});

		return entry.record;
	}
}
