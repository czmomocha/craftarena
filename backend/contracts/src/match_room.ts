/**
 * 匹配 / 房间码 HTTP 契约。
 *
 * 玩家入口在控制面：快速游戏与按码加入都只换一张一次性票据。
 * MatchHost 不查库（宪法第二十一条）。OpenAPI 仍未生成。
 */

export interface MatchmakingJoinResponse {
	readonly roomCode: string;
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
	readonly seats: number;
	readonly issued: number;
}
