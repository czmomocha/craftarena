/**
 * 会话租约。参数的所有者是 CD-44 §3，这里只实现规则，不重新定义数值。
 *
 * 那一节给了两条并存的约束：
 *   1. 默认会话租约 30 分钟，只有"通过校验并改变权威状态的真人命令"可以续租；
 *   2. 连续 10 分钟没有这类输入就关闭进程。
 *
 * 两条都实现、谁先到谁生效。不要因为"续租后 idle 总是先触发"就把它们合并成一条——
 * 那等于替 CD-44 改规则，而续租策略将来完全可能调整。
 */

export interface Lease {
	readonly createdAt: number;
	/** 最近一次**有效**输入的时间。心跳、重复命令、被拒命令和 Bot 流量都不更新它。 */
	readonly lastValidInputAt: number;
	readonly expiresAt: number;
}

export type LeaseExpiryReason = "lease_expired" | "idle_timeout";

export interface LeaseStatus {
	readonly expired: boolean;
	readonly reason?: LeaseExpiryReason | undefined;
}

export function createLease(now: number, leaseDurationMs: number): Lease {
	return {
		createdAt: now,
		lastValidInputAt: now,
		expiresAt: now + leaseDurationMs,
	};
}

/**
 * 仅在收到通过校验且改变了权威状态的真人命令时调用。
 * 调用点必须自己确认这一前提——本函数无法分辨传进来的是什么。
 */
export function renewLease(lease: Lease, now: number, leaseDurationMs: number): Lease {
	return {
		createdAt: lease.createdAt,
		lastValidInputAt: now,
		expiresAt: now + leaseDurationMs,
	};
}

export function evaluateLease(lease: Lease, now: number, idleTimeoutMs: number): LeaseStatus {
	if (now >= lease.expiresAt) {
		return { expired: true, reason: "lease_expired" };
	}

	if (now - lease.lastValidInputAt >= idleTimeoutMs) {
		return { expired: true, reason: "idle_timeout" };
	}

	return { expired: false };
}
