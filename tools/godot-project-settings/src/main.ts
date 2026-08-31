import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { PROJECT_SETTINGS_PATH, findLocalOnlyEntries, scrubLocalOnly } from "./local_only.ts";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const ABSOLUTE_PATH = join(REPO_ROOT, PROJECT_SETTINGS_PATH);
const FIX_COMMAND = "npm run godot-settings:scrub";

const args = process.argv.slice(2);
const scrub = args.includes("--scrub");
const staged = args.includes("--staged");

if (scrub && staged) {
	console.error("godot-project-settings: --scrub and --staged are mutually exclusive");
	process.exit(2);
}

if (scrub) {
	runScrub();
} else {
	runCheck(staged);
}

function runScrub(): void {
	const result = scrubLocalOnly(readFileSync(ABSOLUTE_PATH, "utf8"));
	if (result.removed.length === 0) {
		console.log(report("scrub", "worktree", []));
		process.exit(0);
	}
	writeFileSync(ABSOLUTE_PATH, result.text, "utf8");
	console.log(report("scrub", "worktree", result.removed));
	process.exit(0);
}

function runCheck(fromIndex: boolean): void {
	const source = fromIndex ? "index" : "worktree";
	const text = fromIndex ? readIndexCopy() : readFileSync(ABSOLUTE_PATH, "utf8");
	if (text === undefined) {
		// 索引里没有这份文件（罕见：全新克隆还没 add 过）。没有内容就没有污染。
		console.log(report("check", source, []));
		process.exit(0);
	}
	const removed = findLocalOnlyEntries(text);
	if (removed.length === 0) {
		console.log(report("check", source, []));
		process.exit(0);
	}
	console.error(report("check", source, removed));
	console.error(
		`godot-project-settings: ${PROJECT_SETTINGS_PATH} (${source}) carries machine-local Godot AI entries. Run \`${FIX_COMMAND}\`. CD-51 section 7.3 forbids committing them.`,
	);
	process.exit(1);
}

function readIndexCopy(): string | undefined {
	try {
		return execFileSync("git", ["show", `:${PROJECT_SETTINGS_PATH}`], {
			cwd: REPO_ROOT,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		});
	} catch {
		return undefined;
	}
}

function report(mode: string, source: string, removed: readonly string[]): string {
	return JSON.stringify({
		event: "godot_project_settings",
		mode,
		source,
		path: PROJECT_SETTINGS_PATH,
		ok: removed.length === 0,
		entries: removed,
	});
}
