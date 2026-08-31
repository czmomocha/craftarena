/**
 * `game/project.godot` 里的「本机专属」条目检测与剔除（CD-51 §7.3）。
 *
 * 本机装了 gitignore 的 Godot AI 插件之后，编辑器每次运行都会把
 * `autoload/_mcp_game_helper` 和 `res://addons/godot_ai/plugin.cfg` 写回
 * `game/project.godot`。这个插件不在仓库里，我们改不了它的写入行为；能做的是
 * 让这两处写入**可被一条命令还原**、并且**进不了提交**。
 *
 * 纯文本编辑：不起 Godot、不解析完整 ini 语义，只认这两种行。这样它在 CI、
 * 没装插件的机器和 headless 上都能跑，并且是幂等的 —— 对已提交的干净副本执行
 * 一次得到它自己。
 */

export const PROJECT_SETTINGS_PATH = "game/project.godot";

/** 插件目录名。检测按目录而不是按固定文件名，插件换版本改文件名也拦得住。 */
export const LOCAL_ONLY_ADDON = "addons/godot_ai";

/** 插件给「试玩进程」注入的 autoload。宪法第五条与 CD-51 §7.4：它不是基础服务。 */
export const LOCAL_ONLY_AUTOLOAD = "_mcp_game_helper";

const AUTOLOAD_SECTION = "autoload";
const EDITOR_PLUGINS_SECTION = "editor_plugins";
const ENABLED_PREFIX = "enabled=";
const SECTION_PATTERN = /^\[([^\]]+)\]\s*$/;
const ENABLED_PATTERN = /^enabled=PackedStringArray\((.*)\)\s*$/;
const QUOTED_PATTERN = /"([^"]*)"/g;

export type ScrubResult = {
	/** 剔除之后的全文。没有任何本机条目时与输入完全相同。 */
	readonly text: string;
	/** 被剔除的条目键，形如 `autoload/_mcp_game_helper`。空数组 = 本来就干净。 */
	readonly removed: readonly string[];
};

/** 只问「脏不脏」。CLI 的 `--check` 与 shell-guard 都走这条。 */
export function findLocalOnlyEntries(text: string): readonly string[] {
	return scrubLocalOnly(text).removed;
}

export function scrubLocalOnly(text: string): ScrubResult {
	const eol = text.includes("\r\n") ? "\r\n" : "\n";
	const lines = text.split(/\r?\n/);
	const removed: string[] = [];
	const kept: string[] = [];
	let section = "";

	for (const line of lines) {
		const header = SECTION_PATTERN.exec(line);
		if (header !== null) {
			section = header[1] ?? "";
			kept.push(line);
			continue;
		}
		if (section === AUTOLOAD_SECTION) {
			const autoload = localOnlyAutoloadKey(line);
			if (autoload !== undefined) {
				removed.push(`${AUTOLOAD_SECTION}/${autoload}`);
				continue;
			}
		}
		if (section === EDITOR_PLUGINS_SECTION && line.startsWith(ENABLED_PREFIX)) {
			const stripped = stripLocalOnlyPlugins(line);
			if (stripped !== undefined) {
				for (const entry of stripped.dropped) {
					removed.push(`${EDITOR_PLUGINS_SECTION}/enabled/${entry}`);
				}
				kept.push(stripped.line);
				continue;
			}
		}
		kept.push(line);
	}

	if (removed.length === 0) {
		return { text, removed };
	}
	return { text: dropEmptyAutoloadSection(kept).join(eol), removed };
}

/**
 * `_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"` 这类行的键。
 * 名字命中或路径指向插件目录都算，返回 undefined 表示这行要留下。
 */
function localOnlyAutoloadKey(line: string): string | undefined {
	const separator = line.indexOf("=");
	if (separator <= 0) {
		return undefined;
	}
	const key = line.slice(0, separator).trim();
	const value = line.slice(separator + 1);
	if (key === "") {
		return undefined;
	}
	if (key === LOCAL_ONLY_AUTOLOAD || value.includes(LOCAL_ONLY_ADDON)) {
		return key;
	}
	return undefined;
}

/**
 * 从 `enabled=PackedStringArray(...)` 里摘掉指向插件目录的元素。
 * 返回 undefined 表示这行不是可识别的启用列表，原样留下比猜着改安全。
 */
function stripLocalOnlyPlugins(
	line: string,
): { readonly line: string; readonly dropped: readonly string[] } | undefined {
	const match = ENABLED_PATTERN.exec(line);
	if (match === null) {
		return undefined;
	}
	const body = match[1] ?? "";
	const entries: string[] = [];
	for (const quoted of body.matchAll(QUOTED_PATTERN)) {
		entries.push(quoted[1] ?? "");
	}
	const dropped = entries.filter((entry) => entry.includes(LOCAL_ONLY_ADDON));
	if (dropped.length === 0) {
		return undefined;
	}
	const remaining = entries.filter((entry) => !entry.includes(LOCAL_ONLY_ADDON));
	const rebuilt = remaining.map((entry) => `"${entry}"`).join(", ");
	return { line: `${ENABLED_PREFIX}PackedStringArray(${rebuilt})`, dropped };
}

/**
 * 摘掉 autoload 行之后 `[autoload]` 会剩一个空段。已提交的副本里根本没有这个段，
 * 所以连头带随后的空行一起删，让 diff 真的回到零。只对 autoload 段这么做：
 * 其他空段是不是有意留的，本工具不猜。
 */
function dropEmptyAutoloadSection(lines: readonly string[]): readonly string[] {
	const header = `[${AUTOLOAD_SECTION}]`;
	const start = lines.findIndex((line) => line.trim() === header);
	if (start === -1) {
		return lines;
	}
	let end = start + 1;
	while (end < lines.length) {
		const line = lines[end] ?? "";
		if (SECTION_PATTERN.test(line)) {
			break;
		}
		if (line.trim() !== "") {
			return lines;
		}
		end += 1;
	}
	return [...lines.slice(0, start), ...lines.slice(end)];
}
