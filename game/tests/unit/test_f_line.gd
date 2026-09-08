extends GutTest

## F-line smoke: audio mute, hazard telegraph, pickups, movers, demo course.
## Presentation checks are construct / no-crash / node counts, not albedo.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const MatchHazardWarnGd := preload("res://src/client/match_hazard_warn.gd")
const MatchPickupMapGd := preload("res://src/client/match_pickup_map.gd")
const MatchSolidMapGd := preload("res://src/client/match_solid_map.gd")
const OfficialCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const PlaySfxGd := preload("res://src/client/play_sfx.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMoverCycleGd := preload("res://src/games/traprush/mover_cycle.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const VisualCatalogGd := preload("res://src/shared/visual_asset_catalog.gd")
const VisualIdsGd := preload("res://src/shared/visual_asset_catalog_ids.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")

const CELL: int = 65536
const COURSE_F: String = "res://content/official/traprush/course_f_playable.json"


func test_headless_sfx_is_silent_and_eight_slots_exist() -> void:
	assert_true(PlaySfxGd.muted())
	assert_false(PlaySfxGd.play(PlaySfxGd.SLOT_JUMP))
	var slots: PackedStringArray = PackedStringArray([
		PlaySfxGd.SLOT_STEP,
		PlaySfxGd.SLOT_JUMP,
		PlaySfxGd.SLOT_LAND,
		PlaySfxGd.SLOT_PICKUP,
		PlaySfxGd.SLOT_CRATE,
		PlaySfxGd.SLOT_HAZARD_WARN,
		PlaySfxGd.SLOT_PORTAL,
		PlaySfxGd.SLOT_FINISH,
	])
	assert_eq(slots.size(), 8)
	for slot: String in slots:
		assert_true(PlaySfxGd.has_slot(slot), slot)


func test_hazard_warn_is_presentation_only() -> void:
	assert_eq(PlaceholderSpec.HAZARD_WARN_TICKS, 15)
	assert_false(MatchHazardWarnGd.is_warning(0, 30, 15))
	assert_true(MatchHazardWarnGd.is_warning(45, 30, 15))
	assert_eq(MatchHazardWarnGd.warn_name(50), "warn_50")


func test_visual_catalog_has_portal_pickup_spawn_scenes() -> void:
	assert_eq(
		VisualCatalogGd.scene_for_bag(VisualIdsGd.BAG_PORTAL),
		VisualCatalogGd.PORTAL_SCENE_PATH
	)
	assert_eq(
		VisualCatalogGd.scene_for_bag(VisualIdsGd.BAG_PICKUP_BOMB),
		VisualCatalogGd.PICKUP_BOMB_SCENE_PATH
	)
	assert_eq(
		VisualCatalogGd.scene_for_bag(VisualIdsGd.BAG_PICKUP_DASH),
		VisualCatalogGd.PICKUP_DASH_SCENE_PATH
	)
	assert_eq(
		VisualCatalogGd.scene_for_bag(VisualIdsGd.BAG_SPAWN),
		VisualCatalogGd.SPAWN_MARKER_SCENE_PATH
	)
	assert_true(ResourceLoader.exists(VisualCatalogGd.PORTAL_SCENE_PATH))


func test_bundle_movers_key_is_optional() -> void:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	assert_true(data.has(SimulationBundleGd.FIELD_MOVERS))
	var without: Dictionary = data.duplicate(true)
	without.erase(SimulationBundleGd.FIELD_MOVERS)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(without)
	assert_not_null(decoded)
	assert_eq(decoded.movers.size(), 0)
	data.erase(SimulationBundleGd.FIELD_SOLIDS)
	assert_null(SimulationBundleGd.from_dictionary(data))


func test_compile_rejects_mover_that_is_not_axial() -> void:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	var record: SharedComponentRecordGd = SharedComponentRecordGd.create(70, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid"],
		},
		"mover": {
			"path": [
				{"x": 0, "y": -CELL, "z": 0},
				{"x": CELL, "y": -CELL, "z": CELL},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_mover_pose_ping_pongs_when_looped() -> void:
	var path: Array = [
		{"x": 0, "y": 0, "z": 0},
		{"x": CELL, "y": 0, "z": 0},
	]
	var start: Dictionary = TraprushMoverCycleGd.pose_at(0, path, CELL / 16, true)
	assert_eq(PlayClockGd.dict_int(start, "x", -1), 0)
	var far: Dictionary = TraprushMoverCycleGd.pose_at(16, path, CELL / 16, true)
	assert_eq(PlayClockGd.dict_int(far, "x", -1), CELL)
	var back: Dictionary = TraprushMoverCycleGd.pose_at(32, path, CELL / 16, true)
	assert_eq(PlayClockGd.dict_int(back, "x", -1), 0)


func test_course_f_playable_compiles_with_f_line_features() -> void:
	assert_false(OfficialCoursesGd.is_id(OfficialCoursesGd.COURSE_F_PLAYABLE))
	assert_eq(
		OfficialCoursesGd.normalize_id("  course_f_playable  "),
		OfficialCoursesGd.COURSE_F_PLAYABLE
	)
	assert_eq(OfficialCoursesGd.document_path(OfficialCoursesGd.COURSE_F_PLAYABLE), COURSE_F)
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(COURSE_F)
	assert_not_null(world)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 2)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.portals.size(), 2)
	assert_eq(bundle.pickups.size(), 2)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.movers.size(), 2)
	assert_eq(bundle.conveyors.size(), 3)
	assert_eq(bundle.launches.size(), 1)
	assert_gt(bundle.solids.size(), 6)
	var high_solid: bool = false
	var pad0: Dictionary = bundle.pads[0]
	var pad1: Dictionary = bundle.pads[1]
	if PlayClockGd.dict_int(pad0, "x", 0) > PlayClockGd.dict_int(pad1, "x", 0):
		pad0 = bundle.pads[1]
		pad1 = bundle.pads[0]
	assert_eq(PlayClockGd.dict_int(pad0, "x", -1), 0)
	assert_eq(PlayClockGd.dict_int(pad1, "x", -1), 3 * CELL)
	assert_eq(PlayClockGd.dict_int(bundle.finish[0], "x", -1), 7 * CELL)
	for bag: Dictionary in bundle.solids:
		if PlayClockGd.dict_int(bag, "y", 0) == 0 and PlayClockGd.dict_int(bag, "z", 0) == -5 * CELL:
			high_solid = true
	assert_true(high_solid)
	var pickups: MatchPickupMapGd = MatchPickupMapGd.new()
	add_child_autofree(pickups)
	assert_true(pickups.apply_bundle(bundle))
	assert_eq(pickups.pickup_count(), 2)
	var solids: MatchSolidMapGd = MatchSolidMapGd.new()
	add_child_autofree(solids)
	solids.tile_scene_path = ""
	assert_true(solids.apply_bundle(bundle))
	assert_true(solids.apply_tick(8))


func test_solo_shell_opens_course_f_playable() -> void:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child_autofree(shell)
	assert_true(shell.open())
	shell.set_course_id_text(OfficialCoursesGd.COURSE_F_PLAYABLE)
	assert_eq(shell.selected_course_id(), OfficialCoursesGd.COURSE_F_PLAYABLE)
	assert_false(shell.try_quick())
	assert_false(shell.join.has_pending())
	assert_eq(shell.join.error, "http_official_only")
	assert_true(shell.status_label_text().contains("error=http_official_only"))
	assert_true(shell.try_solo(), shell.offline.last_error)
	assert_eq(shell.offline.state, MatchOfflineSessionGd.STATE_PLAYING)
	assert_false(shell.status_label_text().contains("error=http_official_only"))
	assert_eq(shell.course.pad_count(), 2)
	assert_eq(shell.course.finish_count(), 1)
	assert_gt(shell.solids.solid_count(), 6)
	assert_eq(shell.pickups.pickup_count(), 2)
	assert_true(shell.status_label_text().contains("offline=playing"))
	assert_true(shell.status_label_text().contains("course_id=%s" % OfficialCoursesGd.COURSE_F_PLAYABLE))
	assert_true(shell.try_camera_zoom(-3))
	assert_gt(shell.map.camera_distance, PlaceholderSpec.CAMERA_DISTANCE)
	var offset: Vector3 = PlaceholderSpec.camera_offset_for_distance(shell.map.camera_distance)
	var horizontal: float = sqrt(offset.x * offset.x + offset.z * offset.z)
	assert_almost_eq(rad_to_deg(atan2(offset.y, horizontal)), 45.0, 0.0001)
	assert_true(shell.try_camera_pan(Vector2(80.0, 0.0)))
	assert_gt(shell.map.camera_pan.length(), 0.0)


func test_solo_unknown_course_sets_offline_error() -> void:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child_autofree(shell)
	assert_true(shell.open())
	shell.set_course_id_text("course_99")
	assert_eq(shell.selected_course_id(), "")
	assert_false(shell.try_solo())
	assert_eq(shell.offline.last_error, "unknown_course")
	assert_true(shell.status_label_text().contains("offline_error=unknown_course"))
