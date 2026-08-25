/**
 * 匹配 / 房间码 / 等待队列 HTTP 契约。
 *
 * 玩家入口在控制面：快速游戏与按码加入都只换一张一次性票据。
 * 容量满时入 FIFO，轮询换同一张票。MatchHost 不查库（宪法第二十一条）。
 * 快速游戏 / 建房可带官方赛道 `course` 与本场 `seats`（1～8，省略为 2）；
 * 按码加入走房内已锁课程与人数。OpenAPI 仍未生成。
 */

import type { OfficialTraprushCourseId } from "./official_courses.ts";

export interface MatchmakingJoinResponse {
	readonly roomCode: string;
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
	readonly seats: number;
	readonly issued: number;
	readonly course: OfficialTraprushCourseId;
}

export type MatchQueueKind = "quick" | "create_room";

export interface MatchmakingQueueWaitingResponse {
	readonly status: "waiting";
	readonly queueToken: string;
	readonly position: number;
	readonly estimatedWaitMs: number;
	readonly expiresAt: string;
	readonly course: OfficialTraprushCourseId;
	readonly seats: number;
}

export interface MatchmakingQueueReadyResponse extends MatchmakingJoinResponse {
	readonly status: "ready";
}

export interface MatchmakingQueueFailedResponse {
	readonly status: "failed";
	readonly error: string;
}

export type MatchmakingQueueStatusResponse =
	| MatchmakingQueueWaitingResponse
	| MatchmakingQueueReadyResponse
	| MatchmakingQueueFailedResponse;

export interface CancelMatchQueueResponse {
	readonly ok: true;
}
