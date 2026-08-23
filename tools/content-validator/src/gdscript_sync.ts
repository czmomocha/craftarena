import { readFileSync } from "node:fs";

import { COMPONENT_SCHEMA_VERSION, L0_CONTRACT_VERSION } from "../../../backend/contracts/src/schemas.ts";
import { CANONICAL_MAX_DEPTH } from "./canonical_depth.ts";
import { loadJsonFile } from "./json_schema.ts";
import {
	CANONICAL_PAYLOAD_PATH,
	COLLISION_SHAPE_KINDS_PATH,
	COMMAND_SCHEMA_PATH,
	COMPONENT_NAMES_PATH,
	COMPONENT_RECORD_PATH,
	COMPONENT_SCHEMA_PATH,
	EVENT_SCHEMA_PATH,
	PLAYER_INTENT_NAMES_PATH,
	SHARED_COMMAND_PATH,
	SHARED_DOMAIN_EVENT_PATH,
	SHARED_IDS_PATH,
	TOWER_TARGET_PRIORITIES_PATH,
} from "./paths.ts";

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

	return mismatches;
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

function commandPlayerIntentEnum(schema: unknown): string[] {
	const allOf = asArray(property(schema, "allOf"));
	for (const entry of allOf) {
		const thenPayload = property(property(property(entry, "then"), "properties"), "payload");
		const intent = property(property(thenPayload, "properties"), "intent");
		const values = asArray(property(intent, "enum"));
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
