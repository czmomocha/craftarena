import assert from "node:assert/strict";
import { join } from "node:path";
import { describe, it } from "node:test";

import { FIXTURES_DIR, REPO_ROOT } from "../src/paths.ts";
import { RULE_ID } from "../src/rules.ts";
import { scanRepo, type Finding } from "../src/scan.ts";

describe("redline fixtures", () => {
	it("accepts a clean tree including an explicit float exemption", () => {
		assert.deepEqual(scanRepo(join(FIXTURES_DIR, "clean")), []);
	});

	it("reports each constitution rule against the dirty tree", () => {
		const findings = scanRepo(join(FIXTURES_DIR, "dirty"));
		const ids = new Set(findings.map((finding) => finding.ruleId));
		assert.equal(ids.has(RULE_ID.simulationNoSceneTree), true);
		assert.equal(ids.has(RULE_ID.simulationNoFloat), true);
		assert.equal(ids.has(RULE_ID.coreNoGdextension), true);
		assert.equal(ids.has(RULE_ID.noGodot3Api), true);
		assert.equal(ids.has(RULE_ID.noDotnet), true);
		assert.equal(ids.has(RULE_ID.audioNoGameplayVocab), true);
		assert.equal(ids.has(RULE_ID.audioBackendOnlyEngine), true);
		assert.ok(hasFinding(findings, RULE_ID.noGodot3Api, "game/src/client/old_api.gd"));
		assert.equal(
			findings.some(
				(finding) =>
					finding.path === "game/src/client/old_api.gd" && finding.message.includes("onready var"),
			),
			true,
		);
		assert.ok(hasFinding(findings, RULE_ID.noDotnet, "game/Cheat.cs"));
		assert.ok(hasFinding(findings, RULE_ID.coreNoGdextension, "game/src/shared/native.gdextension"));
		assert.ok(hasFinding(findings, RULE_ID.audioNoGameplayVocab, "game/src/audio/uses_jump.gd"));
		assert.ok(hasFinding(findings, RULE_ID.audioBackendOnlyEngine, "game/src/audio/uses_engine.gd"));
	});

	it("does not treat _physics_process as _process", () => {
		const findings = scanRepo(join(FIXTURES_DIR, "clean"));
		assert.equal(
			findings.some((finding) => finding.message.includes("_physics_process")),
			false,
		);
	});
});

describe("live repository", () => {
	it("has no red-line findings in game/src today", () => {
		assert.deepEqual(scanRepo(REPO_ROOT), []);
	});
});

function hasFinding(findings: readonly Finding[], ruleId: string, path: string): boolean {
	return findings.some((finding) => finding.ruleId === ruleId && finding.path === path);
}
