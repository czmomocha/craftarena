import { createHash, randomBytes } from "node:crypto";

/** 开发期占位 TTL，不是产品锁定值。正式窗口见后续章节 / CD-63。 */
export const DEFAULT_TICKET_TTL_MS = 120_000;

export const MATCH_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isMatchId(value: string): boolean {
	return MATCH_ID_PATTERN.test(value);
}

export function generateTicket(): string {
	return randomBytes(32).toString("base64url");
}

export function hashTicket(ticket: string): string {
	return createHash("sha256").update(ticket, "utf8").digest("hex");
}

/**
 * 对局进程 WebSocket 地址。只允许 ws/wss，拒绝 userinfo 和 fragment，
 * 避免把票据解析成任意 URI。
 */
export function parseUpstreamUrl(raw: string): string | undefined {
	const trimmed = raw.trim();
	if (trimmed === "" || trimmed.length > 512) {
		return undefined;
	}

	let parsed: URL;
	try {
		parsed = new URL(trimmed);
	} catch {
		return undefined;
	}

	if (parsed.protocol !== "ws:" && parsed.protocol !== "wss:") {
		return undefined;
	}
	if (parsed.username !== "" || parsed.password !== "") {
		return undefined;
	}
	if (parsed.hostname === "" || parsed.hash !== "") {
		return undefined;
	}

	return trimmed;
}
