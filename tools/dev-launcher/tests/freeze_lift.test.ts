import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

function read(relativePath: string): string {
	return readFileSync(join(REPO_ROOT, relativePath), "utf8")
		.replace(/^\uFEFF/, "")
		.replaceAll("\r\n", "\n");
}

describe("course-correction freeze lift 2026-09-03", () => {
	it("records the lift in the plan, audit, freeze rule, and CD-61", () => {
		const plan = read("docs/plans/course-correction-2026-08.md");
		assert.match(plan, /冻结令已解除/);
		assert.match(plan, /### 1\.4 解除（2026-09-03）/);
		assert.match(plan, /选项 A/);
		assert.match(plan, /一期收尾/);

		const audit = "docs/audits/2026-09-03-freeze-lift.md";
		assert.equal(existsSync(join(REPO_ROOT, audit)), true, audit);
		assert.match(read(audit), /解除/);
		assert.match(read(audit), /不设每周 PR 上限/);

		const rule = read(".cursor/rules/course-correction-freeze.mdc");
		assert.match(rule, /已解除/);
		assert.doesNotMatch(rule, /只有纠偏方案的 C0–C5/);

		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		assert.match(live, /纠偏冻结令已解除|纠偏闸门[\s\S]{0,80}已解除/);
		assert.match(live, /M-Export 收尾/);
	});

	it("closes E8 font packaging and E10 without a weekly cap", () => {
		const plan = read("docs/plans/course-correction-2026-08.md");
		assert.match(plan, /E8[\s\S]{0,400}已关闭/);
		assert.match(plan, /E10[\s\S]{0,400}已关闭/);
		assert.match(plan, /不设.*周 PR 上限/);

		const scope = read("Confirmed-docs/10-product/11-scope-and-platforms.md");
		assert.match(scope, /一期收尾/);
		assert.match(scope, /任意中文缺字/);

		const risks = read("Confirmed-docs/60-plan/62-risk-register.md");
		assert.match(risks, /不设.*周/);
		assert.doesNotMatch(risks, /E10 周 PR 上限仍待观察/);

		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		assert.match(decisions, /course_correction_freeze = lifted/);
		assert.match(decisions, /font_packaging = defer_to_phase1_end/);
	});

	it("keeps D9 chapter size after the freeze lifts", () => {
		const workflow = read("Confirmed-docs/50-engineering/52-ai-workflow.md");
		assert.match(workflow, /里程碑归属/);
		assert.match(workflow, /placeholder_spec/);
		assert.match(workflow, /5 倍/);
		assert.doesNotMatch(workflow, /纠偏归属：C0/);
	});
});
