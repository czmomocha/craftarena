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

describe("C5 CD-61 writeback after human approval", () => {
	it("makes the approved rearrangement the live CD-61", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		assert.match(live, /^## 当前生效值/m);
		assert.match(live, /覆盖而非追加/);
		assert.match(live, /本文件是现行口径/);
		assert.match(live, /### M-Export/);
		assert.match(live, /### M-Art/);
		assert.match(live, /### M4a/);
		assert.match(live, /### M4b/);
		assert.doesNotMatch(live, /### M4：规则字节码与热发布/);
		assert.match(live, /纠偏冻结/);
	});

	it("rewrites the M3 item gate and moves export off M5", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		const m3 = headingSection(live, "### M3：", "### M-Export");
		assert.match(m3, /爆破球/);
		assert.match(m3, /冲刺/);
		assert.match(m3, /不是 M3 退出条件/);

		const m5 = headingSection(live, "### M5：", "### M6：");
		assert.doesNotMatch(m5, /Windows 导出/);
		assert.doesNotMatch(m5, /Android\/iOS 导出烟测/);
		assert.match(m5, /M-Export/);
		assert.match(m5, /可玩性/);
	});

	it("gives every CD-11 §4 must-do an owner without inventing M8", () => {
		const live = read("Confirmed-docs/60-plan/61-milestones.md");
		const ownersStart = live.indexOf("## 5. 一期必做项所有者");
		assert.ok(ownersStart >= 0, "missing §5");
		const owners = live.slice(ownersStart);
		assert.match(owners, /Web 轻量 Edit/);
		assert.match(owners, /M-Export/);
		assert.match(owners, /表现 \/ 美术/);
		assert.match(owners, /M-Art/);
		assert.match(owners, /账号 \+ 草稿云/);
		assert.match(owners, /M4b/);
		assert.match(owners, /Rule VM/);
		assert.doesNotMatch(live, /### M8/);
	});

	it("records the writeback over the pending-draft decision", () => {
		const decisions = read("Confirmed-docs/90-reference/91-decision-log.md");
		assert.match(decisions, /cd61_rearrangement = approved_writeback/);
		assert.match(decisions, /draft_pending_human/);
	});
});
