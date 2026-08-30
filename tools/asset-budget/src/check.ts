import { statSync } from "node:fs";

import { NodeIO, type Document } from "@gltf-transform/core";

import {
	GLTF_MODE_TRIANGLES,
	GLTF_MODE_TRIANGLE_FAN,
	GLTF_MODE_TRIANGLE_STRIP,
	MAX_FILE_BYTES,
	MAX_TEXTURE_SIZE,
	MAX_TRIANGLES_RIGGED,
	MAX_TRIANGLES_STATIC,
} from "./budget.ts";
import { readImageSize } from "./image_size.ts";

/**
 * 单资产预算判定（CD-11 §8.1）。
 *
 * **本章只做单资产准入。** 场景总量、Draw call、材质数与骨骼上限仍属
 * CD-63 §1.7 延期，人类 2026-08-30 明确本章不做，所以这里没有它们的位置。
 * 想加须先拍板，不得由实现自选。
 */

export type AssetViolationKind =
	| "triangles"
	| "texture_size"
	| "file_bytes"
	| "unknown_texture_format"
	| "unsupported_primitive_mode";

export interface AssetViolation {
	readonly kind: AssetViolationKind;
	readonly detail: string;
}

export interface AssetReport {
	readonly path: string;
	/** glTF 有 skin 就按角色档，不看文件名——文件名是约定，skin 是事实。 */
	readonly rigged: boolean;
	readonly triangles: number;
	readonly maxTriangles: number;
	readonly fileBytes: number;
	readonly textureCount: number;
	readonly largestTexture: number;
	readonly violations: readonly AssetViolation[];
}

export function isWithinBudget(report: AssetReport): boolean {
	return report.violations.length === 0;
}

export async function checkAssetFile(path: string): Promise<AssetReport> {
	const document = await new NodeIO().read(path);
	return checkDocument(document, path, statSync(path).size);
}

/** 与文件系统解耦，好让测试用合成 Document 覆盖每一条超限。 */
export function checkDocument(document: Document, path: string, fileBytes: number): AssetReport {
	const root = document.getRoot();
	const rigged = root.listSkins().length > 0;
	const maxTriangles = rigged ? MAX_TRIANGLES_RIGGED : MAX_TRIANGLES_STATIC;
	const violations: AssetViolation[] = [];

	let triangles = 0;
	for (const mesh of root.listMeshes()) {
		for (const primitive of mesh.listPrimitives()) {
			const mode = primitive.getMode();
			const vertexCount = primitive.getIndices()?.getCount() ?? primitive.getAttribute("POSITION")?.getCount() ?? 0;
			const counted = countTriangles(mode, vertexCount);
			if (counted === undefined) {
				// 点 / 线 / 未知模式：按 ADR-0006 的同一条纪律**明确拒绝而不近似**。
				// 静默当成 0 个三角面，等于给"用线段画出来的资产"开一条绕过预算的路。
				violations.push({
					kind: "unsupported_primitive_mode",
					detail: `mesh "${mesh.getName()}" uses primitive mode ${mode}; only TRIANGLES (${GLTF_MODE_TRIANGLES}), TRIANGLE_STRIP (${GLTF_MODE_TRIANGLE_STRIP}) and TRIANGLE_FAN (${GLTF_MODE_TRIANGLE_FAN}) can be counted`,
				});
				continue;
			}
			triangles += counted;
		}
	}

	if (triangles > maxTriangles) {
		violations.push({
			kind: "triangles",
			detail: `${triangles} triangles exceeds the ${rigged ? "rigged" : "static"} budget of ${maxTriangles}`,
		});
	}

	let largestTexture = 0;
	for (const [index, texture] of root.listTextures().entries()) {
		const image = texture.getImage();
		// 生成产物的贴图既没有名字也没有 URI，全叫 `<embedded>` 就分不清是哪一张。
		// 索引是 glTF 里稳定的标识，`gltf-transform inspect` 也按它列表。
		const named = texture.getName() !== "" ? texture.getName() : texture.getURI();
		const label = named !== "" ? `#${index} ${named}` : `#${index}`;
		if (image === null) {
			violations.push({
				kind: "unknown_texture_format",
				detail: `texture "${label}" has no image payload, so its size cannot be decided`,
			});
			continue;
		}
		const size = readImageSize(image);
		if (size === undefined) {
			violations.push({
				kind: "unknown_texture_format",
				detail: `texture "${label}" (${texture.getMimeType()}) is not a format this gate can measure; treat it as a failure, not a pass`,
			});
			continue;
		}
		const longestEdge = Math.max(size.width, size.height);
		largestTexture = Math.max(largestTexture, longestEdge);
		if (longestEdge > MAX_TEXTURE_SIZE) {
			violations.push({
				kind: "texture_size",
				detail: `texture "${label}" is ${size.width}x${size.height}; the budget is ${MAX_TEXTURE_SIZE} per edge`,
			});
		}
	}

	if (fileBytes > MAX_FILE_BYTES) {
		violations.push({
			kind: "file_bytes",
			detail: `${formatBytes(fileBytes)} exceeds the ${formatBytes(MAX_FILE_BYTES)} budget`,
		});
	}

	return {
		path,
		rigged,
		triangles,
		maxTriangles,
		fileBytes,
		textureCount: root.listTextures().length,
		largestTexture,
		violations,
	};
}

/** 返回 undefined 表示这个 mode 数不出三角面，调用方必须当成失败。 */
function countTriangles(mode: number, vertexCount: number): number | undefined {
	if (mode === GLTF_MODE_TRIANGLES) {
		return Math.floor(vertexCount / 3);
	}
	// 条带与扇形：n 个顶点得 n-2 个三角面。少于 3 个顶点画不出三角形。
	if (mode === GLTF_MODE_TRIANGLE_STRIP || mode === GLTF_MODE_TRIANGLE_FAN) {
		return vertexCount < 3 ? 0 : vertexCount - 2;
	}
	return undefined;
}

export function formatBytes(bytes: number): string {
	if (bytes < 1024) {
		return `${bytes} B`;
	}
	if (bytes < 1024 * 1024) {
		return `${(bytes / 1024).toFixed(1)} KB`;
	}
	return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}
