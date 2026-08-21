import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const AGENTS_DIR = join(REPO_ROOT, ".cursor/agents");
const ALLOWED_KEYS = ["name", "description", "model", "readonly", "is_background"] as const;
const EXPECTED_NAMES = ["architecture", "gameplay", "editor", "networking", "testing", "assets"] as const;
const FORBIDDEN_NAMES = ["review", "reviewer", "auditor", "bugbot"] as const;

describe(".cursor/agents", () => {
	it("defines the six CD-52 roles and no review agent", () => {
		const files = readdirSync(AGENTS_DIR)
			.filter((name) => name.endsWith(".md"))
			.sort();
		assert.deepEqual(
			files,
			[...EXPECTED_NAMES].sort().map((name) => `${name}.md`),
		);
		for (const forbidden of FORBIDDEN_NAMES) {
			assert.equal(files.includes(`${forbidden}.md`), false);
		}
	});

	it("uses only the five documented frontmatter fields", () => {
		for (const name of EXPECTED_NAMES) {
			const source = readFileSync(join(AGENTS_DIR, `${name}.md`), "utf8");
			const fields = parseFrontmatter(source);
			assert.deepEqual([...fields.keys()].sort(), [...ALLOWED_KEYS].sort());
			assert.equal(fields.get("name"), name);
			assert.equal(fields.get("model"), "inherit");
			assert.equal(fields.get("readonly"), "false");
			assert.equal(fields.get("is_background"), "false");
			assert.ok((fields.get("description") ?? "").length > 0);
			assert.match(source, /worktree/i);
			assert.match(source, /Bugbot/);
		}
	});
});

function parseFrontmatter(source: string): Map<string, string> {
	const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(source);
	assert.ok(match !== null, "missing YAML frontmatter");
	const fields = new Map<string, string>();
	for (const line of (match[1] ?? "").split(/\r?\n/)) {
		if (line.trim() === "") {
			continue;
		}
		const separator = line.indexOf(":");
		assert.ok(separator > 0, `invalid frontmatter line: ${line}`);
		fields.set(line.slice(0, separator).trim(), line.slice(separator + 1).trim());
	}
	return fields;
}
