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

describe("CODEOWNERS", () => {
	it("marks the four ADR-0004 contract paths", () => {
		const source = readFileSync(join(REPO_ROOT, ".github/CODEOWNERS"), "utf8");
		for (const path of REQUIRED_PATHS) {
			const escaped = path.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
			assert.match(source, new RegExp(`^${escaped}\\s+@\\S+`, "m"), path);
		}
	});
});
