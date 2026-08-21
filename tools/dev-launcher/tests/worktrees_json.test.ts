import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

describe(".cursor/worktrees.json", () => {
	it("defines both OS setup keys pointing at the shared Node script", () => {
		const parsed: unknown = JSON.parse(readFileSync(join(REPO_ROOT, ".cursor/worktrees.json"), "utf8"));
		assert.ok(parsed !== null && typeof parsed === "object");
		const config = parsed as { readonly [key: string]: unknown };
		assert.deepEqual(config["setup-worktree-windows"], ["node tools/dev-launcher/src/setup_worktree.ts"]);
		assert.deepEqual(config["setup-worktree-unix"], ["node tools/dev-launcher/src/setup_worktree.ts"]);
	});
});
