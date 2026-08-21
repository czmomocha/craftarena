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

describe("shell-guard blocks protected-branch writes", () => {
	it("blocks git push that updates main", () => {
		assert.equal(decideShellCommand("git push origin main").code, "push-protected");
		assert.equal(decideShellCommand("git push origin HEAD:main", { currentBranch: "feat/x" }).code, "push-protected");
		assert.equal(decideShellCommand("git push origin feat/x:main").code, "push-protected");
		assert.equal(decideShellCommand("git push origin +main").code, "push-protected");
		assert.equal(decideShellCommand("git push origin refs/heads/main").code, "push-protected");
		assert.equal(decideShellCommand("git push --force origin main").code, "push-protected");
		assert.equal(decideShellCommand("git --no-pager push origin main").code, "push-protected");
	});

	it("blocks implicit push when the current branch is main or unknown", () => {
		assert.equal(decideShellCommand("git push -u origin HEAD", { currentBranch: "main" }).code, "push-protected");
		assert.equal(decideShellCommand("git push origin HEAD").code, "push-implicit-unknown");
		assert.equal(decideShellCommand("git push", { currentBranch: "main" }).code, "push-protected");
		assert.equal(decideShellCommand("git push origin", { currentBranch: "main" }).code, "push-protected");
		assert.equal(decideShellCommand("git push").code, "push-implicit-unknown");
		assert.equal(decideShellCommand("git push origin", { currentBranch: "feat/x" }).permission, "allow");
	});

	it("blocks git push --all and --mirror", () => {
		assert.equal(decideShellCommand("git push --all origin").code, "push-all");
		assert.equal(decideShellCommand("git push --mirror origin").code, "push-all");
	});

	it("blocks commit-like commands on main", () => {
		assert.equal(decideShellCommand("git commit -m x", { currentBranch: "main" }).code, "commit-on-protected");
		assert.equal(decideShellCommand("git merge feat/x", { currentBranch: "main" }).code, "commit-on-protected");
		assert.equal(decideShellCommand("git merge --abort", { currentBranch: "main" }).permission, "allow");
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
	it("still sees git push origin main inside powershell -Command", () => {
		const wrapped = 'powershell.exe -NoProfile -Command "git push origin main"';
		assert.equal(decideShellCommand(wrapped).code, "push-protected");
	});
});
