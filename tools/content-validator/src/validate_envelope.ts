import { payloadExceedsCanonicalDepth } from "./canonical_depth.ts";
import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { COMMAND_SCHEMA_PATH, EVENT_SCHEMA_PATH } from "./paths.ts";

export function validateSharedCommand(instance: unknown): JsonSchemaError[] {
	return validateWithPayloadDepth(COMMAND_SCHEMA_PATH, instance);
}

export function validateSharedDomainEvent(instance: unknown): JsonSchemaError[] {
	return validateWithPayloadDepth(EVENT_SCHEMA_PATH, instance);
}

function validateWithPayloadDepth(schemaPath: string, instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(schemaPath), instance, { schemaPath });
	if (hasPayload(instance) && payloadExceedsCanonicalDepth(instance.payload)) {
		errors.push({ path: "$.payload", message: "canonical payload exceeds MAX_DEPTH" });
	}
	return errors;
}

function hasPayload(value: unknown): value is { readonly payload: unknown } {
	return typeof value === "object" && value !== null && !Array.isArray(value) && Object.hasOwn(value, "payload");
}
