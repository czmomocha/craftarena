import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";

export type JsonSchemaError = {
	readonly path: string;
	readonly message: string;
};

type SchemaObject = { readonly [key: string]: unknown };

type Ctx = {
	readonly document: unknown;
	readonly baseDir: string;
	readonly cache: Map<string, unknown>;
};

export function loadJsonFile(path: string): unknown {
	return JSON.parse(readFileSync(path, "utf8")) as unknown;
}

export function validateJsonSchema(
	schema: unknown,
	instance: unknown,
	options: { readonly schemaPath: string },
): JsonSchemaError[] {
	const cache = new Map<string, unknown>();
	cache.set(options.schemaPath, schema);
	return apply(schema, instance, "$", {
		document: schema,
		baseDir: dirname(options.schemaPath),
		cache,
	});
}

function apply(schema: unknown, instance: unknown, path: string, ctx: Ctx): JsonSchemaError[] {
	if (schema === true) {
		return [];
	}
	if (schema === false) {
		return [{ path, message: "schema is false" }];
	}
	if (!isObject(schema)) {
		return [{ path, message: "schema must be a boolean or object" }];
	}

	const errors: JsonSchemaError[] = [];
	const ref = schema.$ref;
	if (typeof ref === "string") {
		const resolved = resolveRef(ref, ctx);
		if (resolved.error !== undefined) {
			errors.push({ path, message: resolved.error });
		} else {
			errors.push(...apply(resolved.schema, instance, path, resolved.ctx));
		}
	}

	const typeValue = schema.type;
	if (typeof typeValue === "string") {
		errors.push(...checkType(typeValue, instance, path));
	} else if (Array.isArray(typeValue)) {
		const matched = typeValue.some(
			(entry) => typeof entry === "string" && checkType(entry, instance, path).length === 0,
		);
		if (!matched) {
			errors.push({ path, message: `type must be one of ${typeValue.join(", ")}` });
		}
	}

	if (Object.hasOwn(schema, "const") && !sameValue(instance, schema.const)) {
		errors.push({ path, message: "does not match const" });
	}

	if (Array.isArray(schema.enum) && !schema.enum.some((entry) => sameValue(instance, entry))) {
		errors.push({ path, message: "does not match enum" });
	}

	if (typeof schema.minLength === "number" && typeof instance === "string" && instance.length < schema.minLength) {
		errors.push({ path, message: `shorter than minLength ${schema.minLength}` });
	}

	if (typeof instance === "number" && Number.isInteger(instance)) {
		if (typeof schema.minimum === "number" && instance < schema.minimum) {
			errors.push({ path, message: `below minimum ${schema.minimum}` });
		}
		if (typeof schema.exclusiveMinimum === "number" && instance <= schema.exclusiveMinimum) {
			errors.push({ path, message: `not above exclusiveMinimum ${schema.exclusiveMinimum}` });
		}
	}

	if (schema.type === "object" || isObject(instance)) {
		errors.push(...applyObject(schema, instance, path, ctx));
	}

	if (schema.type === "array" || Array.isArray(instance)) {
		errors.push(...applyArray(schema, instance, path, ctx));
	}

	if (Array.isArray(schema.allOf)) {
		for (const entry of schema.allOf) {
			errors.push(...apply(entry, instance, path, ctx));
		}
	}

	if (Array.isArray(schema.oneOf)) {
		const matches = schema.oneOf.filter((entry) => apply(entry, instance, path, ctx).length === 0);
		if (matches.length !== 1) {
			errors.push({ path, message: `oneOf matched ${matches.length} branches` });
		}
	}

	if (Object.hasOwn(schema, "if")) {
		const ifOk = apply(schema.if, instance, path, ctx).length === 0;
		if (ifOk && Object.hasOwn(schema, "then")) {
			errors.push(...apply(schema.then, instance, path, ctx));
		}
		if (!ifOk && Object.hasOwn(schema, "else")) {
			errors.push(...apply(schema.else, instance, path, ctx));
		}
	}

	return errors;
}

function applyObject(schema: SchemaObject, instance: unknown, path: string, ctx: Ctx): JsonSchemaError[] {
	if (!isObject(instance)) {
		return schema.type === "object" ? [{ path, message: "expected object" }] : [];
	}

	const errors: JsonSchemaError[] = [];
	if (Array.isArray(schema.required)) {
		for (const key of schema.required) {
			if (typeof key === "string" && !Object.hasOwn(instance, key)) {
				errors.push({ path: joinPath(path, key), message: "required property is missing" });
			}
		}
	}

	const properties = isObject(schema.properties) ? schema.properties : undefined;
	if (properties !== undefined) {
		for (const [key, childSchema] of Object.entries(properties)) {
			if (Object.hasOwn(instance, key)) {
				errors.push(...apply(childSchema, instance[key], joinPath(path, key), ctx));
			}
		}
	}

	if (Object.hasOwn(schema, "additionalProperties")) {
		const extraKeys = Object.keys(instance).filter((key) => properties === undefined || !Object.hasOwn(properties, key));
		if (schema.additionalProperties === false) {
			for (const key of extraKeys) {
				errors.push({ path: joinPath(path, key), message: "additional property is not allowed" });
			}
		} else if (schema.additionalProperties !== true) {
			for (const key of extraKeys) {
				errors.push(...apply(schema.additionalProperties, instance[key], joinPath(path, key), ctx));
			}
		}
	}

	return errors;
}

function applyArray(schema: SchemaObject, instance: unknown, path: string, ctx: Ctx): JsonSchemaError[] {
	if (!Array.isArray(instance)) {
		return schema.type === "array" ? [{ path, message: "expected array" }] : [];
	}
	const errors: JsonSchemaError[] = [];
	if (typeof schema.maxItems === "number" && instance.length > schema.maxItems) {
		errors.push({ path, message: `longer than maxItems ${schema.maxItems}` });
	}
	if (!Object.hasOwn(schema, "items")) {
		return errors;
	}
	for (const [index, item] of instance.entries()) {
		errors.push(...apply(schema.items, item, `${path}/${index}`, ctx));
	}
	return errors;
}

function checkType(typeName: string, instance: unknown, path: string): JsonSchemaError[] {
	switch (typeName) {
		case "null":
			return instance === null ? [] : [{ path, message: "expected null" }];
		case "boolean":
			return typeof instance === "boolean" ? [] : [{ path, message: "expected boolean" }];
		case "string":
			return typeof instance === "string" ? [] : [{ path, message: "expected string" }];
		case "integer":
			if (typeof instance !== "number" || !Number.isInteger(instance) || !Number.isSafeInteger(instance)) {
				return [{ path, message: "expected safe integer" }];
			}
			return [];
		case "number":
			return typeof instance === "number" && Number.isFinite(instance) ? [] : [{ path, message: "expected number" }];
		case "object":
			return isObject(instance) ? [] : [{ path, message: "expected object" }];
		case "array":
			return Array.isArray(instance) ? [] : [{ path, message: "expected array" }];
		default:
			return [{ path, message: `unsupported type keyword ${typeName}` }];
	}
}

function resolveRef(
	ref: string,
	ctx: Ctx,
): { readonly schema: unknown; readonly ctx: Ctx; readonly error?: undefined } | { readonly error: string } {
	const hashIndex = ref.indexOf("#");
	const filePart = hashIndex === -1 ? ref : ref.slice(0, hashIndex);
	const pointer = hashIndex === -1 ? "" : ref.slice(hashIndex + 1);

	let document = ctx.document;
	let nextCtx = ctx;
	if (filePart !== "") {
		const filePath = join(ctx.baseDir, filePart);
		const cached = ctx.cache.get(filePath);
		if (cached !== undefined) {
			document = cached;
		} else {
			document = loadJsonFile(filePath);
			ctx.cache.set(filePath, document);
		}
		nextCtx = {
			document,
			baseDir: dirname(filePath),
			cache: ctx.cache,
		};
	}

	const target = pointer === "" || pointer === "/" ? document : lookupPointer(document, pointer);
	if (target === undefined) {
		return { error: `unresolved $ref ${ref}` };
	}
	return { schema: target, ctx: nextCtx };
}

function lookupPointer(document: unknown, pointer: string): unknown {
	if (!pointer.startsWith("/")) {
		return undefined;
	}
	let current: unknown = document;
	for (const raw of pointer.slice(1).split("/")) {
		const key = raw.replaceAll("~1", "/").replaceAll("~0", "~");
		if (!isObject(current) || !Object.hasOwn(current, key)) {
			return undefined;
		}
		current = current[key];
	}
	return current;
}

function isObject(value: unknown): value is SchemaObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function sameValue(left: unknown, right: unknown): boolean {
	return JSON.stringify(left) === JSON.stringify(right);
}

function joinPath(path: string, key: string): string {
	return `${path}/${key.replaceAll("~", "~0").replaceAll("/", "~1")}`;
}
