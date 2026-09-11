/**
 * Ogg Vorbis identification + duration from granule position.
 * No native decoder. CD-11 §8.3 numbers are not owned here.
 */

const OGG_CAPTURE = Buffer.from("OggS");
const VORBIS_IDENT = Buffer.from("\x01vorbis");
const LFS_PREFIX = "version https://git-lfs.github.com/spec/v1";

export type OggInfo = {
	readonly channels: number;
	readonly sampleRate: number;
	readonly durationSec: number;
	readonly bytes: number;
};

export type OggParseResult = OggInfo | { readonly error: string };

export function parseOggVorbis(data: Uint8Array): OggParseResult {
	const bytes = Buffer.from(data);
	if (bytes.length === 0) {
		return { error: "empty audio file" };
	}
	if (bytes.toString("utf8", 0, Math.min(bytes.length, LFS_PREFIX.length)) === LFS_PREFIX) {
		return { error: "LFS pointer, not an audio payload" };
	}
	if (bytes.length < 4 || !bytes.subarray(0, 4).equals(OGG_CAPTURE)) {
		return { error: "not Ogg Vorbis" };
	}
	const identAt = bytes.indexOf(VORBIS_IDENT);
	if (identAt < 0 || identAt + 16 > bytes.length) {
		return { error: "missing Vorbis identification header" };
	}
	const version = bytes.readUInt32LE(identAt + 7);
	if (version !== 0) {
		return { error: "unsupported Vorbis version" };
	}
	const channels = bytes[identAt + 11] ?? 0;
	const sampleRate = bytes.readUInt32LE(identAt + 12);
	if (channels < 1 || sampleRate < 1) {
		return { error: "illegal Vorbis identification header" };
	}
	let lastGranule = 0n;
	let pos = 0;
	while (pos + 27 <= bytes.length) {
		if (!bytes.subarray(pos, pos + 4).equals(OGG_CAPTURE)) {
			pos += 1;
			continue;
		}
		const granule = bytes.readBigInt64LE(pos + 6);
		if (granule > lastGranule) {
			lastGranule = granule;
		}
		const nseg = bytes[pos + 26] ?? 0;
		let packetLen = 0;
		for (let i = 0; i < nseg; i += 1) {
			packetLen += bytes[pos + 27 + i] ?? 0;
		}
		const next = pos + 27 + nseg + packetLen;
		if (next <= pos) {
			break;
		}
		pos = next;
	}
	const durationSec = Number(lastGranule) / sampleRate;
	return {
		channels,
		sampleRate,
		durationSec,
		bytes: bytes.length,
	};
}

export function isOggInfo(value: OggParseResult): value is OggInfo {
	return !("error" in value);
}
