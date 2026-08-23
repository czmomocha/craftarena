import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { AUTHORING_SCHEMA_FILES, COMPONENT_SCHEMA_FILES, L0_SCHEMA_FILES, SIMULATION_BUNDLE_SCHEMA_FILES } from "../../../backend/contracts/src/schemas.ts";
import { collectGdscriptSchemaMismatches } from "../src/gdscript_sync.ts";
import {
	loadAuthoringFixtures,
	loadComponentFixtures,
	loadEnvelopeFixtures,
	loadOfficialAuthoringDocuments,
	loadSimulationBundleFixtures,
} from "../src/load_fixtures.ts";
import {
	AUTHORING_DOCUMENT_SCHEMA_PATH,
	CANONICAL_SCHEMA_PATH,
	COMPONENT_SCHEMA_PATH,
	CONTRACTS_SCHEMA_DIR,
	SIMULATION_BUNDLE_SCHEMA_PATH,
} from "../src/paths.ts";
import { validateAuthoringDocument } from "../src/validate_authoring_document.ts";
import { validateComponentRecord } from "../src/validate_component.ts";
import { validateSharedCommand, validateSharedDomainEvent } from "../src/validate_envelope.ts";
import { validateSimulationBundle } from "../src/validate_simulation_bundle.ts";

describe("L0 schema catalog", () => {
	it("keeps every registered schema file on disk", () => {
		for (const file of L0_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(CANONICAL_SCHEMA_PATH), true);
	});
});

describe("Component Schema catalog", () => {
	it("keeps every registered component schema file on disk", () => {
		for (const file of COMPONENT_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(COMPONENT_SCHEMA_PATH), true);
	});
});

describe("AuthoringDocument catalog", () => {
	it("keeps every registered authoring schema file on disk", () => {
		for (const file of AUTHORING_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(AUTHORING_DOCUMENT_SCHEMA_PATH), true);
	});
});

describe("SimulationBundle catalog", () => {
	it("keeps every registered simulation bundle schema file on disk", () => {
		for (const file of SIMULATION_BUNDLE_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(SIMULATION_BUNDLE_SCHEMA_PATH), true);
	});
});

describe("GDScript and JSON Schema stay aligned", () => {
	it("matches intent names, kind numbers, fields, depth, versions, component catalogs, authoring document fields, and simulation bundle fields", () => {
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

describe("component fixtures", () => {
	const fixtures = loadComponentFixtures();

	it("has both valid and invalid component examples", () => {
		assert.ok(fixtures.some((fixture) => fixture.valid));
		assert.ok(fixtures.some((fixture) => !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`component/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors = validateComponentRecord(fixture.instance);
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected schema errors");
			}
		});
	}
});

describe("authoring document fixtures", () => {
	const fixtures = loadAuthoringFixtures();

	it("has both valid and invalid authoring examples", () => {
		assert.ok(fixtures.some((fixture) => fixture.valid));
		assert.ok(fixtures.some((fixture) => !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`authoring/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors = validateAuthoringDocument(fixture.instance);
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected schema errors");
			}
		});
	}
});

describe("official authoring documents", () => {
	const documents = loadOfficialAuthoringDocuments();

	it("keeps both TRAPRUSH courses", () => {
		assert.ok(documents.some((document) => document.name === "course_01.json"));
		assert.ok(documents.some((document) => document.name === "course_02.json"));
	});

	for (const document of documents) {
		it(`official/${document.name} is schema-valid`, () => {
			assert.deepEqual(validateAuthoringDocument(document.instance), []);
		});
	}
});

describe("simulation bundle fixtures", () => {
	const fixtures = loadSimulationBundleFixtures();

	it("has both valid and invalid simulation bundle examples", () => {
		assert.ok(fixtures.some((fixture) => fixture.valid));
		assert.ok(fixtures.some((fixture) => !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`simulation_bundle/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors = validateSimulationBundle(fixture.instance);
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected schema errors");
			}
		});
	}
});
