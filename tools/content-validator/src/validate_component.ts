import { payloadExceedsCanonicalDepth } from "./canonical_depth.ts";
import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { COMPONENT_SCHEMA_PATH } from "./paths.ts";

export function validateComponentRecord(instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(COMPONENT_SCHEMA_PATH), instance, {
		schemaPath: COMPONENT_SCHEMA_PATH,
	});
	if (hasComponents(instance) && payloadExceedsCanonicalDepth(instance.components)) {
		errors.push({ path: "$.components", message: "canonical payload exceeds MAX_DEPTH" });
	}
	return errors;
}

function hasComponents(value: unknown): value is { readonly components: unknown } {
	return (
		typeof value === "object" &&
		value !== null &&
		!Array.isArray(value) &&
		Object.hasOwn(value, "components")
	);
}
