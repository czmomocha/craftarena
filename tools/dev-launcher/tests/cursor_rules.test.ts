import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const PLAN = "docs/plans/course-correction-2026-08.md";
const FREEZE_RULE = ".cursor/rules/course-correction-freeze.mdc";
const GRANULARITY_RULE = ".cursor/rules/chapter-granularity-and-review.mdc";

function read(relative: string): string {
	return readFileSync(join(REPO_ROOT, relative), "utf8").replaceAll("\r\n", "\n");
}

/**
 * A new Agent session only sees `.cursor/rules/`, never the plan document. Any
 * list that lives in both places has to be compared, not eyeballed.
 */
function fencedBlockContaining(source: string, needle: string, label: string): string {
	const blocks = source.match(/```[\w-]*\n[\s\S]*?```/g) ?? [];
	const hit = blocks.find((block) => block.includes(needle));
	assert.ok(hit !== undefined, `${label}: no fenced block contains ${needle}`);
	return hit.replace(/```[\w-]*\n/, "").replace(/```$/, "").trim();
}

describe(".cursor/rules course-correction freeze", () => {
	it("applies to every session without reading the plan", () => {
		const source = read(FREEZE_RULE);
		assert.match(source, /^alwaysApply: true$/m);
		assert.match(source, /E1[–-]E14/);
		assert.match(source, /freeze-exception/);
		assert.equal(existsSync(join(REPO_ROOT, PLAN)), true);
	});

	it("names every frozen work item so a fresh session cannot start one", () => {
		const source = read(FREEZE_RULE);
		for (const frozen of ["M4", "M6", "M7", "Rule VM", "BASTION"]) {
			assert.match(source, new RegExp(frozen.replaceAll(" ", "\\s")), frozen);
		}
	});

	it("keeps the placeholder constant list identical to the plan", () => {
		const inRule = fencedBlockContaining(read(FREEZE_RULE), "CAPSULE_RADIUS", FREEZE_RULE);
		const inPlan = fencedBlockContaining(read(PLAN), "CAPSULE_RADIUS", PLAN);
		assert.equal(inRule, inPlan);
		for (const name of ["STUB_HALF", "play_jump_dy", "SNAPSHOT_EVERY_TICKS", "OWN_ALBEDO", "Fixed.SCALE"]) {
			assert.ok(inRule.includes(name), name);
		}
	});

	it("keeps the two extra task-sheet lines identical to the plan", () => {
		const inRule = fencedBlockContaining(read(FREEZE_RULE), "纠偏归属", FREEZE_RULE);
		const inPlan = fencedBlockContaining(read(PLAN), "纠偏归属", PLAN);
		assert.equal(inRule, inPlan);
		assert.ok(inRule.includes("是否新增冻结常量引用"));
	});
});

describe(".cursor/rules chapter granularity", () => {
	it("applies to every session and carries the three review tiers", () => {
		const source = read(GRANULARITY_RULE);
		assert.match(source, /^alwaysApply: true$/m);
		for (const tier of ["深审", "常审", "轻审"]) {
			assert.ok(source.includes(tier), tier);
		}
	});

	it("states the 5x floor the human signed off and forbids new placeholder assertions", () => {
		const source = read(GRANULARITY_RULE);
		assert.match(source, /5\s*倍/);
		assert.match(source, /不再为占位表现新增强断言/);
	});
});
