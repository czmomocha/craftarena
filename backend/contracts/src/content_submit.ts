/**
 * 玩家代签发布 HTTP 契约（CD-33 §2.2 / CD-42 §3.5）。
 *
 * 玩家只上传 bundle + content_hash。控制面鉴权后代签；不接受 signature /
 * version / content_id。持钥 POST /content/publish 仍只给测试 / 工具。
 * OpenAPI 仍未生成。
 */

import { CONTENT_HEX_LEN } from "./content_publish.ts";

export const CONTENT_SUBMIT_BUNDLE_SCHEMA_MIN = 1;
export const CONTENT_SUBMIT_BUNDLE_SCHEMA_MAX = 2;

export const CONTENT_SUBMIT_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	hashInvalid: "hash_invalid",
	bundleInvalid: "bundle_invalid",
	idOfficial: "id_official",
	sessionInvalid: "session_invalid",
} as const;

export type ContentSubmitError =
	(typeof CONTENT_SUBMIT_ERRORS)[keyof typeof CONTENT_SUBMIT_ERRORS];

export interface ContentSubmitRequest {
	readonly bundle: Record<string, unknown>;
	readonly content_hash: string;
}

export interface ContentSubmitView {
	readonly id: string;
	readonly version: number;
	readonly content_hash: string;
	readonly latest: number;
}

export const contentSubmitBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["bundle", "content_hash"],
	properties: {
		bundle: { type: "object" },
		content_hash: {
			type: "string",
			minLength: CONTENT_HEX_LEN,
			maxLength: CONTENT_HEX_LEN,
			pattern: "^[0-9a-f]{64}$",
		},
	},
} as const;
