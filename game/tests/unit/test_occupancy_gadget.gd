extends GutTest

## Occupancy gadgets are presentation smoke: they construct, hang a child, and
## do not pave a terrain tile. No colour assertions (CD-53 §1.1).

const MatchSolidMapGd := preload("res://src/client/match_solid_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536
const CONVEYOR_ID: int = 71
const LIFT_ID: int = 72
const LAUNCH_ID: int = 73
const SWITCH_ID: int = 74


func test_attach_builds_named_gadget_children() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	assert_true(OccupancyGadget.attach(host, OccupancyGadget.KIND_CONVEYOR, 0))
	var gadget: Node3D = OccupancyGadget.gadget_node(host)
	assert_not_null(gadget)
	assert_gte(gadget.get_child_count(), 2)


func test_lift_path_is_pure_y() -> void:
	assert_true(OccupancyGadget.is_lift_path([
		{"x": 0, "y": 0, "z": 0},
		{"x": 0, "y": CELL * 2, "z": 0},
	]))
	assert_false(OccupancyGadget.is_lift_path([
		{"x": 0, "y": 0, "z": 0},
		{"x": CELL * 2, "y": 0, "z": 0},
	]))


func test_solid_map_skips_tiles_for_gadget_kinds() -> void:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	assert_true(world.put(_tagged_solid(CONVEYOR_ID, 0, -1, 1, ["solid", "conveyor"], 0)))
	assert_true(world.put(_tagged_solid(LAUNCH_ID, 1, -1, 1, ["solid", "launch"], 0)))
	assert_true(world.put(_tagged_solid(SWITCH_ID, 2, -1, 1, ["solid", "switch"], 1)))
	assert_true(world.put(SharedComponentRecordGd.create(LIFT_ID, {
		"transform": {"x": 3 * CELL, "y": -CELL, "z": CELL, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "lift"],
		},
		"mover": {
			"path": [
				{"x": 3 * CELL, "y": -CELL, "z": CELL},
				{"x": 3 * CELL, "y": CELL, "z": CELL},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	var bundle: SimulationBundle = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var solids: MatchSolidMapGd = MatchSolidMapGd.new()
	add_child_autofree(solids)
	assert_true(solids.apply_bundle(bundle))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(CONVEYOR_ID)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(LAUNCH_ID)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(LIFT_ID)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(SWITCH_ID)))
	assert_eq(solids.visual_node(CONVEYOR_ID), null)
	assert_eq(solids.visual_node(SWITCH_ID), null)


func _tagged_solid(
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
	if link_group >= 0 and tags.has("switch"):
		components["interactable"] = {"state": 0, "link_group": link_group}
	return SharedComponentRecordGd.create(entity_id, components)
