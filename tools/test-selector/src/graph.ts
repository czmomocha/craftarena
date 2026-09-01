import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, posix, relative, sep } from "node:path";

import { SCAN_ROOTS } from "./paths.ts";

/** 一个 `.gd` 文件在依赖图里的样子。路径一律是仓库相对、正斜杠。 */
export interface ScriptNode {
	/** 仓库相对路径，例如 `game/tests/unit/test_fixed.gd`。 */
	readonly path: string;
	/** Godot 资源路径，例如 `res://tests/unit/test_fixed.gd`。 */
	readonly resPath: string;
	/** 本文件里出现过的、能解析成仓库内文件的 `res://` 引用。 */
	readonly deps: readonly string[];
	/**
	 * 本文件里有无法静态判定的 `preload(` / `load(` 实参。
	 *
	 * 这类文件的依赖是**不完整**的，所以依赖它的测试一律当作「永远受影响」，
	 * 而不是假装图是全的。这是本工具唯一诚实的处理方式。
	 */
	readonly dynamic: boolean;
}

export interface DependencyGraph {
	/** 仓库相对路径 → 节点。 */
	readonly nodes: ReadonlyMap<string, ScriptNode>;
	/** `res://` 路径 → 仓库相对路径。只收录真实存在的文件。 */
	readonly byResPath: ReadonlyMap<string, string>;
}

const RES_LITERAL = /res:\/\/[A-Za-z0-9_\-./]+/g;
/** `preload(` 或 `load(` 后面第一个非空白字符不是引号，就是动态实参。 */
const DYNAMIC_LOAD = /(?<![A-Za-z0-9_])(?:pre)?load\s*\(\s*(?!["'])/;

export function buildGraph(repoRoot: string): DependencyGraph {
	const files: string[] = [];
	for (const root of SCAN_ROOTS) {
		collectGdFiles(join(repoRoot, root), repoRoot, files);
	}

	const byResPath = new Map<string, string>();
	for (const path of files) {
		byResPath.set(toResPath(path), path);
	}

	const nodes = new Map<string, ScriptNode>();
	for (const path of files) {
		const text = readFileSync(join(repoRoot, path), "utf8");
		const deps: string[] = [];
		for (const match of text.matchAll(RES_LITERAL)) {
			const target = byResPath.get(match[0]);
			if (target !== undefined && target !== path && !deps.includes(target)) {
				deps.push(target);
			}
		}
		nodes.set(path, {
			path,
			resPath: toResPath(path),
			deps,
			dynamic: DYNAMIC_LOAD.test(text),
		});
	}

	return { nodes, byResPath };
}

/**
 * 反向可达：给定一组改动文件，算出所有（传递地）依赖它们的脚本。
 * 返回集合**包含**改动文件自身，因为改一个测试脚本当然要跑它。
 */
export function dependentsOf(
	graph: DependencyGraph,
	changed: readonly string[],
): ReadonlySet<string> {
	const reverse = new Map<string, string[]>();
	for (const node of graph.nodes.values()) {
		for (const dep of node.deps) {
			const list = reverse.get(dep);
			if (list === undefined) {
				reverse.set(dep, [node.path]);
			} else {
				list.push(node.path);
			}
		}
	}

	const seen = new Set<string>();
	const queue = changed.filter((path) => graph.nodes.has(path));
	for (const path of queue) {
		seen.add(path);
	}
	while (queue.length > 0) {
		const current = queue.pop();
		if (current === undefined) {
			break;
		}
		for (const dependent of reverse.get(current) ?? []) {
			if (!seen.has(dependent)) {
				seen.add(dependent);
				queue.push(dependent);
			}
		}
	}
	return seen;
}

/**
 * 依赖链上碰到过 `dynamic` 文件的脚本。
 *
 * 它们的依赖图不完整，所以无论改了什么都要跑——否则本工具就是在用一张自己
 * 都知道有洞的图去声称「这些测试不受影响」。
 */
export function dynamicTainted(graph: DependencyGraph): ReadonlySet<string> {
	const tainted = new Set<string>();
	const resolving = new Set<string>();

	const visit = (path: string): boolean => {
		if (tainted.has(path)) {
			return true;
		}
		if (resolving.has(path)) {
			return false;
		}
		const node = graph.nodes.get(path);
		if (node === undefined) {
			return false;
		}
		resolving.add(path);
		let hit = node.dynamic;
		for (const dep of node.deps) {
			if (visit(dep)) {
				hit = true;
			}
		}
		resolving.delete(path);
		if (hit) {
			tainted.add(path);
		}
		return hit;
	};

	for (const path of graph.nodes.keys()) {
		visit(path);
	}
	return tainted;
}

export function toResPath(repoRelative: string): string {
	return `res://${repoRelative.slice("game/".length)}`;
}

function collectGdFiles(dir: string, repoRoot: string, out: string[]): void {
	let entries: readonly string[];
	try {
		entries = readdirSync(dir);
	} catch {
		return;
	}
	for (const entry of entries) {
		const full = join(dir, entry);
		if (statSync(full).isDirectory()) {
			collectGdFiles(full, repoRoot, out);
			continue;
		}
		if (entry.endsWith(".gd")) {
			out.push(relative(repoRoot, full).split(sep).join(posix.sep));
		}
	}
}
