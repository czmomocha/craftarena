class_name UiCopyS1
extends RefCounted

## S1 主大厅键。从 `UiCopy` 拆出以免那个文件超过 E9 400 行。
## 查表仍走 `UiCopy.text()`；本文件只拥有键名。

const BRAND_SUBTITLE: String = "craft_arena.s1.brand_subtitle"
const CHIP_OPEN: String = "craft_arena.s1.chip_open"
const TRAPRUSH_TITLE: String = "craft_arena.s1.traprush_title"
const TRAPRUSH_DESC: String = "craft_arena.s1.traprush_desc"
const ENTER: String = "craft_arena.s1.enter"
const BASTION_TITLE: String = "craft_arena.s1.bastion_title"
const BASTION_DESC: String = "craft_arena.s1.bastion_desc"
const NAV_CHARACTER: String = "craft_arena.s1.nav_character"
const NAV_REPLAY: String = "craft_arena.s1.nav_replay"
const NAV_MY_CONTENT: String = "craft_arena.s1.nav_my_content"
const NAV_WORKSHOP: String = "craft_arena.s1.nav_workshop"
const NAV_SETTINGS: String = "craft_arena.s1.nav_settings"
const STATUS_ONLINE: String = "craft_arena.s1.status_online"

const ALL_KEYS: PackedStringArray = [
	BRAND_SUBTITLE,
	CHIP_OPEN,
	TRAPRUSH_TITLE,
	TRAPRUSH_DESC,
	ENTER,
	BASTION_TITLE,
	BASTION_DESC,
	NAV_CHARACTER,
	NAV_REPLAY,
	NAV_MY_CONTENT,
	NAV_WORKSHOP,
	NAV_SETTINGS,
	STATUS_ONLINE,
]
