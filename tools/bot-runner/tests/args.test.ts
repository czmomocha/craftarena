import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { formatArgsError, parseArgs } from "../src/args.ts";
import { botRunGodotArgs } from "../src/godot.ts";

describe("parseArgs", () => {
	it("forwards Godot flags and leaves report unset", () => {
		const parsed = parseArgs(["--course=course_01", "--route=safe"]);
		assert.deepEqual(parsed, {
			reportPath: null,
			godotUserArgs: ["--course=course_01", "--route=safe"],
		});
	});

	it("strips --report= so Godot never sees it", () => {
		const parsed = parseArgs([
			"--report=artifacts/bot-run.json",
			"--course=course_02",
		]);
		assert.deepEqual(parsed, {
			reportPath: "artifacts/bot-run.json",
			godotUserArgs: ["--course=course_02"],
		});
	});

	it("rejects --report without a path", () => {
		const parsed = parseArgs(["--report"]);
		assert.deepEqual(parsed, { error: "missing_report_path" });
		assert.match(formatArgsError({ error: "missing_report_path" }), /--report=/);
	});

	it("rejects an empty --report= path", () => {
		const parsed = parseArgs(["--report="]);
		assert.deepEqual(parsed, { error: "empty_report_path" });
		assert.match(formatArgsError({ error: "empty_report_path" }), /empty/);
	});
});

describe("botRunGodotArgs", () => {
	it("always injects --bot-run after the user-args separator", () => {
		assert.deepEqual(botRunGodotArgs(["--course=course_01"]), [
			"--headless",
			"--path",
			"game",
			"--",
			"--bot-run",
			"--course=course_01",
		]);
	});

	it("does not forward a duplicate --bot-run flag", () => {
		assert.deepEqual(botRunGodotArgs(["--bot-run", "--route=any"]), [
			"--headless",
			"--path",
			"game",
			"--",
			"--bot-run",
			"--route=any",
		]);
	});
});
