import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import { AUDIO_BANK_SCHEMA_FILES } from "../../../backend/contracts/src/schemas.ts";
import { collectGdscriptSchemaMismatches, parseStringConstants } from "../src/gdscript_sync.ts";
import { loadAudioBankFixtures } from "../src/load_fixtures.ts";
import { AUDIO_BANK_SCHEMA_PATH, AUDIO_CUE_CATALOG_PATH, CONTRACTS_SCHEMA_DIR } from "../src/paths.ts";
import {
	EMPTY_AUDIO_MESSAGE,
	SFX_MAX_BYTES,
	bytesOk,
	checkAudioFile,
	validateAudioBank,
	validateProductionAudioAssets,
	validateProductionAudioBanks,
} from "../src/validate_audio_bank.ts";

const catalogIds = parseStringConstants(readFileSync(AUDIO_CUE_CATALOG_PATH, "utf8"));

function makeVorbisOgg(options: {
	readonly channels: number;
	readonly sampleRate: number;
	readonly granule: bigint;
}): Buffer {
	const ident = Buffer.alloc(16);
	ident[0] = 1;
	ident.write("vorbis", 1);
	ident.writeUInt32LE(0, 7);
	ident[11] = options.channels;
	ident.writeUInt32LE(options.sampleRate, 12);
	const header = Buffer.alloc(28);
	header.write("OggS", 0);
	header[5] = 2;
	header.writeBigInt64LE(options.granule, 6);
	header[26] = 1;
	header[27] = ident.length;
	return Buffer.concat([header, ident]);
}

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
		const over = join(dir, "over.ogg");
		writeFileSync(over, Buffer.alloc(SFX_MAX_BYTES + 1));
		assert.equal(bytesOk(SFX_MAX_BYTES, "sfx"), true);
		assert.equal(bytesOk(SFX_MAX_BYTES + 1, "sfx"), false);
		const errors = validateAudioBank(
			{
				schema_version: 1,
				cues: [
					{
						id: "step",
						streams: ["res://content/audio/sfx/over.ogg"],
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

	it("says nothing was checked when sfx and music have zero ogg files", () => {
		const dir = mkdtempSync(join(tmpdir(), "audio-empty-"));
		const sfxDir = join(dir, "sfx");
		const musicDir = join(dir, "music");
		mkdirSync(sfxDir);
		mkdirSync(musicDir);
		const errors = validateProductionAudioAssets(sfxDir, musicDir, dir);
		assert.equal(errors.length, 1);
		assert.equal(errors[0]?.message, EMPTY_AUDIO_MESSAGE);
	});

	it("rejects leftover wav even when an ogg is present", () => {
		const dir = mkdtempSync(join(tmpdir(), "audio-wav-"));
		const sfxDir = join(dir, "sfx");
		const musicDir = join(dir, "music");
		mkdirSync(sfxDir);
		mkdirSync(musicDir);
		writeFileSync(
			join(sfxDir, "ok.ogg"),
			makeVorbisOgg({ channels: 1, sampleRate: 44100, granule: 44100n }),
		);
		writeFileSync(join(dir, "leftover.wav"), Buffer.from("RIFF"));
		const errors = validateProductionAudioAssets(sfxDir, musicDir, dir);
		assert.ok(errors.some((error) => error.message.includes("not WAV")));
	});

	it("rejects sfx longer than 2 s", () => {
		const dir = mkdtempSync(join(tmpdir(), "audio-long-"));
		const path = join(dir, "long.ogg");
		writeFileSync(
			path,
			makeVorbisOgg({ channels: 1, sampleRate: 44100, granule: 132300n }),
		);
		const errors = checkAudioFile(path, "sfx", path);
		assert.ok(errors.some((error) => error.message.includes("duration")));
	});

	it("rejects the wrong sample rate or channel count", () => {
		const dir = mkdtempSync(join(tmpdir(), "audio-rate-"));
		const ratePath = join(dir, "rate.ogg");
		writeFileSync(
			ratePath,
			makeVorbisOgg({ channels: 1, sampleRate: 22050, granule: 22050n }),
		);
		assert.ok(
			checkAudioFile(ratePath, "sfx", ratePath).some((error) =>
				error.message.includes("44100"),
			),
		);
		const stereoPath = join(dir, "stereo.ogg");
		writeFileSync(
			stereoPath,
			makeVorbisOgg({ channels: 2, sampleRate: 44100, granule: 44100n }),
		);
		assert.ok(
			checkAudioFile(stereoPath, "sfx", stereoPath).some((error) =>
				error.message.includes("mono"),
			),
		);
	});
});
