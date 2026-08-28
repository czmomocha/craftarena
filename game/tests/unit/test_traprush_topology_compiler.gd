extends GutTest

## TRAPRUSH topology compile: AuthoringWorld -> SimulationBundle -> SimulationWorld.
## Official courses compile. Dangling portals are omitted. Checkpoints without
## transform fail the whole compile. Loaded pads and finish are non-solid
## occupancy boxes. one_way landing uses the existing portal graph. Never
## settlement. Not a new op.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushPortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const CELL: int = 65536


func test_empty_world_compiles_to_empty_bundle() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.cell, CELL)
	assert_eq(bundle.source_revision, 0)
	assert_eq(bundle.pads.size(), 0)
	assert_eq(bundle.portals.size(), 0)
	assert_eq(bundle.finish.size(), 0)
	assert_eq(bundle.destructibles.size(), 0)
	assert_eq(bundle.hazards.size(), 0)
	assert_eq(bundle.solids.size(), 0)
	var encoded: Dictionary = bundle.to_dictionary()
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(encoded)
	assert_not_null(decoded)
	assert_eq(decoded.pads.size(), 0)


func test_official_courses_compile_distinct_topology() -> void:
	var first: SimulationBundle = _compile_path(COURSE_01_PATH)
	var second: SimulationBundle = _compile_path(COURSE_02_PATH)
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.pads.size(), 3)
	assert_eq(first.portals.size(), 5)
	assert_eq(second.pads.size(), 3)
	assert_eq(second.portals.size(), 2)
	assert_eq(first.finish.size(), 1)
	assert_eq(second.finish.size(), 1)
	assert_eq(first.destructibles.size(), 1)
	assert_eq(second.destructibles.size(), 1)
	assert_eq(first.hazards.size(), 1)
	assert_eq(second.hazards.size(), 1)
	assert_eq(first.solids.size(), 36)
	assert_eq(second.solids.size(), 8)
	var first_hazard: Dictionary = _hazard(first, 60)
	var first_solid: Dictionary = _solid(first, 70)
	var first_footing: Dictionary = _solid(first, 80)
	var first_hazard_z: int = first_hazard.get("z", 1)
	var first_hazard_cd: int = first_hazard.get("cooldown_ticks", -1)
	var first_solid_x: int = first_solid.get("x", 1)
	var second_hazard_z: int = _hazard(second, 60).get("z", 1)
	var second_solid_x: int = _solid(second, 70).get("x", 1)
	assert_eq(first_hazard_z, -2 * CELL)
	assert_eq(first_hazard_cd, 1)
	assert_eq(first_solid_x, -CELL)
	var first_footing_y: int = first_footing.get("y", 1)
	assert_eq(first_footing_y, -CELL)
	var second_footing_y: int = _solid(second, 80).get("y", 1)
	assert_eq(second_footing_y, -CELL)
	assert_eq(second_hazard_z, -2 * CELL)
	assert_eq(second_solid_x, -CELL)
	var first_crate: Dictionary = _destructible(first, 40)
	var second_crate: Dictionary = _destructible(second, 40)
	var first_crate_z: int = first_crate.get("z", -1)
	var first_crate_durability: int = first_crate.get("durability", -1)
	var second_crate_z: int = second_crate.get("z", -1)
	assert_eq(first_crate_z, CELL)
	assert_eq(first_crate_durability, 1)
	assert_eq(second_crate_z, CELL)
	var first_finish: Dictionary = _finish(first, 30)
	var second_finish: Dictionary = _finish(second, 30)
	var first_finish_x: int = first_finish.get("x", -1)
	var first_finish_y: int = first_finish.get("y", -1)
	var first_finish_z: int = first_finish.get("z", -1)
	var second_finish_z: int = second_finish.get("z", -1)
	assert_eq(first_finish_x, 2 * CELL)
	assert_eq(first_finish_y, CELL)
	assert_eq(first_finish_z, -3 * CELL)
	assert_eq(second_finish_z, 2 * CELL)
	var first_pad_x: int = _pad(first, 1).get("x", -1)
	var first_pad_z: int = _pad(first, 1).get("z", -1)
	var second_pad_z: int = _pad(second, 3).get("z", -1)
	var first_kind: String = str(_portal(first, 10).get("kind", ""))
	var first_source_x: int = _portal(first, 10).get("x", -1)
	var first_source_y: int = _portal(first, 10).get("y", -1)
	var first_source_z: int = _portal(first, 10).get("z", -1)
	var first_dest_x: int = _portal(first, 10).get("dest_x", -1)
	var first_dest_y: int = _portal(first, 10).get("dest_y", -1)
	var first_dest_z: int = _portal(first, 10).get("dest_z", -1)
	var second_kind: String = str(_portal(second, 20).get("kind", ""))
	var second_dest_z: int = _portal(second, 20).get("dest_z", -1)
	assert_eq(first_pad_x, 0)
	assert_eq(first_pad_z, 0)
	assert_eq(second_pad_z, 2 * CELL)
	assert_eq(first_kind, AuthoringPortalKinds.TWO_WAY)
	assert_eq(str(_portal(first, 12).get("kind", "")), AuthoringPortalKinds.ONE_WAY)
	assert_eq(str(_portal(first, 20).get("kind", "")), AuthoringPortalKinds.TWO_WAY)
	assert_eq(first_source_x, 3 * CELL)
	assert_eq(first_source_y, 0)
	assert_eq(first_source_z, 0)
	assert_eq(first_dest_x, 0)
	assert_eq(first_dest_y, CELL)
	assert_eq(first_dest_z, -3 * CELL)
	assert_eq(second_kind, AuthoringPortalKinds.TWO_WAY)
	assert_eq(second_dest_z, 2 * CELL)
	assert_ne(first_dest_z, second_dest_z)
	assert_true(_flag(TraprushTopologyLoader.try_load(first, 1)))
	assert_true(_flag(TraprushTopologyLoader.try_load(second, 1)))


func test_dangling_portal_is_omitted_and_one_way_is_kept() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0)))
	assert_true(world.put(_portal_record(2, 99, CELL, 16384)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 0)
	assert_eq(bundle.portals.size(), 1)
	var portal: Dictionary = bundle.portals[0]
	var portal_id: int = portal.get("entity_id", 0)
	var target_id: int = portal.get("target_id", 0)
	var kind: String = str(portal.get("kind", ""))
	var source_x: int = portal.get("x", -1)
	var dest_x: int = portal.get("dest_x", -1)
	var dest_yaw_bam: int = portal.get("dest_yaw_bam", -1)
	assert_eq(portal_id, 1)
	assert_eq(target_id, 2)
	assert_eq(kind, AuthoringPortalKinds.ONE_WAY)
	assert_eq(source_x, 0)
	assert_eq(dest_x, CELL)
	assert_eq(dest_yaw_bam, 16384)


func test_portal_source_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var source: SharedComponentRecord = SharedComponentRecord.create(1, {
		"portal": {"target_id": 2, "yaw_bam": 0, "cooldown_ticks": 0},
	})
	assert_not_null(source)
	assert_true(world.put(source))
	assert_true(world.put(_portal_record(2, 99, CELL, 0)))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_portal_bag_without_source_pose_is_rejected() -> void:
	var data: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"source_revision": 0,
		"pads": [],
		"portals": [
			{
				"entity_id": 1,
				"target_id": 2,
				"kind": AuthoringPortalKinds.ONE_WAY,
				"dest_x": 0,
				"dest_y": 0,
				"dest_z": 0,
				"dest_yaw_bam": 0,
			},
		],
		"finish": [],
		"destructibles": [],
		"hazards": [],
		"solids": [],
		"pickups": [],
	}
	assert_null(SimulationBundle.from_dictionary(data))


func test_checkpoint_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_extra_bundle_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data["signed"] = false
	assert_null(SimulationBundle.from_dictionary(data))


func test_dangling_kind_in_bundle_is_rejected() -> void:
	var data: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"source_revision": 0,
		"pads": [],
		"portals": [
			{
				"entity_id": 1,
				"target_id": 2,
				"kind": AuthoringPortalKinds.DANGLING,
				"x": 0,
				"y": 0,
				"z": 0,
				"dest_x": 0,
				"dest_y": 0,
				"dest_z": 0,
				"dest_yaw_bam": 0,
			},
		],
		"finish": [],
		"destructibles": [],
		"hazards": [],
		"solids": [],
		"pickups": [],
	}
	assert_null(SimulationBundle.from_dictionary(data))


func test_loaded_pads_are_non_solid_occupancy_and_world_ticks() -> void:
	var bundle: SimulationBundle = _compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var world: SimulationWorld = loaded["world"]
	var pad_ids: Dictionary = loaded["pad_ids"]
	var portal_ids: Dictionary = loaded["portal_ids"]
	var finish_ids: Dictionary = loaded["finish_ids"]
	var destructible_ids: Dictionary = loaded["destructible_ids"]
	assert_eq(pad_ids.size(), 3)
	assert_eq(portal_ids.size(), 5)
	assert_eq(finish_ids.size(), 1)
	assert_eq(destructible_ids.size(), 1)
	var hazard_ids: Dictionary = loaded["hazard_ids"]
	assert_eq(hazard_ids.size(), 1)
	var solid_ids: Dictionary = loaded["solid_ids"]
	assert_eq(solid_ids.size(), 36)
	var pickup_ids: Dictionary = loaded["pickup_ids"]
	assert_eq(pickup_ids.size(), 2)
	var box_id: int = pad_ids[1]
	assert_false(world.is_static_box_solid(box_id))
	var portal_box_id: int = portal_ids[10]
	assert_false(world.is_static_box_solid(portal_box_id))
	var finish_box_id: int = finish_ids[30]
	assert_false(world.is_static_box_solid(finish_box_id))
	var crate_box_id: int = destructible_ids[40]
	assert_true(world.is_static_box_solid(crate_box_id))
	var hazard_box_id: int = hazard_ids[60]
	assert_true(world.is_static_box_solid(hazard_box_id))
	var solid_box_id: int = solid_ids[70]
	assert_true(world.is_static_box_solid(solid_box_id))
	var footing_box_id: int = solid_ids[80]
	assert_true(world.is_static_box_solid(footing_box_id))
	var approach_box_id: int = solid_ids[87]
	assert_true(world.is_static_box_solid(approach_box_id))
	var hazard_floor_box_id: int = solid_ids[88]
	assert_true(world.is_static_box_solid(hazard_floor_box_id))
	var pickup_box_id: int = pickup_ids[100]
	assert_false(world.is_static_box_solid(pickup_box_id))
	var capsule_id: int = world.spawn_capsule(0, 0, 0, 0, 1, 1)
	var overlapping: PackedInt32Array = world.overlapping_static_boxes(capsule_id)
	assert_true(_has_id(overlapping, box_id))
	assert_false(_has_id(overlapping, portal_box_id))
	assert_false(_has_id(overlapping, finish_box_id))
	var at_portal: int = world.spawn_capsule(3 * CELL, 0, 0, 0, 1, 1)
	var portal_overlap: PackedInt32Array = world.overlapping_static_boxes(at_portal)
	assert_true(_has_id(portal_overlap, portal_box_id))
	var at_finish: int = world.spawn_capsule(2 * CELL, CELL, -3 * CELL, 0, 1, 1)
	var finish_overlap: PackedInt32Array = world.overlapping_static_boxes(at_finish)
	assert_true(_has_id(finish_overlap, finish_box_id))
	assert_eq(world.tick_index, 0)
	world.tick()
	assert_eq(world.tick_index, 1)


func test_one_way_bundle_lands_on_dest_transform() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0)))
	assert_true(world.put(_portal_record(2, 99, 2 * CELL, 16384)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var sim: SimulationWorld = loaded["world"]
	var graph: TraprushPortalGraph = loaded["graph"]
	var capsule_id: int = sim.spawn_capsule(0, 0, 0, 8, 1, 1)
	var result: Dictionary = TraprushPortalLanding.try_land(sim, capsule_id, graph, 1, 1)
	assert_true(_flag(result))
	var landed: bool = result.get("landed", false)
	assert_true(landed)
	var pose: Dictionary = sim.get_pose(capsule_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(pose_yaw, 16384)
	assert_eq(sim.tick_index, 0)


func test_null_world_or_bundle_fails() -> void:
	assert_null(TraprushTopologyCompiler.compile(null))
	var loaded: Dictionary = TraprushTopologyLoader.try_load(null, 1)
	assert_false(_flag(loaded))


func test_two_finish_zones_fail_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_finish_record(30, 0, 0, 0)))
	assert_true(world.put(_finish_record(31, CELL, 0, 0)))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_finish_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(30, {
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": [TraprushTopologyCompiler.FINISH_ZONE_TAG],
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_finish_on_checkpoint_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": [TraprushTopologyCompiler.FINISH_ZONE_TAG],
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_bundle_without_finish_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data.erase(SimulationBundle.FIELD_FINISH)
	assert_null(SimulationBundle.from_dictionary(data))


func test_two_finish_bags_are_rejected() -> void:
	var data: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"source_revision": 0,
		"pads": [],
		"portals": [],
		"finish": [
			{"entity_id": 30, "x": 0, "y": 0, "z": 0},
			{"entity_id": 31, "x": CELL, "y": 0, "z": 0},
		],
		"destructibles": [],
		"hazards": [],
		"solids": [],
		"pickups": [],
	}
	assert_null(SimulationBundle.from_dictionary(data))


func test_destructible_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(40, {
		"destructible": {"durability": 1, "regen_policy_id": 0},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_destructible_on_checkpoint_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
		"destructible": {"durability": 1, "regen_policy_id": 0},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_bundle_without_destructibles_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data.erase(SimulationBundle.FIELD_DESTRUCTIBLES)
	assert_null(SimulationBundle.from_dictionary(data))


func test_bundle_without_hazards_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data.erase(SimulationBundle.FIELD_HAZARDS)
	assert_null(SimulationBundle.from_dictionary(data))


func test_bundle_without_solids_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data.erase(SimulationBundle.FIELD_SOLIDS)
	assert_null(SimulationBundle.from_dictionary(data))


func test_bundle_without_pickups_key_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var data: Dictionary = bundle.to_dictionary()
	data.erase(SimulationBundle.FIELD_PICKUPS)
	assert_null(SimulationBundle.from_dictionary(data))


func test_hazard_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(50, {
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_hazard_on_checkpoint_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_hazard_compiles_and_loads_solid_at_tick_zero() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_hazard_record(50, CELL, 0, 0, 1)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.hazards.size(), 1)
	var hazard: Dictionary = _hazard(bundle, 50)
	var hazard_x: int = hazard.get("x", -1)
	var hazard_period: int = hazard.get("cooldown_ticks", -1)
	assert_eq(hazard_x, CELL)
	assert_eq(hazard_period, 1)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var sim: SimulationWorld = loaded["world"]
	var hazard_ids: Dictionary = loaded["hazard_ids"]
	assert_eq(hazard_ids.size(), 1)
	var box_id: int = hazard_ids[50]
	assert_true(sim.is_static_box_solid(box_id))


func test_solid_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var half: int = CELL / 2
	var record: SharedComponentRecord = SharedComponentRecord.create(70, {
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.SOLID_ZONE_TAG],
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_solid_on_checkpoint_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var half: int = CELL / 2
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.SOLID_ZONE_TAG],
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_finish_and_solid_tags_together_fail_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var half: int = CELL / 2
	var record: SharedComponentRecord = SharedComponentRecord.create(30, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [
				TraprushTopologyCompiler.FINISH_ZONE_TAG,
				TraprushTopologyCompiler.SOLID_ZONE_TAG,
			],
		},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_solid_compiles_and_loads_always_solid() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_solid_record(70, 0, -CELL, 0)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.solids.size(), 1)
	var solid: Dictionary = _solid(bundle, 70)
	var solid_y: int = solid.get("y", 1)
	assert_eq(solid_y, -CELL)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var sim: SimulationWorld = loaded["world"]
	var solid_ids: Dictionary = loaded["solid_ids"]
	assert_eq(solid_ids.size(), 1)
	var box_id: int = solid_ids[70]
	assert_true(sim.is_static_box_solid(box_id))


func test_pickup_without_transform_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(100, {
		"inventory": {"item_state": "bomb"},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_pickup_on_checkpoint_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
		"inventory": {"item_state": "bomb"},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_unknown_pickup_kind_fails_compile() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(100, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"inventory": {"item_state": "shield"},
	})
	assert_not_null(record)
	assert_true(world.put(record))
	assert_null(TraprushTopologyCompiler.compile(world))


func test_pickup_compiles_and_loads_non_solid() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_pickup_record(100, 0, 0, 0, "bomb")))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pickups.size(), 1)
	var pickup: Dictionary = _pickup(bundle, 100)
	var pickup_kind: String = pickup.get("kind", "")
	assert_eq(pickup_kind, "bomb")
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var sim: SimulationWorld = loaded["world"]
	var pickup_ids: Dictionary = loaded["pickup_ids"]
	assert_eq(pickup_ids.size(), 1)
	var box_id: int = pickup_ids[100]
	assert_false(sim.is_static_box_solid(box_id))


func _compile_path(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompiler.compile(world)


func _pad(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for pad: Dictionary in bundle.pads:
		if pad.get("entity_id", 0) == entity_id:
			return pad
	return {}


func _portal(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for portal: Dictionary in bundle.portals:
		if portal.get("entity_id", 0) == entity_id:
			return portal
	return {}


func _finish(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.finish:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _destructible(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.destructibles:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _hazard(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.hazards:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _solid(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.solids:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _pickup(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.pickups:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _hazard_record(entity_id: int, x: int, y: int, z: int, cooldown_ticks: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _portal_record(entity_id: int, target_id: int, x: int, yaw_bam: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": yaw_bam, "cooldown_ticks": 0},
	})


func _finish_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.FINISH_ZONE_TAG],
		},
	})


func _solid_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.SOLID_ZONE_TAG],
		},
	})


func _pickup_record(entity_id: int, x: int, y: int, z: int, kind: String) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"inventory": {"item_state": kind},
	})


func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _has_id(ids: PackedInt32Array, box_id: int) -> bool:
	for index: int in range(ids.size()):
		if ids[index] == box_id:
			return true
	return false
