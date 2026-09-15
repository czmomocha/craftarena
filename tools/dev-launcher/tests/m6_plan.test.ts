import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

function read(relativePath: string): string {
	return readFileSync(join(REPO_ROOT, relativePath), "utf8")
		.replace(/^\uFEFF/, "")
		.replaceAll("\r\n", "\n");
}

function headingSection(source: string, heading: string, nextHeading: string): string {
	const start = source.indexOf(heading);
	assert.ok(start >= 0, `missing ${heading}`);
	const fromHeading = source.slice(start);
	const next = fromHeading.indexOf(nextHeading, heading.length);
	return next < 0 ? fromHeading : fromHeading.slice(0, next);
}

const PLAN = "docs/plans/m6-bastion-1v1.md";

/**
 * M6 章节计划落库时的口径门禁。
 *
 * 存在的理由：M6 要动四处宪法第十八条边界（实时帧 / 匹配 HTTP / 结算 HTTP /
 * 控制面加列），并且 UI 接线第二批会让 M5 刚签的可玩性结论作废。这两件事都是
 * 「写在计划里人类才知道」的，一旦被后续编辑顺手删掉，下一个读者会以为 M6
 * 可以直接开工、以为旧签署仍然成立。本文件把这些句子钉住。
 */
describe("M6 chapter plan is landed as a plan, not as a start signal", () => {
	it("splits M6 into the eleven chapters and keeps them ordered D1 to F2", () => {
		const plan = read(PLAN);
		assert.match(plan, /^# M6 章节计划/m);
		assert.match(plan, /不是所有者文档/);
		for (const chapter of ["D1", "D2", "D3", "D4", "D5", "E1", "E2", "E3", "E4", "F1", "F2"]) {
			assert.match(plan, new RegExp(`### ${chapter} `), `${PLAN}: missing chapter ${chapter}`);
		}
		assert.match(plan, /D1 → D2 → D3 → D4 → D5 → E1 → E2 → E3 → E4 → F1 → F2/);
		assert.match(plan, /不发明 M8/);
		assert.doesNotMatch(plan, /### M8/);
	});

	it("says the delivered D segment is still an offline base with no playable match", () => {
		const plan = read(PLAN);
		// D1–D4 之前这里钉的是「没有一行实现」。那句话在 D1 之后就假了，直接删掉
		// 等于把门禁拆了，所以换成三件仍然为真、同样容易被顺手抹掉的事。
		assert.match(plan, /D1–D4 已交，D5 起未开工/);
		assert.match(plan, /game\/src\/games\/bastion\//);
		// 「第一次有画面是 E4」必须留在章节清单的引子里，不能只活在 §8 那张
		// 故障注入表的行文里——那样这条断言会被自己的文档描述喂饱。
		const chapters = headingSection(plan, "## 4. 章节清单", "### D1 ");
		assert.match(chapters, /第一次有画面是 E4/);
		// 数值仍是占位桩：这是「拍板只关闭了用哪九个」的另一半。
		assert.match(plan, /占位桩/);
	});

	it("moves the two settled calls to 5.1 and keeps the other six pending", () => {
		const plan = read(PLAN);
		const settled = headingSection(plan, "### 5.1 已拍板", "### 5.2");
		// 两项结论各自的要害：不动已发布内容的哈希载体；只锁「用哪九个」。
		assert.match(settled, /独立新类型/);
		assert.match(settled, /一个字节不动/);
		assert.match(settled, /只锁「M6 用哪九个」/);
		assert.match(settled, /不在 M6/);
		// 「3 种障碍」是本次新增口径，不得被读成夹具本来的要求。
		assert.match(settled, /不是文档原有要求/);

		const pending = headingSection(plan, "### 5.2 待拍板", "### 5.3");
		// 行号覆盖而非删除，前两行必须写明已拍，后六行必须仍带推荐而非结论。
		assert.match(pending, /\| 1 \| ~~/);
		assert.match(pending, /\| 2 \| ~~/);
		for (const index of ["| 3 |", "| 4 |", "| 5 |", "| 6 |", "| 7 |", "| 8 |"]) {
			assert.ok(pending.includes(index), `${PLAN}: §5.2 must keep pending row ${index}`);
		}
		assert.match(pending, /AI 推荐/);
		assert.match(pending, /不挡 D1/);
	});

	it("records both calls in CD-91 without closing the deferred full lists", () => {
		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		assert.match(decisions, /bastion_blueprint_bundle = separate_type_not_simulation_bundle/);
		assert.match(decisions, /bastion_minimum_set_m6 = three_towers_three_units_three_obstacles/);

		// CD-63 §1.2 / §1.3 只被迁出「M6 用哪九个」，完整清单与数值仍延期。
		const open = read("Confirmed-docs/60-plan/63-open-decisions.md");
		assert.match(open, /M6 的 BASTION 最小九项也已迁出|M6 的 BASTION 最小塔/);
		assert.match(open, /完整清单仍延期|完整清单与 §1\.3 的具体伤害/);
		// 隐藏布障仍未拍，不得被这次拍板顺带认领。
		assert.match(open, /BASTION 隐藏布障的协议实现/);

		// Schema 所有者必须写明 Bundle v2 与 Component v1 没动。
		const contracts = read("Confirmed-docs/40-technical/42-contracts-and-rulevm.md");
		assert.match(contracts, /BASTION 蓝图不进 Bundle v2/);
		assert.match(contracts, /Component v1 不改/);
	});

	it("keeps the four article-18 boundaries visible instead of burying them in chapters", () => {
		const plan = read(PLAN);
		const facts = headingSection(plan, "### 3.3 实时面与两条 HTTP", "## 4.");
		assert.match(facts, /宪法第十八条/);
		assert.match(facts, /没有线上 id|没有玩法判别位/);
		// 不在变更范围内的三条，写进计划才防得住顺手改。
		assert.match(plan, /`SimulationCore` 定点合同/);
		assert.match(plan, /22 个袋/);
	});

	it("warns that wiring S1 voids the signed TRAPRUSH playability checklist", () => {
		// 宪法第二十四条：不得把已作废的签署当成仍然成立。
		const plan = read(PLAN);
		const f1 = headingSection(plan, "### F1 UI 接线第二批", "### F2");
		assert.match(f1, /作废/);
		assert.match(f1, /重签/);

		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		const m6 = headingSection(live, "### M6：", "### M7：");
		assert.match(m6, /F1/);
		assert.match(m6, /重签/);
	});

	it("points CD-61 and CD-22 at the plan without claiming M6 can be played", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		const m6 = headingSection(live, "### M6：", "### M7：");
		assert.match(m6, /m6-bastion-1v1\.md/);
		assert.match(m6, /D5 起未开工/);
		assert.match(m6, /其余六项仍待拍板/);
		// 「交了什么」必须和「没交什么」写在一起，否则下一个读者会以为 M6 快好了。
		assert.match(m6, /开不出一局给人看|第一次有画面是 E4/);
		// 产出与验收句仍归 CD-61，计划文件不得替代它。
		assert.match(m6, /非法封路、伪造金币和伪造建造均被拒绝/);

		const bastion = read("Confirmed-docs/20-gameplay/22-bastion.md");
		assert.match(bastion, /m6-bastion-1v1\.md/);
		assert.match(bastion, /仍不是锁定清单/);
		assert.match(bastion, /占位桩/);
		// 最小集与其排除项都要在玩法所有者文档里，不能只活在计划文件。
		assert.match(bastion, /箭塔/);
		assert.match(bastion, /狙击 \/ 电弧 \/ 增幅塔/);
	});

	it("routes BASTION placeholder numbers to a single source per the freeze rule", () => {
		const freeze = read(".cursor/rules/course-correction-freeze.mdc");
		assert.match(freeze, /game\/src\/games\/bastion\/play_stubs\.gd/);
		assert.match(freeze, /placeholder_spec\.gd/);

		const plan = read(PLAN);
		assert.match(plan, /bastion_play_stubs\.gd/);
		assert.match(plan, /不散落新 `const`|不散落几何 \/ 色板常量/);
	});
});
