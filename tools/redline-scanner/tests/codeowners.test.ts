import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { REPO_ROOT } from "../src/paths.ts";

const REQUIRED_PATHS = [
	"/game/src/shared/",
	"/backend/contracts/",
	"/Confirmed-docs/",
	"/.github/",
] as const;

// Course correction C0. Audit finding 8.4: the drift landed exactly in the
// directories ownership did not cover.
const COURSE_CORRECTION_PATHS = [
	"/game/src/client/",
	"/game/src/games/",
	"/.cursor/rules/",
] as const;

function assertOwned(source: string, path: string): void {
	const escaped = path.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
	assert.match(source, new RegExp(`^${escaped}\\s+@\\S+`, "m"), path);
}

describe("CODEOWNERS", () => {
	it("marks the four ADR-0004 contract paths", () => {
		const source = readFileSync(join(REPO_ROOT, ".github/CODEOWNERS"), "utf8");
		for (const path of REQUIRED_PATHS) {
			assertOwned(source, path);
		}
	});

	it("covers the client, games, and rules blind spots", () => {
		const source = readFileSync(join(REPO_ROOT, ".github/CODEOWNERS"), "utf8");
		for (const path of COURSE_CORRECTION_PATHS) {
			assertOwned(source, path);
		}
	});
});
