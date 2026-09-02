import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const CONFIRMED = join(REPO_ROOT, "Confirmed-docs");
const OLD_RUNBOOK = "docs/runbooks/chapter-device-check.md";
const NEW_RUNBOOK = "docs/runbooks/dev-window-check.md";
const DRAFT = "docs/plans/cd-61-rearrangement-draft.md";

function read(relativePath: string): string {
	return readFileSync(join(REPO_ROOT, relativePath), "utf8").replace(/^\uFEFF/, "").replaceAll("\r\n", "\n");
}

function markdownFilesUnder(dir: string): string[] {
	const out: string[] = [];
	for (const name of readdirSync(dir)) {
		const full = join(dir, name);
		if (statSync(full).isDirectory()) {
			out.push(...markdownFilesUnder(full));
			continue;
		}
		if (name.endsWith(".md")) {
			out.push(relative(REPO_ROOT, full).replaceAll("\\", "/"));
		}
	}
	return out.sort();
}

/** Owner docs: every Confirmed-docs markdown except the index. */
function ownerDocs(): string[] {
	return markdownFilesUnder(CONFIRMED).filter((path) => path !== "Confirmed-docs/README.md");
}

function currentValuesSection(source: string, label: string): string {
	const match = source.match(/^## 当前生效值\n([\s\S]*?)(?=^## |\z)/m);
	assert.ok(match !== null, `${label}: missing "## 当前生效值"`);
	return (match[1] ?? "").trim();
}

describe("C5 document governance", () => {
	it("renames the window-check runbook and drops the old filename", () => {
		assert.equal(existsSync(join(REPO_ROOT, NEW_RUNBOOK)), true, NEW_RUNBOOK);
		assert.equal(existsSync(join(REPO_ROOT, OLD_RUNBOOK)), false, `stale ${OLD_RUNBOOK}`);
		const runbook = read(NEW_RUNBOOK);
		assert.match(runbook, /^# 开发机窗口验收/m);
		assert.match(runbook, /导出包/);
		assert.doesNotMatch(runbook, /Headless `--quit` \*\*不是\*\*真机/);
	});

	it("keeps the task-loop and PR rule pointing at the new runbook", () => {
		for (const path of [
			"AGENTS.md",
			"README.md",
			"Confirmed-docs/README.md",
			"Confirmed-docs/50-engineering/52-ai-workflow.md",
			".cursor/rules/complete-chapter-prs.mdc",
		]) {
			const source = read(path);
			assert.ok(source.includes(NEW_RUNBOOK), `${path}: missing ${NEW_RUNBOOK}`);
			assert.ok(!source.includes(OLD_RUNBOOK), `${path}: still names ${OLD_RUNBOOK}`);
			assert.ok(source.includes("开发机窗口验收"), `${path}: missing display name`);
		}
	});

	it("gives every owner document an overwrite-not-append current-values section", () => {
		const docs = ownerDocs();
		assert.ok(docs.length >= 20, `expected the Confirmed-docs set, got ${docs.length}`);
		for (const path of docs) {
			const source = read(path);
			const section = currentValuesSection(source, path);
			assert.ok(section.length > 40, `${path}: 当前生效值 too short to be a real section`);
			const lineCount = section.split("\n").length;
			assert.ok(
				lineCount <= 80,
				`${path}: 当前生效值 is ${lineCount} lines; 30-second read needs overwrite, not another dump`,
			);
			assert.match(section, /覆盖而非追加|全文即当前口径|本文件不拥有口径|术语以本表为准/);
		}
	});

	it("collapses the CD-41 §5 dump and the CD-21 append chain", () => {
		const architecture = read("Confirmed-docs/40-technical/41-architecture.md");
		assert.doesNotMatch(architecture, /截至本刀，`game\/src\/shared\/`/);
		assert.match(architecture, /placeholder_spec\.gd/);

		const traprush = read("Confirmed-docs/20-gameplay/21-traprush.md");
		const appendHits = [...traprush.matchAll(/实现落点（20\d{2}-\d{2}-\d{2}）/g)];
		assert.ok(
			appendHits.length <= 2,
			`CD-21 still has ${appendHits.length} dated 实现落点 appendages`,
		);
		assert.match(traprush, /一期最小集/);
		assert.match(traprush, /爆破球/);
		assert.match(traprush, /冲刺/);
		assert.doesNotMatch(traprush, /以下\*\*不是\*\*已锁定的正式道具表/);
	});

	it("corrects CD-62 statuses to match C1/C5 facts", () => {
		const source = read("Confirmed-docs/60-plan/62-risk-register.md");
		assert.match(source, /网页\/微信包体超限[\s\S]{0,80}未开始/);
		assert.match(source, /第一次真导出/);
		assert.match(source, /传送迷路或跳关[\s\S]{0,80}已缓解/);
		assert.match(source, /镜头过渡/);
		assert.match(source, /单人审查带宽超载/);
		assert.match(source, /在零延迟条件下锁定网络参数/);
		assert.doesNotMatch(source, /这些门禁尚未进 CI/);
		assert.doesNotMatch(source, /资源变体、子包、按需资源模块/);
	});

	it("keeps the approved rearrangement draft as the approval record", () => {
		assert.equal(existsSync(join(REPO_ROOT, DRAFT)), true, DRAFT);
		const draft = read(DRAFT);
		assert.match(draft, /已批准并回写/);
		assert.match(draft, /CD-11 §4/);
		assert.match(draft, /表现\/美术/);
		assert.match(draft, /平台导出与 Web/);
		assert.match(draft, /账号 \+ 草稿云 \+ 内容平台/);
		assert.match(draft, /M4a|M4-VM|Rule VM/);
		assert.match(draft, /M4b|M4-platform|内容平台/);

		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		assert.match(live, /cd-61-rearrangement-draft\.md/);
		assert.match(live, /本文件是现行口径/);
		assert.doesNotMatch(live, /待人类逐条批准后才回写/);
	});

	it("syncs the Web gate and export timing already decided in D2/D11", () => {
		const scope = read("Confirmed-docs/10-product/11-scope-and-platforms.md");
		assert.match(scope, /公开运营前/);
		assert.match(scope, /域名/);
		assert.doesNotMatch(scope, /C1 内完成域名/);

		const env = read("Confirmed-docs/50-engineering/51-dev-environment.md");
		assert.doesNotMatch(env, /Web 预设在核心切片稳定后加入/);
		assert.match(env, /export_presets\.cfg/);
	});

	it("copies D9 into the CD-52 task sheet the freeze rules already use", () => {
		const workflow = read("Confirmed-docs/50-engineering/52-ai-workflow.md");
		assert.match(workflow, /纠偏归属/);
		assert.match(workflow, /是否新增冻结常量引用/);
		assert.match(workflow, /深审/);
		assert.match(workflow, /章粒度/);
	});

	it("closes C5 against E3/E6 facts without unlocking the freeze", () => {
		const risks = read("Confirmed-docs/60-plan/62-risk-register.md");
		assert.match(risks, /零延迟锁定网络参数[\s\S]{0,80}已治理/);
		assert.doesNotMatch(risks, /锁定仍待人类拍板/);

		const testing = read("Confirmed-docs/50-engineering/53-testing-and-ci.md");
		assert.match(testing, /E6 已签：好玩/);
		assert.doesNotMatch(testing, /可玩性签署尚未发生/);

		const plan = read("docs/plans/course-correction-2026-08.md");
		assert.match(plan, /C5 治理与里程碑重排[\s\S]{0,80}已结束/);
		assert.match(plan, /不得\*\*把 C5 结束读成已解冻/);

		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		assert.match(decisions, /c5_batch = complete_e9_lock_e11_facts/);
	});
});
