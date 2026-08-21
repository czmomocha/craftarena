import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { CANONICAL_MAX_DEPTH, canonicalDepth, payloadExceedsCanonicalDepth } from "../src/canonical_depth.ts";

describe("canonical payload depth", () => {
	it("counts an empty payload object as depth 0 and a scalar field as depth 1", () => {
		assert.equal(canonicalDepth({}), 0);
		assert.equal(canonicalDepth({ intent: "MoveIntent" }), 1);
	});

	it("allows a scalar at MAX_DEPTH and rejects one step deeper", () => {
		let allowed: unknown = 1;
		for (let depth = 0; depth < CANONICAL_MAX_DEPTH; depth += 1) {
			allowed = { child: allowed };
		}
		assert.equal(payloadExceedsCanonicalDepth(allowed), false);

		let rejected: unknown = 1;
		for (let depth = 0; depth < CANONICAL_MAX_DEPTH + 1; depth += 1) {
			rejected = { child: rejected };
		}
		assert.equal(payloadExceedsCanonicalDepth(rejected), true);
	});
});
