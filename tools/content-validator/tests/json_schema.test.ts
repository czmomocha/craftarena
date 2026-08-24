import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { validateJsonSchema } from "../src/json_schema.ts";

describe("json schema subset", () => {
	it("accepts a matching object and rejects extra keys", () => {
		const schema = {
			type: "object",
			additionalProperties: false,
			required: ["id"],
			properties: { id: { type: "integer", minimum: 1 } },
		};

		assert.deepEqual(validateJsonSchema(schema, { id: 2 }, { schemaPath: "/tmp/x.json" }), []);
		assert.ok(validateJsonSchema(schema, { id: 0 }, { schemaPath: "/tmp/x.json" }).length > 0);
		assert.ok(validateJsonSchema(schema, { id: 2, extra: true }, { schemaPath: "/tmp/x.json" }).length > 0);
	});

	it("rejects JSON floats when the schema asks for integer", () => {
		const errors = validateJsonSchema({ type: "integer" }, 1.5, { schemaPath: "/tmp/x.json" });
		assert.ok(errors.some((error) => error.message.includes("integer")));
	});

	it("applies if/then/else", () => {
		const schema = {
			type: "object",
			required: ["kind", "actor_id"],
			properties: {
				kind: { type: "integer" },
				actor_id: { type: "integer" },
			},
			if: {
				properties: { kind: { const: 4 } },
				required: ["kind"],
			},
			then: {
				properties: { actor_id: { type: "integer", minimum: 0 } },
			},
			else: {
				properties: { actor_id: { type: "integer", minimum: 1 } },
			},
		};

		assert.deepEqual(
			validateJsonSchema(schema, { kind: 4, actor_id: 0 }, { schemaPath: "/tmp/x.json" }),
			[],
		);
		assert.ok(
			validateJsonSchema(schema, { kind: 1, actor_id: 0 }, { schemaPath: "/tmp/x.json" }).length > 0,
		);
	});

	it("requires exactly one oneOf branch", () => {
		const schema = {
			oneOf: [{ type: "string" }, { type: "integer" }],
		};
		assert.deepEqual(validateJsonSchema(schema, "ok", { schemaPath: "/tmp/x.json" }), []);
		assert.ok(validateJsonSchema(schema, true, { schemaPath: "/tmp/x.json" }).length > 0);
	});

	it("rejects arrays longer than maxItems", () => {
		const schema = { type: "array", maxItems: 1, items: { type: "integer" } };
		assert.deepEqual(validateJsonSchema(schema, [1], { schemaPath: "/tmp/x.json" }), []);
		assert.ok(
			validateJsonSchema(schema, [1, 2], { schemaPath: "/tmp/x.json" }).some((error) =>
				error.message.includes("maxItems"),
			),
		);
	});
});
