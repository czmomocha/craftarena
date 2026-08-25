/**
 * 对局票据 HTTP 契约。
 *
 * Fastify JSON Schema 是控制面契约的单一事实源（CD-43）。网关只调用
 * `POST /tickets/verify`，不解析签发细节，也不碰数据库（宪法第二十一条）。
 * OpenAPI 仍未从这些 schema 生成，不把本文件表述为已发布的 OpenAPI。
 */

export const TICKET_REJECT_REASONS = {
	missingTicket: "missing_ticket",
	unknownTicket: "unknown_ticket",
	expiredTicket: "expired_ticket",
	consumedTicket: "consumed_ticket",
} as const;

export type TicketRejectReason = (typeof TICKET_REJECT_REASONS)[keyof typeof TICKET_REJECT_REASONS];

export interface RegisterMatchSessionRequest {
	readonly matchId?: string;
	readonly upstreamUrl: string;
	/** 本场席位。省略时控制面按 TRAPRUSH 上限 8 记，不是默认开局人数。 */
	readonly seats?: number;
}

export interface RegisterMatchSessionResponse {
	readonly matchId: string;
	readonly upstreamUrl: string;
	readonly seats: number;
}

export interface UnregisterMatchSessionResponse {
	readonly matchId: string;
}

export interface IssueMatchTicketResponse {
	readonly ticket: string;
	readonly matchId: string;
	readonly expiresAt: string;
}

export interface VerifyMatchTicketRequest {
	readonly ticket: string;
}

export interface VerifyMatchTicketSuccess {
	readonly ok: true;
	readonly upstreamUrl: string;
}

export interface VerifyMatchTicketFailure {
	readonly ok: false;
	readonly reason: TicketRejectReason;
}

export type VerifyMatchTicketResponse = VerifyMatchTicketSuccess | VerifyMatchTicketFailure;

export const registerMatchSessionBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["upstreamUrl"],
	properties: {
		matchId: { type: "string", minLength: 1, maxLength: 64 },
		upstreamUrl: { type: "string", minLength: 1, maxLength: 512 },
		seats: { type: "integer", minimum: 1, maximum: 8 },
	},
} as const;

export const verifyMatchTicketBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["ticket"],
	properties: {
		ticket: { type: "string", minLength: 1, maxLength: 256 },
	},
} as const;
