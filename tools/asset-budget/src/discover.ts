import { readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/**
 * 扫描要被预算门禁覆盖的资产。
 *
 * 只看 `game/`，且**跳过 `addons/`**：GUT 与本机安装的 Godot AI 插件不是本项目资产，
 * 拿平台预算去卡第三方插件自带的图只会制造假红。
 */

const SKIPPED_DIRECTORIES = new Set(["addons", ".godot", "node_modules"]);

/** glTF 二进制容器。`.gltf` + 外部 bin 一期不入库（CD-51 §5 统一 GLB）。 */
const ASSET_EXTENSION = ".glb";

export function findAssets(root: string): readonly string[] {
	const found: string[] = [];
	walk(root, found);
	return found.sort();
}

function walk(directory: string, found: string[]): void {
	let entries: readonly string[];
	try {
		entries = readdirSync(directory);
	} catch {
		return;
	}

	for (const entry of entries) {
		if (SKIPPED_DIRECTORIES.has(entry)) {
			continue;
		}
		const path = join(directory, entry);
		const stat = statSync(path, { throwIfNoEntry: false });
		if (stat === undefined) {
			continue;
		}
		if (stat.isDirectory()) {
			walk(path, found);
			continue;
		}
		if (entry.toLowerCase().endsWith(ASSET_EXTENSION)) {
			found.push(path);
		}
	}
}
