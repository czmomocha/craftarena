extends GutTest

## 出界范围按内容推导（标杆跑酷课 P1a）。紧凑课仍是 ±STUB_HALF 立方体，逐字节不变；
## 越出的那一侧放到该侧最远实体中心 + MARGIN。对局 / Solo（含幽灵）/ Preview 同一规则。
## STUB_HALF 与 MARGIN 都是开发桩，不是产品场地。

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringPreviewGd := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKindsGd := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShellGd := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSessionGd := preload("res://src/creator/authoring_session.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const MatchOfflineGhostGd := preload("res://src/client/match_offline_ghost.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const PlaySetbackGd := preload("res://src/shared/play_setback.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const FAR_X_CELLS: int = 20
## 显式列出，不遍历 MATCH_IDS：之后进白名单的大课本来就不该是立方体。
const COMPACT_IDS: PackedStringArray = [
	"course_01",
	"course_02",
	"course_03",
	"course_04",
	"course_05",
	"course_06",
	"course_07",
	"course_f_playable",
]

var _preview_shell: AuthoringPreviewShellGd = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_margin_is_four_cells_and_stub_half_unchanged() -> void:
	assert_eq(OutOfRangeReset.MARGIN, 4 * CELL)
	assert_eq(OutOfRangeReset.STUB_HALF, 8 * CELL)


func test_compact_official_courses_derive_the_stub_cube() -> void:
	var cube: Dictionary = OutOfRangeReset.cube_bounds(OutOfRangeReset.STUB_HALF)
	assert_false(COMPACT_IDS.has("course_08"))
	for course_id: String in COMPACT_IDS:
		var bundle: SimulationBundleGd = _compile_official(course_id)
		assert_not_null(bundle, course_id)
		if bundle == null:
			continue
		assert_eq(OutOfRangeReset.content_bounds(bundle), cube, course_id)
		var session: TraprushMatchSessionGd = _session_for(bundle)
		assert_not_null(session, course_id)
		if session == null:
			continue
		assert_true(session.range_enabled, course_id)
		assert_eq(_session_bounds(session), cube, course_id)


func test_course_08_content_bounds_exceed_the_stub_cube() -> void:
	var cube: Dictionary = OutOfRangeReset.cube_bounds(OutOfRangeReset.STUB_HALF)
	var bundle: SimulationBundleGd = _compile_official("course_08")
	assert_not_null(bundle)
	if bundle == null:
		return
	var bounds: Dictionary = OutOfRangeReset.content_bounds(bundle)
	assert_true(OutOfRangeReset.bounds_ok(bounds))
	assert_ne(bounds, cube)
	var exceeds: bool = (
		PlayClock.dict_int(bounds, "min_x", 0) < PlayClock.dict_int(cube, "min_x", 0)
		or PlayClock.dict_int(bounds, "max_x", 0) > PlayClock.dict_int(cube, "max_x", 0)
		or PlayClock.dict_int(bounds, "min_y", 0) < PlayClock.dict_int(cube, "min_y", 0)
		or PlayClock.dict_int(bounds, "max_y", 0) > PlayClock.dict_int(cube, "max_y", 0)
		or PlayClock.dict_int(bounds, "min_z", 0) < PlayClock.dict_int(cube, "min_z", 0)
		or PlayClock.dict_int(bounds, "max_z", 0) > PlayClock.dict_int(cube, "max_z", 0)
	)
	assert_true(exceeds, "course_08 content_bounds must leave the ±8 cube on at least one face")


func test_entity_at_x_twenty_moves_only_max_x() -> void:
	var bundle: SimulationBundleGd = _origin_pad_bundle()
	bundle.solids.append(_at(2, FAR_X_CELLS, 0, 0))
	var bounds: Dictionary = OutOfRangeReset.content_bounds(bundle)
	assert_eq(bounds, {
		"min_x": -8 * CELL, "max_x": 24 * CELL,
		"min_y": -8 * CELL, "max_y": 8 * CELL,
		"min_z": -8 * CELL, "max_z": 8 * CELL,
	})


func test_every_positioned_bag_counts() -> void:
	var pad_far: SimulationBundleGd = _origin_pad_bundle()
	pad_far.pads.append(_pad(2, -20, 0, 0, 0, 0, 0))
	assert_eq(_face(pad_far, "min_x"), -24 * CELL)
	var respawn_far: SimulationBundleGd = SimulationBundleGd.new()
	respawn_far.pads.append(_pad(1, 0, 0, 0, 0, 15 * CELL, 0))
	assert_eq(_face(respawn_far, "max_y"), 19 * CELL)
	var portal_src: SimulationBundleGd = _origin_pad_bundle()
	portal_src.portals.append(_portal(2, 0, 0, 20, 0, 0, 0))
	assert_eq(_face(portal_src, "max_z"), 24 * CELL)
	var portal_dest: SimulationBundleGd = _origin_pad_bundle()
	portal_dest.portals.append(_portal(2, 0, 0, 0, 0, -20, 0))
	assert_eq(_face(portal_dest, "min_y"), -24 * CELL)
	var finish_far: SimulationBundleGd = _origin_pad_bundle()
	finish_far.finish.append(_at(2, 12, 0, 0))
	assert_eq(_face(finish_far, "max_x"), 16 * CELL)
	var crate_far: SimulationBundleGd = _origin_pad_bundle()
	crate_far.destructibles.append(_at(2, 0, 0, -12))
	assert_eq(_face(crate_far, "min_z"), -16 * CELL)
	var hazard_far: SimulationBundleGd = _origin_pad_bundle()
	hazard_far.hazards.append(_at(2, 0, 10, 0))
	assert_eq(_face(hazard_far, "max_y"), 14 * CELL)
	var pickup_far: SimulationBundleGd = _origin_pad_bundle()
	pickup_far.pickups.append(_at(2, 9, 0, 0))
	assert_eq(_face(pickup_far, "max_x"), 13 * CELL)
	var mover_far: SimulationBundleGd = _origin_pad_bundle()
	mover_far.movers.append({
		"entity_id": 2,
		"speed": CELL / 16,
		"loop": true,
		"path": [{"x": 0, "y": 0, "z": 0}, {"x": 0, "y": 0, "z": -30 * CELL}],
	})
	assert_eq(_face(mover_far, "min_z"), -34 * CELL)


func test_on_stub_face_is_still_cube_one_unit_past_is_not() -> void:
	var cube: Dictionary = OutOfRangeReset.cube_bounds(OutOfRangeReset.STUB_HALF)
	var on_face: SimulationBundleGd = _origin_pad_bundle()
	on_face.solids.append(_at(2, 8, -8, 8))
	assert_eq(OutOfRangeReset.content_bounds(on_face), cube)
	var past: SimulationBundleGd = _origin_pad_bundle()
	past.solids.append({"entity_id": 2, "x": 8 * CELL + 1, "y": 0, "z": 0})
	assert_eq(_face(past, "max_x"), 12 * CELL + 1)


func test_once_any_side_exceeds_each_side_takes_margin() -> void:
	var bundle: SimulationBundleGd = _origin_pad_bundle()
	bundle.solids.append(_at(2, FAR_X_CELLS, 0, 0))
	bundle.solids.append(_at(3, 0, 0, 6))
	assert_eq(_face(bundle, "max_z"), 10 * CELL)
	assert_eq(_face(bundle, "min_z"), -8 * CELL)


func test_null_or_empty_bundle_is_cube() -> void:
	var cube: Dictionary = OutOfRangeReset.cube_bounds(OutOfRangeReset.STUB_HALF)
	assert_eq(OutOfRangeReset.content_bounds(null), cube)
	assert_eq(OutOfRangeReset.content_bounds(SimulationBundleGd.new()), cube)


func test_extreme_coordinates_saturate_instead_of_wrapping() -> void:
	var bundle: SimulationBundleGd = _origin_pad_bundle()
	bundle.solids.append({"entity_id": 2, "x": Fixed.INT64_MAX - 1, "y": 0, "z": Fixed.INT64_MIN + 1})
	assert_eq(_face(bundle, "max_x"), Fixed.INT64_MAX)
	assert_eq(_face(bundle, "min_z"), Fixed.INT64_MIN)


func test_bounds_ok_rejects_missing_and_inverted() -> void:
	assert_true(OutOfRangeReset.bounds_ok(OutOfRangeReset.cube_bounds(CELL)))
	assert_false(OutOfRangeReset.bounds_ok({}))
	var inverted: Dictionary = OutOfRangeReset.cube_bounds(CELL)
	inverted["min_y"] = 2 * CELL
	assert_false(OutOfRangeReset.bounds_ok(inverted))
	var session: TraprushMatchSessionGd = _session_for(_compile_world(_long_world()))
	session.enable_play_bounds(inverted)
	assert_false(session.range_enabled)


func test_session_on_big_course_walks_past_eight_and_resets_past_derived_face() -> void:
	var session: TraprushMatchSessionGd = _session_for(_compile_world(_long_world()))
	assert_not_null(session)
	assert_eq(session.range_max_x, 24 * CELL)
	assert_eq(session.range_min_x, -8 * CELL)
	for _step: int in range(12):
		assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(PlayClock.dict_int(session.player_pose(0), "x", -1), 12 * CELL)
	assert_eq(session.player_setback_count(0), 0)
	for _step: int in range(12):
		assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(PlayClock.dict_int(session.player_pose(0), "x", -1), 24 * CELL)
	assert_eq(session.player_setback_count(0), 0)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(PlayClock.dict_int(session.player_pose(0), "x", -1), 0)
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.OUT_OF_RANGE)


func test_literal_stub_cube_still_resets_at_nine_cells_on_same_course() -> void:
	var session: TraprushMatchSessionGd = _session_for(_compile_world(_long_world()))
	session.enable_play_range(OutOfRangeReset.STUB_HALF)
	for _step: int in range(9):
		assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(PlayClock.dict_int(session.player_pose(0), "x", -1), 0)
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.OUT_OF_RANGE)


func test_solo_uses_content_bounds_and_ghost_copies_the_switch() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.apply_play_stubs()
	assert_true(offline.play_range_from_content)
	assert_true(offline.try_begin_bundle(_compile_world(_long_world())))
	offline.skip_opening_countdown()
	assert_eq(offline.session.range_max_x, 24 * CELL)
	assert_eq(offline.session.range_min_x, -8 * CELL)
	for _step: int in range(12):
		assert_false(offline.try_encode_intent(PlayerIntentNamesGd.MOVE, CELL, 0, -1).is_empty())
	assert_eq(PlayClock.dict_int(offline.session.player_pose(0), "x", -1), 12 * CELL)
	var ghost_host: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	MatchOfflineGhostGd.copy_play_stubs(offline, ghost_host)
	assert_true(ghost_host.play_range_from_content)
	assert_true(ghost_host.try_begin_bundle(_compile_world(_long_world())))
	assert_eq(_session_bounds(ghost_host.session), _session_bounds(offline.session))
	assert_true(offline.try_stop())
	assert_true(ghost_host.try_stop())


func test_solo_zero_half_stays_off_even_with_content_switch() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.apply_play_stubs()
	offline.play_range_half = 0
	assert_true(offline.try_begin_bundle(_compile_world(_long_world())))
	assert_false(offline.session.range_enabled)
	assert_true(offline.try_stop())


func test_solo_compact_course_keeps_stub_cube() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.apply_play_stubs()
	assert_true(offline.try_begin(OfficialTraprushCoursesGd.document_path("course_01")))
	assert_eq(
		_session_bounds(offline.session), OutOfRangeReset.cube_bounds(OutOfRangeReset.STUB_HALF)
	)
	assert_true(offline.try_stop())


func test_preview_shell_uses_content_bounds_on_big_course() -> void:
	var session: AuthoringSessionGd = AuthoringSessionGd.new()
	session.world = _long_world()
	_preview_shell = AuthoringPreviewShellGd.create(AuthoringPreviewHostKindsGd.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var preview: AuthoringPreviewGd = _preview_shell.preview
	assert_true(preview.play_range_enabled)
	assert_eq(preview.play_range_max_x, 24 * CELL)
	assert_eq(preview.play_range_min_x, -8 * CELL)
	assert_eq(preview.play_range_max_y, 8 * CELL)
	for _step: int in range(12):
		assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	assert_eq(PlayClock.dict_int(pose, "x", -1), 12 * CELL)


func test_bare_preview_without_switch_keeps_literal_cube() -> void:
	var session: AuthoringSessionGd = AuthoringSessionGd.new()
	session.world = _long_world()
	var preview: AuthoringPreviewGd = AuthoringPreviewGd.new()
	assert_true(preview.connect_from(session))
	preview.enable_play_range(OutOfRangeReset.STUB_HALF)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_range_max_x, OutOfRangeReset.STUB_HALF)


func _compile_official(course_id: String) -> SimulationBundleGd:
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(
		OfficialTraprushCoursesGd.document_path(course_id)
	)
	if world == null:
		return null
	return TraprushTopologyCompilerGd.compile(world)


func _compile_world(world: AuthoringWorldGd) -> SimulationBundleGd:
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	return bundle


func _session_for(bundle: SimulationBundleGd) -> TraprushMatchSessionGd:
	if bundle == null:
		return null
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, TraprushPlayStubsGd.CAPSULE_RADIUS, TraprushPlayStubsGd.CAPSULE_HEIGHT
	)
	if session != null:
		TraprushPlayStubsGd.apply_match(session)
	return session


func _session_bounds(session: TraprushMatchSessionGd) -> Dictionary:
	return {
		"min_x": session.range_min_x, "max_x": session.range_max_x,
		"min_y": session.range_min_y, "max_y": session.range_max_y,
		"min_z": session.range_min_z, "max_z": session.range_max_z,
	}


func _face(bundle: SimulationBundleGd, key: String) -> int:
	return PlayClock.dict_int(OutOfRangeReset.content_bounds(bundle), key, 0)


## 起点垫在原点，地板 x 0..12，x = 20 另有一块孤立固体把 +X 面推到 24 格。
func _long_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	for cell_x: int in range(13):
		assert_true(world.put(_solid_record(10 + cell_x, cell_x, -1, 0)))
	assert_true(world.put(_solid_record(40, FAR_X_CELLS, -1, 0)))
	return world


func _solid_record(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> SharedComponentRecordGd:
	return SharedComponentRecordGd.create(entity_id, {
		"transform": {"x": cell_x * CELL, "y": cell_y * CELL, "z": cell_z * CELL, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid"],
		},
	})


func _origin_pad_bundle() -> SimulationBundleGd:
	var bundle: SimulationBundleGd = SimulationBundleGd.new()
	bundle.pads.append(_pad(1, 0, 0, 0, 0, 0, 0))
	return bundle


func _at(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> Dictionary:
	return {"entity_id": entity_id, "x": cell_x * CELL, "y": cell_y * CELL, "z": cell_z * CELL}


func _pad(
	entity_id: int, cell_x: int, cell_y: int, cell_z: int, rdx: int, rdy: int, rdz: int
) -> Dictionary:
	var pad: Dictionary = _at(entity_id, cell_x, cell_y, cell_z)
	pad["order"] = entity_id
	pad["respawn_dx"] = rdx
	pad["respawn_dy"] = rdy
	pad["respawn_dz"] = rdz
	return pad


func _portal(
	entity_id: int, cell_x: int, cell_y: int, cell_z: int, dest_x: int, dest_y: int, dest_z: int
) -> Dictionary:
	var portal: Dictionary = _at(entity_id, cell_x, cell_y, cell_z)
	portal["dest_x"] = dest_x * CELL
	portal["dest_y"] = dest_y * CELL
	portal["dest_z"] = dest_z * CELL
	return portal


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}
