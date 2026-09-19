class_name UiCopyChar
extends RefCounted

## 角色选择屏键。从 `UiCopy` 拆出以免那个文件超过 E9 400 行。
## 查表仍走 `UiCopy.text()`；本文件只拥有键名。
##
## 角色显示名键必须等于 `SharedCharacterCatalog.name_key(id)`，由测试钉住。
## 加一个系统角色 = 目录追加 id + 本表追加 `NAME_*` + locale 表加一行。

const TITLE: String = "craft_arena.char.title"
const SUBTITLE: String = "craft_arena.char.subtitle"
const HINT: String = "craft_arena.char.hint"
const SELECTED: String = "craft_arena.char.selected"
const BACK: String = "craft_arena.char.back"
const NAME_CAT: String = "craft_arena.char.name_cat"
const NAME_RUNNER: String = "craft_arena.char.name_runner"
const NAME_ROBOT: String = "craft_arena.char.name_robot"

const ALL_KEYS: PackedStringArray = [
	TITLE,
	SUBTITLE,
	HINT,
	SELECTED,
	BACK,
	NAME_CAT,
	NAME_RUNNER,
	NAME_ROBOT,
]
