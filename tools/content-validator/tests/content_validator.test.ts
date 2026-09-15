import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { AUTHORING_SCHEMA_FILES, AUDIO_BANK_SCHEMA_FILES, BASTION_BLUEPRINT_SCHEMA_FILES, COMPONENT_SCHEMA_FILES, L0_SCHEMA_FILES, SIMULATION_BUNDLE_SCHEMA_FILES } from "../../../backend/contracts/src/schemas.ts";
import { collectGdscriptSchemaMismatches } from "../src/gdscript_sync.ts";
import {
	loadAuthoringFixtures,
	loadBastionBlueprintFixtures,
	loadComponentFixtures,
	loadEnvelopeFixtures,
	loadOfficialAuthoringDocuments,
	loadSimulationBundleFixtures,
	loadTestFixtureAuthoringDocuments,
} from "../src/load_fixtures.ts";
import {
	AUDIO_BANK_SCHEMA_PATH,
	AUTHORING_DOCUMENT_SCHEMA_PATH,
	BASTION_BLUEPRINT_SCHEMA_PATH,
	CANONICAL_SCHEMA_PATH,
	COMPONENT_SCHEMA_PATH,
	CONTRACTS_SCHEMA_DIR,
	SIMULATION_BUNDLE_SCHEMA_PATH,
} from "../src/paths.ts";
import { validateAuthoringDocument } from "../src/validate_authoring_document.ts";
import { validateBastionBlueprintBundle } from "../src/validate_bastion_blueprint_bundle.ts";
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

describe("BastionBlueprintBundle catalog", () => {
	it("keeps the blueprint schema in its own file instead of folding it into the bundle catalog", () => {
		for (const file of BASTION_BLUEPRINT_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(BASTION_BLUEPRINT_SCHEMA_PATH), true);
		// 两张目录不得合并：合并等于承认两个玩法共用一条 wire，而 TRAPRUSH 那条
		// 上挂着已发布内容的 ContentHash（CD-91 D.4）。
		for (const file of BASTION_BLUEPRINT_SCHEMA_FILES) {
			assert.ok(!SIMULATION_BUNDLE_SCHEMA_FILES.includes(file as never), file);
		}
	});
});

describe("Audio cue bank catalog", () => {
	it("keeps every registered audio bank schema file on disk", () => {
		for (const file of AUDIO_BANK_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(AUDIO_BANK_SCHEMA_PATH), true);
	});
});

describe("GDScript and JSON Schema stay aligned", () => {
	it("matches intent names, kind numbers, fields, depth, versions, component catalogs, authoring document fields, simulation bundle fields, and audio cue banks", () => {
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

	it("keeps the official TRAPRUSH match courses", () => {
		assert.ok(documents.some((document) => document.name === "course_01.json"));
		assert.ok(documents.some((document) => document.name === "course_02.json"));
		assert.ok(documents.some((document) => document.name === "course_03.json"));
		assert.ok(documents.some((document) => document.name === "course_04.json"));
		assert.ok(documents.some((document) => document.name === "course_05.json"));
	});

	it("keeps the official BASTION blueprint", () => {
		assert.ok(documents.some((document) => document.name === "blueprint_01.json"));
	});

	for (const document of documents) {
		it(`official/${document.name} is schema-valid`, () => {
			assert.deepEqual(validateAuthoringDocument(document.instance), []);
		});
	}
});

describe("graybox blueprint fixtures", () => {
	const documents = loadTestFixtureAuthoringDocuments();

	it("keeps the BASTION graybox blueprint on disk and schema-valid", () => {
		assert.ok(documents.some((document) => document.name === "graybox.json"));
	});

	for (const document of documents) {
		it(`test_fixtures/${document.name} is a valid AuthoringDocument`, () => {
			// 蓝图输入仍然是一份普通 AuthoringDocument：Component Schema v1 一个
			// 字节没改，这条断言就是那句话的证据。
			assert.deepEqual(validateAuthoringDocument(document.instance), []);
		});
	}
});

describe("bastion blueprint bundle fixtures", () => {
	const fixtures = loadBastionBlueprintFixtures();

	it("has both valid and invalid bastion blueprint examples", () => {
		assert.ok(fixtures.some((fixture) => fixture.valid));
		assert.ok(fixtures.some((fixture) => !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`bastion_blueprint_bundle/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors = validateBastionBlueprintBundle(fixture.instance);
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected schema errors");
			}
		});
	}

	it("rejects a TRAPRUSH bundle outright", () => {
		const traprush = loadSimulationBundleFixtures().find(
			(fixture) => fixture.valid && fixture.name === "one_solid.json",
		);
		assert.ok(traprush !== undefined);
		assert.ok(validateBastionBlueprintBundle(traprush.instance).length > 0);
	});

	it("keeps TRAPRUSH validation blind to BASTION blueprints", () => {
		const bastion = fixtures.find((fixture) => fixture.valid);
		assert.ok(bastion !== undefined);
		assert.ok(validateSimulationBundle(bastion.instance).length > 0);
	});
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
