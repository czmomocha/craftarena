extends GutTest

## C4 表现动画状态契约：状态名 + 优先级。不播 clip、不锁时长、不改协议。

const PlayAnimStateGd := preload("res://src/shared/play_anim_state.gd")
const MatchSnapshotMap := preload("res://src/client/match_snapshot_map.gd")

const CELL: int = 65536


func test_names_are_the_locked_set() -> void:
	var expected: PackedStringArray = [
		"idle",
		"run",
		"jump",
		"land",
		"shove",
		"hit",
		"break",
		"portal",
	]
	assert_eq(PlayAnimStateGd.NAMES, expected)
	for name: String in expected:
		assert_true(PlayAnimStateGd.contains(name), name)
	assert_false(PlayAnimStateGd.contains("sprint"))
	assert_false(PlayAnimStateGd.contains("fall"))
	assert_false(PlayAnimStateGd.contains(""))


func test_priority_hit_beats_everything() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(true, true, true, true, true, true)),
		PlayAnimStateGd.HIT
	)


func test_priority_portal_then_airborne_then_actions() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, true, false, true, true, true)),
		PlayAnimStateGd.PORTAL
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(true, true, false, false, true, true)),
		PlayAnimStateGd.JUMP
	)
	resolver.reset()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, true, false, false, true, true)),
		PlayAnimStateGd.SHOVE
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, true, false, false, false, true)),
		PlayAnimStateGd.BREAK
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, true, false, false, false, false)),
		PlayAnimStateGd.RUN
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, false, false, false, false, false)),
		PlayAnimStateGd.IDLE
	)


func test_land_fires_once_when_airborne_ends() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(true, false, false, false, false, false)),
		PlayAnimStateGd.JUMP
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, false, false, false, false, false)),
		PlayAnimStateGd.LAND
	)
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, false, false, false, false, false)),
		PlayAnimStateGd.IDLE
	)


func test_spawn_grounded_is_idle_not_land() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(resolver.resolve(PlayAnimStateGd.empty_facts()), PlayAnimStateGd.IDLE)


func test_airborne_uses_contact_not_jump_support() -> void:
	assert_eq(PlayAnimStateGd.CONTACT_DY, -PlaceholderSpec.CELL / 2)
	assert_true(PlayAnimStateGd.is_airborne(1, true))
	assert_true(PlayAnimStateGd.is_airborne(0, false))
	assert_false(PlayAnimStateGd.is_airborne(0, true))
	assert_true(PlayAnimStateGd.is_airborne(-1, true))


func test_missing_facts_do_not_invent_airborne() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(resolver.resolve({}), PlayAnimStateGd.IDLE)


func test_reset_clears_airborne_memory() -> void:
	var resolver: PlayAnimStateGd = PlayAnimStateGd.new()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(true, false, false, false, false, false)),
		PlayAnimStateGd.JUMP
	)
	resolver.reset()
	assert_eq(
		resolver.resolve(PlayAnimStateGd.facts(false, false, false, false, false, false)),
		PlayAnimStateGd.IDLE
	)


func test_snapshot_map_writes_metadata_and_label() -> void:
	var map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(map)
	assert_true(map.apply_players([_player(0, 0, 0, 0)]))
	assert_eq(map.anim_state(0), "")
	assert_null(map.anim_node(0))
	assert_true(map.set_anim_state(0, PlayAnimStateGd.RUN))
	assert_eq(map.anim_state(0), PlayAnimStateGd.RUN)
	var label: Label3D = map.anim_node(0)
	assert_not_null(label)
	assert_eq(label.text, PlayAnimStateGd.RUN)
	assert_true(map.set_anim_state(0, PlayAnimStateGd.JUMP))
	assert_eq(map.anim_node(0), label)
	assert_eq(label.text, PlayAnimStateGd.JUMP)
	assert_false(map.set_anim_state(0, "sprint"))
	assert_eq(map.anim_state(0), PlayAnimStateGd.JUMP)
	assert_false(map.set_anim_state(3, PlayAnimStateGd.IDLE))


func test_reused_player_node_keeps_anim_child() -> void:
	var map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(map)
	assert_true(map.apply_players([_player(0, 0, 0, 0)]))
	assert_true(map.set_anim_state(0, PlayAnimStateGd.IDLE))
	var label: Label3D = map.anim_node(0)
	var player: MeshInstance3D = map.player_node(0)
	assert_true(map.apply_players([_player(CELL, 0, 0, 0)]))
	assert_eq(map.player_node(0), player)
	assert_eq(map.anim_node(0), label)
	assert_eq(map.anim_state(0), PlayAnimStateGd.IDLE)


func _player(x: int, y: int, z: int, yaw_bam: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": yaw_bam,
		"accepted_count": 0,
		"finish_tick": -1,
	}
