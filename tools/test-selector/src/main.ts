import { spawnSync } from "node:child_process";

import { discoverChanges } from "./git.ts";
import { gutArgs, resolveGodotExecutable } from "./godot.ts";
import { FAST_TIER_DIRS, REPO_ROOT } from "./paths.ts";
import { selectAffected } from "./select.ts";
import type { Selection } from "./select.ts";

/**
 * 只跑「这一刀碰得到」的 GUT 脚本。
 *
 * **这不是门禁。** CI 每次 PR 仍然跑四个目录全量。本工具存在的唯一目的是把开发
 * 中途那一轮再压短一点；它算错的后果上限是「某个失败晚几分钟被发现」，不是
 * 「某个失败进了 main」。CD-53 §4.1 里「受影响单元测试」这一项指的就是它。
 *
 * 用法：
 *   node tools/test-selector/src/main.ts            # 算出来并直接跑
 *   node tools/test-selector/src/main.ts --dry-run  # 只打印会跑什么
 *   node tools/test-selector/src/main.ts --base=xxx # 换对比基线（默认 main）
 */
const argv = process.argv.slice(2);
const dryRun = argv.includes("--dry-run");
const base = readOption(argv, "--base") ?? "main";

const selection = decide(base);
report(selection);

if (selection.kind === "none") {
	process.exit(0);
}
if (dryRun) {
	process.exit(0);
}

const selector =
	selection.kind === "full"
		? `-gdir=${FAST_TIER_DIRS.join(",")}`
		: `-gtest=${selection.scripts.join(",")}`;

const { executable, source } = resolveGodotExecutable(process.env, process.platform);
console.log(`test-selector: engine from ${source}`);
const result = spawnSync(executable, [...gutArgs(selector)], {
	cwd: REPO_ROOT,
	stdio: "inherit",
});
if (result.error !== undefined) {
	console.error(`test-selector: failed to start ${executable}: ${result.error.message}`);
	process.exit(1);
}
process.exit(result.status ?? 1);

function decide(baseRef: string): Selection {
	try {
		const changes = discoverChanges(REPO_ROOT, baseRef);
		const where = changes.base === undefined ? "working tree only" : `vs ${changes.base}`;
		console.log(`test-selector: ${changes.paths.length} changed path(s) (${where})`);
		return selectAffected(REPO_ROOT, changes.paths);
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		return { kind: "full", reason: `could not read the change set from git: ${message}` };
	}
}

function report(decided: Selection): void {
	switch (decided.kind) {
		case "none":
			console.log(`test-selector: nothing to run (${decided.reason})`);
			return;
		case "full":
			console.log(`test-selector: falling back to the whole fast tier (${decided.reason})`);
			return;
		case "subset":
			console.log(`test-selector: ${decided.scripts.length} script(s) (${decided.reason})`);
			for (const script of decided.scripts) {
				console.log(`  ${script}`);
			}
			return;
	}
}

function readOption(args: readonly string[], name: string): string | undefined {
	const prefix = `${name}=`;
	const hit = args.find((arg) => arg.startsWith(prefix));
	return hit?.slice(prefix.length);
}
