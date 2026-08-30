import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { checkAssetFile, formatBytes, isWithinBudget, type AssetReport } from "./check.ts";
import { findAssets } from "./discover.ts";

/**
 * 单资产预算门禁（CD-11 §8.1）。
 *
 *   node tools/asset-budget/src/main.ts              扫 game/ 下所有 .glb
 *   node tools/asset-budget/src/main.ts a.glb b.glb  只查指定文件
 *
 * 超限退出码 1。**仓库里一个 .glb 都没有时也不静默成功**：它会明确说出扫了哪里、
 * 找到 0 个，避免"门禁绿着但其实什么都没查"这种宪法第二十四条要防的假象。
 */

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const SCAN_ROOT = join(REPO_ROOT, "game");

const explicit = process.argv.slice(2);
const targets = explicit.length > 0 ? explicit.map((path) => resolve(path)) : findAssets(SCAN_ROOT);

if (targets.length === 0) {
	console.log(`asset-budget: no .glb under ${relative(REPO_ROOT, SCAN_ROOT)}/ — nothing was checked.`);
	console.log("asset-budget: this is not a pass. The first asset lands in C4 chapter 5 (E7).");
	process.exit(0);
}

let failed = false;
for (const target of targets) {
	let report: AssetReport;
	try {
		report = await checkAssetFile(target);
	} catch (error) {
		// 读不出来也是失败：LFS 指针文件、截断的 glb、非 glTF 内容都走这条路。
		console.error(`${relative(REPO_ROOT, target)}: cannot be read as glTF — ${describe(error)}`);
		failed = true;
		continue;
	}

	const label = relative(REPO_ROOT, report.path);
	const summary = `${report.triangles}/${report.maxTriangles} tris (${report.rigged ? "rigged" : "static"}), ${report.textureCount} textures, largest edge ${report.largestTexture}, ${formatBytes(report.fileBytes)}`;

	if (isWithinBudget(report)) {
		console.log(`ok   ${label}: ${summary}`);
		continue;
	}

	failed = true;
	console.error(`FAIL ${label}: ${summary}`);
	for (const violation of report.violations) {
		console.error(`       [${violation.kind}] ${violation.detail}`);
	}
}

if (failed) {
	console.error("");
	console.error("asset-budget: over budget. Bake it down first — see docs/runbooks/asset-bake.md.");
	process.exit(1);
}

process.exit(0);

function describe(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}
