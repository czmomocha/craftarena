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

		// 所有者文档与入口必须一直指得到这两份清单。「当前刀」规则
		// (complete-chapter-prs) 不在此列：M5 退出后它指向下一刀，
		// 继续挂已退出章节的清单反而会误导下一个会话。
		for (const path of [
			"Confirmed-docs/50-engineering/53-testing-and-ci.md",
			"Confirmed-docs/60-plan/61-milestones.md",
			"README.md",
			"docs/runbooks/dev-window-check.md",
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

	it("keeps one execution row per checklist item and never lets AI judge them", () => {
		const runbook = read(NET_FAULT);
		// §5 的记录表：九行，每行「清单项 | 执行方式 | 结论 | 日期/机器」。
		// 行数由清单长度决定，填没填都必须是九行——少一行就是漏了一项。
		const rows = [...runbook.matchAll(/^\|[^|\n]+\|\s*(?:§2\.4|§3)[^|\n]*\|[^|\n]+\|[^|\n]*\|$/gm)];
		assert.equal(rows.length, 9, `expected 9 execution rows, found ${rows.length}`);
		for (const [row] of rows) {
			const conclusion = row.split("|")[3]?.trim() ?? "";
			assert.ok(conclusion !== "", `row has an empty conclusion cell: ${row}`);
		}
		assert.match(runbook, /结论只能来自人类执行/);
		assert.match(runbook, /AI 只能誊抄/);
		// 跑过一轮不等于有回归覆盖（宪法第二十四条）。
		assert.match(runbook, /不是回归覆盖/);
	});

	it("keeps the macOS reordering and duplication gap visible instead of green", () => {
		// dnctl 没有 reorder / duplicate。第一轮在 macOS 上跳过了这两项，
		// 「跑完没发现异常」是同义反复，不是证据（宪法第二十四条）。
		const runbook = read(NET_FAULT);
		assert.match(runbook, /未严格注入/);
		assert.match(runbook, /同义反复/);
		assert.match(runbook, /tc netem reorder/);

		// CD-53 的状态行必须跟着说 7 项，不许写成九项全过。
		const testing = read("Confirmed-docs/50-engineering/53-testing-and-ci.md");
		assert.match(testing, /7 项符合预期/);
		assert.match(testing, /乱序与重复包未严格注入/);
		assert.doesNotMatch(testing, /九项全部符合预期/);
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
		// 八行签署表：每行都要有结论与日期，空格子等于没签。
		const rows = [...signoff.matchAll(/^\|\s*[1-8]\s*\|[^|\n]+\|([^|\n]+)\|([^|\n]+)\|[^|\n]*\|$/gm)];
		assert.equal(rows.length, 8, `expected 8 signature rows, found ${rows.length}`);
		for (const [, verdict, date] of rows) {
			assert.match(
				(verdict ?? "").trim(),
				/^(通过|带条件通过|不通过)$/,
				`verdict must be one of the three allowed values, got ${verdict}`,
			);
			assert.notEqual((date ?? "").trim(), "", "a signed row needs a date");
		}
		assert.match(signoff, /不得代签/);
		assert.match(signoff, /签署人：\S/);
	});

	it("quotes the overall verdict verbatim instead of upgrading it", () => {
		// 人类写的是「基本通过」。把它抄成无保留的「通过」会让下游读者
		// 以为没有保留意见——那是伪造签署内容（宪法第二十四条）。
		const signoff = read(SIGNOFF);
		assert.match(signoff, /一句话结论：基本通过/);
		assert.match(signoff, /不得改写成无保留/);

		for (const path of [
			"Confirmed-docs/60-plan/61-milestones.md",
			"Confirmed-docs/90-reference/91-decision-log.md",
			"Confirmed-docs/50-engineering/53-testing-and-ci.md",
			"README.md",
		]) {
			assert.match(read(path), /基本通过/, `${path}: must quote the verdict verbatim`);
		}
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

	it("records the M5 exit with its date and keeps the gate decision traceable", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		assert.match(live, /C6/);
		assert.match(live, /2026-09-13/);
		assert.match(live, /M5 退出记录/);
		// 退出后不得再自称「待签署」。
		assert.doesNotMatch(live, /退出待人类签署|待人类执行并签署/);

		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		// 旧门禁行保留（覆盖链可追溯），新行覆盖它。
		assert.match(decisions, /m5_exit_gate = two_manual_checklists_pending_signature/);
		assert.match(decisions, /milestone_m5 = exited_basically_pass_2026_09_13/);
		assert.match(decisions, /net_fault_tooling = clumsy_netem_external/);
	});

	it("carries the two M5 leftovers past the exit instead of dropping them", () => {
		// 退出 ≠ 已解决。这两项一旦从文档里消失，下一个读者就会以为它们做过了。
		for (const path of [
			"Confirmed-docs/60-plan/61-milestones.md",
			"Confirmed-docs/90-reference/91-decision-log.md",
			"README.md",
			".cursor/rules/course-correction-freeze.mdc",
		]) {
			const source = read(path);
			assert.match(source, /未严格注入/, `${path}: must keep the reorder/duplicate gap`);
			assert.match(source, /占位/, `${path}: must keep the placeholder-art caveat`);
		}
		// 发布候选清单仍未签，不得被 M5 的签署顺带认领。
		const testing = read("Confirmed-docs/50-engineering/53-testing-and-ci.md");
		assert.match(testing, /发布候选[\s\S]{0,120}仍未签|仍未签[\s\S]{0,120}发布候选/);
	});

	it("points both always-on rules at font packaging as the next slice", () => {
		for (const path of [
			".cursor/rules/complete-chapter-prs.mdc",
			".cursor/rules/course-correction-freeze.mdc",
		]) {
			const rule = read(path);
			assert.match(rule, /^alwaysApply: true$/m);
			assert.match(rule, /字体入包/, `${path}: next action must be 字体入包`);
			// 子集范围仍属人类门禁，规则必须继续挡住 AI 自选。
			assert.match(rule, /子集范围/, `${path}: must keep the subset decision with the human`);
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
