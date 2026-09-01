import { spawnSync } from "node:child_process";

import { gutArgs, resolveGodotExecutable } from "./godot.ts";
import { FAST_TIER_DIRS, REPO_ROOT, SLOW_TIER_DIRS } from "./paths.ts";

/**
 * 按层跑 GUT。存在的理由是**跨平台**：npm script 在 Linux 走 sh、在 Windows 走
 * cmd.exe，`$GODOT4` 与 `%GODOT4%` 写不进同一行，于是引擎路径只能在 Node 里解析。
 * 顺带让四条命令共用 `resolveGodotExecutable`，不会一处改了另一处忘了。
 *
 *   fast  unit + integration + replay
 *   slow  官方赛道在权威上的完整搜索
 *   full  两层都跑，**CI 每次 PR 跑的就是它**
 *
 * 分层只是让本地能少跑一层，两层都是合并门禁（CD-53 §4.1）。
 */
const TIERS = {
	fast: FAST_TIER_DIRS,
	slow: SLOW_TIER_DIRS,
	full: [...FAST_TIER_DIRS, ...SLOW_TIER_DIRS],
} as const;

type TierName = keyof typeof TIERS;

const requested = process.argv[2];
if (requested === undefined || !isTierName(requested)) {
	console.error(`usage: run_tier.ts <${Object.keys(TIERS).join("|")}>`);
	process.exit(2);
}

const dirs = TIERS[requested];
const { executable, source } = resolveGodotExecutable(process.env, process.platform);
console.log(`gut ${requested} tier: ${dirs.join(",")} (engine from ${source})`);

const result = spawnSync(executable, [...gutArgs(`-gdir=${dirs.join(",")}`)], {
	cwd: REPO_ROOT,
	stdio: "inherit",
});
if (result.error !== undefined) {
	console.error(`run_tier: failed to start ${executable}: ${result.error.message}`);
	process.exit(1);
}
process.exit(result.status ?? 1);

function isTierName(value: string): value is TierName {
	return Object.hasOwn(TIERS, value);
}
