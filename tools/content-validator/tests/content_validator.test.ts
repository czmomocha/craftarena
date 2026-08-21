import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { L0_SCHEMA_FILES } from "../../../backend/contracts/src/schemas.ts";
import { collectGdscriptSchemaMismatches } from "../src/gdscript_sync.ts";
import { loadEnvelopeFixtures } from "../src/load_fixtures.ts";
import { CANONICAL_SCHEMA_PATH, CONTRACTS_SCHEMA_DIR } from "../src/paths.ts";
import { validateSharedCommand, validateSharedDomainEvent } from "../src/validate_envelope.ts";

describe("L0 schema catalog", () => {
	it("keeps every registered schema file on disk", () => {
		for (const file of L0_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(CANONICAL_SCHEMA_PATH), true);
	});
});

describe("GDScript and JSON Schema stay aligned", () => {
	it("matches intent names, kind numbers, fields, depth, and contract version", () => {
		assert.deepEqual(collectGdscriptSchemaMismatches(), []);
	});
});

describe("envelope fixtures", () => {
	const fixtures = loadEnvelopeFixtures();

	it("has both valid and invalid examples for each envelope", () => {
		assert.ok(fixtures.some((fixture) => fixture.kind === "command" && fixture.valid));
		assert.ok(fixtures.some((fixture) => fixture.kind === "command" && !fixture.valid));
		assert.ok(fixtures.some((fixture) => fixture.kind === "event" && fixture.valid));
		assert.ok(fixtures.some((fixture) => fixture.kind === "event" && !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`${fixture.kind}/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors =
				fixture.kind === "command"
					? validateSharedCommand(fixture.instance)
					: validateSharedDomainEvent(fixture.instance);
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected schema errors");
			}
		});
	}
});
