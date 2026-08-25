import { createHash, randomBytes } from "node:crypto";

/** 队列条目过期窗口。开发期占位，不是产品锁定值。 */
export const DEFAULT_QUEUE_TTL_MS = 600_000;

/**
 * 预计等待 = 当前位次 × 本间隔。开发期占位，不是产品局时或真实排队模型。
 */
export const DEFAULT_QUEUE_SLOT_ESTIMATE_MS = 30_000;

export function generateQueueToken(): string {
	return randomBytes(32).toString("base64url");
}

export function hashQueueToken(token: string): string {
	return createHash("sha256").update(token, "utf8").digest("hex");
}
