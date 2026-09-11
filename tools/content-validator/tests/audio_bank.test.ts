import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import { AUDIO_BANK_SCHEMA_FILES } from "../../../backend/contracts/src/schemas.ts";
import { collectGdscriptSchemaMismatches, parseStringConstants } from "../src/gdscript_sync.ts";
import { loadAudioBankFixtures } from "../src/load_fixtures.ts";
import { AUDIO_BANK_SCHEMA_PATH, AUDIO_CUE_CATALOG_PATH, CONTRACTS_SCHEMA_DIR } from "../src/paths.ts";
import {
	SFX_MAX_BYTES,
	bytesOk,
	validateAudioBank,
	validateProductionAudioBanks,
} from "../src/validate_audio_bank.ts";

const catalogIds = parseStringConstants(readFileSync(AUDIO_CUE_CATALOG_PATH, "utf8"));

describe("audio cue bank schema", () => {
	it("keeps the registered schema file on disk", () => {
		for (const file of AUDIO_BANK_SCHEMA_FILES) {
			assert.equal(existsSync(join(CONTRACTS_SCHEMA_DIR, file)), true, file);
		}
		assert.equal(existsSync(AUDIO_BANK_SCHEMA_PATH), true);
	});
});

describe("audio cue catalog stays aligned with production banks", () => {
	it("matches catalog ids, cue fields, and schema version", () => {
		assert.deepEqual(collectGdscriptSchemaMismatches(), []);
	});

	it("accepts the production banks as a complete catalog set", () => {
		assert.deepEqual(validateProductionAudioBanks(catalogIds), []);
	});
});

describe("audio bank fixtures", () => {
	const fixtures = loadAudioBankFixtures();

	it("has both valid and invalid examples", () => {
		assert.ok(fixtures.some((fixture) => fixture.valid));
		assert.ok(fixtures.some((fixture) => !fixture.valid));
	});

	for (const fixture of fixtures) {
		it(`audio_bank/${fixture.valid ? "valid" : "invalid"}/${fixture.name}`, () => {
			const errors = validateAudioBank(fixture.instance, {
				catalogIds,
				requireCatalogCoverage: false,
			});
			if (fixture.valid) {
				assert.deepEqual(errors, []);
			} else {
				assert.ok(errors.length > 0, "expected bank errors");
			}
		});
	}
});

describe("audio bank budget", () => {
	it("rejects a stream over the sfx byte cap", () => {
		const dir = mkdtempSync(join(tmpdir(), "audio-bank-"));
		const over = join(dir, "over.bin");
		writeFileSync(over, Buffer.alloc(SFX_MAX_BYTES + 1));
		assert.equal(bytesOk(SFX_MAX_BYTES, "sfx"), true);
		assert.equal(bytesOk(SFX_MAX_BYTES + 1, "sfx"), false);
		const errors = validateAudioBank(
			{
				schema_version: 1,
				cues: [
					{
						id: "step",
						streams: ["res://content/audio/f_line_temp/over.bin"],
						bus: "sfx",
					},
				],
			},
			{
				catalogIds,
				requireCatalogCoverage: false,
				resolveStream: () => over,
			},
		);
		assert.ok(errors.some((error) => error.message.includes("byte cap")));
	});
});
