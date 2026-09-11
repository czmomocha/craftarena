import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { AUDIO_BANK_SCHEMA_VERSION } from "../../../backend/contracts/src/schemas.ts";
import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { isOggInfo, parseOggVorbis } from "./parse_ogg.ts";
import {
	AUDIO_BANK_SCHEMA_PATH,
	AUDIO_BANKS_DIR,
	AUDIO_MUSIC_DIR,
	AUDIO_RUNTIME_DIR,
	AUDIO_SFX_DIR,
	REPO_ROOT,
} from "./paths.ts";

export const STREAM_PREFIX = "res://content/audio/";
export const STREAM_SUFFIX = ".ogg";
/** Executable copy of CD-11 §8.3. Change the numbers there first. */
export const SFX_MAX_BYTES = 256 * 1024;
export const MUSIC_MAX_BYTES = 3 * 1024 * 1024;
export const TOTAL_MAX_BYTES = 20 * 1024 * 1024;
export const SFX_MAX_SECONDS = 2;
export const SAMPLE_RATE = 44100;
export const SFX_CHANNELS = 1;
export const MUSIC_CHANNELS = 2;
export const EMPTY_AUDIO_MESSAGE =
	"audio-budget: no .ogg under game/content/audio/sfx/ or music/ — nothing was checked.";

export type AudioBankValidateOptions = {
	readonly catalogIds: readonly string[];
	readonly requireCatalogCoverage: boolean;
	readonly resolveStream?: (stream: string) => string | undefined;
};

type JsonObject = { readonly [key: string]: unknown };

export function validateAudioBank(
	instance: unknown,
	options: AudioBankValidateOptions,
): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(AUDIO_BANK_SCHEMA_PATH), instance, {
		schemaPath: AUDIO_BANK_SCHEMA_PATH,
	});
	if (!isObject(instance)) {
		return errors;
	}
	if (instance.schema_version !== AUDIO_BANK_SCHEMA_VERSION) {
		errors.push({ path: "$.schema_version", message: "schema_version must match AudioBank.SCHEMA_VERSION" });
	}
	if (!Array.isArray(instance.cues)) {
		return errors;
	}
	const catalog = new Set(options.catalogIds);
	const seen = new Set<string>();
	for (const [index, item] of instance.cues.entries()) {
		const prefix = `$.cues/${index}`;
		if (!isObject(item) || typeof item.id !== "string") {
			continue;
		}
		const cueId = item.id;
		if (seen.has(cueId)) {
			errors.push({ path: `${prefix}/id`, message: "duplicate cue id" });
		}
		seen.add(cueId);
		if (!catalog.has(cueId)) {
			errors.push({ path: `${prefix}/id`, message: "cue id is not in the platform catalog" });
		}
		if (!Array.isArray(item.streams)) {
			continue;
		}
		const bus = typeof item.bus === "string" ? item.bus : "";
		for (const [streamIndex, stream] of item.streams.entries()) {
			if (typeof stream !== "string") {
				continue;
			}
			errors.push(...checkStream(stream, bus, `${prefix}/streams/${streamIndex}`, options));
		}
	}
	if (options.requireCatalogCoverage) {
		for (const cueId of options.catalogIds) {
			if (!seen.has(cueId)) {
				errors.push({ path: "$.cues", message: `catalog id ${cueId} is missing from this bank set` });
			}
		}
	}
	return errors;
}

export function validateProductionAudioBanks(catalogIds: readonly string[]): JsonSchemaError[] {
	if (!existsSync(AUDIO_BANKS_DIR)) {
		return [{ path: "$", message: `missing banks directory ${AUDIO_BANKS_DIR}` }];
	}
	const files = readdirSync(AUDIO_BANKS_DIR)
		.filter((name) => name.endsWith(".json"))
		.sort();
	if (files.length === 0) {
		return [{ path: "$", message: "no bank JSON files" }];
	}
	const errors: JsonSchemaError[] = [];
	const mergedCues: unknown[] = [];
	const seenIds = new Set<string>();
	const seenStreams = new Set<string>();
	let totalBytes = 0;
	for (const name of files) {
		const path = join(AUDIO_BANKS_DIR, name);
		const instance = loadJsonFile(path);
		const fileErrors = validateAudioBank(instance, {
			catalogIds,
			requireCatalogCoverage: false,
		});
		for (const error of fileErrors) {
			errors.push({ path: `${name}:${error.path}`, message: error.message });
		}
		if (!isObject(instance) || !Array.isArray(instance.cues)) {
			continue;
		}
		for (const item of instance.cues) {
			if (!isObject(item) || typeof item.id !== "string") {
				continue;
			}
			if (seenIds.has(item.id)) {
				errors.push({ path: `${name}:$.cues/id`, message: `duplicate cue id ${item.id} across banks` });
			}
			seenIds.add(item.id);
			mergedCues.push(item);
			if (!Array.isArray(item.streams)) {
				continue;
			}
			const bus = typeof item.bus === "string" ? item.bus : "";
			for (const stream of item.streams) {
				if (typeof stream !== "string" || seenStreams.has(stream)) {
					continue;
				}
				seenStreams.add(stream);
				const disk = resolveResStream(stream);
				if (disk === undefined || !existsSync(disk)) {
					continue;
				}
				const size = statSync(disk).size;
				totalBytes += size;
				if (!bytesOk(size, bus)) {
					errors.push({
						path: `${name}:$.cues`,
						message: `${stream} exceeds the CD-11 §8.3 byte cap`,
					});
				}
			}
		}
	}
	if (totalBytes > TOTAL_MAX_BYTES) {
		errors.push({ path: "$", message: "bank streams exceed the CD-11 §8.3 total cap" });
	}
	for (const cueId of catalogIds) {
		if (!seenIds.has(cueId)) {
			errors.push({ path: "$.cues", message: `catalog id ${cueId} is missing from production banks` });
		}
	}
	if (mergedCues.length === 0 && errors.length === 0) {
		errors.push({ path: "$", message: "production banks have no cues" });
	}
	errors.push(...validateProductionAudioAssets());
	return errors;
}

export function validateProductionAudioAssets(
	sfxDir: string = AUDIO_SFX_DIR,
	musicDir: string = AUDIO_MUSIC_DIR,
	runtimeDir: string = AUDIO_RUNTIME_DIR,
): JsonSchemaError[] {
	const errors: JsonSchemaError[] = [];
	const files = [...listOgg(sfxDir), ...listOgg(musicDir)];
	if (files.length === 0) {
		errors.push({ path: "$", message: EMPTY_AUDIO_MESSAGE });
	} else {
		for (const file of files) {
			const bus = file.startsWith(musicDir) ? "music" : "sfx";
			errors.push(...checkAudioFile(file, bus, file));
		}
	}
	for (const wav of listWav(runtimeDir)) {
		errors.push({ path: wav, message: "runtime audio must be OGG Vorbis, not WAV" });
	}
	return errors;
}

export function bytesOk(byteCount: number, bus: string): boolean {
	if (byteCount < 0) {
		return false;
	}
	if (bus === "music") {
		return byteCount <= MUSIC_MAX_BYTES;
	}
	return byteCount <= SFX_MAX_BYTES;
}

export function resolveResStream(stream: string): string | undefined {
	if (!stream.startsWith(STREAM_PREFIX) || stream.includes("..")) {
		return undefined;
	}
	const relative = stream.slice("res://".length);
	return join(REPO_ROOT, "game", relative);
}

function checkStream(
	stream: string,
	bus: string,
	path: string,
	options: AudioBankValidateOptions,
): JsonSchemaError[] {
	const disk = options.resolveStream?.(stream) ?? resolveResStream(stream);
	if (disk === undefined) {
		return [{ path, message: "stream path must be res://content/audio/ without .." }];
	}
	if (!existsSync(disk)) {
		return [{ path, message: "stream file is missing" }];
	}
	const size = statSync(disk).size;
	if (!bytesOk(size, bus)) {
		return [{ path, message: "stream exceeds the CD-11 §8.3 byte cap" }];
	}
	if (!stream.endsWith(STREAM_SUFFIX)) {
		return [{ path, message: "stream must be an .ogg file" }];
	}
	return checkAudioFile(disk, bus, path);
}

export function checkAudioFile(disk: string, bus: string, path: string): JsonSchemaError[] {
	const parsed = parseOggVorbis(readFileSync(disk));
	if (!isOggInfo(parsed)) {
		return [{ path, message: parsed.error }];
	}
	if (parsed.sampleRate !== SAMPLE_RATE) {
		return [{ path, message: "sample rate must be 44100 Hz (CD-11 §8.3)" }];
	}
	const music = bus === "music";
	const wantChannels = music ? MUSIC_CHANNELS : SFX_CHANNELS;
	if (parsed.channels !== wantChannels) {
		return [{ path, message: music ? "music must be stereo" : "sfx must be mono" }];
	}
	if (!music && parsed.durationSec > SFX_MAX_SECONDS + 1e-6) {
		return [{ path, message: "sfx duration exceeds 2 s (CD-11 §8.3)" }];
	}
	return [];
}

function listOgg(directory: string): string[] {
	if (!existsSync(directory)) {
		return [];
	}
	return readdirSync(directory)
		.filter((name) => name.toLowerCase().endsWith(".ogg"))
		.map((name) => join(directory, name))
		.sort();
}

function listWav(directory: string): string[] {
	if (!existsSync(directory)) {
		return [];
	}
	const found: string[] = [];
	for (const name of readdirSync(directory)) {
		if (name === "banks" || name.startsWith(".")) {
			continue;
		}
		const path = join(directory, name);
		const stat = statSync(path, { throwIfNoEntry: false });
		if (stat === undefined) {
			continue;
		}
		if (stat.isDirectory()) {
			found.push(...listWav(path));
			continue;
		}
		if (name.toLowerCase().endsWith(".wav")) {
			found.push(path);
		}
	}
	return found.sort();
}

function isObject(value: unknown): value is JsonObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
