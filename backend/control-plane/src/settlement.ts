import type {
	MatchSettlementRow,
	MatchSettlementTeam,
	RecordMatchSettlementRequest,
} from "../../contracts/src/match_settlement.ts";
import { BASTION_MATCH_SEATS, bastionSeatForTeamId, bastionTeamIdForSeat } from "../../contracts/src/match_gameplay.ts";

export function isValidSettlementSemantics(body: RecordMatchSettlementRequest): boolean {
	if (body.teams !== undefined) {
		return isValidBastionSettlement(body);
	}
	return isValidTraprushSettlement(body);
}

function isValidTraprushSettlement(body: RecordMatchSettlementRequest): boolean {
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

function isValidBastionSettlement(body: RecordMatchSettlementRequest): boolean {
	const teams = body.teams;
	if (teams === undefined || teams.length !== BASTION_MATCH_SEATS || body.rows.length !== BASTION_MATCH_SEATS) {
		return false;
	}
	const teamIds = new Set<number>();
	const teamById = new Map<number, (typeof teams)[number]>();
	for (const team of teams) {
		if (teamIds.has(team.teamId) || bastionSeatForTeamId(team.teamId) < 0) {
			return false;
		}
		if (team.place !== 1 && team.place !== 2) {
			return false;
		}
		teamIds.add(team.teamId);
		teamById.set(team.teamId, team);
	}
	if (!teamIds.has(1) || !teamIds.has(2)) {
		return false;
	}

	const slots = new Set<number>();
	for (const row of body.rows) {
		if (slots.has(row.slot) || row.slot < 0 || row.slot >= BASTION_MATCH_SEATS) {
			return false;
		}
		slots.add(row.slot);
		const team = teamById.get(bastionTeamIdForSeat(row.slot));
		if (team === undefined || row.place !== team.place) {
			return false;
		}
	}
	if (slots.size !== BASTION_MATCH_SEATS) {
		return false;
	}

	const placeOne = teams.filter((team) => team.place === 1);
	if (placeOne.length === 2) {
		return body.mvpSlot === 0 || body.mvpSlot === 1;
	}
	if (placeOne.length !== 1) {
		return false;
	}
	return body.mvpSlot === bastionSeatForTeamId(placeOne[0]!.teamId);
}

export function settlementRowsFromUnknown(rows: readonly MatchSettlementRow[]): readonly MatchSettlementRow[] {
	return rows.map((row) => ({
		slot: row.slot,
		place: row.place,
		finishTick: row.finishTick,
		acceptedCount: row.acceptedCount,
	}));
}

export function settlementTeamsFromUnknown(
	teams: readonly MatchSettlementTeam[] | undefined,
): readonly MatchSettlementTeam[] | undefined {
	if (teams === undefined) {
		return undefined;
	}
	return teams.map((team) => ({
		teamId: team.teamId,
		place: team.place,
		coreHealth: team.coreHealth,
		leaked: team.leaked,
		finishTick: team.finishTick,
	}));
}
