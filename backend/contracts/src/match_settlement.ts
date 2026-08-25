/**
 * 单局结算 HTTP 契约。
 *
 * Fastify JSON Schema 是控制面契约的单一事实源（CD-43）。MatchHost 在对局
 * 停止前把权威心跳里的结算记录 POST 上来；控制面写库。客户端与离线模式
 * 不调用本接口。OpenAPI 仍未生成。不锁账号绑定、MMR 或限时未全员冲线结算。
 */

export interface MatchSettlementRow {
	readonly slot: number;
	readonly place: number;
	readonly finishTick: number;
	readonly acceptedCount: number;
}

export interface RecordMatchSettlementRequest {
	readonly tick: number;
	readonly stateHash: string;
	readonly padTotal: number;
	readonly mvpSlot: number;
	readonly rows: readonly MatchSettlementRow[];
}

export interface MatchSettlementResponse {
	readonly matchId: string;
	readonly tick: number;
	readonly stateHash: string;
	readonly padTotal: number;
	readonly mvpSlot: number;
	readonly rows: readonly MatchSettlementRow[];
	readonly createdAt: string;
}

export const recordMatchSettlementBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["tick", "stateHash", "padTotal", "mvpSlot", "rows"],
	properties: {
		tick: { type: "integer", minimum: 0 },
		stateHash: { type: "string", minLength: 1, maxLength: 128 },
		padTotal: { type: "integer", minimum: 0 },
		mvpSlot: { type: "integer", minimum: 0, maximum: 7 },
		rows: {
			type: "array",
			minItems: 1,
			maxItems: 8,
			items: {
				type: "object",
				additionalProperties: false,
				required: ["slot", "place", "finishTick", "acceptedCount"],
				properties: {
					slot: { type: "integer", minimum: 0, maximum: 7 },
					place: { type: "integer", minimum: 1, maximum: 8 },
					finishTick: { type: "integer", minimum: 0 },
					acceptedCount: { type: "integer", minimum: 0 },
				},
			},
		},
	},
} as const;
