extends GutTest

## M6 E4: BASTION client shell. Placeholder gadgets are smoke only
## (construct, hang children, order-of-magnitude counts). No colour
## asserts. Interact encodes then waits; the field map does not spawn
## a tower until the next authoritative snapshot says so.

const BastionFieldMapGd := preload("res://src/client/bastion_field_map.gd")
const BastionFrameCodec := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const BastionHudGd := preload("res://src/client/bastion_hud.gd")
const BastionInteractGd := preload("res://src/client/bastion_interact.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionSnapshotFollowGd := preload("res://src/client/bastion_snapshot_follow.gd")
const CatalogGd := preload("res://src/ugc/bastion_prototype_catalog.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const MatchLobbyRuntimeGd := preload("res://src/client/match_lobby_runtime.gd")
const MatchLobbyShell := preload("res://src/client/match_lobby_shell.gd")
const MatchLobbyStageBastionGd := preload("res://src/client/match_lobby_stage_bastion.gd")
const MatchPlaySession := preload("res://src/client/match_play_session.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const OfficialBlueprints := preload("res://src/shared/official_bastion_blueprints.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const Priorities := preload("res://src/shared/schema/tower_target_priorities.gd")

const BLUEPRINT_PATH: String = "res://content/official/bastion/blueprint_01.json"
const TEAM_A: int = 1
const TEAM_B: int = 2

var _shell: MatchLobbyShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_official_blueprint_field_map_constructs_without_live_overlay() -> void:
	var field: BastionFieldMapGd = _mounted_field()
	assert_true(field.apply_path(BLUEPRINT_PATH))
	assert_eq(field.core_count(), 2)
	assert_eq(field.build_slot_count(), 6)
	assert_eq(field.obstacle_slot_count(), 6)
	assert_gte(field.path_count(), 6)
	assert_eq(field.tower_count(), 0)
	assert_eq(field.unit_count(), 0)
	assert_eq(field.obstacle_count(), 0)
	var static_root: Node = field.get_node("StaticField")
	assert_not_null(static_root)
	assert_gt(static_root.get_child_count(), 0)
	var first_host: Node3D = static_root.get_child(0) as Node3D
	assert_not_null(OccupancyGadget.gadget_node(first_host))


func test_follow_ignores_older_ticks_and_maps_live_nodes() -> void:
	var field: BastionFieldMapGd = _mounted_field()
	assert_true(field.apply_path(BLUEPRINT_PATH))
	var slot_id: int = _first_build_slot(field.bundle)
	var node_id: int = _first_obstacle_node(field.bundle)
	var follow: BastionSnapshotFollowGd = BastionSnapshotFollowGd.new()
	assert_true(follow.apply_frame(_snap(4, BastionMatchSession.PHASE_PREP, _teams(
		[{
			"slot_id": slot_id,
			"prototype_id": CatalogGd.TOWER_ARROW,
			"level": 1,
			"target_priority": Priorities.FRONT,
			"cooldown_left": 0,
		}],
		[{
			"unit_id": 7,
			"prototype_id": CatalogGd.UNIT_SWIFT,
			"health": 4,
			"x": 0,
			"y": 0,
			"z": 0,
		}],
		[{"node_id": node_id, "prototype_id": CatalogGd.OBSTACLE_BARRICADE}]
	))))
	assert_false(follow.apply_frame(_snap(3, BastionMatchSession.PHASE_PREP, _teams([], [], []))))
	assert_eq(follow.tick, 4)
	assert_true(field.apply_follow(follow))
	assert_eq(field.tower_count(), 1)
	assert_eq(field.unit_count(), 1)
	assert_eq(field.obstacle_count(), 1)
	assert_eq(field.apply_count(), 1)


func test_interact_encodes_without_spawning_a_local_tower() -> void:
	var field: BastionFieldMapGd = _mounted_field()
	assert_true(field.apply_path(BLUEPRINT_PATH))
	var slot_id: int = _first_build_slot(field.bundle)
	var interact: BastionInteractGd = BastionInteractGd.new()
	assert_true(interact.try_select(BastionInteractGd.KIND_BUILD, slot_id))
	var bytes: PackedByteArray = interact.encode_prototype(CatalogGd.TOWER_ARROW)
	assert_gt(bytes.size(), 0)
	var decoded: Dictionary = BastionFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_true(decoded_ok)
	assert_eq(str(decoded.get("intent", "")), PlayerIntentNames.BUILD_TOWER)
	var arg0: int = decoded.get("arg0", 0)
	var arg1: int = decoded.get("arg1", 0)
	assert_eq(arg0, slot_id)
	assert_eq(arg1, CatalogGd.TOWER_ARROW)
	assert_eq(field.tower_count(), 0)
	var lock: PackedByteArray = interact.encode_lock()
	var lock_decoded: Dictionary = BastionFrameCodec.decode_command(lock)
	assert_eq(str(lock_decoded.get("intent", "")), PlayerIntentNames.LOCK_SETUP)


func test_hud_tokens_and_setup_clip_only_draw_visible_obstacles() -> void:
	var field: BastionFieldMapGd = _mounted_field()
	assert_true(field.apply_path(BLUEPRINT_PATH))
	var own_node: int = _first_obstacle_node(field.bundle)
	var other_node: int = _other_team_obstacle_node(field.bundle)
	var teams: Array[Dictionary] = _teams(
		[],
		[],
		[{"node_id": own_node, "prototype_id": CatalogGd.OBSTACLE_BARRICADE}]
	)
	teams[1]["obstacles"] = [{"node_id": other_node, "prototype_id": CatalogGd.OBSTACLE_SLOW_TILE}]
	var clipped: PackedByteArray = BastionFrameCodec.encode_snapshot(
		2, BastionMatchSession.PHASE_SETUP, 0, 0, teams, TEAM_A
	)
	var follow: BastionSnapshotFollowGd = BastionSnapshotFollowGd.new()
	assert_true(follow.apply_frame(clipped))
	var other: Dictionary = follow.team_of(TEAM_B)
	var hidden: Array = other.get("obstacles", [])
	assert_eq(hidden.size(), 0)
	assert_true(field.apply_follow(follow))
	assert_eq(field.obstacle_count(), 1)
	var view: Dictionary = BastionHudGd.view_from_follow(follow, TEAM_A, 5, 12)
	var active: bool = view.get("active", false)
	assert_true(active)
	var parts: PackedStringArray = PackedStringArray()
	BastionHudGd.append_play(parts, view)
	var line: String = " ".join(parts)
	assert_true(line.contains("phase=setup"))
	assert_true(line.contains("remain=12"))
	assert_true(line.contains("cores=100/100"))
	assert_true(line.contains("gold=200"))
	assert_true(line.contains("wave=0/5"))
	assert_true(line.contains("leaked=0/0"))


func test_lobby_course_id_blueprint_01_quick_play_follows_type_6() -> void:
	_shell = MatchLobbyShell.create()
	add_child(_shell)
	assert_true(_shell.open())
	_shell.set_course_id_text(OfficialBlueprints.DEFAULT_ID)
	assert_eq(_shell.selected_course_id(), OfficialBlueprints.DEFAULT_ID)
	assert_false(_shell.try_solo())
	assert_eq(_shell.offline.last_error, "unknown_course")
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("blueprint_01"))
	assert_true(_shell.join.pending_body().contains("bastion"))
	assert_false(_shell.join.pending_body().contains("course"))
	assert_true(_shell.accept_http(201, {
		"roomCode": "B1ROOM",
		"ticket": "ticket-b1",
		"matchId": "match-b1",
		"expiresAt": "2026-09-16T03:00:00.000Z",
		"seats": 2,
		"issued": 1,
		"seat": 0,
		"course": null,
		"gameplay": MatchGameplayGd.BASTION,
		"blueprint": OfficialBlueprints.DEFAULT_ID,
	}))
	assert_true(_shell.play.is_bastion())
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	var field: BastionFieldMapGd = MatchLobbyStageBastionGd.field_of(_shell)
	assert_not_null(field)
	assert_true(field.visible)
	assert_eq(field.core_count(), 2)
	assert_true(_shell.on_socket_open())
	var slot_id: int = _first_build_slot(field.bundle)
	assert_true(_shell.on_binary(_snap(8, BastionMatchSession.PHASE_PREP, _teams(
		[{
			"slot_id": slot_id,
			"prototype_id": CatalogGd.TOWER_CANNON,
			"level": 2,
			"target_priority": Priorities.FRONT,
			"cooldown_left": 0,
		}],
		[],
		[]
	))))
	assert_eq(_shell.play.bastion.tick, 8)
	assert_eq(field.tower_count(), 1)
	assert_true(_shell.status_label_text().contains("phase=prep"))
	assert_true(_shell.status_label_text().contains("gold=200"))
	assert_true(_shell.status_label_text().contains("cores=100/100"))
	assert_false(_shell.status_label_text().contains("pads="))
	var interact: BastionInteractGd = MatchLobbyStageBastionGd.interact_of(_shell)
	assert_true(interact.try_select(BastionInteractGd.KIND_BUILD, slot_id))
	assert_true(MatchLobbyRuntimeGd.try_key(_shell, KEY_U))
	var upgrade: Dictionary = BastionFrameCodec.decode_command(_shell.last_sent_command)
	assert_eq(str(upgrade.get("intent", "")), PlayerIntentNames.UPGRADE_TOWER)
	assert_eq(field.tower_count(), 1)


func _mounted_field() -> BastionFieldMapGd:
	var field: BastionFieldMapGd = BastionFieldMapGd.new()
	add_child_autofree(field)
	field.ensure_rig()
	return field


func _first_build_slot(bundle: BastionBlueprintBundle) -> int:
	assert_not_null(bundle)
	assert_gt(bundle.build_slots.size(), 0)
	var slot: Dictionary = bundle.build_slots[0]
	return _i(slot, "entity_id")


func _first_obstacle_node(bundle: BastionBlueprintBundle) -> int:
	assert_not_null(bundle)
	assert_gt(bundle.obstacle_slots.size(), 0)
	var slot: Dictionary = bundle.obstacle_slots[0]
	return _i(slot, "node_id")


func _other_team_obstacle_node(bundle: BastionBlueprintBundle) -> int:
	assert_not_null(bundle)
	var first_slot: Dictionary = bundle.obstacle_slots[0]
	var first_team: int = _i(first_slot, "team_id")
	for item: Dictionary in bundle.obstacle_slots:
		if _i(item, "team_id") != first_team:
			return _i(item, "node_id")
	return 0


func _i(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw


func _snap(tick: int, phase: int, teams: Array[Dictionary]) -> PackedByteArray:
	return BastionFrameCodec.encode_snapshot(tick, phase, 0, 0, teams, TEAM_A)


func _teams(towers: Array, units: Array, obstacles: Array) -> Array[Dictionary]:
	return [
		{
			"team_id": TEAM_A,
			"core_health": 100,
			"gold": 200,
			"leaked": 0,
			"kills": 0,
			"locked": 0,
			"towers": towers,
			"units": units,
			"obstacles": obstacles,
		},
		{
			"team_id": TEAM_B,
			"core_health": 100,
			"gold": 200,
			"leaked": 0,
			"kills": 0,
			"locked": 0,
			"towers": [],
			"units": [],
			"obstacles": [],
		},
	]
