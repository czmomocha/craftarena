import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

describe(".cursor/hooks.json", () => {
	it("enables failClosed beforeShellExecution for git commands", () => {
		const parsed: unknown = JSON.parse(readFileSync(join(REPO_ROOT, ".cursor/hooks.json"), "utf8"));
		assert.ok(parsed !== null && typeof parsed === "object");
		const root = parsed as { readonly version?: unknown; readonly hooks?: unknown };
		assert.equal(root.version, 1);
		assert.ok(root.hooks !== null && typeof root.hooks === "object");
		const hooks = root.hooks as { readonly beforeShellExecution?: unknown };
		assert.ok(Array.isArray(hooks.beforeShellExecution));
		const first = hooks.beforeShellExecution[0] as {
			readonly command?: unknown;
			readonly failClosed?: unknown;
			readonly matcher?: unknown;
		};
		assert.equal(first.command, "node tools/shell-guard/src/main.ts");
		assert.equal(first.failClosed, true);
		assert.equal(first.matcher, "git");
	});
});
