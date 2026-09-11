import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { parseBotRunStdout } from "../src/parse.ts";

const COURSE = JSON.stringify({
	event: "bot_run_course",
	course: "course_01",
	route: "any",
	outcome: "completable",
	reason: "",
	steps: 5,
	search_ticks: 40,
	expansions: 8,
	max_ticks: 3000,
	max_depth: 48,
	action_count: 11,
	wall_ms: 12,
});

const SUMMARY = JSON.stringify({
	event: "bot_run_summary",
	ok: true,
	total: 1,
	completable: 1,
	not_completable: 0,
	route: "any",
	max_ticks: 3000,
	max_depth: 48,
	action_count: 11,
	wall_ms: 20,
});

describe("parseBotRunStdout", () => {
	it("keeps course and summary JSON and ignores the engine banner", () => {
		const parsed = parseBotRunStdout(
			`Godot Engine v4.7.2.stable\n${COURSE}\n${SUMMARY}\n`,
		);
		assert.equal(parsed.courses.length, 1);
		assert.equal(parsed.courses[0]?.course, "course_01");
		assert.equal(parsed.courses[0]?.steps, 5);
		assert.equal(parsed.courses[0]?.search_ticks, 40);
		assert.equal(parsed.summary?.ok, true);
		assert.equal(parsed.error, null);
	});

	it("reads a CLI error line without inventing a course", () => {
		const parsed = parseBotRunStdout(
			`${JSON.stringify({ event: "bot_run_error", error: "unknown_course", detail: "course_99" })}\n`,
		);
		assert.deepEqual(parsed.courses, []);
		assert.equal(parsed.summary, null);
		assert.equal(parsed.error?.error, "unknown_course");
		assert.equal(parsed.error?.detail, "course_99");
	});

	it("treats banner-only stdout as empty", () => {
		const parsed = parseBotRunStdout("Godot Engine v4.7.2.stable\nWARNING: dummy\n");
		assert.deepEqual(parsed.courses, []);
		assert.equal(parsed.summary, null);
		assert.equal(parsed.error, null);
	});

	it("drops a malformed JSON line instead of failing closed on noise", () => {
		const parsed = parseBotRunStdout(`{not json\n${COURSE}\n`);
		assert.equal(parsed.courses.length, 1);
		assert.equal(parsed.courses[0]?.course, "course_01");
	});
});
