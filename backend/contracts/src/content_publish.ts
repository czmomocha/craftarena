/**
 * 内容发布 HTTP 契约。
 *
 * Fastify JSON Schema 是控制面契约的单一事实源（CD-43）。控制面只校验信封
 * 形状与 HMAC，不重算 ContentHash（规范编码在 Godot StateHasher）。
 * OpenAPI 仍未从这些 schema 生成。
 */

export const CONTENT_PUBLISH_SCHEMA_VERSION = 1;
export const CONTENT_VERSION_MIN = 1;
export const CONTENT_VERSION_MAX = 1_000_000;
export const CONTENT_ID_MAX = 64;
export const CONTENT_HEX_LEN = 64;

export const CONTENT_PUBLISH_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	envelopeKeys: "envelope_keys",
	idInvalid: "id_invalid",
	versionInvalid: "version_invalid",
	signatureMismatch: "signature_mismatch",
	versionExists: "version_exists",
	versionNotNext: "version_not_next",
	contentNotFound: "content_not_found",
	versionNotFound: "version_not_found",
} as const;

export type ContentPublishError =
	(typeof CONTENT_PUBLISH_ERRORS)[keyof typeof CONTENT_PUBLISH_ERRORS];

export interface ContentPublishRequest {
	readonly schema_version: typeof CONTENT_PUBLISH_SCHEMA_VERSION;
	readonly content_id: string;
	readonly version: number;
	readonly content_hash: string;
	readonly signature: string;
	readonly bundle: Record<string, unknown>;
}

export type ContentVersionView = ContentPublishRequest;

export const contentPublishBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["schema_version", "content_id", "version", "content_hash", "signature", "bundle"],
	properties: {
		schema_version: { type: "integer", const: CONTENT_PUBLISH_SCHEMA_VERSION },
		content_id: {
			type: "string",
			minLength: 1,
			maxLength: CONTENT_ID_MAX,
			pattern: "^[A-Za-z0-9._-]+$",
		},
		version: { type: "integer", minimum: CONTENT_VERSION_MIN, maximum: CONTENT_VERSION_MAX },
		content_hash: {
			type: "string",
			minLength: CONTENT_HEX_LEN,
			maxLength: CONTENT_HEX_LEN,
			pattern: "^[0-9a-f]{64}$",
		},
		signature: {
			type: "string",
			minLength: CONTENT_HEX_LEN,
			maxLength: CONTENT_HEX_LEN,
			pattern: "^[0-9a-f]{64}$",
		},
		bundle: { type: "object" },
	},
} as const;
