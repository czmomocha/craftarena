import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isOfficialTraprushCourseId,
	type OfficialTraprushCourseId,
} from "../../contracts/src/official_courses.ts";
import type { MatchContentRef } from "../../contracts/src/match_body.ts";
import { createLease, evaluateLease, renewLease, type Lease, type LeaseExpiryReason } from "./lease.ts";
import { PortAllocator } from "./ports.ts";
import type { LaunchedProcess, MatchExit, ProcessLauncher } from "./launcher.ts";
import { type MatchListenProbe } from "./listen_probe.ts";
import {
	MatchSessionSettlementError,
	MatchSessionUnregisterError,
	type MatchSessionRegistrar,
} from "./registrar.ts";
import type { ContentEnvelopeFetcher } from "./content_envelope.ts";
import { removeMatchEnvelopeFile } from "./content_envelope.ts";
import { launchRegisteredMatch } from "./registry_start.ts";
import { parseMatchTickSettlement, parseMatchTickValidInputTick } from "./settlement.ts";

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
	readonly seats: number;
	readonly course: OfficialTraprushCourseId | null;
	readonly content?: MatchContentRef | undefined;
	readonly contentHash?: string | undefined;
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
	/** 本场席位，随登记交给控制面。省略 POST /matches.seats 时用这个默认。 */
	readonly seats: number;
	/** 空 POST /matches 时使用的官方赛道。省略时 `course_01`。 */
	readonly defaultCourse?: string;
	/** 拉 UGC 信封。省略时 `startContent` 失败。MatchHost 仍不查库。 */
	readonly contentEnvelope?: ContentEnvelopeFetcher | undefined;
	readonly portRangeMin: number;
	readonly portRangeMax: number;
	readonly leaseDurationMs: number;
	readonly idleTimeoutMs: number;
	readonly maxConcurrentMatches: number;
	readonly now?: () => number;
	readonly onEvent?: (event: MatchEvent) => void;
}

export interface MatchEvent {
	readonly type: "started" | "stopped" | "start_failed";
	readonly matchId: string;
	readonly port: number;
	readonly reason?: MatchStopReason | undefined;
	/** `start_failed` 才有：抛给调用方的失败原因。 */
	readonly message?: string | undefined;
	readonly recentOutput?: readonly string[] | undefined;
}

/**
 * 拼进错误消息的进程输出行数。
 *
 * `POST /matches` 的调用方（控制面、运维的 curl）看不到 MatchHost 日志，而"为什么起不来"
 * 只写在子进程这几行里：`spawn ... ENOENT`、项目路径不对、场景缺失、引擎版本不匹配。
 * 不带上它们，502 就只剩一句"进程在 listen 前退出了"。
 */
export class MatchCapacityError extends Error {
	constructor(limit: number) {
		super(`match host is at capacity (${limit} concurrent matches)`);
		this.name = "MatchCapacityError";
	}
}

interface MatchEntry {
	record: MatchRecord;
	readonly process: LaunchedProcess;
	settlementPosted: boolean;
	/** 该场上次已用来续租的 valid_input_tick。同一 tick 不重复续。 */
	lastRenewedValidInputTick: number;
	envelopePath?: string | undefined;
}

/**
 * 对局注册表：一场对局一个 Godot Headless 进程（CD-44 §3）。
 *
 * 这里管进程生命周期、端口、租约，以及 listen 可连后再经控制面 API 登记上游；
 * 停止时再经同一接口注销，避免给已死场签发票据。它**不碰数据库**——
 * 宪法第二十一条规定只有控制面能直接读写 SQLite。
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

	async start(
		course: OfficialTraprushCourseId = this.#defaultCourse(),
		seats: number = this.#options.seats,
	): Promise<MatchRecord> {
		return this.#startPlan({ kind: "official", course, seats });
	}

	async startContent(
		content: MatchContentRef,
		seats: number = this.#options.seats,
	): Promise<MatchRecord> {
		return this.#startPlan({ kind: "content", content, seats });
	}

	#defaultCourse(): OfficialTraprushCourseId {
		return isOfficialTraprushCourseId(this.#options.defaultCourse)
			? this.#options.defaultCourse
			: DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
	}

	async #startPlan(
		plan:
			| { readonly kind: "official"; readonly course: OfficialTraprushCourseId; readonly seats: number }
			| { readonly kind: "content"; readonly content: MatchContentRef; readonly seats: number },
	): Promise<MatchRecord> {
		if (this.occupiedCount() >= this.#options.maxConcurrentMatches) {
			throw new MatchCapacityError(this.#options.maxConcurrentMatches);
		}

		this.#reservations += 1;
		try {
			const started = await launchRegisteredMatch(
				{
					launcher: this.#options.launcher,
					registrar: this.#options.registrar,
					listenProbe: this.#options.listenProbe,
					contentEnvelope: this.#options.contentEnvelope,
					upstreamHost: this.#options.upstreamHost,
					ports: this.#ports,
					now: this.#now,
					onStartFailed: (event) => {
						this.#options.onEvent?.({
							type: "start_failed",
							matchId: event.matchId,
							port: event.port,
							message: event.message,
							recentOutput: event.recentOutput,
						});
					},
				},
				plan,
			);
			const now = this.#now();
			const record: MatchRecord = {
				matchId: started.matchId,
				port: started.port,
				pid: started.pid,
				state: "running",
				startedAt: now,
				lease: createLease(now, this.#options.leaseDurationMs),
				upstreamUrl: started.upstreamUrl,
				seats: started.seats,
				course: started.course,
				content: started.content,
				contentHash: started.contentHash,
			};
			this.#entries.set(started.matchId, {
				record,
				process: started.process,
				settlementPosted: false,
				lastRenewedValidInputTick: -1,
				envelopePath: started.envelopePath,
			});
			this.#options.onEvent?.({ type: "started", matchId: started.matchId, port: started.port });
			void started.process.exited.then(async (exit) => {
				try {
					await this.#finalize(started.matchId, "process_exited", exit);
				} catch {
					// 本地已经停了。控制面注销失败不能再抛，否则变成未处理拒绝。
				}
			});
			return record;
		} finally {
			this.#reservations -= 1;
		}
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

	async stop(matchId: string, reason: MatchStopReason = "requested"): Promise<MatchRecord | undefined> {
		const entry = this.#entries.get(matchId);
		if (entry === undefined || entry.record.state !== "running") {
			return entry?.record;
		}

		entry.process.kill();
		return this.#finalize(matchId, reason);
	}

	/**
	 * 扫描最近一条 match_tick：`valid_input_tick` 相对该场上次续租前进才 renew。
	 * 心跳本身、缺字段、负数、垃圾行都不续（CD-44 §3）。
	 */
	renewFromValidInput(): void {
		for (const [matchId, entry] of this.#entries) {
			if (entry.record.state !== "running") {
				continue;
			}
			const tick = parseMatchTickValidInputTick(entry.process.recentOutput());
			if (tick === undefined || tick <= entry.lastRenewedValidInputTick) {
				continue;
			}
			this.renew(matchId);
			entry.lastRenewedValidInputTick = tick;
		}
	}

	/**
	 * 运行中心跳一旦带上全员冲线结算，立刻 POST 控制面（409 视为已写入）。
	 * 停止路径仍会再 POST 一次。失败不杀进程，下轮重试。
	 */
	async flushSettlements(): Promise<void> {
		for (const [matchId, entry] of this.#entries) {
			if (entry.record.state !== "running" || entry.settlementPosted) {
				continue;
			}
			const settlement = parseMatchTickSettlement(entry.process.recentOutput());
			if (settlement === undefined) {
				continue;
			}
			try {
				await this.#options.registrar.recordSettlement(matchId, settlement);
				entry.settlementPosted = true;
			} catch {
				continue;
			}
		}
	}

	/** 扫描并回收到期对局。由 MatchHost 定时调用。 */
	async reclaimExpired(): Promise<readonly MatchRecord[]> {
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

			const matchId = entry.record.matchId;
			try {
				const stopped = await this.stop(matchId, status.reason);
				if (stopped !== undefined) {
					reclaimed.push(stopped);
				}
			} catch (error) {
				if (!(error instanceof MatchSessionUnregisterError)) {
					throw error;
				}
				const stopped = this.get(matchId);
				if (stopped !== undefined) {
					reclaimed.push(stopped);
				}
			}
		}

		return reclaimed;
	}

	/** 关闭全部对局。进程退出时调用，避免留下孤儿 Godot 进程。 */
	async shutdown(): Promise<void> {
		await Promise.all(
			[...this.#entries.keys()].map(async (matchId) => {
				try {
					await this.stop(matchId, "requested");
				} catch {
					// 子进程已经杀掉。控制面注销失败不能挡住关机。
				}
			}),
		);
	}

	async #finalize(matchId: string, reason: MatchStopReason, exit?: MatchExit): Promise<MatchRecord | undefined> {
		const entry = this.#entries.get(matchId);
		if (entry === undefined || entry.record.state === "stopped") {
			return entry?.record;
		}

		this.#ports.release(entry.record.port);
		removeMatchEnvelopeFile(entry.envelopePath);
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

		try {
			const settlement = parseMatchTickSettlement(entry.process.recentOutput());
			if (settlement !== undefined) {
				await this.#options.registrar.recordSettlement(matchId, settlement);
				entry.settlementPosted = true;
			}
		} catch (error) {
			if (error instanceof MatchSessionSettlementError) {
				throw error;
			}
			throw new MatchSessionSettlementError(error instanceof Error ? error.message : String(error));
		}

		try {
			await this.#options.registrar.unregister(matchId);
		} catch (error) {
			if (error instanceof MatchSessionUnregisterError) {
				throw error;
			}
			throw new MatchSessionUnregisterError(error instanceof Error ? error.message : String(error));
		}

		return entry.record;
	}
}
