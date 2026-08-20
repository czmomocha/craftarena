import { randomUUID } from "node:crypto";

import { createLease, evaluateLease, renewLease, type Lease, type LeaseExpiryReason } from "./lease.ts";
import { PortAllocator } from "./ports.ts";
import type { LaunchedProcess, MatchExit, ProcessLauncher } from "./launcher.ts";

export type MatchState = "running" | "stopped";

export type MatchStopReason = LeaseExpiryReason | "requested" | "process_exited";

export interface MatchRecord {
	readonly matchId: string;
	readonly port: number;
	readonly pid: number | undefined;
	readonly state: MatchState;
	readonly startedAt: number;
	readonly lease: Lease;
	readonly stopReason?: MatchStopReason | undefined;
	readonly exit?: MatchExit | undefined;
}

export interface MatchRegistryOptions {
	readonly launcher: ProcessLauncher;
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
 * 这里只管进程生命周期、端口和租约。它**不碰数据库**——宪法第二十一条规定
 * 只有控制面能直接读写 SQLite，MatchHost 需要持久化时必须走控制面 API。
 */
export class MatchRegistry {
	readonly #options: MatchRegistryOptions;
	readonly #ports: PortAllocator;
	readonly #entries = new Map<string, MatchEntry>();
	readonly #now: () => number;

	constructor(options: MatchRegistryOptions) {
		this.#options = options;
		this.#ports = new PortAllocator(options.portRangeMin, options.portRangeMax);
		this.#now = options.now ?? (() => Date.now());
	}

	start(): MatchRecord {
		if (this.runningCount() >= this.#options.maxConcurrentMatches) {
			throw new MatchCapacityError(this.#options.maxConcurrentMatches);
		}

		const matchId = randomUUID();
		const port = this.#ports.allocate();
		const now = this.#now();

		let process: LaunchedProcess;
		try {
			process = this.#options.launcher.launch({ matchId, port });
		} catch (error) {
			// 启动失败必须还回端口，否则反复失败会把号段耗干。
			this.#ports.release(port);
			throw error;
		}

		const record: MatchRecord = {
			matchId,
			port,
			pid: process.pid,
			state: "running",
			startedAt: now,
			lease: createLease(now, this.#options.leaseDurationMs),
		};

		this.#entries.set(matchId, { record, process });
		this.#options.onEvent?.({ type: "started", matchId, port });

		// 进程自己退出（崩溃或正常结束）时同步状态，不然注册表会一直显示 running。
		void process.exited.then((exit) => {
			this.#finalize(matchId, "process_exited", exit);
		});

		return record;
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
