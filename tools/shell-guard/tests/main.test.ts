import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const MAIN = join(REPO_ROOT, "tools/shell-guard/src/main.ts");

describe("shell-guard hook process", () => {
	it("prints deny JSON for git push origin main", async () => {
		const body = await runHook({ command: "git push origin main", cwd: REPO_ROOT });
		assert.equal(body.permission, "deny");
		assert.equal(typeof body.user_message, "string");
		assert.match(String(body.user_message), /blocked/i);
	});

	it("prints allow JSON for git status", async () => {
		const body = await runHook({ command: "git status", cwd: REPO_ROOT });
		assert.equal(body.permission, "allow");
	});
});

function runHook(payload: { readonly command: string; readonly cwd: string }): Promise<Record<string, unknown>> {
	return new Promise((resolve, reject) => {
		const child = spawn(process.execPath, [MAIN], { cwd: REPO_ROOT, stdio: ["pipe", "pipe", "pipe"] });
		const stdout: Buffer[] = [];
		const stderr: Buffer[] = [];
		child.stdout.on("data", (chunk: Buffer) => {
			stdout.push(chunk);
		});
		child.stderr.on("data", (chunk: Buffer) => {
			stderr.push(chunk);
		});
		child.on("error", reject);
		child.on("close", (code) => {
			if (code !== 0) {
				reject(new Error(`hook exit ${String(code)}: ${Buffer.concat(stderr).toString("utf8")}`));
				return;
			}
			try {
				resolve(JSON.parse(Buffer.concat(stdout).toString("utf8")) as Record<string, unknown>);
			} catch (error) {
				reject(error);
			}
		});
		child.stdin.end(`${JSON.stringify(payload)}\n`);
	});
}
