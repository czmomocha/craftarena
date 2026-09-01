import { buildGraph, dependentsOf, dynamicTainted, toResPath } from "./graph.ts";
import type { DependencyGraph } from "./graph.ts";

export type Selection =
	| { readonly kind: "full"; readonly reason: string }
	| { readonly kind: "none"; readonly reason: string }
	| {
			readonly kind: "subset";
			readonly reason: string;
			/** `res://` 路径，已排序，可直接拼进 `-gtest=`。 */
			readonly scripts: readonly string[];
	  };

/** fast 层测试脚本所在目录，与 `paths.ts` 的 `FAST_TIER_DIRS` 对应。 */
const FAST_TIER_PREFIXES = [
	"game/tests/unit/",
	"game/tests/integration/",
	"game/tests/replay/",
] as const;

/**
 * 命中即退回全量的路径。
 *
 * 本工具只服务本地循环，**从不是门禁**（CI 每次 PR 仍跑四个目录全量），所以取舍
 * 一律偏向多跑：算错方向如果是「少跑」，代价是把一个本可以在提交前发现的失败推到
 * CI 上；算错方向如果是「多跑」，代价只是十几秒。
 */
const ALWAYS_FULL_PREFIXES = [
	// 共享测试夹具：图能算对，但它一变就是成片测试跟着变，没必要精算。
	"game/tests/support/",
	// GUT 自身与第三方插件：不在扫描范围内，图里根本没有它们的边。
	"game/addons/",
] as const;

/**
 * `game/` 下引擎压根不读的文件，改了也不可能挪动任何 GDScript 行为。
 *
 * 名单**故意很短**，只收「Godot 不读」这一条能一句话说清的：说明文档和 Git 自己
 * 的排除规则。`.gdignore` 不在其中——它决定编辑器导不导入某个目录，是会改变
 * 运行结果的。`.import` 也不在其中，它决定资源怎么被导入。
 */
const INERT_SUFFIXES = [".md", "/.gitignore"] as const;

export function selectAffected(
	repoRoot: string,
	changedPaths: readonly string[],
	graph: DependencyGraph = buildGraph(repoRoot),
): Selection {
	const gameChanges = changedPaths.filter(
		(path) =>
			path.startsWith("game/") &&
			!INERT_SUFFIXES.some((suffix) => path.endsWith(suffix)),
	);
	if (gameChanges.length === 0) {
		return {
			kind: "none",
			reason: "no files under game/ changed; GDScript behaviour cannot have moved",
		};
	}

	for (const path of gameChanges) {
		const forced = ALWAYS_FULL_PREFIXES.find((prefix) => path.startsWith(prefix));
		if (forced !== undefined) {
			return { kind: "full", reason: `${path} is under ${forced}` };
		}
		if (!path.endsWith(".gd")) {
			return {
				kind: "full",
				reason: `${path} is not a .gd file; content, imports and project settings are not in the graph`,
			};
		}
		if (!graph.nodes.has(path)) {
			return {
				kind: "full",
				reason: `${path} is not in the dependency graph (deleted, renamed, or outside the scan roots)`,
			};
		}
	}

	const affected = dependentsOf(graph, gameChanges);
	const tainted = dynamicTainted(graph);
	const scripts = new Set<string>();
	for (const path of [...affected, ...tainted]) {
		if (isFastTierTest(path)) {
			scripts.add(toResPath(path));
		}
	}

	if (scripts.size === 0) {
		return {
			kind: "none",
			reason: `${gameChanges.length} changed script(s) reach no fast-tier test`,
		};
	}
	return {
		kind: "subset",
		reason: `${gameChanges.length} changed script(s); ${tainted.size} script(s) carry an unresolvable load and always run`,
		scripts: [...scripts].sort(),
	};
}

function isFastTierTest(path: string): boolean {
	if (!path.endsWith(".gd")) {
		return false;
	}
	const prefix = FAST_TIER_PREFIXES.find((candidate) => path.startsWith(candidate));
	if (prefix === undefined) {
		return false;
	}
	return path.slice(prefix.length).startsWith("test_");
}
