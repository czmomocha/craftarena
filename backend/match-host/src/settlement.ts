import type { RecordMatchSettlementRequest } from "../../contracts/src/match_settlement.ts";

export type MatchHeartbeatSettlement = RecordMatchSettlementRequest;

function asRecord(value: unknown): Record<string, unknown> | undefined {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		return undefined;
	}
	return value as Record<string, unknown>;
}

function asInt(value: unknown): number | undefined {
	return typeof value === "number" && Number.isInteger(value) ? value : undefined;
}

function asString(value: unknown): string | undefined {
	return typeof value === "string" && value.length > 0 ? value : undefined;
}

function parseRow(value: unknown): RecordMatchSettlementRequest["rows"][number] | undefined {
	const row = asRecord(value);
	if (row === undefined) {
		return undefined;
	}
	const slot = asInt(row["slot"]);
	const place = asInt(row["place"]);
	const finishTick = asInt(row["finish_tick"]);
	const acceptedCount = asInt(row["accepted_count"]);
	if (slot === undefined || place === undefined || finishTick === undefined || acceptedCount === undefined) {
		return undefined;
	}
	if (finishTick < 0 || slot < 0 || slot > 7 || place < 1 || place > 8 || acceptedCount < 0) {
		return undefined;
	}
	return { slot, place, finishTick, acceptedCount };
}

function parseSettlementObject(raw: Record<string, unknown>): MatchHeartbeatSettlement | undefined {
	const tick = asInt(raw["tick"]);
	const stateHash = asString(raw["state_hash"]);
	const padTotal = asInt(raw["pad_total"]);
	const mvpSlot = asInt(raw["mvp_slot"]);
	const rowsRaw = raw["rows"];
	if (
		tick === undefined ||
		stateHash === undefined ||
		padTotal === undefined ||
		mvpSlot === undefined ||
		!Array.isArray(rowsRaw) ||
		rowsRaw.length < 1 ||
		rowsRaw.length > 8
	) {
		return undefined;
	}
	const rows = [];
	for (const item of rowsRaw) {
		const row = parseRow(item);
		if (row === undefined) {
			return undefined;
		}
		rows.push(row);
	}
	return { tick, stateHash, padTotal, mvpSlot, rows };
}

/**
 * 从对局进程 recentOutput 里取最后一条带 settlement 的 match_tick 心跳。
 * 心跳是 snake_case；控制面 POST 是 camelCase。
 */
export function parseMatchTickSettlement(lines: readonly string[]): MatchHeartbeatSettlement | undefined {
	for (let index = lines.length - 1; index >= 0; index -= 1) {
		const line = lines[index]?.trim() ?? "";
		if (line === "") {
			continue;
		}
		let parsed: unknown;
		try {
			parsed = JSON.parse(line);
		} catch {
			continue;
		}
		const body = asRecord(parsed);
		if (body === undefined || body["event"] !== "match_tick") {
			continue;
		}
		const settlement = asRecord(body["settlement"]);
		if (settlement === undefined) {
			continue;
		}
		const payload = parseSettlementObject(settlement);
		if (payload === undefined) {
			continue;
		}
		const heartbeatTick = asInt(body["tick"]);
		if (heartbeatTick !== undefined && heartbeatTick !== payload.tick) {
			continue;
		}
		return payload;
	}
	return undefined;
}

/**
 * 从 recentOutput 取最后一条 match_tick 的 `valid_input_tick`。
 * 只认 ≥0 的整数。缺字段、负数、非整数、没有 match_tick：不续租。
 * 以最后一条 match_tick 为准，不回看更早的心跳。
 */
export function parseMatchTickValidInputTick(lines: readonly string[]): number | undefined {
	for (let index = lines.length - 1; index >= 0; index -= 1) {
		const line = lines[index]?.trim() ?? "";
		if (line === "") {
			continue;
		}
		let parsed: unknown;
		try {
			parsed = JSON.parse(line);
		} catch {
			continue;
		}
		const body = asRecord(parsed);
		if (body === undefined || body["event"] !== "match_tick") {
			continue;
		}
		const tick = asInt(body["valid_input_tick"]);
		if (tick === undefined || tick < 0) {
			return undefined;
		}
		return tick;
	}
	return undefined;
}
