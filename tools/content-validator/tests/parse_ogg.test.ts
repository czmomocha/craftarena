import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { isOggInfo, parseOggVorbis } from "../src/parse_ogg.ts";

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

describe("parseOggVorbis", () => {
	it("reads channels, sample rate, and granule duration from a Vorbis ident page", () => {
		const parsed = parseOggVorbis(
			makeVorbisOgg({ channels: 1, sampleRate: 44100, granule: 88200n }),
		);
		assert.equal(isOggInfo(parsed), true);
		if (!isOggInfo(parsed)) {
			return;
		}
		assert.equal(parsed.channels, 1);
		assert.equal(parsed.sampleRate, 44100);
		assert.equal(parsed.durationSec, 2);
	});

	it("rejects an LFS pointer instead of treating it as audio", () => {
		const parsed = parseOggVorbis(
			Buffer.from("version https://git-lfs.github.com/spec/v1\noid sha256:abc\n"),
		);
		assert.equal(isOggInfo(parsed), false);
		if (isOggInfo(parsed)) {
			return;
		}
		assert.match(parsed.error, /LFS pointer/);
	});

	it("rejects a buffer that is not Ogg Vorbis", () => {
		const parsed = parseOggVorbis(Buffer.from("RIFF"));
		assert.equal(isOggInfo(parsed), false);
		if (isOggInfo(parsed)) {
			return;
		}
		assert.equal(parsed.error, "not Ogg Vorbis");
	});
});
