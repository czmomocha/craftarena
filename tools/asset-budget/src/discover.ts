import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/**
 * 扫描要被预算门禁覆盖的资产。
 */

/**
 * 不是本项目资产的目录，按**目录名**跳过。
 *
 * - `addons/`：GUT 与本机安装的 Godot AI 插件。第三方插件自带的图不受平台预算
 *   约束（CD-51 §5.1），拿它去判定只会制造假红。
 * - `_source_refs/`：AI 生成工具（TRELLIS、混元 3D 等）的原始产物落点，烘焙**前**的
 *   glb 与 4K 源贴图，按定义过不了 CD-11 §8.1（本批次实测 7 个源 glb 全在
 *   16–26 MB、贴图 4096）。它不是资产目录，规则见该目录自己的 `.gitignore`
 *   与 [CD-51 §5.1](../../../Confirmed-docs/50-engineering/51-dev-environment.md)。
 *
 * **为什么必须在这里也跳过一层**：这些文件被 `.gitignore` 排除，所以 CI checkout
 * 拿不到它们、CI 永远绿；而开发机上有它们，于是同一份代码**本地红、CI 绿**。
 * 一个门禁如果只在其中一处成立，另一处的人就会开始无视它。这里要卡的是「准备
 * 入库的资产」，不是「还没烘焙的原料」。
 *
 * 补一句：**仍然可以显式指定**。`npm run asset-budget <file>` 走的是调用方给的
 * 路径，不经过本文件的遍历，所以想单独查一个源产物查得到，不会被这层藏起来。
 */
const SKIPPED_DIRECTORIES = new Set(["addons", "_source_refs", ".godot", "node_modules"]);

/**
 * Godot 的目录忽略标记。
 *
 * 与 `SKIPPED_DIRECTORIES` 不是重复：那边是**命名约定**（目录叫什么），这边是
 * **目录自己声明的**（里面放了 `.gdignore`）。认这个标记是为了让门禁与 Godot
 * 导入器看成同一份目录树——一个说"别导入"、另一个说"超预算"，是同一个目录在
 * 两套规则下给出两个答案。
 *
 * **它是递归的，这是实测结论不是推断**（Godot 4.7.2，2026-09-01）：一个一次性
 * 工程里 `ignored/` 放了 `.gdignore`，`ignored/child/nested.glb` **也没有**被导入
 * （只为 `kept/found.glb` 生成了 `.import`）。所以这里整棵子树剪掉，与引擎一致。
 * 别照".gdignore 只作用于那一层"的印象改回逐层判定。
 */
const GODOT_IGNORE_FILE = ".gdignore";

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
			// 整棵子树剪掉：Godot 的 .gdignore 是递归的（实测，见 GODOT_IGNORE_FILE）。
			if (existsSync(join(path, GODOT_IGNORE_FILE))) {
				continue;
			}
			walk(path, found);
			continue;
		}
		if (entry.toLowerCase().endsWith(ASSET_EXTENSION)) {
			found.push(path);
		}
	}
}
