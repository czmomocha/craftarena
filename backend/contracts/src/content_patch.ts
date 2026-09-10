/**
 * P0/P1 运行房补丁 HTTP 契约。
 *
 * Fastify JSON Schema 是控制面契约的单一事实源（CD-43）。控制面只校验信封
 * 形状、HMAC 与 ops 白名单等级，不重算 PatchHash（规范编码在 Godot StateHasher）。
 * 补丁不移动 latest。OpenAPI 仍未从这些 schema 生成。
 */

import {
	CONTENT_HEX_LEN,
	CONTENT_ID_MAX,
	CONTENT_PUBLISH_SCHEMA_VERSION,
	CONTENT_VERSION_MAX,
	CONTENT_VERSION_MIN,
} from "./content_publish.ts";

export const CONTENT_PATCH_SCHEMA_VERSION = CONTENT_PUBLISH_SCHEMA_VERSION;
export const CONTENT_PATCH_SEQ_MIN = 1;
export const CONTENT_PATCH_SEQ_MAX = 1_000_000;

export const CONTENT_PATCH_BAGS = {
	visual: "visual",
	destructibles: "destructibles",
	hazards: "hazards",
} as const;

export const CONTENT_PATCH_FIELDS = {
	fxRevision: "fx_revision",
	durability: "durability",
	cooldownTicks: "cooldown_ticks",
} as const;

export const CONTENT_PATCH_LEVELS = {
	p0: "p0",
	p1: "p1",
	p2: "p2",
} as const;

export const CONTENT_PATCH_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	envelopeKeys: "envelope_keys",
	idInvalid: "id_invalid",
	versionInvalid: "version_invalid",
	seqInvalid: "seq_invalid",
	levelInvalid: "level_invalid",
	levelForbidden: "level_forbidden",
	levelUnderreported: "level_underreported",
	signatureMismatch: "signature_mismatch",
	seqNotNext: "seq_not_next",
	contentNotFound: "content_not_found",
	versionNotFound: "version_not_found",
	alreadyLatest: "already_latest",
	opsInvalid: "ops_invalid",
} as const;

export type ContentPatchError =
	(typeof CONTENT_PATCH_ERRORS)[keyof typeof CONTENT_PATCH_ERRORS];

export type ContentPatchLevel =
	(typeof CONTENT_PATCH_LEVELS)[keyof typeof CONTENT_PATCH_LEVELS];

export interface ContentPatchOp {
	readonly bag: string;
	readonly entity_id: number;
	readonly field: string;
	readonly value: number;
}

export interface ContentPatchRequest {
	readonly schema_version: typeof CONTENT_PATCH_SCHEMA_VERSION;
	readonly content_id: string;
	readonly base_version: number;
	readonly seq: number;
	readonly level: "p0" | "p1";
	readonly patch_hash: string;
	readonly signature: string;
	readonly ops: readonly ContentPatchOp[];
}

export interface ContentPatchView {
	readonly schema_version: typeof CONTENT_PATCH_SCHEMA_VERSION;
	readonly content_id: string;
	readonly base_version: number;
	readonly seq: number;
	readonly level: "p0" | "p1";
	readonly patch_hash: string;
	readonly signature: string;
	readonly ops: readonly ContentPatchOp[];
}

export interface ContentRollbackRequest {
	readonly schema_version: typeof CONTENT_PATCH_SCHEMA_VERSION;
	readonly target_version: number;
}

export const contentPatchOpSchema = {
	type: "object",
	additionalProperties: false,
	required: ["bag", "entity_id", "field", "value"],
	properties: {
		bag: { type: "string", minLength: 1, maxLength: 32 },
		entity_id: { type: "integer", minimum: 0 },
		field: { type: "string", minLength: 1, maxLength: 32 },
		value: { type: "integer", minimum: 0 },
	},
} as const;

export const contentPatchBodySchema = {
	type: "object",
	additionalProperties: false,
	required: [
		"schema_version",
		"content_id",
		"base_version",
		"seq",
		"level",
		"patch_hash",
		"signature",
		"ops",
	],
	properties: {
		schema_version: { type: "integer", const: CONTENT_PATCH_SCHEMA_VERSION },
		content_id: {
			type: "string",
			minLength: 1,
			maxLength: CONTENT_ID_MAX,
			pattern: "^[A-Za-z0-9._-]+$",
		},
		base_version: { type: "integer", minimum: CONTENT_VERSION_MIN, maximum: CONTENT_VERSION_MAX },
		seq: { type: "integer", minimum: CONTENT_PATCH_SEQ_MIN, maximum: CONTENT_PATCH_SEQ_MAX },
		level: { type: "string", enum: ["p0", "p1"] },
		patch_hash: {
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
		ops: { type: "array", minItems: 1, maxItems: 32, items: contentPatchOpSchema },
	},
} as const;

export const contentRollbackBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["schema_version", "target_version"],
	properties: {
		schema_version: { type: "integer", const: CONTENT_PATCH_SCHEMA_VERSION },
		target_version: { type: "integer", minimum: CONTENT_VERSION_MIN, maximum: CONTENT_VERSION_MAX },
	},
} as const;

export function classifyPatchOp(op: ContentPatchOp): ContentPatchLevel | "invalid" {
	if (op.bag === CONTENT_PATCH_BAGS.visual && op.field === CONTENT_PATCH_FIELDS.fxRevision) {
		return CONTENT_PATCH_LEVELS.p0;
	}
	if (op.bag === CONTENT_PATCH_BAGS.destructibles && op.field === CONTENT_PATCH_FIELDS.durability) {
		return CONTENT_PATCH_LEVELS.p1;
	}
	if (op.bag === CONTENT_PATCH_BAGS.hazards && op.field === CONTENT_PATCH_FIELDS.cooldownTicks) {
		return CONTENT_PATCH_LEVELS.p1;
	}
	if (op.bag.length === 0 || op.field.length === 0) {
		return "invalid";
	}
	return CONTENT_PATCH_LEVELS.p2;
}

export function classifyPatchOps(ops: readonly ContentPatchOp[]): ContentPatchLevel | "invalid" {
	if (ops.length === 0) {
		return "invalid";
	}
	let required: ContentPatchLevel = CONTENT_PATCH_LEVELS.p0;
	for (const op of ops) {
		const classified = classifyPatchOp(op);
		if (classified === "invalid") {
			return "invalid";
		}
		if (patchRank(classified) > patchRank(required)) {
			required = classified;
		}
	}
	return required;
}

export function livePatchAllowed(level: ContentPatchLevel): boolean {
	return level === CONTENT_PATCH_LEVELS.p0 || level === CONTENT_PATCH_LEVELS.p1;
}

export function patchRank(level: ContentPatchLevel): number {
	if (level === CONTENT_PATCH_LEVELS.p0) {
		return 0;
	}
	if (level === CONTENT_PATCH_LEVELS.p1) {
		return 1;
	}
	return 2;
}
