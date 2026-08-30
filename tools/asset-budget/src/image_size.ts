/**
 * 从图像字节的头部读出尺寸，**不解码像素**。
 *
 * 为什么自己写而不用 sharp：sharp 是 native 预编译二进制（libvips），装不上的平台
 * 就没有门禁；而 0.34.x 那条链上还挂着 4 个 libvips CVE。判定"这张图是不是超过
 * 512"只需要 header 里的两个整数，不需要把 4096×4096 解码进内存。
 *
 * 只认 glTF 2.0 core 允许的两种（PNG / JPEG）加两个常见扩展（WebP / KTX2）。
 * 认不出的一律返回 undefined，由调用方当成"无法判定"**拒绝**，不是放过。
 */

export interface ImageSize {
	readonly width: number;
	readonly height: number;
}

const PNG_MAGIC = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** JPEG 里带尺寸的 SOF 段。0xC4 / 0xC8 / 0xCC 是 DHT / JPG / DAC，不是 SOF。 */
function isStartOfFrame(marker: number): boolean {
	return marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
}

export function readImageSize(bytes: Uint8Array): ImageSize | undefined {
	return readPngSize(bytes) ?? readJpegSize(bytes) ?? readWebpSize(bytes) ?? readKtx2Size(bytes);
}

function readPngSize(bytes: Uint8Array): ImageSize | undefined {
	if (bytes.length < 24) {
		return undefined;
	}
	for (const [index, expected] of PNG_MAGIC.entries()) {
		if (bytes[index] !== expected) {
			return undefined;
		}
	}
	// IHDR 必须是第一个 chunk，宽高是它的前两个 big-endian uint32。
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	return { width: view.getUint32(16, false), height: view.getUint32(20, false) };
}

function readJpegSize(bytes: Uint8Array): ImageSize | undefined {
	if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) {
		return undefined;
	}

	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	let offset = 2;
	while (offset + 4 <= bytes.length) {
		if (bytes[offset] !== 0xff) {
			// 段之间允许填充 0xFF，其他值说明流坏了——宁可判不出也不要猜。
			offset += 1;
			continue;
		}
		const marker = bytes[offset + 1];
		if (marker === undefined) {
			return undefined;
		}
		if (marker === 0xff) {
			offset += 1;
			continue;
		}
		// 这些标记没有长度字段。
		if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd9)) {
			offset += 2;
			continue;
		}
		const length = view.getUint16(offset + 2, false);
		if (isStartOfFrame(marker)) {
			if (offset + 9 > bytes.length) {
				return undefined;
			}
			return { width: view.getUint16(offset + 7, false), height: view.getUint16(offset + 5, false) };
		}
		if (length < 2) {
			return undefined;
		}
		offset += 2 + length;
	}
	return undefined;
}

function readWebpSize(bytes: Uint8Array): ImageSize | undefined {
	if (bytes.length < 30) {
		return undefined;
	}
	if (asciiAt(bytes, 0, 4) !== "RIFF" || asciiAt(bytes, 8, 4) !== "WEBP") {
		return undefined;
	}

	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	const format = asciiAt(bytes, 12, 4);
	// VP8X 的扩展头存的是 width-1 / height-1，各 24 位小端。
	if (format === "VP8X") {
		const width = 1 + (view.getUint16(24, true) | ((bytes[26] ?? 0) << 16));
		const height = 1 + (view.getUint16(27, true) | ((bytes[29] ?? 0) << 16));
		return { width, height };
	}
	if (format === "VP8 ") {
		// 有损：关键帧头之后是 14 位宽、14 位高。
		return { width: view.getUint16(26, true) & 0x3fff, height: view.getUint16(28, true) & 0x3fff };
	}
	if (format === "VP8L") {
		const packed = view.getUint32(21, true);
		return { width: 1 + (packed & 0x3fff), height: 1 + ((packed >> 14) & 0x3fff) };
	}
	return undefined;
}

function readKtx2Size(bytes: Uint8Array): ImageSize | undefined {
	// «KTX 20»\r\n\x1A\n
	const magic = [0xab, 0x4b, 0x54, 0x58, 0x20, 0x32, 0x30, 0xbb, 0x0d, 0x0a, 0x1a, 0x0a];
	if (bytes.length < 28) {
		return undefined;
	}
	for (const [index, expected] of magic.entries()) {
		if (bytes[index] !== expected) {
			return undefined;
		}
	}
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	return { width: view.getUint32(20, true), height: view.getUint32(24, true) };
}

function asciiAt(bytes: Uint8Array, offset: number, length: number): string {
	let out = "";
	for (let index = offset; index < offset + length; index += 1) {
		out += String.fromCharCode(bytes[index] ?? 0);
	}
	return out;
}
