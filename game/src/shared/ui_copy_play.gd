class_name UiCopyPlay
extends RefCounted

## Play HUD keys (opening countdown / replay banner). Split from `UiCopy`
## so that file stays under E9. Lookup still goes through `UiCopy.text()`.

const COUNTDOWN_WAIT: String = "craft_arena.ui.countdown_wait"
const COUNTDOWN_GO: String = "craft_arena.ui.countdown_go"
const REPLAY_BANNER: String = "craft_arena.ui.replay_banner"
const REPLAY_TITLE: String = "craft_arena.ui.replay_title"
const REPLAY_SUBTITLE: String = "craft_arena.ui.replay_subtitle"
const REPLAY_EMPTY: String = "craft_arena.ui.replay_empty"
const REPLAY_LOCAL: String = "craft_arena.ui.replay_local"
const REPLAY_ONLINE: String = "craft_arena.ui.replay_online"

const ALL_KEYS: PackedStringArray = [
	COUNTDOWN_WAIT,
	COUNTDOWN_GO,
	REPLAY_BANNER,
	REPLAY_TITLE,
	REPLAY_SUBTITLE,
	REPLAY_EMPTY,
	REPLAY_LOCAL,
	REPLAY_ONLINE,
]
