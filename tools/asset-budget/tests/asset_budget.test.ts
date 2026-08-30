import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { describe, test } from "node:test";

import { Document, NodeIO, type Primitive } from "@gltf-transform/core";

import {
	MAX_FILE_BYTES,
	MAX_TEXTURE_SIZE,
	MAX_TRIANGLES_RIGGED,
	MAX_TRIANGLES_STATIC,
} from "../src/budget.ts";
import { checkAssetFile, checkDocument, isWithinBudget } from "../src/check.ts";
import { findAssets } from "../src/discover.ts";
import { readImageSize } from "../src/image_size.ts";

/**
 * 预算数值本身不在这里断言"对不对"——那是 CD-11 §8.1 的决定。
 * 这里断言的是：**超一点就红、刚好不超就绿**，以及无法判定时**拒绝而不是放过**。
 */

/** 造一张能被 header 解析的 PNG（只有 magic + IHDR，不含像素数据）。 */
function pngHeader(width: number, height: number): Uint8Array {
	const bytes = new Uint8Array(24);
	bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
	const view = new DataView(bytes.buffer);
	view.setUint32(8, 13, false);
	bytes.set([0x49, 0x48, 0x44, 0x52], 12);
	view.setUint32(16, width, false);
	view.setUint32(20, height, false);
	return bytes;
}

/** 造一张最小 JPEG：SOI + SOF0，尺寸写在 SOF0 里。 */
function jpegHeader(width: number, height: number): Uint8Array {
	const bytes = new Uint8Array(11);
	bytes.set([0xff, 0xd8, 0xff, 0xc0], 0);
	const view = new DataView(bytes.buffer);
	view.setUint16(4, 8, false); // 段长
	bytes[6] = 8; // 精度
	view.setUint16(7, height, false);
	view.setUint16(9, width, false);
	return bytes;
}

interface MeshSpec {
	readonly triangles: number;
	readonly mode?: Parameters<Primitive["setMode"]>[0];
}

function makeDocument(spec: {
	readonly meshes?: readonly MeshSpec[];
	readonly rigged?: boolean;
	readonly textures?: readonly Uint8Array[];
}): Document {
	const document = new Document();
	const buffer = document.createBuffer();

	for (const mesh of spec.meshes ?? []) {
		const vertexCount = mesh.triangles * 3;
		const position = document
			.createAccessor()
			.setType("VEC3")
			.setArray(new Float32Array(vertexCount * 3))
			.setBuffer(buffer);
		const primitive = document.createPrimitive().setAttribute("POSITION", position);
		if (mesh.mode !== undefined) {
			primitive.setMode(mesh.mode);
		}
		document.createMesh().addPrimitive(primitive);
	}

	if (spec.rigged === true) {
		document.createSkin("rig");
	}

	for (const image of spec.textures ?? []) {
		const isPng = image[0] === 0x89;
		// 刻意**不给名字**：生成工具产出的贴图既无 name 也无 URI，这才是要靠
		// glTF 索引区分的真实情形。
		document
			.createTexture()
			.setMimeType(isPng ? "image/png" : "image/jpeg")
			.setImage(image);
	}

	return document;
}

describe("image header size", () => {
	test("reads PNG, JPEG, WebP and KTX2 without decoding pixels", () => {
		assert.deepEqual(readImageSize(pngHeader(512, 256)), { width: 512, height: 256 });
		assert.deepEqual(readImageSize(jpegHeader(4096, 2048)), { width: 4096, height: 2048 });

		// WebP VP8L：packed 里宽高各 14 位，存的是 size-1。
		const webp = new Uint8Array(30);
		webp.set([0x52, 0x49, 0x46, 0x46], 0);
		webp.set([0x57, 0x45, 0x42, 0x50], 8);
		webp.set([0x56, 0x50, 0x38, 0x4c], 12);
		new DataView(webp.buffer).setUint32(21, (511 & 0x3fff) | ((255 & 0x3fff) << 14), true);
		assert.deepEqual(readImageSize(webp), { width: 512, height: 256 });

		const ktx2 = new Uint8Array(28);
		ktx2.set([0xab, 0x4b, 0x54, 0x58, 0x20, 0x32, 0x30, 0xbb, 0x0d, 0x0a, 0x1a, 0x0a], 0);
		const ktxView = new DataView(ktx2.buffer);
		ktxView.setUint32(20, 1024, true);
		ktxView.setUint32(24, 1024, true);
		assert.deepEqual(readImageSize(ktx2), { width: 1024, height: 1024 });
	});

	test("returns undefined for anything it cannot measure", () => {
		assert.equal(readImageSize(new Uint8Array(0)), undefined);
		assert.equal(readImageSize(new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8])), undefined);
		// 截断的 PNG：magic 对但读不到 IHDR。
		assert.equal(readImageSize(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), undefined);
	});
});

describe("single-asset budget (CD-11 section 8.1)", () => {
	test("a static asset at exactly the budget passes", () => {
		const report = checkDocument(
			makeDocument({ meshes: [{ triangles: MAX_TRIANGLES_STATIC }], textures: [pngHeader(512, 512)] }),
			"exact.glb",
			MAX_FILE_BYTES,
		);
		assert.equal(report.rigged, false);
		assert.equal(report.triangles, MAX_TRIANGLES_STATIC);
		assert.equal(report.maxTriangles, MAX_TRIANGLES_STATIC);
		assert.ok(isWithinBudget(report), JSON.stringify(report.violations));
	});

	test("one triangle over the static budget fails", () => {
		const report = checkDocument(
			makeDocument({ meshes: [{ triangles: MAX_TRIANGLES_STATIC + 1 }] }),
			"over.glb",
			1024,
		);
		assert.deepEqual(
			report.violations.map((violation) => violation.kind),
			["triangles"],
		);
	});

	test("a skin raises the budget to the rigged tier, and it is decided by skins not by name", () => {
		const triangles = MAX_TRIANGLES_STATIC + 1;
		const asStatic = checkDocument(makeDocument({ meshes: [{ triangles }] }), "character.glb", 1024);
		assert.equal(asStatic.violations.length, 1, "no skin means the static tier applies even if named character");

		const asRigged = checkDocument(makeDocument({ meshes: [{ triangles }], rigged: true }), "x.glb", 1024);
		assert.equal(asRigged.rigged, true);
		assert.equal(asRigged.maxTriangles, MAX_TRIANGLES_RIGGED);
		assert.ok(isWithinBudget(asRigged));

		const overRigged = checkDocument(
			makeDocument({ meshes: [{ triangles: MAX_TRIANGLES_RIGGED + 1 }], rigged: true }),
			"x.glb",
			1024,
		);
		assert.deepEqual(
			overRigged.violations.map((violation) => violation.kind),
			["triangles"],
		);
	});

	test("triangles add up across meshes so splitting an asset cannot dodge the budget", () => {
		const half = MAX_TRIANGLES_STATIC / 2;
		const report = checkDocument(
			makeDocument({ meshes: [{ triangles: half }, { triangles: half + 1 }] }),
			"split.glb",
			1024,
		);
		assert.equal(report.triangles, MAX_TRIANGLES_STATIC + 1);
		assert.deepEqual(
			report.violations.map((violation) => violation.kind),
			["triangles"],
		);
	});

	test("strip and fan modes count as n-2, not n/3", () => {
		// 4 个顶点：TRIANGLES 只有 1 个三角面，STRIP 有 2 个。数错会让预算偏松。
		const strip = checkDocument(makeDocument({ meshes: [{ triangles: 2, mode: 5 }] }), "strip.glb", 1024);
		assert.equal(strip.triangles, 4); // 6 个顶点 - 2
		const fan = checkDocument(makeDocument({ meshes: [{ triangles: 1, mode: 6 }] }), "fan.glb", 1024);
		assert.equal(fan.triangles, 1); // 3 个顶点 - 2
	});

	test("point and line modes are rejected instead of silently counting zero", () => {
		// 静默当 0 个三角面，等于给"用线段画的资产"开一条绕过预算的路。
		const modes: Parameters<Primitive["setMode"]>[0][] = [0, 1, 2, 3];
		for (const mode of modes) {
			const report = checkDocument(makeDocument({ meshes: [{ triangles: 9_999, mode }] }), "lines.glb", 1024);
			assert.deepEqual(
				report.violations.map((violation) => violation.kind),
				["unsupported_primitive_mode"],
				`mode ${mode}`,
			);
		}
	});

	test("one texture edge over the budget fails, and every offending texture is named", () => {
		const report = checkDocument(
			makeDocument({
				meshes: [{ triangles: 10 }],
				textures: [
					pngHeader(MAX_TEXTURE_SIZE, MAX_TEXTURE_SIZE),
					pngHeader(MAX_TEXTURE_SIZE + 1, MAX_TEXTURE_SIZE),
					jpegHeader(MAX_TEXTURE_SIZE, 4096),
				],
			}),
			"tex.glb",
			1024,
		);
		assert.deepEqual(
			report.violations.map((violation) => violation.kind),
			["texture_size", "texture_size"],
		);
		assert.equal(report.largestTexture, 4096);
		// 三张全叫 <embedded> 时分不出是哪一张，所以标签必须带 glTF 索引。
		assert.match(report.violations[0]?.detail ?? "", /"#1" is 513x512/);
		assert.match(report.violations[1]?.detail ?? "", /"#2" is 512x4096/);
	});

	test("an unmeasurable texture is a failure, not a pass", () => {
		const document = makeDocument({ meshes: [{ triangles: 10 }] });
		document.createTexture("mystery").setMimeType("image/tiff").setImage(new Uint8Array([1, 2, 3, 4]));
		const report = checkDocument(document, "mystery.glb", 1024);
		assert.deepEqual(
			report.violations.map((violation) => violation.kind),
			["unknown_texture_format"],
		);
	});

	test("file size is judged in binary MB, one byte over fails", () => {
		const meshes = [{ triangles: 10 }];
		assert.ok(isWithinBudget(checkDocument(makeDocument({ meshes }), "at.glb", MAX_FILE_BYTES)));
		const over = checkDocument(makeDocument({ meshes }), "over.glb", MAX_FILE_BYTES + 1);
		assert.deepEqual(
			over.violations.map((violation) => violation.kind),
			["file_bytes"],
		);
		assert.match(over.violations[0]?.detail ?? "", /2\.00 MB/);
	});

	test("every violation is reported at once, not just the first", () => {
		const report = checkDocument(
			makeDocument({ meshes: [{ triangles: MAX_TRIANGLES_STATIC + 1 }], textures: [pngHeader(4096, 4096)] }),
			"bad.glb",
			MAX_FILE_BYTES + 1,
		);
		assert.deepEqual(new Set(report.violations.map((violation) => violation.kind)), new Set(["triangles", "texture_size", "file_bytes"]));
	});
});

describe("asset budget over real files", () => {
	test("reads a written glb and rejects an LFS pointer masquerading as one", async () => {
		const directory = mkdtempSync(join(tmpdir(), "asset-budget-"));
		try {
			const good = join(directory, "good.glb");
			await new NodeIO().write(
				good,
				makeDocument({ meshes: [{ triangles: 100 }], textures: [pngHeader(256, 256)] }),
			);
			const report = await checkAssetFile(good);
			assert.equal(report.triangles, 100);
			assert.equal(report.largestTexture, 256);
			assert.ok(isWithinBudget(report));

			// 忘了 git lfs pull 时磁盘上是这个文本指针。当成 0 面数的合法资产放过去
			// 会让门禁在最需要它的时候变绿。
			const pointer = join(directory, "pointer.glb");
			writeFileSync(
				pointer,
				"version https://git-lfs.github.com/spec/v1\noid sha256:0000\nsize 123\n",
			);
			await assert.rejects(() => checkAssetFile(pointer));
		} finally {
			rmSync(directory, { recursive: true, force: true });
		}
	});

	test("discovery finds nested glb but skips addons and is case-insensitive", async () => {
		const directory = mkdtempSync(join(tmpdir(), "asset-discover-"));
		try {
			const io = new NodeIO();
			const document = makeDocument({ meshes: [{ triangles: 1 }] });

			mkdirSync(join(directory, "assets", "props"), { recursive: true });
			mkdirSync(join(directory, "addons", "gut"), { recursive: true });
			await io.write(join(directory, "assets", "props", "crate.GLB"), document);
			await io.write(join(directory, "root.glb"), document);
			// 第三方插件自带的资产不该被平台预算判定，否则每次都是假红。
			await io.write(join(directory, "addons", "gut", "plugin_art.glb"), document);

			const found = findAssets(directory).map((path) => relative(directory, path));
			assert.deepEqual(found, [join("assets", "props", "crate.GLB"), "root.glb"]);
		} finally {
			rmSync(directory, { recursive: true, force: true });
		}
	});
});
