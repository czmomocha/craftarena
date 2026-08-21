import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import { applyDotEnv, mergeDotEnv, parseDotEnv } from "../src/dotenv_file.ts";
import { setupWorktree } from "../src/setup_worktree.ts";
import { BASE_PORTS, hashSlot, portsForSlot, worktreeSlot } from "../src/worktree_ports.ts";

describe("worktree port slots", () => {
	it("keeps the primary checkout on slot 0", () => {
		assert.equal(worktreeSlot("/repo/craftarena", "/repo/craftarena", {}), 0);
		assert.deepEqual(portsForSlot(0).CONTROL_PLANE_PORT, BASE_PORTS.controlPlane);
	});

	it("hashes a worktree name into 1..9 and honors WORKTREE_SLOT", () => {
		const slot = hashSlot("sim-core");
		assert.ok(slot >= 1 && slot <= 9);
		assert.equal(hashSlot("sim-core"), slot);
		assert.equal(worktreeSlot("/tmp/sim-core", "/repo/craftarena", { WORKTREE_SLOT: "3" }), 3);
	});

	it("keeps slot 1 ports off the default service ports", () => {
		const ports = portsForSlot(1);
		assert.equal(ports.CONTROL_PLANE_PORT, BASE_PORTS.controlPlane + 100);
		assert.equal(ports.GATEWAY_PORT, BASE_PORTS.gateway + 100);
		assert.equal(ports.MATCH_HOST_PORT, BASE_PORTS.matchHost + 100);
		assert.equal(ports.CONTROL_PLANE_URL, "http://127.0.0.1:8180");
		assert.notEqual(ports.CONTROL_PLANE_PORT, BASE_PORTS.gateway);
	});
});

describe("dotenv helpers", () => {
	it("does not override an already-set variable", () => {
		const env: NodeJS.ProcessEnv = { EXISTING: "preset" };
		applyDotEnv("EXISTING=fromfile\nNEW=1\n", env);
		assert.equal(env["EXISTING"], "preset");
		assert.equal(env["NEW"], "1");
	});

	it("overwrites port keys when merging a generated map", () => {
		const merged = mergeDotEnv("KEEP=yes\nCONTROL_PLANE_PORT=8080\n", {
			CONTROL_PLANE_PORT: "8180",
			GATEWAY_PORT: "8190",
		});
		const parsed = parseDotEnv(merged);
		assert.equal(parsed["KEEP"], "yes");
		assert.equal(parsed["CONTROL_PLANE_PORT"], "8180");
		assert.equal(parsed["GATEWAY_PORT"], "8190");
	});
});

describe("setupWorktree", () => {
	it("installs, copies optional local files, writes ports, and imports Godot", async () => {
		const root = mkdtempSync(join(tmpdir(), "craftarena-root-"));
		const cwd = mkdtempSync(join(tmpdir(), "craftarena-wt-"));
		writeFileSync(join(root, ".env"), "KEEP_ME=yes\n");
		mkdirSync(join(root, "data"));
		writeFileSync(join(root, "data/control-plane.sqlite"), "db");

		const commands: string[][] = [];
		const result = await setupWorktree({
			cwd,
			rootWorktreePath: root,
			env: { GODOT4: "/opt/godot" },
			platform: "linux",
			runCommand: async (command, args) => {
				commands.push([command, ...args]);
				return { code: 0 };
			},
		});

		assert.notEqual(result.slot, 0);
		assert.equal(result.wroteEnv, true);
		assert.equal(existsSync(join(cwd, "data/control-plane.sqlite")), true);
		const env = parseDotEnv(readFileSync(join(cwd, ".env"), "utf8"));
		assert.equal(env["KEEP_ME"], "yes");
		assert.equal(env["CONTROL_PLANE_PORT"], String(result.ports.CONTROL_PLANE_PORT));
		assert.ok(commands.some((command) => command[0] === "npm" && command[1] === "install"));
		assert.ok(commands.some((command) => command.includes("--import")));
	});

	it("does not rewrite .env on the primary checkout", async () => {
		const cwd = mkdtempSync(join(tmpdir(), "craftarena-main-"));
		const result = await setupWorktree({
			cwd,
			rootWorktreePath: cwd,
			env: { GODOT4: "/opt/godot" },
			platform: "linux",
			runCommand: async () => ({ code: 0 }),
		});
		assert.equal(result.slot, 0);
		assert.equal(result.wroteEnv, false);
		assert.equal(existsSync(join(cwd, ".env")), false);
	});

	it("fails when GODOT4 is missing", async () => {
		const cwd = mkdtempSync(join(tmpdir(), "craftarena-nogodot-"));
		await assert.rejects(
			setupWorktree({
				cwd,
				rootWorktreePath: undefined,
				env: {},
				platform: "linux",
				runCommand: async () => ({ code: 0 }),
			}),
			/GODOT4 is not set/,
		);
	});
});
