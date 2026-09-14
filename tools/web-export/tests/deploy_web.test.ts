import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import {
	DEFAULT_REMOTE_PATH,
	DEPLOY_HOST_ENV,
	DEPLOY_PATH_ENV,
	DEPLOY_SSH_PORT_ENV,
	DEPLOY_USER_ENV,
	EXPORT_RELATIVE_DIR,
} from "../src/constants.ts";
import { buildDeployPlan, runDeployWeb } from "../src/deploy_web.ts";

const HOST = "203.0.113.9";
const USER = "deploy";

function writeWebLayout(dir: string): void {
	mkdirSync(dir, { recursive: true });
	writeFileSync(join(dir, "index.html"), "<html></html>\n");
	writeFileSync(join(dir, "index.js"), "print();\n");
	writeFileSync(join(dir, "index.wasm"), "wasm\n");
	writeFileSync(join(dir, "index.pck"), "pck\n");
}

describe("buildDeployPlan", () => {
	it("refuses to guess a host", () => {
		const plan = buildDeployPlan({ env: {}, platform: "linux" });
		assert.equal(plan.ok, false);
		if (!plan.ok) {
			assert.match(plan.error, new RegExp(DEPLOY_HOST_ENV));
		}
	});

	it("refuses a URL host and filesystem root", () => {
		const url = buildDeployPlan({
			env: { [DEPLOY_HOST_ENV]: "http://203.0.113.9", [DEPLOY_USER_ENV]: USER },
			platform: "linux",
		});
		assert.equal(url.ok, false);

		const root = buildDeployPlan({
			env: {
				[DEPLOY_HOST_ENV]: HOST,
				[DEPLOY_USER_ENV]: USER,
				[DEPLOY_PATH_ENV]: "/",
			},
			platform: "linux",
		});
		assert.equal(root.ok, false);
	});

	it("builds scp by default and rsync when asked", () => {
		const scp = buildDeployPlan({
			env: { [DEPLOY_HOST_ENV]: HOST, [DEPLOY_USER_ENV]: USER },
			platform: "win32",
		});
		assert.equal(scp.ok, true);
		if (scp.ok) {
			assert.equal(scp.command.executable, "scp");
			assert.ok(scp.display.includes(`${USER}@${HOST}:${DEFAULT_REMOTE_PATH}`));
			assert.ok(!scp.display.includes("--delete"));
		}

		const rsync = buildDeployPlan({
			env: {
				[DEPLOY_HOST_ENV]: HOST,
				[DEPLOY_USER_ENV]: USER,
				[DEPLOY_PATH_ENV]: DEFAULT_REMOTE_PATH,
				[DEPLOY_SSH_PORT_ENV]: "2222",
			},
			platform: "linux",
			hasRsync: true,
		});
		assert.equal(rsync.ok, true);
		if (rsync.ok) {
			assert.equal(rsync.command.executable, "rsync");
			assert.ok(rsync.command.args.includes("-e"));
			assert.ok(rsync.command.args.includes("ssh -p 2222"));
			assert.ok(!rsync.display.includes("--delete"));
		}
	});
});

describe("runDeployWeb", () => {
	it("dry-run prints the copy command and does not spawn", () => {
		const logs: string[] = [];
		let spawned = 0;
		const code = runDeployWeb({
			argv: ["--dry-run"],
			env: { [DEPLOY_HOST_ENV]: HOST, [DEPLOY_USER_ENV]: USER },
			platform: "linux",
			log: (line) => logs.push(line),
			logError: (line) => logs.push(line),
			spawn: () => {
				spawned += 1;
				return { status: 0, stdout: "", stderr: "", error: undefined };
			},
		});
		assert.equal(code, 0);
		assert.equal(spawned, 0);
		assert.ok(logs.some((line) => line.includes("scp") || line.includes("rsync")));
		assert.ok(logs.some((line) => line.includes("dry-run")));
	});

	it("execute copies after a real export dir exists", () => {
		const root = mkdtempSync(join(tmpdir(), "craftarena-web-deploy-"));
		writeWebLayout(join(root, EXPORT_RELATIVE_DIR));
		const logs: string[] = [];
		let spawned = 0;
		const code = runDeployWeb({
			argv: [],
			env: { [DEPLOY_HOST_ENV]: HOST, [DEPLOY_USER_ENV]: USER },
			platform: "linux",
			cwd: root,
			log: (line) => logs.push(line),
			logError: (line) => logs.push(line),
			spawn: (executable, args) => {
				spawned += 1;
				assert.equal(executable, "scp");
				assert.ok(args.includes("-r"));
				return { status: 0, stdout: "", stderr: "", error: undefined };
			},
		});
		assert.equal(code, 0);
		assert.equal(spawned, 1);
		assert.ok(logs.some((line) => line.includes('"event":"web_deploy"')));
	});
});
