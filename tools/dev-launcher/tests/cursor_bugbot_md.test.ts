import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

describe(".cursor/BUGBOT.md", () => {
	it("points at CD-00 and does not claim to be a merge gate", () => {
		const source = readFileSync(join(REPO_ROOT, ".cursor/BUGBOT.md"), "utf8");
		assert.match(source, /Confirmed-docs\/00-constitution\/CONSTITUTION\.md/);
		assert.match(source, /AGENTS\.md/);
		assert.match(source, /not.*merge gate/i);
		assert.match(source, /game\/src\/simulation/);
		assert.match(source, /SceneTree/);
		assert.match(source, /float/);
		assert.match(source, /\.gdextension/);
		assert.match(source, /\.cs/);
		assert.equal(existsSync(join(REPO_ROOT, "Confirmed-docs/00-constitution/CONSTITUTION.md")), true);
		assert.equal(existsSync(join(REPO_ROOT, "AGENTS.md")), true);
		assert.ok(source.length < 30_000);
	});
});
