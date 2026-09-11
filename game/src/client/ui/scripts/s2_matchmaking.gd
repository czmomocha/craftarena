extends Control
## S2 TRAPRUSH matchmaking.
##
## Both queue states from spec 2 live in the same scene so the transition can be
## animated later.  MATCH_FOUND collapses the "matching mode" and "players"
## sections and reveals the focus panel, as in the visual mockup.

enum State { WAITING, MATCH_FOUND }

@export var state: State = State.WAITING:
	set(value):
		state = value
		_apply()

@export var player_count := 4:
	set(value):
		player_count = clampi(value, 1, 8)
		_apply()

@export var solo_mode := false:
	set(value):
		solo_mode = value
		_apply()

const _RIGHT := "Layout/Main/Columns/Right"
const _TRACK_STATE_LABEL := "Layout/Main/Columns/Left/TrackList/Track1/Row/State/L"

@onready var _method_section: Control = get_node(_RIGHT + "/MethodSection")
@onready var _player_count_section: Control = get_node(_RIGHT + "/PlayerCountSection")
@onready var _waiting_panel: Control = get_node(_RIGHT + "/WaitingPanel")
@onready var _found_panel: Control = get_node(_RIGHT + "/FoundPanel")
@onready var _solo_banner: Control = get_node("Layout/SoloBanner")
@onready var _count_label: Label = get_node(_RIGHT + "/PlayerCountSection/Row/Count")
@onready var _segments: HBoxContainer = get_node(_RIGHT + "/PlayerCountSection/Row/Segments")
@onready var _track_state_label: Label = get_node(_TRACK_STATE_LABEL)


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return

	var found := state == State.MATCH_FOUND

	_method_section.visible = not found
	_player_count_section.visible = not found
	_waiting_panel.visible = not found
	_found_panel.visible = found

	# The SOLO banner is persistent whenever the offline mode is active.
	_solo_banner.visible = solo_mode

	# Spec 2: the selected track's chip flips from "已选择" to "已锁定 LOCKED"
	# once the match is found.
	if _track_state_label:
		_track_state_label.text = "已锁定 LOCKED" if found else "已选择"

	if _count_label:
		_count_label.text = str(player_count)
	if _segments:
		var i := 0
		for seg: Node in _segments.get_children():
			(seg as Control).modulate = Color.WHITE if i < player_count else Color(1, 1, 1, 0.18)
			i += 1
