import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const E9_LINE_CAP = 400;

function walk(dir: string, keep: (name: string, full: string) => boolean): string[] {
	const out: string[] = [];
	for (const name of readdirSync(dir)) {
		const full = join(dir, name);
		if (statSync(full).isDirectory()) {
			out.push(...walk(full, keep));
			continue;
		}
		if (keep(name, full)) {
			out.push(relative(REPO_ROOT, full).replaceAll("\\", "/"));
		}
	}
	return out.sort();
}

function lineCount(relativePath: string): number {
	const text = readFileSync(join(REPO_ROOT, relativePath), "utf8");
	return text.split("\n").length;
}

function overCap(files: string[]): string[] {
	return files.filter((path) => lineCount(path) >= E9_LINE_CAP);
}

describe("C5 E9 production line cap", () => {
	it("keeps every game/src GDScript file under 400 lines", () => {
		const files = walk(join(REPO_ROOT, "game/src"), (name) => name.endsWith(".gd"));
		assert.ok(files.length >= 80, `expected the production src tree, got ${files.length}`);
		assert.deepEqual(
			overCap(files),
			[],
			`E9 cap is ${E9_LINE_CAP} including blanks`,
		);
	});

	it("keeps every backend production TypeScript file under 400 lines", () => {
		const files = walk(join(REPO_ROOT, "backend"), (name, full) => {
			if (!name.endsWith(".ts")) {
				return false;
			}
			const rel = relative(REPO_ROOT, full).replaceAll("\\", "/");
			if (rel.includes("/tests/") || name.endsWith(".test.ts")) {
				return false;
			}
			return true;
		});
		assert.ok(files.length >= 20, `expected backend production sources, got ${files.length}`);
		assert.deepEqual(
			overCap(files),
			[],
			`E9 cap is ${E9_LINE_CAP} including blanks`,
		);
	});
});
