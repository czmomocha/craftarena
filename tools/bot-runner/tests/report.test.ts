import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { parseBotRunStdout } from "../src/parse.ts";
import { assembleReport, isEmptyRun } from "../src/report.ts";

const COURSE = {
	event: "bot_run_course",
	course: "course_04",
	route: "any",
	outcome: "completable",
	reason: "",
	steps: 9,
	search_ticks: 80,
	expansions: 14,
	max_ticks: 3000,
	max_depth: 48,
} as const;

const SUMMARY = {
	event: "bot_run_summary",
	ok: true,
	total: 1,
	completable: 1,
	not_completable: 0,
	route: "any",
	max_ticks: 3000,
	max_depth: 48,
	action_count: 11,
	wall_ms: 30,
} as const;

describe("assembleReport", () => {
	it("records completable, steps, search budget, and exit code", () => {
		const parsed = parseBotRunStdout(`${JSON.stringify(COURSE)}\n${JSON.stringify(SUMMARY)}\n`);
		const report = assembleReport(parsed, 0);
		assert.equal(report.empty, false);
		assert.equal(report.ok, true);
		assert.equal(report.exit_code, 0);
		assert.equal(report.courses.length, 1);
		assert.deepEqual(report.courses[0], {
			course: "course_04",
			route: "any",
			outcome: "completable",
			reason: "",
			completable: true,
			steps: 9,
			search_ticks: 80,
			expansions: 14,
			max_ticks: 3000,
			max_depth: 48,
		});
	});

	it("fills max_ticks from the summary when a course line omitted it", () => {
		const thin = {
			event: "bot_run_course",
			course: "course_01",
			route: "safe",
			outcome: "completable",
			reason: "",
			steps: 32,
			search_ticks: 400,
			expansions: 0,
		};
		const parsed = parseBotRunStdout(
			`${JSON.stringify(thin)}\n${JSON.stringify({ ...SUMMARY, route: "safe" })}\n`,
		);
		const report = assembleReport(parsed, 0);
		assert.equal(report.courses[0]?.max_ticks, 3000);
		assert.equal(report.courses[0]?.max_depth, 48);
		assert.equal(report.route, "safe");
	});

	it("marks an empty parse as not ok even if Godot exited 0", () => {
		const parsed = parseBotRunStdout("Godot Engine v4.7.2.stable\n");
		assert.equal(isEmptyRun(parsed), true);
		const report = assembleReport(parsed, 0);
		assert.equal(report.empty, true);
		assert.equal(report.ok, false);
		assert.equal(report.exit_code, 1);
		assert.deepEqual(report.courses, []);
	});

	it("keeps Godot's non-zero exit when a course is not completable", () => {
		const failed = {
			...COURSE,
			course: "course_03",
			outcome: "not_completable",
			reason: "budget_exhausted",
			steps: 48,
		};
		const parsed = parseBotRunStdout(
			`${JSON.stringify(failed)}\n${JSON.stringify({ ...SUMMARY, ok: false, completable: 0, not_completable: 1 })}\n`,
		);
		const report = assembleReport(parsed, 1);
		assert.equal(report.ok, false);
		assert.equal(report.exit_code, 1);
		assert.equal(report.courses[0]?.completable, false);
		assert.equal(report.courses[0]?.reason, "budget_exhausted");
	});
});
