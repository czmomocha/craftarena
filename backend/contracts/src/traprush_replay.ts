/**
 * TRAPRUSH 玩家回放库 HTTP 契约。
 *
 * 磁带是命令日志重仿真（CD-43 §3），不是录像、不是快照流。
 * MatchHost 在全员冲线后 POST；GET 只返回当前账号（Guest 按 guest id）。
 * 每账号环 100 条。本机 Solo 环 50 不走本接口。结算表不动。
 * Fastify JSON Schema 是单一事实源。OpenAPI 仍未生成。
 */

export const TRAPRUSH_REPLAY_SCHEMA_VERSION = 1;
export const TRAPRUSH_REPLAY_MAX_BYTES = 524_288;
export const TRAPRUSH_REPLAY_SERVER_RING = 100;
export const TRAPRUSH_REPLAY_LOCAL_RING = 50;
export const TRAPRUSH_REPLAY_INTENT_ID_MIN = 1;
export const TRAPRUSH_REPLAY_INTENT_ID_MAX = 6;

export const TRAPRUSH_REPLAY_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	invalidMatchId: "invalid_match_id",
	invalidTape: "invalid_tape",
	tapeTooLarge: "tape_too_large",
	matchNotFound: "match_not_found",
	sessionInvalid: "session_invalid",
	notFound: "replay_not_found",
	alreadyStored: "already_stored",
} as const;

export type TraprushReplayError = (typeof TRAPRUSH_REPLAY_ERRORS)[keyof typeof TRAPRUSH_REPLAY_ERRORS];

export interface TraprushReplayCommand {
	readonly tick: number;
	readonly slot: number;
	readonly intent_id: number;
	readonly dx: number;
	readonly dz: number;
	readonly yaw_bam: number;
}

export interface TraprushReplayTape {
	readonly schema_version: number;
	readonly course_id: string;
	readonly official_path: string;
	readonly content_hash: string;
	readonly seed: number;
	readonly go_tick: number;
	readonly seats: number;
	readonly commands: readonly TraprushReplayCommand[];
	readonly finish_ticks: readonly number[];
}

export interface RecordMatchReplayRequest {
	readonly tape: TraprushReplayTape;
}

export interface RecordMatchReplayResponse {
	readonly matchId: string;
	readonly stored: number;
}

export interface TraprushReplayListItem {
	readonly replay_id: string;
	readonly match_id: string;
	readonly course_id: string;
	readonly seats: number;
	readonly finish_ticks: readonly number[];
	readonly created_at: string;
}

export interface TraprushReplayListResponse {
	readonly items: readonly TraprushReplayListItem[];
}

export interface TraprushReplayView extends TraprushReplayListItem {
	readonly tape: TraprushReplayTape;
}

const commandSchema = {
	type: "object",
	additionalProperties: false,
	required: ["tick", "slot", "intent_id", "dx", "dz", "yaw_bam"],
	properties: {
		tick: { type: "integer", minimum: 0 },
		slot: { type: "integer", minimum: 0, maximum: 7 },
		intent_id: {
			type: "integer",
			minimum: TRAPRUSH_REPLAY_INTENT_ID_MIN,
			maximum: TRAPRUSH_REPLAY_INTENT_ID_MAX,
		},
		dx: { type: "integer" },
		dz: { type: "integer" },
		yaw_bam: { type: "integer" },
	},
} as const;

export const traprushReplayTapeSchema = {
	type: "object",
	additionalProperties: false,
	required: [
		"schema_version",
		"course_id",
		"official_path",
		"content_hash",
		"seed",
		"go_tick",
		"seats",
		"commands",
		"finish_ticks",
	],
	properties: {
		schema_version: { type: "integer", const: TRAPRUSH_REPLAY_SCHEMA_VERSION },
		course_id: { type: "string", minLength: 1, maxLength: 64 },
		official_path: { type: "string", minLength: 1, maxLength: 256 },
		content_hash: { type: "string", minLength: 64, maxLength: 64 },
		seed: { type: "integer" },
		go_tick: { type: "integer", minimum: 0 },
		seats: { type: "integer", minimum: 1, maximum: 8 },
		commands: {
			type: "array",
			maxItems: 24_000,
			items: commandSchema,
		},
		finish_ticks: {
			type: "array",
			minItems: 1,
			maxItems: 8,
			items: { type: "integer", minimum: 0 },
		},
	},
} as const;

export const recordMatchReplayBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["tape"],
	properties: {
		tape: traprushReplayTapeSchema,
	},
} as const;
