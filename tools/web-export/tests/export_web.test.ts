import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import { runExportWeb, webExportGodotArgs } from "../src/export_web.ts";
import { resolveGodotExecutable } from "../src/godot.ts";
import { verifyWebExportDir } from "../src/verify.ts";

function spawnOk(): () => { status: number; stdout: string; stderr: string; error: undefined } {
	return () => ({ status: 0, stdout: "export ok\n", stderr: "", error: undefined });
}

function writeWebLayout(dir: string): void {
	mkdirSync(dir, { recursive: true });
	writeFileSync(join(dir, "index.html"), "<html></html>\n");
	writeFileSync(join(dir, "index.js"), "print();\n");
	writeFileSync(join(dir, "index.wasm"), "wasm\n");
	writeFileSync(join(dir, "index.pck"), "pck\n");
}

describe("resolveGodotExecutable", () => {
	it("prefers GODOT4_CONSOLE on Windows", () => {
		const resolved = resolveGodotExecutable(
			{ GODOT4_CONSOLE: "C:\\godot\\godot.console.exe", GODOT4: "C:\\godot\\godot.exe" },
			"win32",
		);
		assert.equal(resolved.source, "GODOT4_CONSOLE");
		assert.equal(resolved.executable, "C:\\godot\\godot.console.exe");
	});

	it("does not fall back to PATH", () => {
		assert.throws(() => resolveGodotExecutable({}, "linux"), /GODOT4 must point/);
	});
});

describe("webExportGodotArgs", () => {
	it("matches the README Web export line", () => {
		assert.deepEqual(webExportGodotArgs(), [
			"--headless",
			"--path",
			"game",
			"--export-release",
			"Web",
			"../export/web/index.html",
		]);
	});
});

describe("verifyWebExportDir", () => {
	it("accepts a Godot Web layout and rejects an empty dir", () => {
		const root = mkdtempSync(join(tmpdir(), "craftarena-web-export-"));
		assert.equal(verifyWebExportDir(root).ok, false);
		const dir = join(root, "web");
		writeWebLayout(dir);
		const verified = verifyWebExportDir(dir);
		assert.equal(verified.ok, true);
		if (verified.ok) {
			assert.ok(verified.files.includes("index.html"));
			assert.ok(verified.files.includes("index.wasm"));
		}
	});
});

describe("runExportWeb", () => {
	it("dry-run prints the engine command and does not spawn", () => {
		const logs: string[] = [];
		let spawned = 0;
		const code = runExportWeb({
			argv: ["--dry-run"],
			env: { GODOT4: "/usr/bin/godot" },
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
		assert.ok(logs.some((line) => line.includes("--export-release Web")));
		assert.ok(logs.some((line) => line.includes("dry-run")));
	});

	it("refuses a spawn that leaves no wasm", () => {
		const root = mkdtempSync(join(tmpdir(), "craftarena-web-export-"));
		const errors: string[] = [];
		const code = runExportWeb({
			argv: [],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			cwd: root,
			mkdir: () => {},
			spawn: spawnOk(),
			log: () => {},
			logError: (line) => errors.push(line),
		});
		assert.equal(code, 1);
		assert.ok(errors.some((line) => line.includes(".wasm") || line.includes("missing")));
	});

	it("returns 0 when Godot writes html/js/wasm/pck", () => {
		const root = mkdtempSync(join(tmpdir(), "craftarena-web-export-"));
		const logs: string[] = [];
		const code = runExportWeb({
			argv: [],
			env: { GODOT4: "/usr/bin/godot" },
			platform: "linux",
			cwd: root,
			mkdir: (dir) => {
				writeWebLayout(dir);
				assert.ok(dir.replaceAll("\\", "/").endsWith("export/web"));
			},
			spawn: spawnOk(),
			log: (line) => logs.push(line),
			logError: (line) => logs.push(line),
		});
		assert.equal(code, 0);
		assert.ok(logs.some((line) => line.includes('"event":"web_export"')));
	});
});
