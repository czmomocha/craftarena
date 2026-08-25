import type { MatchSettlementRow, RecordMatchSettlementRequest } from "../../contracts/src/match_settlement.ts";

export function isValidSettlementSemantics(body: RecordMatchSettlementRequest): boolean {
	const slots = new Set<number>();
	const places = new Set<number>();
	let winnerSlot = -1;
	for (const row of body.rows) {
		if (slots.has(row.slot) || places.has(row.place)) {
			return false;
		}
		slots.add(row.slot);
		places.add(row.place);
		if (row.place === 1) {
			winnerSlot = row.slot;
		}
	}
	if (winnerSlot < 0 || winnerSlot !== body.mvpSlot) {
		return false;
	}
	for (let place = 1; place <= body.rows.length; place += 1) {
		if (!places.has(place)) {
			return false;
		}
	}
	return true;
}

export function settlementRowsFromUnknown(rows: readonly MatchSettlementRow[]): readonly MatchSettlementRow[] {
	return rows.map((row) => ({
		slot: row.slot,
		place: row.place,
		finishTick: row.finishTick,
		acceptedCount: row.acceptedCount,
	}));
}
