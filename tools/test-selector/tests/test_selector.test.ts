import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";

import { buildGraph, dynamicTainted } from "../src/graph.ts";
import { FIXTURES_DIR } from "../src/paths.ts";
import { selectAffected } from "../src/select.ts";
import { gutArgs, resolveGodotExecutable } from "../src/godot.ts";

const SAMPLE = join(FIXTURES_DIR, "sample");

test("a leaf change reaches every fast-tier test that depends on it", () => {
	const selection = selectAffected(SAMPLE, ["game/src/shared/fixed.gd"]);
	assert.equal(selection.kind, "subset");
	if (selection.kind !== "subset") {
		return;
	}
	assert.ok(selection.scripts.includes("res://tests/unit/test_fixed.gd"));
	// 传递依赖：fixed.gd -> world.gd -> test_world.gd
	assert.ok(selection.scripts.includes("res://tests/unit/test_world.gd"));
});

test("slow-tier scripts are never selected, even when they depend on the change", () => {
	const selection = selectAffected(SAMPLE, ["game/src/simulation/world.gd"]);
	assert.equal(selection.kind, "subset");
	if (selection.kind !== "subset") {
		return;
	}
	assert.ok(selection.scripts.includes("res://tests/unit/test_world.gd"));
	assert.ok(!selection.scripts.includes("res://tests/slow/test_slow_search.gd"));
});

test("a script behind an unresolvable load always runs", () => {
	// 改的是 fixed.gd，和 dynamic_only.gd 之间没有任何静态边。
	const selection = selectAffected(SAMPLE, ["game/src/shared/fixed.gd"]);
	assert.equal(selection.kind, "subset");
	if (selection.kind !== "subset") {
		return;
	}
	assert.ok(selection.scripts.includes("res://tests/unit/test_dynamic.gd"));
});

test("dynamic taint is computed from the load call, not the file name", () => {
	const tainted = dynamicTainted(buildGraph(SAMPLE));
	assert.ok(tainted.has("game/src/client/dynamic_only.gd"));
	assert.ok(tainted.has("game/tests/unit/test_dynamic.gd"));
	assert.ok(!tainted.has("game/tests/unit/test_fixed.gd"));
});

test("non-.gd changes under game/ fall back to the whole fast tier", () => {
	const selection = selectAffected(SAMPLE, ["game/content/official/course_01.json"]);
	assert.equal(selection.kind, "full");
});

test("shared test fixtures fall back to the whole fast tier", () => {
	const selection = selectAffected(SAMPLE, ["game/tests/support/helper.gd"]);
	assert.equal(selection.kind, "full");
});

test("addons fall back to the whole fast tier", () => {
	const selection = selectAffected(SAMPLE, ["game/addons/gut/gut.gd"]);
	assert.equal(selection.kind, "full");
});

test("a .gd path the graph has never seen falls back to the whole fast tier", () => {
	const selection = selectAffected(SAMPLE, ["game/src/shared/renamed_away.gd"]);
	assert.equal(selection.kind, "full");
});

test("documentation and gitignore under game/ do not force a full run", () => {
	const selection = selectAffected(SAMPLE, [
		"game/content/assets/_source_refs/.gitignore",
		"game/README.md",
	]);
	assert.equal(selection.kind, "none");
	// 但 .gdignore 会改变编辑器导入什么，仍然退回全量。
	const gdignore = selectAffected(SAMPLE, ["game/content/assets/_source_refs/.gdignore"]);
	assert.equal(gdignore.kind, "full");
});

test("changes outside game/ select nothing", () => {
	const selection = selectAffected(SAMPLE, [
		"backend/control-plane/src/main.ts",
		"docs/plans/whatever.md",
	]);
	assert.equal(selection.kind, "none");
});

test("the real repository graph resolves the probe cache into its callers", () => {
	const repoRoot = join(FIXTURES_DIR, "../../..");
	const selection = selectAffected(repoRoot, [
		"game/src/games/traprush/course_completion_probe.gd",
	]);
	// support/ 是 ALWAYS_FULL，但探针本身不是，所以这里必须算出一个真子集。
	assert.equal(selection.kind, "subset");
	if (selection.kind !== "subset") {
		return;
	}
	assert.ok(selection.scripts.includes("res://tests/unit/test_traprush_course_routes.gd"));
	assert.ok(!selection.scripts.includes("res://tests/slow/test_traprush_official_course_completability.gd"));
});

test("the engine path comes from the environment with no PATH fallback", () => {
	assert.deepEqual(resolveGodotExecutable({ GODOT4: "/opt/godot" }, "linux"), {
		executable: "/opt/godot",
		source: "GODOT4",
	});
	assert.deepEqual(
		resolveGodotExecutable({ GODOT4: "a.exe", GODOT4_CONSOLE: "b.exe" }, "win32"),
		{ executable: "b.exe", source: "GODOT4_CONSOLE" },
	);
	assert.throws(() => resolveGodotExecutable({}, "linux"), /GODOT4 must point at/);
	assert.throws(() => resolveGodotExecutable({ GODOT4: "  " }, "linux"), /must point at/);
});

test("gut arguments keep the headless GUT entry point", () => {
	const args = gutArgs("-gtest=res://tests/unit/test_fixed.gd");
	assert.deepEqual(args, [
		"--headless",
		"--path",
		"game",
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		"-gtest=res://tests/unit/test_fixed.gd",
		"-gexit",
	]);
});
