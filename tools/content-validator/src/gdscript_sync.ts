import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import {
	AUDIO_BANK_SCHEMA_VERSION,
	AUTHORING_DOCUMENT_SCHEMA_VERSION,
	BASTION_BLUEPRINT_SCHEMA_VERSION,
	COMPONENT_SCHEMA_VERSION,
	L0_CONTRACT_VERSION,
	SIMULATION_BUNDLE_SCHEMA_VERSION,
} from "../../../backend/contracts/src/schemas.ts";
import { CANONICAL_MAX_DEPTH } from "./canonical_depth.ts";
import { loadJsonFile } from "./json_schema.ts";
import {
	AUDIO_BANK_PATH,
	AUDIO_BANK_SCHEMA_PATH,
	AUDIO_BANKS_DIR,
	AUDIO_CUE_CATALOG_PATH,
	AUDIO_CUE_PATH,
	AUTHORING_DOCUMENT_PATH,
	AUTHORING_DOCUMENT_SCHEMA_PATH,
	BASTION_BLUEPRINT_BUNDLE_PATH,
	BASTION_BLUEPRINT_SCHEMA_PATH,
	BASTION_PROTOTYPE_CATALOG_PATH,
	CANONICAL_PAYLOAD_PATH,
	COLLISION_SHAPE_KINDS_PATH,
	COMMAND_SCHEMA_PATH,
	COMPONENT_NAMES_PATH,
	COMPONENT_RECORD_PATH,
	COMPONENT_SCHEMA_PATH,
	EDIT_OP_NAMES_PATH,
	EVENT_SCHEMA_PATH,
	PLAYER_INTENT_NAMES_PATH,
	SHARED_COMMAND_PATH,
	SHARED_DOMAIN_EVENT_PATH,
	SHARED_IDS_PATH,
	SIMULATION_BUNDLE_PATH,
	SIMULATION_BUNDLE_SCHEMA_PATH,
	SKY_CATALOG_PATH,
	TOWER_TARGET_PRIORITIES_PATH,
} from "./paths.ts";
import { SKY_ID_MAX } from "./sky_catalog.ts";

export type SyncMismatch = {
	readonly name: string;
	readonly expected: string;
	readonly actual: string;
};

export function collectGdscriptSchemaMismatches(): SyncMismatch[] {
	const commandSchema = loadJsonFile(COMMAND_SCHEMA_PATH);
	const eventSchema = loadJsonFile(EVENT_SCHEMA_PATH);
	const mismatches: SyncMismatch[] = [];

	const intentNames = parseStringConstants(readFileSync(PLAYER_INTENT_NAMES_PATH, "utf8"));
	const schemaIntents = commandPlayerIntentEnum(commandSchema);
	pushListMismatch(mismatches, "player_intent_names", intentNames, schemaIntents);

	const editOps = parseStringConstants(readFileSync(EDIT_OP_NAMES_PATH, "utf8"));
	const schemaEditOps = commandEditOpEnum(commandSchema);
	pushListMismatch(mismatches, "edit_op_names", editOps, schemaEditOps);

	const kindValues = parseEnumNumbers(readFileSync(SHARED_COMMAND_PATH, "utf8"), "Kind");
	const schemaKinds = commandKindEnum(commandSchema);
	pushListMismatch(mismatches, "command_kind", kindValues.map(String), schemaKinds.map(String));

	const commandFields = parseVarNames(readFileSync(SHARED_COMMAND_PATH, "utf8"));
	const schemaCommandFields = schemaRequired(commandSchema);
	pushListMismatch(mismatches, "shared_command_fields", commandFields, schemaCommandFields);

	const eventFields = parseVarNames(readFileSync(SHARED_DOMAIN_EVENT_PATH, "utf8"));
	const schemaEventFields = schemaRequired(eventSchema);
	pushListMismatch(mismatches, "shared_domain_event_fields", eventFields, schemaEventFields);

	const maxDepth = parseIntConstant(readFileSync(CANONICAL_PAYLOAD_PATH, "utf8"), "MAX_DEPTH");
	if (maxDepth !== CANONICAL_MAX_DEPTH) {
		mismatches.push({
			name: "canonical_max_depth",
			expected: String(CANONICAL_MAX_DEPTH),
			actual: String(maxDepth),
		});
	}

	const contractVersion = parseIntConstant(readFileSync(SHARED_IDS_PATH, "utf8"), "CONTRACT_VERSION");
	if (contractVersion !== L0_CONTRACT_VERSION) {
		mismatches.push({
			name: "contract_version",
			expected: String(L0_CONTRACT_VERSION),
			actual: String(contractVersion),
		});
	}

	const componentSchema = loadJsonFile(COMPONENT_SCHEMA_PATH);
	const componentNames = parseStringConstants(readFileSync(COMPONENT_NAMES_PATH, "utf8"));
	const schemaComponentNames = componentPropertyNames(componentSchema);
	pushListMismatch(mismatches, "component_names", componentNames, schemaComponentNames);

	const shapeKinds = parseStringConstants(readFileSync(COLLISION_SHAPE_KINDS_PATH, "utf8"));
	const schemaShapeKinds = collisionShapeKindConsts(componentSchema);
	pushListMismatch(mismatches, "collision_shape_kinds", shapeKinds, schemaShapeKinds);

	const towerPriorities = parseStringConstants(readFileSync(TOWER_TARGET_PRIORITIES_PATH, "utf8"));
	const schemaTowerPriorities = towerTargetPriorityEnum(componentSchema);
	pushListMismatch(mismatches, "tower_target_priorities", towerPriorities, schemaTowerPriorities);

	const componentFields = parseVarNames(readFileSync(COMPONENT_RECORD_PATH, "utf8"));
	const schemaComponentFields = schemaRequired(componentSchema);
	pushListMismatch(mismatches, "component_record_fields", componentFields, schemaComponentFields);

	const componentSchemaVersion = parseIntConstant(readFileSync(COMPONENT_RECORD_PATH, "utf8"), "SCHEMA_VERSION");
	if (componentSchemaVersion !== COMPONENT_SCHEMA_VERSION) {
		mismatches.push({
			name: "component_schema_version",
			expected: String(COMPONENT_SCHEMA_VERSION),
			actual: String(componentSchemaVersion),
		});
	}

	// 天空目录上界。少了这条，谁在 GDScript 里加第三张天空、忘了改 TS，
	// content-validator 就会继续把 `sky_id = 2` 当未知 id 拒掉，而编译器已经放行。
	const skyIdMax = parseIntConstant(readFileSync(SKY_CATALOG_PATH, "utf8"), "SKY_ID_MAX");
	if (skyIdMax !== SKY_ID_MAX) {
		mismatches.push({
			name: "sky_id_max",
			expected: String(SKY_ID_MAX),
			actual: String(skyIdMax),
		});
	}

	const authoringSchema = loadJsonFile(AUTHORING_DOCUMENT_SCHEMA_PATH);
	const authoringFields = parseStringConstants(readFileSync(AUTHORING_DOCUMENT_PATH, "utf8"));
	const schemaAuthoringFields = schemaRequired(authoringSchema);
	pushListMismatch(mismatches, "authoring_document_fields", authoringFields, schemaAuthoringFields);

	const authoringSchemaVersion = parseIntConstant(readFileSync(AUTHORING_DOCUMENT_PATH, "utf8"), "SCHEMA_VERSION");
	if (authoringSchemaVersion !== AUTHORING_DOCUMENT_SCHEMA_VERSION) {
		mismatches.push({
			name: "authoring_document_schema_version",
			expected: String(AUTHORING_DOCUMENT_SCHEMA_VERSION),
			actual: String(authoringSchemaVersion),
		});
	}

	const bundleSchema = loadJsonFile(SIMULATION_BUNDLE_SCHEMA_PATH);
	const bundleFields = parseStringConstants(readFileSync(SIMULATION_BUNDLE_PATH, "utf8"));
	const schemaBundleFields = schemaPropertyNames(bundleSchema);
	pushListMismatch(mismatches, "simulation_bundle_fields", bundleFields, schemaBundleFields);

	const bundleSchemaVersion = parseIntConstant(readFileSync(SIMULATION_BUNDLE_PATH, "utf8"), "SCHEMA_VERSION");
	if (bundleSchemaVersion !== SIMULATION_BUNDLE_SCHEMA_VERSION) {
		mismatches.push({
			name: "simulation_bundle_schema_version",
			expected: String(SIMULATION_BUNDLE_SCHEMA_VERSION),
			actual: String(bundleSchemaVersion),
		});
	}

	pushBastionBlueprintMismatches(mismatches);

	const audioBankSchema = loadJsonFile(AUDIO_BANK_SCHEMA_PATH);
	const cueFields = parseVarNames(readFileSync(AUDIO_CUE_PATH, "utf8"));
	const schemaCueFields = cuePropertyNames(audioBankSchema);
	pushListMismatch(mismatches, "audio_cue_fields", cueFields, schemaCueFields);

	const audioBankSchemaVersion = parseIntConstant(readFileSync(AUDIO_BANK_PATH, "utf8"), "SCHEMA_VERSION");
	if (audioBankSchemaVersion !== AUDIO_BANK_SCHEMA_VERSION) {
		mismatches.push({
			name: "audio_bank_schema_version",
			expected: String(AUDIO_BANK_SCHEMA_VERSION),
			actual: String(audioBankSchemaVersion),
		});
	}

	const catalogIds = parseStringConstants(readFileSync(AUDIO_CUE_CATALOG_PATH, "utf8"));
	const bankIds = collectProductionBankIds();
	pushListMismatch(mismatches, "audio_cue_catalog", [...catalogIds].sort(), [...bankIds].sort());

	return mismatches;
}

/**
 * BASTION 蓝图 bundle 的两侧对齐。
 *
 * 除了字段名与版本号，这里还把**九个原型 id** 钉在 GDScript 白名单与 JSON Schema
 * 的 enum 之间。理由不是洁癖：2026-09-15 那次拍板只锁了「M6 用哪九个」，
 * CD-22 的候选表原文仍写着「不是锁定清单」。少了这条对齐，谁在 GDScript 里加一
 * 个狙击塔、Schema 忘了改，`npm test` 照样绿，白名单就悄悄扩大了。
 */
function pushBastionBlueprintMismatches(mismatches: SyncMismatch[]): void {
	const schema = loadJsonFile(BASTION_BLUEPRINT_SCHEMA_PATH);
	const bundleSource = readFileSync(BASTION_BLUEPRINT_BUNDLE_PATH, "utf8");

	pushListMismatch(
		mismatches,
		"bastion_blueprint_fields",
		parseFieldConstants(bundleSource),
		schemaPropertyNames(schema),
	);

	const version = parseIntConstant(bundleSource, "SCHEMA_VERSION");
	if (version !== BASTION_BLUEPRINT_SCHEMA_VERSION) {
		mismatches.push({
			name: "bastion_blueprint_schema_version",
			expected: String(BASTION_BLUEPRINT_SCHEMA_VERSION),
			actual: String(version),
		});
	}

	pushListMismatch(
		mismatches,
		"bastion_economy_keys",
		parseStringArrayConstant(bundleSource, "ECONOMY_KEYS"),
		schemaRequired(property(property(schema, "$defs"), "economy")),
	);

	const catalog = readFileSync(BASTION_PROTOTYPE_CATALOG_PATH, "utf8");
	const prototypeGroups: readonly { readonly name: string; readonly def: string }[] = [
		{ name: "TOWER_IDS", def: "tower_prototype_id" },
		{ name: "UNIT_IDS", def: "unit_prototype_id" },
		{ name: "OBSTACLE_IDS", def: "obstacle_prototype_id" },
	];
	for (const group of prototypeGroups) {
		pushListMismatch(
			mismatches,
			`bastion_${group.def}`,
			parseIntArrayConstant(catalog, group.name).map(String),
			defEnum(schema, group.def).map(String),
		);
	}

	const levelCap = parseIntConstant(catalog, "MAX_TOWER_LEVEL");
	if (levelCap !== 3) {
		mismatches.push({
			name: "bastion_max_tower_level",
			expected: "3",
			actual: String(levelCap),
		});
	}
}

function defEnum(schema: unknown, name: string): number[] {
	const values = asArray(property(property(property(schema, "$defs"), name), "enum"));
	return values.filter((value): value is number => typeof value === "number");
}

/** 只读 `const FIELD_*: String = "..."`，这样门面上的非字段字符串常量不参与对齐。 */
export function parseFieldConstants(source: string): string[] {
	const names: string[] = [];
	const pattern = /const\s+FIELD_[A-Z0-9_]*:\s*String\s*=\s*"([^"]+)"/g;
	for (const match of source.matchAll(pattern)) {
		const value = match[1];
		if (value !== undefined) {
			names.push(value);
		}
	}
	return names;
}

/**
 * `const X: PackedInt32Array = [A, B, C]`。元素可以是字面量，也可以是同一文件里
 * 用 `const NAME: int = N` 定义的符号——白名单就是那么写的，读不懂符号等于读不到
 * 真正生效的 id。
 */
export function parseIntArrayConstant(source: string, name: string): number[] {
	const match = source.match(new RegExp(`const\\s+${name}:\\s*PackedInt32Array\\s*=\\s*\\[([^\\]]*)\\]`));
	const body = match?.[1];
	if (body === undefined) {
		return [];
	}
	const symbols = parseIntConstantMap(source);
	const values: number[] = [];
	for (const raw of body.split(",")) {
		const token = raw.trim();
		if (token.length === 0) {
			continue;
		}
		const resolved = /^-?\d+$/.test(token) ? Number(token) : symbols.get(token);
		values.push(resolved ?? Number.NaN);
	}
	return values;
}

function parseIntConstantMap(source: string): Map<string, number> {
	const symbols = new Map<string, number>();
	for (const match of source.matchAll(/const\s+([A-Z_][A-Z0-9_]*):\s*int\s*=\s*(-?\d+)/g)) {
		const name = match[1];
		const raw = match[2];
		if (name !== undefined && raw !== undefined) {
			symbols.set(name, Number(raw));
		}
	}
	return symbols;
}

export function parseStringArrayConstant(source: string, name: string): string[] {
	const match = source.match(new RegExp(`const\\s+${name}:\\s*PackedStringArray\\s*=\\s*\\[([^\\]]*)\\]`));
	const body = match?.[1];
	if (body === undefined) {
		return [];
	}
	const values: string[] = [];
	for (const entry of body.matchAll(/"([^"]+)"/g)) {
		const value = entry[1];
		if (value !== undefined) {
			values.push(value);
		}
	}
	return values;
}

export function parseStringConstants(source: string): string[] {
	const names: string[] = [];
	const pattern = /const\s+[A-Z_][A-Z0-9_]*:\s*String\s*=\s*"([^"]+)"/g;
	for (const match of source.matchAll(pattern)) {
		const value = match[1];
		if (value !== undefined) {
			names.push(value);
		}
	}
	return names;
}

export function parseVarNames(source: string): string[] {
	const names: string[] = [];
	const pattern = /^var\s+([a-z_][a-z0-9_]*):/gm;
	for (const match of source.matchAll(pattern)) {
		const value = match[1];
		if (value !== undefined) {
			names.push(value);
		}
	}
	return names;
}

export function parseEnumNumbers(source: string, enumName: string): number[] {
	const block = source.match(new RegExp(`enum\\s+${enumName}\\s*\\{([^}]+)\\}`));
	const body = block?.[1];
	if (body === undefined) {
		return [];
	}
	const values: number[] = [];
	const pattern = /=\s*(-?\d+)/g;
	for (const match of body.matchAll(pattern)) {
		const raw = match[1];
		if (raw !== undefined) {
			values.push(Number(raw));
		}
	}
	return values;
}

export function parseIntConstant(source: string, name: string): number | undefined {
	const match = source.match(new RegExp(`const\\s+${name}:\\s*int\\s*=\\s*(-?\\d+)`));
	const raw = match?.[1];
	return raw === undefined ? undefined : Number(raw);
}

function cuePropertyNames(schema: unknown): string[] {
	const cue = property(property(schema, "$defs"), "cue");
	return schemaPropertyNames(cue);
}

function collectProductionBankIds(): string[] {
	const ids: string[] = [];
	const seen = new Set<string>();
	for (const name of readdirSync(AUDIO_BANKS_DIR).sort()) {
		if (!name.endsWith(".json")) {
			continue;
		}
		const instance = loadJsonFile(join(AUDIO_BANKS_DIR, name));
		const cues = property(instance, "cues");
		if (!Array.isArray(cues)) {
			continue;
		}
		for (const item of cues) {
			const cueId = property(item, "id");
			if (typeof cueId === "string" && !seen.has(cueId)) {
				seen.add(cueId);
				ids.push(cueId);
			}
		}
	}
	return ids;
}

function commandPlayerIntentEnum(schema: unknown): string[] {
	return commandPayloadStringEnum(schema, 1, "intent");
}

function commandEditOpEnum(schema: unknown): string[] {
	return commandPayloadStringEnum(schema, 2, "op");
}

function commandPayloadStringEnum(schema: unknown, kind: number, field: string): string[] {
	const allOf = asArray(property(schema, "allOf"));
	for (const entry of allOf) {
		const kindConst = property(property(property(property(entry, "if"), "properties"), "kind"), "const");
		if (kindConst !== kind) {
			continue;
		}
		const thenPayload = property(property(property(entry, "then"), "properties"), "payload");
		const named = property(property(thenPayload, "properties"), field);
		const values = asArray(property(named, "enum"));
		if (values.length > 0 && values.every((value) => typeof value === "string")) {
			return values as string[];
		}
	}
	return [];
}

function commandKindEnum(schema: unknown): number[] {
	const kind = property(property(schema, "properties"), "kind");
	const values = asArray(property(kind, "enum"));
	return values.filter((value): value is number => typeof value === "number");
}

function schemaRequired(schema: unknown): string[] {
	const values = asArray(property(schema, "required"));
	return values.filter((value): value is string => typeof value === "string");
}

function schemaPropertyNames(schema: unknown): string[] {
	const properties = property(schema, "properties");
	if (typeof properties !== "object" || properties === null || Array.isArray(properties)) {
		return [];
	}
	return Object.keys(properties);
}

function componentPropertyNames(schema: unknown): string[] {
	const components = property(property(schema, "properties"), "components");
	const properties = property(components, "properties");
	if (typeof properties !== "object" || properties === null || Array.isArray(properties)) {
		return [];
	}
	return Object.keys(properties);
}

function collisionShapeKindConsts(schema: unknown): string[] {
	const shape = property(property(schema, "$defs"), "collision_shape");
	const branches = asArray(property(shape, "oneOf"));
	const kinds: string[] = [];
	for (const branch of branches) {
		const kind = property(property(property(branch, "properties"), "kind"), "const");
		if (typeof kind === "string") {
			kinds.push(kind);
		}
	}
	return kinds;
}

function towerTargetPriorityEnum(schema: unknown): string[] {
	const tower = property(property(schema, "$defs"), "tower");
	const priority = property(property(tower, "properties"), "target_priority");
	const values = asArray(property(priority, "enum"));
	return values.filter((value): value is string => typeof value === "string");
}

function property(value: unknown, key: string): unknown {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		return undefined;
	}
	return (value as { readonly [name: string]: unknown })[key];
}

function asArray(value: unknown): readonly unknown[] {
	return Array.isArray(value) ? value : [];
}

function pushListMismatch(
	mismatches: SyncMismatch[],
	name: string,
	expected: readonly string[],
	actual: readonly string[],
): void {
	if (expected.join("\0") !== actual.join("\0")) {
		mismatches.push({
			name,
			expected: expected.join(","),
			actual: actual.join(","),
		});
	}
}
