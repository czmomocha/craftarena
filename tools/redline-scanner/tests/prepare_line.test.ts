import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { prepareLine } from "../src/prepare_line.ts";

describe("prepareLine", () => {
	it("keeps code and reads a redline-allow pragma", () => {
		const prepared = prepareLine('var preview: float = 1.5 # redline-allow: float, simulation-no-float');
		assert.equal(prepared.code.includes("float"), true);
		assert.equal(prepared.allows.has("float"), true);
		assert.equal(prepared.allows.has("simulation-no-float"), true);
	});

	it("drops comments and quoted strings so mentions are not hits", () => {
		const prepared = prepareLine('print("Node") # do not use SceneTree');
		assert.equal(prepared.code.includes("Node"), false);
		assert.equal(prepared.code.includes("SceneTree"), false);
		assert.equal(prepared.code.includes("print"), true);
	});
});
