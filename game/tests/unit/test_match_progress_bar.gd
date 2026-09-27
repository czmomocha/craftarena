extends GutTest

## Smoke: rail + markers construct, stay attached, child count is order-of-magnitude.

const ProgressBarGd := preload("res://src/client/match_progress_bar.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

var _shell: MatchLobbyShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_attach_finds_track_and_rebuilds_markers() -> void:
	var host: Window = Window.new()
	add_child_autofree(host)
	var bar: ProgressBarGd = ProgressBarGd.new()
	bar.attach(host)
	var root: Control = host.get_node_or_null(ProgressBarGd.ROOT_NAME) as Control
	assert_not_null(root)
	assert_not_null(root.get_node_or_null(ProgressBarGd.TRACK_NAME))
	var markers: Control = root.get_node_or_null(ProgressBarGd.MARKERS_NAME) as Control
	assert_not_null(markers)
	bar.apply({
		"play_hud_active": true,
		"progress_markers": [
			{"kind": "own", "slot": 0, "percent": 10},
			{"kind": "remote", "slot": 1, "percent": 40},
			{"kind": "ghost", "slot": -1, "percent": 80},
		],
	})
	assert_true(root.visible)
	assert_eq(markers.get_child_count(), 3)
	assert_not_null(markers.get_node_or_null(ProgressBarGd.MARKER_PREFIX + "own"))
	assert_not_null(markers.get_node_or_null(ProgressBarGd.MARKER_PREFIX + "ghost"))
	assert_not_null(markers.get_node_or_null("%sremote_1" % ProgressBarGd.MARKER_PREFIX))
	bar.attach(host)
	assert_eq(host.get_node(ProgressBarGd.ROOT_NAME), root)
	bar.apply({"play_hud_active": false})
	assert_false(root.visible)
	assert_eq(markers.get_child_count(), 0)


func test_solo_chrome_has_rail_and_own_marker() -> void:
	_shell = MatchLobbyShellGd.create()
	add_child(_shell)
	_shell.chrome.hud_settings.path = "user://hud_settings_progress_%s.json" % str(Time.get_ticks_usec())
	assert_true(_shell.open())
	assert_true(_shell.try_solo())
	var root: Control = _shell.window.get_node_or_null(ProgressBarGd.ROOT_NAME) as Control
	assert_not_null(root)
	assert_true(root.visible)
	var markers: Control = root.get_node_or_null(ProgressBarGd.MARKERS_NAME) as Control
	assert_not_null(markers)
	assert_gte(markers.get_child_count(), 1)
	assert_lte(markers.get_child_count(), 3)
	assert_not_null(markers.get_node_or_null(ProgressBarGd.MARKER_PREFIX + "own"))
