import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

import {
	LOCAL_ONLY_ADDON,
	LOCAL_ONLY_AUTOLOAD,
	PROJECT_SETTINGS_PATH,
	findLocalOnlyEntries,
	scrubLocalOnly,
} from "../src/local_only.ts";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "../../..");

const CLEAN = [
	"config_version=5",
	"",
	"[application]",
	"",
	'run/main_scene="res://src/client/main.tscn"',
	'config/features=PackedStringArray("4.7", "GL Compatibility")',
	"",
	"[debug]",
	"",
	"gdscript/warnings/untyped_declaration=2",
	"",
	"[editor_plugins]",
	"",
	'enabled=PackedStringArray("res://addons/gut/plugin.cfg", "res://addons/authoring_editor/plugin.cfg")',
	"",
].join("\n");

const POLLUTED = [
	"config_version=5",
	"",
	"[application]",
	"",
	'run/main_scene="res://src/client/main.tscn"',
	'config/features=PackedStringArray("4.7", "GL Compatibility")',
	"",
	"[autoload]",
	"",
	'_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"',
	"",
	"[debug]",
	"",
	"gdscript/warnings/untyped_declaration=2",
	"",
	"[editor_plugins]",
	"",
	'enabled=PackedStringArray("res://addons/gut/plugin.cfg", "res://addons/authoring_editor/plugin.cfg", "res://addons/godot_ai/plugin.cfg")',
	"",
].join("\n");

describe("godot-project-settings finds machine-local entries", () => {
	it("reports both the autoload and the enabled plugin entry", () => {
		assert.deepEqual(findLocalOnlyEntries(POLLUTED), [
			`autoload/${LOCAL_ONLY_AUTOLOAD}`,
			`editor_plugins/enabled/res://${LOCAL_ONLY_ADDON}/plugin.cfg`,
		]);
	});

	it("reports nothing for a clean file", () => {
		assert.deepEqual(findLocalOnlyEntries(CLEAN), []);
	});

	it("catches a renamed autoload that still points into the addon directory", () => {
		const renamed = POLLUTED.replace(
			`${LOCAL_ONLY_AUTOLOAD}=`,
			"_godot_ai_helper=",
		);
		assert.deepEqual(findLocalOnlyEntries(renamed), [
			"autoload/_godot_ai_helper",
			`editor_plugins/enabled/res://${LOCAL_ONLY_ADDON}/plugin.cfg`,
		]);
	});

	it("keeps an unrelated autoload that a later chapter may add on purpose", () => {
		const other = POLLUTED.replace(
			'_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"',
			'GameClock="*res://src/client/game_clock.gd"',
		);
		assert.deepEqual(findLocalOnlyEntries(other), [
			`editor_plugins/enabled/res://${LOCAL_ONLY_ADDON}/plugin.cfg`,
		]);
	});
});

describe("godot-project-settings scrubs back to the committed shape", () => {
	it("removes the autoload line, the now-empty section, and the plugin entry", () => {
		const result = scrubLocalOnly(POLLUTED);
		assert.equal(result.removed.length, 2);
		assert.equal(result.text, CLEAN);
	});

	it("is idempotent", () => {
		const once = scrubLocalOnly(POLLUTED);
		const twice = scrubLocalOnly(once.text);
		assert.deepEqual(twice.removed, []);
		assert.equal(twice.text, once.text);
	});

	it("leaves a clean file byte-identical", () => {
		const result = scrubLocalOnly(CLEAN);
		assert.deepEqual(result.removed, []);
		assert.equal(result.text, CLEAN);
	});

	it("preserves CRLF line endings", () => {
		const result = scrubLocalOnly(POLLUTED.split("\n").join("\r\n"));
		assert.equal(result.text, CLEAN.split("\n").join("\r\n"));
	});

	it("keeps a non-empty autoload section", () => {
		const mixed = POLLUTED.replace(
			"[autoload]\n\n_mcp_game_helper",
			'[autoload]\n\nGameClock="*res://src/client/game_clock.gd"\n_mcp_game_helper',
		);
		const result = scrubLocalOnly(mixed);
		assert.ok(result.text.includes("[autoload]"));
		assert.ok(result.text.includes("GameClock="));
		assert.ok(!result.text.includes(LOCAL_ONLY_AUTOLOAD));
	});

	it("empties the enabled array rather than dropping the key", () => {
		const only = POLLUTED.replace(
			'enabled=PackedStringArray("res://addons/gut/plugin.cfg", "res://addons/authoring_editor/plugin.cfg", "res://addons/godot_ai/plugin.cfg")',
			'enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")',
		);
		assert.ok(scrubLocalOnly(only).text.includes("enabled=PackedStringArray()"));
	});
});

describe("the committed project.godot stays clean", () => {
	// CD-51 §7.4：`_mcp_game_helper` 只允许存在于未提交的本机副本。GUT 那条
	// （test_authoring_editor_plugin / test_package_check）读的是运行中的
	// ProjectSettings；这条读的是磁盘上的文件，所以不装 Godot 也能跑。
	it("has no Godot AI entry on disk", () => {
		const text = readFileSync(join(REPO_ROOT, PROJECT_SETTINGS_PATH), "utf8");
		assert.deepEqual(
			findLocalOnlyEntries(text),
			[],
			`${PROJECT_SETTINGS_PATH} 带着本机 Godot AI 条目，跑 \`npm run godot-settings:scrub\` 还原`,
		);
	});
});
