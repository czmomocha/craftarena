import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	CONTENT_SUBMIT_ERRORS,
	contentSubmitBodySchema,
} from "../src/content_submit.ts";

describe("content submit contract", () => {
	test("player body is only bundle plus content_hash", () => {
		assert.deepEqual(contentSubmitBodySchema.required, ["bundle", "content_hash"]);
		assert.equal(contentSubmitBodySchema.additionalProperties, false);
		assert.equal("signature" in contentSubmitBodySchema.properties, false);
		assert.equal("version" in contentSubmitBodySchema.properties, false);
		assert.equal("content_id" in contentSubmitBodySchema.properties, false);
		assert.equal(CONTENT_SUBMIT_ERRORS.hashInvalid, "hash_invalid");
		assert.equal(CONTENT_SUBMIT_ERRORS.sessionInvalid, "session_invalid");
	});
});
