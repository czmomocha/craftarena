import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { AUTHORING_DOCUMENT_SCHEMA_PATH } from "./paths.ts";
import { validateComponentRecord } from "./validate_component.ts";

type JsonObject = { readonly [key: string]: unknown };

export function validateAuthoringDocument(instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(AUTHORING_DOCUMENT_SCHEMA_PATH), instance, {
		schemaPath: AUTHORING_DOCUMENT_SCHEMA_PATH,
	});
	if (!isObject(instance) || !Array.isArray(instance.entities)) {
		return errors;
	}
	if (typeof instance.cell !== "number" || !Number.isInteger(instance.cell) || instance.cell < 1) {
		return errors;
	}

	const cell = instance.cell;
	const seenIds = new Set<number>();
	const records = new Map<number, JsonObject>();

	for (const [index, entity] of instance.entities.entries()) {
		const prefix = `$.entities/${index}`;
		for (const error of validateComponentRecord(entity)) {
			errors.push({
				path: rebasePath(error.path, prefix),
				message: error.message,
			});
		}
		if (!isObject(entity) || typeof entity.entity_id !== "number" || !Number.isInteger(entity.entity_id)) {
			continue;
		}
		const entityId = entity.entity_id;
		if (seenIds.has(entityId)) {
			errors.push({ path: `${prefix}/entity_id`, message: "duplicate entity_id" });
		}
		seenIds.add(entityId);
		records.set(entityId, entity);
		if (!transformOnCell(entity, cell)) {
			errors.push({ path: `${prefix}/components/transform`, message: "transform is off the authoring lattice" });
		}
	}

	for (const [entityId, entity] of records) {
		const portal = portalBody(entity);
		if (portal === undefined) {
			continue;
		}
		if (portal.targetId === entityId) {
			errors.push({ path: `$.entities`, message: "portal must not self-loop" });
			continue;
		}
		const dest = records.get(portal.targetId);
		if (dest === undefined) {
			continue;
		}
		if (portalBody(dest) === undefined) {
			errors.push({ path: `$.entities`, message: "portal destination exists without portal" });
		}
	}

	return errors;
}

function transformOnCell(entity: JsonObject, cell: number): boolean {
	if (!hasComponents(entity)) {
		return true;
	}
	const components = entity.components;
	if (!isObject(components) || !Object.hasOwn(components, "transform")) {
		return true;
	}
	const transform = components.transform;
	if (!isObject(transform)) {
		return false;
	}
	return onCell(transform.x, cell) && onCell(transform.y, cell) && onCell(transform.z, cell);
}

function onCell(value: unknown, cell: number): boolean {
	return typeof value === "number" && Number.isInteger(value) && value % cell === 0;
}

function portalBody(entity: JsonObject): { readonly targetId: number } | undefined {
	if (!hasComponents(entity) || !isObject(entity.components) || !Object.hasOwn(entity.components, "portal")) {
		return undefined;
	}
	const portal = entity.components.portal;
	if (!isObject(portal) || typeof portal.target_id !== "number" || !Number.isInteger(portal.target_id)) {
		return undefined;
	}
	return { targetId: portal.target_id };
}

function hasComponents(value: JsonObject): value is JsonObject & { readonly components: unknown } {
	return Object.hasOwn(value, "components");
}

function rebasePath(path: string, prefix: string): string {
	if (path === "$") {
		return prefix;
	}
	if (path.startsWith("$")) {
		return `${prefix}${path.slice(1)}`;
	}
	return `${prefix}/${path}`;
}

function isObject(value: unknown): value is JsonObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
