import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { decideShellCommand } from "../src/decide.ts";

describe("shell-guard allows ordinary git on a feature branch", () => {
	it("allows status, commit, and push to a feature ref", () => {
		assert.equal(decideShellCommand("git status").permission, "allow");
		assert.equal(decideShellCommand("git commit -m ok", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(decideShellCommand("git push -u origin feat/x", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(decideShellCommand("git push origin HEAD:feat/x", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(decideShellCommand("git push -u origin HEAD", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(decideShellCommand("git worktree add ../wt feat/x").permission, "allow");
		assert.equal(decideShellCommand("git worktree remove ../wt").permission, "allow");
		assert.equal(decideShellCommand("npm test").permission, "allow");
	});
});

describe("shell-guard allows ordinary writes on main", () => {
	it("allows commit and ordinary push to main", () => {
		assert.equal(decideShellCommand("git commit -m x", { currentBranch: "main" }).permission, "allow");
		assert.equal(decideShellCommand("git merge feat/x", { currentBranch: "main" }).permission, "allow");
		assert.equal(decideShellCommand("git push origin main").permission, "allow");
		assert.equal(decideShellCommand("git push origin HEAD:main", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(decideShellCommand("git push origin feat/x:main").permission, "allow");
		assert.equal(decideShellCommand("git push origin refs/heads/main").permission, "allow");
		assert.equal(decideShellCommand("git --no-pager push origin main").permission, "allow");
		assert.equal(decideShellCommand("git push -u origin HEAD", { currentBranch: "main" }).permission, "allow");
		assert.equal(decideShellCommand("git push", { currentBranch: "main" }).permission, "allow");
		assert.equal(decideShellCommand("git push origin", { currentBranch: "main" }).permission, "allow");
	});

	it("still blocks force-push and delete of main", () => {
		assert.equal(decideShellCommand("git push --force origin main").code, "push-force-protected");
		assert.equal(decideShellCommand("git push -f origin main").code, "push-force-protected");
		assert.equal(decideShellCommand("git push --force-with-lease origin main").code, "push-force-protected");
		assert.equal(decideShellCommand("git push origin +main").code, "push-force-protected");
		assert.equal(decideShellCommand("git push --force", { currentBranch: "main" }).code, "push-force-protected");
		assert.equal(decideShellCommand("git push --delete origin main").code, "push-protected");
		assert.equal(decideShellCommand("git push origin :main").code, "push-protected");
	});

	it("blocks implicit push when the current branch is unknown", () => {
		assert.equal(decideShellCommand("git push origin HEAD").code, "push-implicit-unknown");
		assert.equal(decideShellCommand("git push").code, "push-implicit-unknown");
		assert.equal(decideShellCommand("git push origin", { currentBranch: "feat/x" }).permission, "allow");
	});

	it("blocks git push --all and --mirror", () => {
		assert.equal(decideShellCommand("git push --all origin").code, "push-all");
		assert.equal(decideShellCommand("git push --mirror origin").code, "push-all");
	});
});

describe("shell-guard blocks forced worktree deletion", () => {
	it("denies --force and -f on worktree remove", () => {
		assert.equal(decideShellCommand("git worktree remove --force ../wt").code, "worktree-force-remove");
		assert.equal(decideShellCommand("git worktree remove ../wt -f").code, "worktree-force-remove");
		assert.equal(decideShellCommand("git -C /tmp worktree remove --force ../wt").code, "worktree-force-remove");
	});
});

describe("shell-guard unwraps quoted wrappers", () => {
	it("still sees git push --force origin main inside powershell -Command", () => {
		const wrapped = 'powershell.exe -NoProfile -Command "git push --force origin main"';
		assert.equal(decideShellCommand(wrapped).code, "push-force-protected");
	});
});

describe("shell-guard keeps machine-local Godot AI settings out of a commit", () => {
	const STAGED = { stagedProjectSettingsLocalOnly: ["autoload/_mcp_game_helper"] } as const;
	const WORKTREE = { worktreeProjectSettingsLocalOnly: ["autoload/_mcp_game_helper"] } as const;

	it("blocks commit when the index already carries the entry", () => {
		assert.equal(
			decideShellCommand("git commit -m x", { currentBranch: "feat/x", ...STAGED }).code,
			"godot-ai-project-settings",
		);
		assert.equal(
			decideShellCommand("git commit --amend --no-edit", { currentBranch: "feat/x", ...STAGED }).code,
			"godot-ai-project-settings",
		);
	});

	it("blocks commit -a while only the working tree carries the entry", () => {
		assert.equal(
			decideShellCommand("git commit -am x", { currentBranch: "feat/x", ...WORKTREE }).code,
			"godot-ai-project-settings",
		);
		assert.equal(
			decideShellCommand("git commit --all -m x", { currentBranch: "feat/x", ...WORKTREE }).code,
			"godot-ai-project-settings",
		);
	});

	it("allows a plain commit of other staged files while only the working tree is dirty", () => {
		assert.equal(
			decideShellCommand("git commit -m x", { currentBranch: "feat/x", ...WORKTREE }).permission,
			"allow",
		);
	});

	it("blocks the git add forms that would stage the file", () => {
		for (const command of [
			"git add .",
			"git add -A",
			"git add -u",
			"git add --all",
			"git add game/project.godot",
			"git add game",
			"git add game/",
			"git add -- game/project.godot",
			"git stage game/project.godot",
			"git add game\\project.godot",
		]) {
			assert.equal(
				decideShellCommand(command, { currentBranch: "feat/x", ...WORKTREE }).code,
				"godot-ai-project-settings",
				command,
			);
		}
	});

	it("allows adding unrelated paths and read-only git", () => {
		for (const command of [
			"git add README.md",
			"git add backend/control-plane/src/main.ts",
			"git status",
			"git diff -- game/project.godot",
			"git checkout -- game/project.godot",
			"git commit --dry-run",
		]) {
			assert.equal(
				decideShellCommand(command, { currentBranch: "feat/x", ...WORKTREE }).permission,
				"allow",
				command,
			);
		}
	});

	it("stays out of the way when nothing is polluted", () => {
		assert.equal(decideShellCommand("git add .", { currentBranch: "feat/x" }).permission, "allow");
		assert.equal(
			decideShellCommand("git commit -am x", { currentBranch: "feat/x" }).permission,
			"allow",
		);
	});

	it("reports the settings problem even when committing on main", () => {
		// 两个原因同时成立时消息里必须写「怎么修 project.godot」，
		// 否则人只看到别的拦截、还原那一步会被漏掉。
		assert.equal(
			decideShellCommand("git commit -m x", { currentBranch: "main", ...STAGED }).code,
			"godot-ai-project-settings",
		);
	});
});
