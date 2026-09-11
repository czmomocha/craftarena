import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { resolveGodotExecutable } from "../src/godot.ts";
import { EMPTY_RUN_MESSAGE } from "../src/report.ts";
import { runBotRun, type SpawnResult } from "../src/run.ts";

function spawnOk(stdout: string): () => SpawnResult {
	return () => ({
		status: 0,
		stdout,
		stderr: "",
		error: undefined,
	});
}

describe("resolveGodotExecutable", () => {
	it("prefers GODOT4_CONSOLE on Windows", () => {
		const resolved = resolveGodotExecutable(
			{ GODOT4_CONSOLE: "C:\\godot\\godot.console.exe", GODOT4: "C:\\godot\\godot.exe" },
			"win32",
		);
		assert.equal(resolved.source, "GODOT4_CONSOLE");
		assert.equal(resolved.executable, "C:\\godot\\godot.console.exe");
	});

	it("does not fall back to PATH", () => {
		assert.throws(
			() => resolveGodotExecutable({}, "linux"),
			/GODOT4 must point/,
		);
	});
});

describe("runBotRun", () => {
	it("writes a report covering five official courses", () => {
		const courses = ["course_01", "course_02", "course_03", "course_04", "course_05"];
		const lines = courses.map((course, index) =>
			JSON.stringify({
				event: "bot_run_course",
				course,
				route: "any",
				outcome: "completable",
				reason: "",
				steps: index + 1,
				search_ticks: 10 * (index + 1),
				expansions: index,
				max_ticks: 3000,
				max_depth: 48,
			}),
		);
		lines.push(
			JSON.stringify({
				event: "bot_run_summary",
				ok: true,
				total: 5,
				completable: 5,
				not_completable: 0,
				route: "any",
				max_ticks: 3000,
				max_depth: 48,
				action_count: 11,
				wall_ms: 99,
			}),
		);
		const written: { path: string; contents: string }[] = [];
		const logs: string[] = [];
		const code = runBotRun({
			argv: ["--report=artifacts/bot-run-default.json"],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			spawn: spawnOk(`${lines.join("\n")}\n`),
			log: (line) => logs.push(line),
			logError: (line) => logs.push(line),
			writeFile: (path, contents) => {
				written.push({ path, contents });
			},
		});
		assert.equal(code, 0);
		assert.equal(written.length, 1);
		assert.match(written[0]?.path ?? "", /bot-run-default\.json$/);
		const report = JSON.parse(written[0]?.contents ?? "{}") as {
			ok: boolean;
			exit_code: number;
			courses: { course: string; completable: boolean; steps: number; search_ticks: number }[];
		};
		assert.equal(report.ok, true);
		assert.equal(report.exit_code, 0);
		assert.deepEqual(
			report.courses.map((course) => course.course),
			courses,
		);
		assert.equal(report.courses.every((course) => course.completable), true);
		assert.ok(logs.some((line) => line.includes("bot-runner: wrote")));
	});

	it("exits 1 and still writes the report when Godot prints nothing useful", () => {
		const written: { path: string; contents: string }[] = [];
		const errors: string[] = [];
		const code = runBotRun({
			argv: ["--report=out.json"],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			spawn: spawnOk("Godot Engine v4.7.2.stable\n"),
			log: () => {},
			logError: (line) => errors.push(line),
			writeFile: (path, contents) => {
				written.push({ path, contents });
			},
		});
		assert.equal(code, 1);
		assert.equal(written.length, 1);
		const report = JSON.parse(written[0]?.contents ?? "{}") as {
			ok: boolean;
			empty: boolean;
			exit_code: number;
		};
		assert.equal(report.empty, true);
		assert.equal(report.ok, false);
		assert.equal(report.exit_code, 1);
		assert.ok(errors.includes(EMPTY_RUN_MESSAGE));
	});

	it("does not spawn when --report is missing a path", () => {
		let spawned = false;
		const errors: string[] = [];
		const code = runBotRun({
			argv: ["--report"],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			spawn: () => {
				spawned = true;
				return { status: 0, stdout: "", stderr: "", error: undefined };
			},
			log: () => {},
			logError: (line) => errors.push(line),
		});
		assert.equal(code, 1);
		assert.equal(spawned, false);
		assert.match(errors[0] ?? "", /--report=/);
	});

	it("forwards Godot's exit 1 for an unknown course", () => {
		const stdout = `${JSON.stringify({
			event: "bot_run_error",
			error: "unknown_course",
			detail: "res://secret.json",
		})}\n`;
		const code = runBotRun({
			argv: ["--course=res://secret.json"],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			spawn: () => ({ status: 1, stdout, stderr: "", error: undefined }),
			log: () => {},
			logError: () => {},
		});
		assert.equal(code, 1);
	});
});
