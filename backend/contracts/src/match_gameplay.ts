/**
 * 匹配 HTTP 的玩法判别位与 BASTION 1v1 席位映射。
 * 字段形状的所有者是 CD-42 §3.5。本文件只放标识符与座位合同。
 */

export const MATCH_GAMEPLAY_TRAPRUSH = "traprush" as const;
export const MATCH_GAMEPLAY_BASTION = "bastion" as const;

export const MATCH_GAMEPLAY_IDS = [MATCH_GAMEPLAY_TRAPRUSH, MATCH_GAMEPLAY_BASTION] as const;
export type MatchGameplay = (typeof MATCH_GAMEPLAY_IDS)[number];

export const DEFAULT_MATCH_GAMEPLAY: MatchGameplay = MATCH_GAMEPLAY_TRAPRUSH;

/** M6 官方 1v1。2v2 属 M7。 */
export const BASTION_MATCH_SEATS = 2;

/** 席位 0 → 蓝图 TEAM_A=1，席位 1 → TEAM_B=2。 */
export const BASTION_SEAT_TEAM_A = 1;
export const BASTION_SEAT_TEAM_B = 2;

export function isMatchGameplay(value: unknown): value is MatchGameplay {
	return value === MATCH_GAMEPLAY_TRAPRUSH || value === MATCH_GAMEPLAY_BASTION;
}

export function bastionTeamIdForSeat(seat: number): number {
	if (seat === 0) {
		return BASTION_SEAT_TEAM_A;
	}
	if (seat === 1) {
		return BASTION_SEAT_TEAM_B;
	}
	return 0;
}

export function bastionSeatForTeamId(teamId: number): number {
	if (teamId === BASTION_SEAT_TEAM_A) {
		return 0;
	}
	if (teamId === BASTION_SEAT_TEAM_B) {
		return 1;
	}
	return -1;
}
