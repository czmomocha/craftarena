import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";

import { prepareLine } from "./prepare_line.ts";
import {
	CORE_SRC_DIRS,
	GODOT3_IDENTIFIERS,
	RULE_ID,
	SCENE_TREE_IDENTIFIERS,
	type RuleId,
} from "./rules.ts";

export type Finding = {
	readonly ruleId: RuleId;
	readonly article: string;
	readonly path: string;
	readonly line: number;
	readonly excerpt: string;
	readonly message: string;
};

const SKIP_DIR_NAMES = new Set([".git", ".godot", "node_modules", "addons"]);

const FLOAT_TYPE = /\bfloat\b/;
const FLOAT_LITERAL = /\b\d+\.\d+([eE][+-]?\d+)?\b|\b\.\d+\b/;
const GODOT3_CALLS: readonly { readonly pattern: RegExp; readonly label: string }[] = [
	{ pattern: /\byield\s*\(/, label: "yield(" },
	{ pattern: /\bfuncref\s*\(/, label: "funcref(" },
	{ pattern: /\bEngine\.editor_hint\b/, label: "Engine.editor_hint" },
	{ pattern: /\bmove_and_slide_with_snap\b/, label: "move_and_slide_with_snap" },
	{ pattern: /\bonready\s+var\b/, label: "onready var" },
	{ pattern: /\bexport\s*\(/, label: "export(" },
	{ pattern: /\bsetget\b/, label: "setget" },
	{ pattern: /^\s*tool\b/, label: "tool" },
];

export function scanRepo(repoRoot: string): Finding[] {
	const findings: Finding[] = [];
	findings.push(...scanSimulationGd(repoRoot));
	findings.push(...scanCoreGdextension(repoRoot));
	findings.push(...scanGodot3Api(repoRoot));
	findings.push(...scanDotnetFiles(repoRoot));
	return findings;
}

function scanSimulationGd(repoRoot: string): Finding[] {
	const findings: Finding[] = [];
	for (const file of listFiles(join(repoRoot, "game/src/simulation"), [".gd"])) {
		const rel = toPosix(relative(repoRoot, file));
		for (const hit of scanGdLines(file)) {
			if (hit.allows.has(RULE_ID.simulationNoSceneTree) === false) {
				const token = firstIdentifier(hit.code, SCENE_TREE_IDENTIFIERS);
				if (token !== undefined) {
					findings.push(
						finding(
							RULE_ID.simulationNoSceneTree,
							"5",
							rel,
							hit.line,
							hit.excerpt,
							`simulation must not use SceneTree token ${token}`,
						),
					);
				}
			}
			if (hit.allows.has(RULE_ID.simulationNoFloat) === false && hit.allows.has("float") === false) {
				if (FLOAT_TYPE.test(hit.code) || FLOAT_LITERAL.test(hit.code)) {
					findings.push(
						finding(
							RULE_ID.simulationNoFloat,
							"5",
							rel,
							hit.line,
							hit.excerpt,
							"simulation must not use float types or float literals",
						),
					);
				}
			}
		}
	}
	return findings;
}

function scanCoreGdextension(repoRoot: string): Finding[] {
	const findings: Finding[] = [];
	for (const dirName of CORE_SRC_DIRS) {
		const root = join(repoRoot, "game/src", dirName);
		for (const file of listFiles(root, undefined)) {
			const rel = toPosix(relative(repoRoot, file));
			if (extname(file).toLowerCase() === ".gdextension") {
				findings.push(
					finding(RULE_ID.coreNoGdextension, "7", rel, 1, rel, "shared core must not contain a .gdextension file"),
				);
				continue;
			}
			if (!isTextFile(file)) {
				continue;
			}
			for (const hit of scanTextLines(file)) {
				if (hit.allows.has(RULE_ID.coreNoGdextension)) {
					continue;
				}
				if (hit.code.includes(".gdextension")) {
					findings.push(
						finding(
							RULE_ID.coreNoGdextension,
							"7",
							rel,
							hit.line,
							hit.excerpt,
							"shared core must not reference .gdextension",
						),
					);
				}
			}
		}
	}
	return findings;
}

function scanGodot3Api(repoRoot: string): Finding[] {
	const findings: Finding[] = [];
	for (const file of listFiles(join(repoRoot, "game/src"), [".gd"])) {
		const rel = toPosix(relative(repoRoot, file));
		for (const hit of scanGdLines(file)) {
			if (hit.allows.has(RULE_ID.noGodot3Api)) {
				continue;
			}
			const token = firstIdentifier(hit.code, GODOT3_IDENTIFIERS);
			if (token !== undefined) {
				findings.push(
					finding(RULE_ID.noGodot3Api, "11", rel, hit.line, hit.excerpt, `Godot 3 identifier ${token}`),
				);
				continue;
			}
			for (const call of GODOT3_CALLS) {
				if (call.pattern.test(hit.code)) {
					findings.push(
						finding(RULE_ID.noGodot3Api, "11", rel, hit.line, hit.excerpt, `Godot 3 API ${call.label}`),
					);
					break;
				}
			}
		}
	}
	return findings;
}

function scanDotnetFiles(repoRoot: string): Finding[] {
	const findings: Finding[] = [];
	const forbidden = new Set([".cs", ".csproj", ".sln"]);
	for (const file of listFiles(join(repoRoot, "game"), undefined)) {
		const extension = extname(file).toLowerCase();
		if (!forbidden.has(extension)) {
			continue;
		}
		const rel = toPosix(relative(repoRoot, file));
		findings.push(finding(RULE_ID.noDotnet, "7", rel, 1, rel, "C# / .NET project files are forbidden"));
	}
	return findings;
}

type LineHit = {
	readonly line: number;
	readonly excerpt: string;
	readonly code: string;
	readonly allows: ReadonlySet<string>;
};

function scanGdLines(file: string): LineHit[] {
	return readFileSync(file, "utf8")
		.split(/\r?\n/)
		.map((excerpt, index) => {
			const prepared = prepareLine(excerpt);
			return {
				line: index + 1,
				excerpt: excerpt.trim(),
				code: prepared.code,
				allows: prepared.allows,
			};
		});
}

function scanTextLines(file: string): LineHit[] {
	return scanGdLines(file);
}

function listFiles(directory: string, extensions: readonly string[] | undefined): string[] {
	const files: string[] = [];
	walk(directory, files);
	if (extensions === undefined) {
		return files;
	}
	const allowed = new Set(extensions.map((item) => item.toLowerCase()));
	return files.filter((file) => allowed.has(extname(file).toLowerCase()));
}

function walk(directory: string, files: string[]): void {
	if (!existsSync(directory)) {
		return;
	}
	for (const name of readdirSync(directory)) {
		if (SKIP_DIR_NAMES.has(name)) {
			continue;
		}
		const full = join(directory, name);
		const stats = statSync(full);
		if (stats.isDirectory()) {
			walk(full, files);
			continue;
		}
		if (stats.isFile()) {
			files.push(full);
		}
	}
}

function firstIdentifier(code: string, names: readonly string[]): string | undefined {
	for (const name of names) {
		if (identifierPattern(name).test(code)) {
			return name;
		}
	}
	return undefined;
}

function identifierPattern(name: string): RegExp {
	const escaped = name.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
	return new RegExp(`(?<![A-Za-z0-9_])${escaped}(?![A-Za-z0-9_])`);
}

function isTextFile(file: string): boolean {
	const extension = extname(file).toLowerCase();
	return extension === ".gd" || extension === ".txt" || extension === ".md" || extension === ".json" || extension === "";
}

function toPosix(path: string): string {
	return path.replaceAll("\\", "/");
}

function finding(
	ruleId: RuleId,
	article: string,
	path: string,
	line: number,
	excerpt: string,
	message: string,
): Finding {
	return { ruleId, article, path, line, excerpt, message };
}
