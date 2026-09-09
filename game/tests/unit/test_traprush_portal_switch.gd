extends GutTest

## 可玩性深化第六批：开关传送。
## 传送占用 + `zone.tags` 的 `portal_switch` + 已有 `interactable.link_group`。
## 不新增组件、不改协议帧。开合是占用的纯函数。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const AuthoringSessionGd := preload("res://src/creator/authoring_session.gd")
const AuthoringPreviewGd := preload("res://src/creator/authoring_preview.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchCourseMapFxGd := preload("res://src/client/match_course_map_fx.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const GATED_ID: int = 40
const DEST_ID: int = 41
const SWITCH_ID: int = 80
const FLOOR_ID: int = 82


func test_gated_portal_compiles_into_optional_bag() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.portal_switches.size(), 1)
	assert_eq(bundle.portals.size(), 2)
	var gated: Dictionary = bundle.portal_switches[0]
	var gated_id: int = gated["entity_id"]
	var link_group: int = gated["link_group"]
	assert_eq(gated_id, GATED_ID)
	assert_eq(link_group, 1)


func test_a_portal_without_the_tag_is_not_gated() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_portal_record(GATED_ID, DEST_ID, 0, 0, 1, false, -1)))
	assert_true(world.put(_portal_record(DEST_ID, GATED_ID, 2, 0, 0, false, -1)))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.portal_switches.size(), 0)
	assert_eq(bundle.portals.size(), 2)


func test_a_gated_portal_without_interactable_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_portal_record(GATED_ID, DEST_ID, 0, 0, 1, true, -1)))
	assert_true(world.put(_portal_record(DEST_ID, GATED_ID, 2, 0, 0, false, -1)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_portal_switch_tag_without_a_portal_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(GATED_ID, {
		"transform": {"x": 0, "y": 0, "z": CELL, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["portal_switch"],
		},
		"interactable": {"state": 0, "link_group": 1},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_dangling_gated_portal_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_portal_record(GATED_ID, DEST_ID, 0, 0, 1, true, 1)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_gated_portal_that_is_also_solid_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(GATED_ID, {
		"transform": {"x": 0, "y": 0, "z": CELL, "yaw_bam": 0},
		"portal": {"target_id": DEST_ID, "yaw_bam": 0, "cooldown_ticks": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "portal_switch"],
		},
		"interactable": {"state": 0, "link_group": 1},
	})))
	assert_true(world.put(_portal_record(DEST_ID, GATED_ID, 2, 0, 0, false, -1)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_key_still_decode() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_PORTAL_SWITCHES)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.portal_switches.size(), 0)
	assert_eq(decoded.portals.size(), 2)


func test_a_portal_switch_bag_pointing_at_no_portal_is_refused() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_PORTAL_SWITCHES] = [{"entity_id": 999, "link_group": 1}]
	assert_null(SimulationBundleGd.from_dictionary(body))


func test_walking_into_a_gated_portal_without_a_switch_does_not_land() -> void:
	var session: TraprushMatchSessionGd = _locked_session()
	assert_eq(session.open_portal_entity_ids().size(), 0)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_z, CELL)


func test_standing_on_the_switch_and_overlapping_the_portal_lands() -> void:
	var session: TraprushMatchSessionGd = _puzzle_session()
	assert_eq(session.open_portal_entity_ids().size(), 0)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_z, 0)
	assert_eq(session.open_portal_entity_ids().size(), 0)


func test_place_gated_portal_twice_compiles_into_the_bag() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(
		AuthoringSurfaceNamesGd.INTERNAL_DEV
	)
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_true(shell.tools.place_next_gated_portal())
	assert_true(shell.tools.place_next_gated_portal())
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.portals.size(), 2)
	assert_eq(bundle.portal_switches.size(), 2)


func test_preview_standing_on_the_switch_lands_through_the_gated_portal() -> void:
	var session: AuthoringSessionGd = AuthoringSessionGd.new()
	var world: AuthoringWorldGd = _puzzle_world()
	for entity_id: int in world.entity_ids():
		assert_true(session.world.put(world.get_record(entity_id)))
	var preview: AuthoringPreviewGd = AuthoringPreviewGd.new()
	assert_true(preview.connect_from(session))
	preview.play_support_dy = TraprushPlayStubsGd.SUPPORT_DY
	preview.play_fall_dy = 0
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(0, CELL)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_z, 0)


func test_course_map_keeps_ungated_portals_enabled() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var map: MatchCourseMapGd = MatchCourseMapGd.new()
	add_child_autofree(map)
	assert_true(map.apply_bundle(bundle))
	assert_false(MatchCourseMapFxGd.portal_is_enabled(map, GATED_ID))
	assert_true(MatchCourseMapFxGd.portal_is_enabled(map, DEST_ID))
	MatchCourseMapFxGd.apply_portal_enabled(map, PackedInt32Array([GATED_ID]))
	assert_true(MatchCourseMapFxGd.portal_is_enabled(map, GATED_ID))


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _solid_record(
	entity_id: int, cell_x: int, cell_y: int, cell_z: int, tags: Array, link_group: int
) -> SharedComponentRecordGd:
	var components: Dictionary = {
		"transform": {
			"x": cell_x * CELL,
			"y": cell_y * CELL,
			"z": cell_z * CELL,
			"yaw_bam": 0,
		},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": tags,
		},
	}
	if link_group >= 0:
		components["interactable"] = {"state": 0, "link_group": link_group}
	return SharedComponentRecordGd.create(entity_id, components)


func _portal_record(
	entity_id: int,
	target_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int,
	gated: bool,
	link_group: int
) -> SharedComponentRecordGd:
	var components: Dictionary = {
		"transform": {
			"x": cell_x * CELL,
			"y": cell_y * CELL,
			"z": cell_z * CELL,
			"yaw_bam": 0,
		},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	}
	if gated:
		components["zone"] = {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["portal_switch"],
		}
		if link_group >= 0:
			components["interactable"] = {"state": 0, "link_group": link_group}
	return SharedComponentRecordGd.create(entity_id, components)


func _puzzle_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(FLOOR_ID, 0, -1, 0, ["solid"], -1)))
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 1, ["solid", "switch"], 1)))
	assert_true(world.put(_solid_record(FLOOR_ID + 1, 2, -1, 0, ["solid"], -1)))
	assert_true(world.put(_portal_record(GATED_ID, DEST_ID, 0, 0, 1, true, 1)))
	assert_true(world.put(_portal_record(DEST_ID, GATED_ID, 2, 0, 0, false, -1)))
	return world


func _locked_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(FLOOR_ID, 0, -1, 0, ["solid"], -1)))
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 1, ["solid"], -1)))
	assert_true(world.put(_solid_record(FLOOR_ID + 1, 2, -1, 0, ["solid"], -1)))
	assert_true(world.put(_portal_record(GATED_ID, DEST_ID, 0, 0, 1, true, 1)))
	assert_true(world.put(_portal_record(DEST_ID, GATED_ID, 2, 0, 0, false, -1)))
	return world


func _puzzle_bundle() -> SimulationBundleGd:
	return TraprushTopologyCompilerGd.compile(_puzzle_world())


func _session_from(world: AuthoringWorldGd) -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	session.fall_dy = 0
	return session


func _puzzle_session() -> TraprushMatchSessionGd:
	return _session_from(_puzzle_world())


func _locked_session() -> TraprushMatchSessionGd:
	return _session_from(_locked_world())
