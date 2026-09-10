import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	plazaDisplayName,
	plazaTagsFromBundle,
	readPlazaTags,
	isPlazaTab,
	isPlazaStars,
} from "../src/content_plaza.ts";

describe("content plaza naming and tags", () => {
	test("display names are deterministic word-bank tokens", () => {
		assert.equal(plazaDisplayName("ugc_pipe_01"), plazaDisplayName("ugc_pipe_01"));
		assert.match(plazaDisplayName("ugc_pipe_01"), /^[a-z]+_[a-z]+$/);
		assert.notEqual(plazaDisplayName("ugc_pipe_01"), plazaDisplayName("ugc_pipe_02"));
	});

	test("tags come from non-empty occupancy bags and ignore unknown keys", () => {
		assert.deepEqual(
			plazaTagsFromBundle({
				portals: [{ entity_id: 1 }],
				hazards: [],
				destructibles: [{ entity_id: 2 }],
				title: "free text must not become a tag",
			}),
			["portal", "crate"],
		);
		assert.deepEqual(plazaTagsFromBundle({}), []);
	});

	test("rating tags reject duplicates and unknown ids", () => {
		assert.deepEqual(readPlazaTags(["ice", "portal"]), ["ice", "portal"]);
		assert.equal(readPlazaTags(["ice", "ice"]), undefined);
		assert.equal(readPlazaTags(["free_text"]), undefined);
		assert.equal(readPlazaTags("ice"), undefined);
	});

	test("tab and stars guards", () => {
		assert.equal(isPlazaTab("newest"), true);
		assert.equal(isPlazaTab("popular"), false);
		assert.equal(isPlazaStars(5), true);
		assert.equal(isPlazaStars(0), false);
		assert.equal(isPlazaStars(1.5), false);
	});
});
