import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { SIMULATION_BUNDLE_SCHEMA_PATH } from "./paths.ts";

type JsonObject = { readonly [key: string]: unknown };

const OCCUPANCY_BAGS = [
	"pads",
	"portals",
	"finish",
	"destructibles",
	"hazards",
	"solids",
	"pickups",
] as const;

export function validateSimulationBundle(instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(SIMULATION_BUNDLE_SCHEMA_PATH), instance, {
		schemaPath: SIMULATION_BUNDLE_SCHEMA_PATH,
	});
	if (!isObject(instance)) {
		return errors;
	}
	for (const bag of OCCUPANCY_BAGS) {
		pushDuplicateIds(errors, instance[bag], `$.${bag}`);
	}
	pushAssetErrors(errors, instance);
	return errors;
}

/**
 * ADR-0006 的资产引用闭合规则。JSON Schema 表达不了"跨袋引用必须存在"和"每条资产
 * 必须被引用"，而 `SimulationBundle.from_dictionary` 会拒；两侧不一致的话，
 * GDScript 拒了但 `npm test` 放行，反例就失去意义。
 */
function pushAssetErrors(errors: JsonSchemaError[], instance: JsonObject): void {
	const assets = instance.assets;
	if (!Array.isArray(assets)) {
		return;
	}
	const versions = new Map<number, number>();
	let previousId = 0;
	for (const [index, entry] of assets.entries()) {
		if (!isObject(entry)) {
			continue;
		}
		const assetId = integerOrUndefined(entry.asset_id);
		const gameplayVersion = integerOrUndefined(entry.gameplay_version);
		if (assetId === undefined || gameplayVersion === undefined) {
			continue;
		}
		if (assetId <= previousId) {
			errors.push({
				path: `$.assets/${index}/asset_id`,
				message: "assets must be strictly ascending by asset_id",
			});
		}
		previousId = assetId;
		versions.set(assetId, gameplayVersion);
		pushDuplicateAttachPointNames(errors, entry.attach_points, `$.assets/${index}/attach_points`);
	}
	const referenced = new Set<number>();
	for (const bag of OCCUPANCY_BAGS) {
		const list = instance[bag];
		if (!Array.isArray(list)) {
			continue;
		}
		for (const [index, item] of list.entries()) {
			if (!isObject(item)) {
				continue;
			}
			const assetId = integerOrUndefined(item.asset_id);
			const gameplayVersion = integerOrUndefined(item.gameplay_version);
			if (assetId === undefined || gameplayVersion === undefined) {
				continue;
			}
			const known = versions.get(assetId);
			if (known === undefined) {
				errors.push({
					path: `$.${bag}/${index}/asset_id`,
					message: "asset_id is not declared in assets",
				});
				continue;
			}
			if (known !== gameplayVersion) {
				errors.push({
					path: `$.${bag}/${index}/gameplay_version`,
					message: "gameplay_version does not match the declared asset",
				});
				continue;
			}
			referenced.add(assetId);
		}
	}
	for (const [index, entry] of assets.entries()) {
		if (!isObject(entry)) {
			continue;
		}
		const assetId = integerOrUndefined(entry.asset_id);
		if (assetId === undefined || referenced.has(assetId)) {
			continue;
		}
		errors.push({
			path: `$.assets/${index}/asset_id`,
			message: "asset is declared but never referenced",
		});
	}
}

/** 挂点名在一条资产内必须唯一。JSON Schema 表达不了唯一性，`entry_is_valid` 会拒。 */
function pushDuplicateAttachPointNames(errors: JsonSchemaError[], value: unknown, path: string): void {
	if (!Array.isArray(value)) {
		return;
	}
	const seen = new Set<string>();
	for (const [index, item] of value.entries()) {
		if (!isObject(item) || typeof item.name !== "string") {
			continue;
		}
		if (seen.has(item.name)) {
			errors.push({ path: `${path}/${index}/name`, message: "duplicate attach point name" });
		}
		seen.add(item.name);
	}
}

function pushDuplicateIds(errors: JsonSchemaError[], value: unknown, path: string): void {
	if (!Array.isArray(value)) {
		return;
	}
	const seen = new Set<number>();
	for (const [index, item] of value.entries()) {
		if (!isObject(item) || typeof item.entity_id !== "number" || !Number.isInteger(item.entity_id)) {
			continue;
		}
		const entityId = item.entity_id;
		if (seen.has(entityId)) {
			errors.push({ path: `${path}/${index}/entity_id`, message: "duplicate entity_id" });
		}
		seen.add(entityId);
	}
}

function integerOrUndefined(value: unknown): number | undefined {
	return typeof value === "number" && Number.isInteger(value) ? value : undefined;
}

function isObject(value: unknown): value is JsonObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
