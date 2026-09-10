import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	isAccountPassword,
	isAccountUsername,
	isGuestId,
	isRecoveryKey,
} from "../src/account.ts";

describe("account contract guards", () => {
	test("usernames are public ids, not free prose", () => {
		assert.equal(isAccountUsername("warm_forge"), true);
		assert.equal(isAccountUsername("ab"), false);
		assert.equal(isAccountUsername("has space"), false);
		assert.equal(isAccountUsername("bad!"), false);
	});

	test("passwords are length-bounded with no composition rules", () => {
		assert.equal(isAccountPassword("password"), true);
		assert.equal(isAccountPassword("short"), false);
		assert.equal(isAccountPassword("x".repeat(65)), false);
	});

	test("guest ids and recovery keys stay in the documented charset", () => {
		assert.equal(isGuestId("gst_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), true);
		assert.equal(isGuestId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), false);
		assert.equal(isRecoveryKey("a".repeat(32)), true);
		assert.equal(isRecoveryKey("a".repeat(31)), false);
		assert.equal(isRecoveryKey("not valid spaces 32chars_______"), false);
	});
});
