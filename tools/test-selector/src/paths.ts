import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

export const REPO_ROOT = join(here, "../../..");
export const FIXTURES_DIR = join(here, "../fixtures");

/**
 * GUT 的 fast 层目录。
 *
 * 分层只影响**本地能不能少跑一层**：CI 的 `godot` job 跑 fast + slow 四个目录，
 * 两层都是每次 PR 的门禁。改这里要同时改 `.github/workflows/ci.yml` 的 `-gdir`。
 */
export const FAST_TIER_DIRS = [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/replay",
] as const;

/** slow 层目录：官方赛道在权威上的完整搜索。同样是每次 PR 的门禁。 */
export const SLOW_TIER_DIRS = ["res://tests/slow"] as const;

/** 扫描依赖图时要读的 Godot 源码根，全部相对仓库根。 */
export const SCAN_ROOTS = [
	"game/src",
	"game/tests",
	"game/addons/authoring_editor",
] as const;
