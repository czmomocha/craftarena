extends GutTest

## F-line smoke: audio mute, hazard telegraph, pickups, movers, demo course.
## Presentation checks are construct / no-crash / node counts, not albedo.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const MatchHazardWarnGd := preload("res://src/client/match_hazard_warn.gd")
const MatchPickupMapGd := preload("res://src/client/match_pickup_map.gd")
const MatchSolidMapGd := preload("res://src/client/match_solid_map.gd")
const MatchCrateMapGd := preload("res://src/client/match_crate_map.gd")
const MatchHazardMapGd := preload("res://src/client/match_hazard_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")
const OfficialCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
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
	assert_true(ClientAudioGd.muted())
	assert_false(ClientAudioGd.post(ClientAudioGd.CUE_JUMP))
	var slots: PackedStringArray = ClientAudioGd.all_slots()
	assert_eq(slots.size(), 8)
	for slot: String in slots:
		assert_true(ClientAudioGd.has_slot(slot), slot)


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
	assert_eq(bundle.portals.size(), 4)
	assert_eq(bundle.pickups.size(), 2)
	assert_eq(bundle.hazards.size(), 3)
	assert_eq(bundle.movers.size(), 4)
	assert_eq(bundle.conveyors.size(), 3)
	assert_eq(bundle.launches.size(), 1)
	assert_eq(bundle.switches.size(), 2)
	assert_eq(bundle.gates.size(), 1)
	assert_eq(bundle.energy_walls.size(), 1)
	assert_eq(bundle.portal_switches.size(), 1)
	assert_eq(bundle.spikes.size(), 1)
	assert_eq(bundle.flames.size(), 1)
	assert_eq(bundle.crushers.size(), 1)
	assert_eq(bundle.rollers.size(), 1)
	assert_eq(bundle.rubbles.size(), 1)
	assert_eq(bundle.obstacle_cores.size(), 1)
	assert_eq(bundle.pendulums.size(), 1)
	assert_eq(bundle.ices.size(), 1)
	assert_eq(bundle.destructibles.size(), 4)
	assert_eq(PlayClockGd.dict_int(bundle.switches[0], "entity_id", 0), 85)
	assert_eq(PlayClockGd.dict_int(bundle.gates[0], "entity_id", 0), 223)
	assert_eq(PlayClockGd.dict_int(bundle.energy_walls[0], "entity_id", 0), 224)
	assert_eq(PlayClockGd.dict_int(bundle.portal_switches[0], "entity_id", 0), 225)
	assert_eq(PlayClockGd.dict_int(bundle.portal_switches[0], "link_group", 0), 2)
	assert_eq(PlayClockGd.dict_int(bundle.spikes[0], "entity_id", 0), 229)
	assert_eq(PlayClockGd.dict_int(bundle.flames[0], "entity_id", 0), 230)
	assert_eq(PlayClockGd.dict_int(bundle.crushers[0], "entity_id", 0), 232)
	assert_eq(PlayClockGd.dict_int(bundle.rollers[0], "entity_id", 0), 234)
	assert_eq(PlayClockGd.dict_int(bundle.rubbles[0], "entity_id", 0), 236)
	assert_eq(PlayClockGd.dict_int(bundle.obstacle_cores[0], "entity_id", 0), 237)
	assert_eq(PlayClockGd.dict_int(bundle.pendulums[0], "entity_id", 0), 238)
	assert_eq(PlayClockGd.dict_int(bundle.ices[0], "entity_id", 0), 239)
	assert_gt(bundle.solids.size(), 6)
	var switch_solid: Dictionary = {}
	var gate_solid: Dictionary = {}
	for bag: Dictionary in bundle.solids:
		var solid_id: int = PlayClockGd.dict_int(bag, "entity_id", 0)
		if solid_id == 85:
			switch_solid = bag
		elif solid_id == 223:
			gate_solid = bag
	assert_eq(PlayClockGd.dict_int(switch_solid, "x", -1), 4 * CELL)
	assert_eq(PlayClockGd.dict_int(switch_solid, "y", 1), -CELL)
	assert_eq(PlayClockGd.dict_int(switch_solid, "z", -1), 2 * CELL)
	assert_eq(PlayClockGd.dict_int(gate_solid, "x", -1), 5 * CELL)
	assert_eq(PlayClockGd.dict_int(gate_solid, "y", -1), 0)
	assert_eq(PlayClockGd.dict_int(gate_solid, "z", -1), 2 * CELL)
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
		if PlayClockGd.dict_int(bag, "y", 0) == 0 and PlayClockGd.dict_int(bag, "z", 0) == -2 * CELL:
			high_solid = true
	assert_true(high_solid)
	var pickups: MatchPickupMapGd = MatchPickupMapGd.new()
	add_child_autofree(pickups)
	assert_true(pickups.apply_bundle(bundle))
	assert_eq(pickups.pickup_count(), 2)
	var solids: MatchSolidMapGd = MatchSolidMapGd.new()
	add_child_autofree(solids)
	assert_true(solids.apply_bundle(bundle))
	assert_true(solids.apply_tick(8))
	assert_not_null(solids.solid_node(85))
	assert_not_null(solids.solid_node(223))
	if solids.visual_count() > 0:
		assert_eq(solids.visual_node(85), null, "switch must stay a coloured box, not a terrain tile")
		assert_eq(solids.visual_node(223), null, "gate must stay a coloured box, not a terrain tile")
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(85)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(223)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(229)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(232)))
	var crates: MatchCrateMapGd = MatchCrateMapGd.new()
	add_child_autofree(crates)
	assert_true(crates.apply_bundle(bundle))
	assert_not_null(OccupancyGadget.gadget_node(crates.crate_node(224)))
	assert_not_null(OccupancyGadget.gadget_node(crates.crate_node(236)))
	assert_not_null(OccupancyGadget.gadget_node(crates.crate_node(237)))
	var hazards: MatchHazardMapGd = MatchHazardMapGd.new()
	add_child_autofree(hazards)
	assert_true(hazards.apply_bundle(bundle))
	assert_not_null(OccupancyGadget.gadget_node(hazards.hazard_node(230)))
	assert_not_null(OccupancyGadget.gadget_node(hazards.hazard_node(234)))


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
