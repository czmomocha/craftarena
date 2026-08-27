import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { SIMULATION_BUNDLE_SCHEMA_PATH } from "./paths.ts";

type JsonObject = { readonly [key: string]: unknown };

export function validateSimulationBundle(instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(SIMULATION_BUNDLE_SCHEMA_PATH), instance, {
		schemaPath: SIMULATION_BUNDLE_SCHEMA_PATH,
	});
	if (!isObject(instance)) {
		return errors;
	}
	pushDuplicateIds(errors, instance.pads, "$.pads");
	pushDuplicateIds(errors, instance.portals, "$.portals");
	pushDuplicateIds(errors, instance.finish, "$.finish");
	pushDuplicateIds(errors, instance.destructibles, "$.destructibles");
	pushDuplicateIds(errors, instance.hazards, "$.hazards");
	pushDuplicateIds(errors, instance.solids, "$.solids");
	pushDuplicateIds(errors, instance.pickups, "$.pickups");
	return errors;
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

function isObject(value: unknown): value is JsonObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
