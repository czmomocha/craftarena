import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const NET_FAULT = "docs/runbooks/network-fault-check.md";
const SIGNOFF = "docs/runbooks/playability-signoff-traprush.md";

function read(relativePath: string): string {
	return readFileSync(join(REPO_ROOT, relativePath), "utf8")
		.replace(/^\uFEFF/, "")
		.replaceAll("\r\n", "\n");
}

/**
 * M5 C6 只交清单与回写，没有可断言的运行时行为。所以这些用例钉的是：
 * 清单没有漏项、外部工具没有被偷偷入库、以及「M5 已退出」这句话在人类
 * 签字之前不许出现（宪法第二十四条）。
 */
describe("M5 C6 exit checklists", () => {
	it("ships the two runbooks CD-53 §2.5 and CD-61 M5 point at", () => {
		assert.equal(existsSync(join(REPO_ROOT, NET_FAULT)), true, NET_FAULT);
		assert.equal(existsSync(join(REPO_ROOT, SIGNOFF)), true, SIGNOFF);

		for (const path of [
			"Confirmed-docs/50-engineering/53-testing-and-ci.md",
			"Confirmed-docs/60-plan/61-milestones.md",
			"README.md",
			"docs/runbooks/dev-window-check.md",
			".cursor/rules/complete-chapter-prs.mdc",
			".cursor/rules/course-correction-freeze.mdc",
		]) {
			const source = read(path);
			assert.ok(source.includes("network-fault-check.md"), `${path}: missing ${NET_FAULT}`);
			assert.ok(source.includes("playability-signoff-traprush.md"), `${path}: missing ${SIGNOFF}`);
		}
	});

	it("covers all nine CD-53 §2.5 items without redefining the checklist", () => {
		const runbook = read(NET_FAULT);
		for (const item of [
			"延迟",
			"抖动",
			"丢包",
			"乱序",
			"重复包",
			"短时断线",
			"基线丢失",
			"恶意高频",
			"篡改",
		]) {
			assert.ok(runbook.includes(item), `${NET_FAULT}: missing 清单项 ${item}`);
		}
		// 所有者仍是 CD-53 §2.5；runbook 只写怎么执行。
		assert.match(runbook, /CD-53 §2\.5/);
		assert.match(runbook, /只写"怎么执行"/);
		assert.match(runbook, /不在这里增删清单项/);
	});

	it("names the decided tools and keeps them out of the repo and CI", () => {
		const runbook = read(NET_FAULT);
		for (const tool of ["clumsy", "tc netem", "dnctl", "pfctl"]) {
			assert.ok(runbook.includes(tool), `${NET_FAULT}: missing ${tool}`);
		}
		assert.match(runbook, /不入库/);
		assert.match(runbook, /不进 CI/);
		assert.match(runbook, /不写成 npm script/);
		assert.match(runbook, /不是 CI 门禁/);

		// 外部工具不得变成仓库脚本入口。
		const packageJson = read("package.json");
		for (const name of ["clumsy", "netem", "dnctl", "net-fault"]) {
			assert.ok(!packageJson.includes(name), `package.json must not script ${name}`);
		}
	});

	it("explains why link shaping cannot prove application-level reordering", () => {
		const runbook = read(NET_FAULT);
		assert.match(runbook, /TCP/);
		assert.match(runbook, /重传/);
		// 基线丢失在 v1 没有增量基线可丢，必须写明改验什么。
		assert.match(runbook, /全量/);
		assert.ok(runbook.includes("MOVE_STEP_MAX") || runbook.includes("超一格"));
	});

	it("leaves the nine execution rows unfilled for the human", () => {
		const runbook = read(NET_FAULT);
		const unexecuted = [...runbook.matchAll(/未执行/g)];
		assert.ok(unexecuted.length >= 9, `expected 9 blank rows, found ${unexecuted.length}`);
		assert.match(runbook, /AI 不得代填/);
	});

	it("carries the eight playability items plus a signature block", () => {
		const signoff = read(SIGNOFF);
		for (const item of [
			"操作手感",
			"机关可读性",
			"路线选择",
			"失败反馈",
			"音频反馈",
			"结算清晰度",
			"创作流畅度",
			"外人 5 分钟上手",
		]) {
			assert.ok(signoff.includes(item), `${SIGNOFF}: missing 签署项 ${item}`);
		}
		const unsigned = [...signoff.matchAll(/未签署/g)];
		assert.ok(unsigned.length >= 9, `expected 8 rows + overall conclusion blank, found ${unsigned.length}`);
		assert.match(signoff, /不得代签/);
		assert.match(signoff, /签署人/);
	});

	it("keeps the honest boundaries the constitution requires", () => {
		const signoff = read(SIGNOFF);
		// 第二十四条：不组织外部真人试玩，自评不得写成已验证。
		assert.match(signoff, /不组织外部真人试玩/);
		assert.match(signoff, /自评/);
		// 第九条：签署期间不得换 UI，否则签署对象作废。
		assert.match(signoff, /不得换 UI|不得接任何一屏/);
		assert.match(signoff, /E6/);
		assert.match(signoff, /发布候选/);
	});

	it("says M5 chapters are all delivered but exit still needs a signature", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		assert.match(live, /C6/);
		assert.match(live, /退出待人类签署|退出待签署|待人类执行并签署/);
		// 在人类签字之前不得出现「M5 已退出」。
		assert.doesNotMatch(live, /M5 已退出/);
		assert.doesNotMatch(live, /milestone_m5 = exited/);

		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		assert.match(decisions, /m5_exit_gate = two_manual_checklists_pending_signature/);
		assert.match(decisions, /net_fault_tooling = clumsy_netem_external/);
		assert.doesNotMatch(decisions, /milestone_m5 = exited/);
	});

	it("points both always-on rules at the next action instead of C6", () => {
		for (const path of [
			".cursor/rules/complete-chapter-prs.mdc",
			".cursor/rules/course-correction-freeze.mdc",
		]) {
			const rule = read(path);
			assert.match(rule, /^alwaysApply: true$/m);
			assert.match(rule, /字体入包/, `${path}: next action must be 字体入包`);
			assert.match(rule, /C6/, `${path}: must record C6 as delivered`);
			assert.doesNotMatch(rule, /下一实现刀是 C6|下一刀 = \*\*M5 C6\*\*/);
		}
	});

	it("records C6 in CD-53 and marks the plan chapter delivered", () => {
		const testing = read("Confirmed-docs/50-engineering/53-testing-and-ci.md");
		assert.match(testing, /M5 C6 退出验收/);
		assert.match(testing, /m5_exit\.test\.ts/);

		const plan = read("docs/plans/m5-traprush-vertical-slice.md");
		assert.match(plan, /### C6 M5 退出验收（\*\*已交，签署待人类\*\*）/);
		assert.match(plan, /十一章全交/);
	});
});
