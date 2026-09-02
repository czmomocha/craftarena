class_name UiCopy
extends RefCounted

## C4 本地化键表。纠偏方案产出 6：UI 与系统文本走 `craft_arena.*` 键
## （[CD-11 §1](Confirmed-docs/10-product/11-scope-and-platforms.md)），
## 不再把中文或英文句子写进壳。
##
## 表是 CSV，不是 Godot 的 Translation 导入产物：`.csv` 默认会被当成
## 翻译资源，Headless / 导出包对不上同一套 remap。本文件自己解析，
## `FileAccess` 读 `res://content/locale/craft_arena.csv`，导出预设必须
## 把它写进 `include_filter`（和官方课 JSON 同一类：不是引擎资源）。
##
## 语言：`zh_CN` 与 `en`（`localization_scope = zh_en`）。当前 locale 以
## `TranslationServer.get_locale()` 为准，`zh*` 归一到 `zh_CN`，其余落到
## `en`。缺键返回键名本身，好让漏翻立刻可见。
##
## **不入字体**。D4 拍了思源黑体 / Noto Sans SC 子集化入包，但那是新增
## 第三方资产与许可证（宪法第十八条），且子集范围会决定公开未过滤昵称
## 会不会变成豆腐块。本刀只锁键。
##
## 不翻译的：开发期状态行（`join=` / `pads=` / `FPS`）、节点名、课程 id、
## 错误码、表现动画状态名。那些是契约标识，不是给玩家读的句子。
##
## 放 `shared/`：大厅与 Editor / Preview 必须读同一份。`simulation/` 不引用。

const TABLE_PATH: String = "res://content/locale/craft_arena.csv"
const FALLBACK_LOCALE: String = "en"
const ZH_LOCALE: String = "zh_CN"

const WINDOW_TRAPRUSH: String = "craft_arena.ui.window_traprush"
const WINDOW_EDITOR: String = "craft_arena.ui.window_editor"
const WINDOW_PREVIEW: String = "craft_arena.ui.window_preview"
const QUICK_PLAY: String = "craft_arena.ui.quick_play"
const CREATE_ROOM: String = "craft_arena.ui.create_room"
const JOIN_ROOM: String = "craft_arena.ui.join_room"
const SOLO_PLAY: String = "craft_arena.ui.solo_play"
const CANCEL: String = "craft_arena.ui.cancel"
const POLL: String = "craft_arena.ui.poll"
const SPRINT: String = "craft_arena.ui.sprint"
const APPLY_SERVER: String = "craft_arena.ui.apply_server"
const SERVER_HOST: String = "craft_arena.ui.server_host"
const ROOM_CODE: String = "craft_arena.ui.room_code"
const OFFLINE_BANNER: String = "craft_arena.ui.offline_banner"
const UNDO: String = "craft_arena.ui.undo"
const REDO: String = "craft_arena.ui.redo"
const PREVIEW: String = "craft_arena.ui.preview"
const PLAY: String = "craft_arena.ui.play"
const STOP: String = "craft_arena.ui.stop"
const RESET: String = "craft_arena.ui.reset"
const USE_ITEM: String = "craft_arena.ui.use_item"
const JUMP: String = "craft_arena.ui.jump"
const ADVANCE_TICK: String = "craft_arena.ui.advance_tick"
const PLACE_CHECKPOINT: String = "craft_arena.ui.place_checkpoint"
const PLACE_PORTAL: String = "craft_arena.ui.place_portal"
const REMOVE_LAST: String = "craft_arena.ui.remove_last"
const PLACE_SOLID: String = "craft_arena.ui.place_solid"
const PLACE_HAZARD: String = "craft_arena.ui.place_hazard"
const PLACE_CRATE: String = "craft_arena.ui.place_crate"
const PLACE_FINISH: String = "craft_arena.ui.place_finish"
const FLOOR_UP: String = "craft_arena.ui.floor_up"
const FLOOR_DOWN: String = "craft_arena.ui.floor_down"
const FOCUS_ISSUE: String = "craft_arena.ui.focus_issue"

const ALL_KEYS: PackedStringArray = [
	WINDOW_TRAPRUSH,
	WINDOW_EDITOR,
	WINDOW_PREVIEW,
	QUICK_PLAY,
	CREATE_ROOM,
	JOIN_ROOM,
	SOLO_PLAY,
	CANCEL,
	POLL,
	SPRINT,
	APPLY_SERVER,
	SERVER_HOST,
	ROOM_CODE,
	OFFLINE_BANNER,
	UNDO,
	REDO,
	PREVIEW,
	PLAY,
	STOP,
	RESET,
	USE_ITEM,
	JUMP,
	ADVANCE_TICK,
	PLACE_CHECKPOINT,
	PLACE_PORTAL,
	REMOVE_LAST,
	PLACE_SOLID,
	PLACE_HAZARD,
	PLACE_CRATE,
	PLACE_FINISH,
	FLOOR_UP,
	FLOOR_DOWN,
	FOCUS_ISSUE,
]

static var _loaded: bool = false
static var _tables: Dictionary = {}


static func ensure_loaded() -> bool:
	if _loaded:
		return not _tables.is_empty()
	_loaded = true
	_tables = {}
	if not FileAccess.file_exists(TABLE_PATH):
		return false
	var file: FileAccess = FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	_tables = _parse_csv(text)
	return not _tables.is_empty()


static func reset_for_tests() -> void:
	_loaded = false
	_tables = {}


static func text(key: String, locale: String = "") -> String:
	ensure_loaded()
	var loc: String = locale if locale != "" else effective_locale()
	var table_raw: Variant = _tables.get(loc, {})
	if typeof(table_raw) == TYPE_DICTIONARY:
		var table: Dictionary = table_raw
		if table.has(key):
			return str(table[key])
	if loc != FALLBACK_LOCALE:
		var fallback_raw: Variant = _tables.get(FALLBACK_LOCALE, {})
		if typeof(fallback_raw) == TYPE_DICTIONARY:
			var fallback: Dictionary = fallback_raw
			if fallback.has(key):
				return str(fallback[key])
	return key


static func effective_locale() -> String:
	var loc: String = TranslationServer.get_locale()
	if loc.begins_with("zh"):
		return ZH_LOCALE
	if _tables.has(loc):
		return loc
	return FALLBACK_LOCALE


static func has_locale(locale: String) -> bool:
	ensure_loaded()
	return _tables.has(locale)


static func _parse_csv(text: String) -> Dictionary:
	var tables: Dictionary = {}
	var rows: Array[PackedStringArray] = _split_csv(text)
	if rows.is_empty():
		return tables
	var header: PackedStringArray = rows[0]
	if header.size() < 2 or header[0] != "keys":
		return tables
	for col: int in range(1, header.size()):
		tables[header[col]] = {}
	for row_index: int in range(1, rows.size()):
		var row: PackedStringArray = rows[row_index]
		if row.is_empty():
			continue
		var key: String = row[0].strip_edges()
		if key == "" or key.begins_with("#"):
			continue
		for col: int in range(1, mini(row.size(), header.size())):
			var locale: String = header[col]
			var bag_raw: Variant = tables.get(locale, {})
			if typeof(bag_raw) != TYPE_DICTIONARY:
				continue
			var bag: Dictionary = bag_raw
			bag[key] = row[col]
	return tables


static func _split_csv(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var fields: PackedStringArray = PackedStringArray()
	var field: String = ""
	var in_quotes: bool = false
	var source: String = text.replace("\r\n", "\n").replace("\r", "\n")
	if source.begins_with("\uFEFF"):
		source = source.substr(1)
	var i: int = 0
	while i < source.length():
		var ch: String = source.substr(i, 1)
		if in_quotes:
			if ch == "\"":
				if i + 1 < source.length() and source.substr(i + 1, 1) == "\"":
					field += "\""
					i += 2
					continue
				in_quotes = false
				i += 1
				continue
			field += ch
			i += 1
			continue
		if ch == "\"":
			in_quotes = true
			i += 1
			continue
		if ch == ",":
			fields.append(field)
			field = ""
			i += 1
			continue
		if ch == "\n":
			fields.append(field)
			if not _row_is_blank(fields):
				rows.append(fields)
			fields = PackedStringArray()
			field = ""
			i += 1
			continue
		field += ch
		i += 1
	if in_quotes or field != "" or not fields.is_empty():
		fields.append(field)
		if not _row_is_blank(fields):
			rows.append(fields)
	return rows


static func _row_is_blank(fields: PackedStringArray) -> bool:
	if fields.is_empty():
		return true
	if fields.size() == 1 and fields[0] == "":
		return true
	return false
