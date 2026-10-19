extends GutTest

## Seventh official TRAPRUSH course: seven layers, same climb as course_06,
## floors stepped away from the locked 45° camera so a higher band does not
## roof the cell you are standing on. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BuilderGd := preload("res://src/games/traprush/course_07_builder.gd")
const Course07Scripts := preload("res://src/games/traprush/course_07_scripts.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_06_PATH: String = "res://content/official/traprush/course_06.json"
const COURSE_07_PATH: String = "res://content/official/traprush/course_07.json"
const CELL: int = 65536
const ENTITY_COUNT: int = 1086
const _RAY_Y: float = 0.55
const _BOX_HALF: float = 0.5


func test_builder_export_matches_the_committed_document() -> void:
	var built: Dictionary = BuilderGd.export_document()
	assert_false(built.is_empty())
	var built_world: AuthoringWorld = AuthoringDocument.decode(built)
	assert_not_null(built_world)
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(loaded)
	assert_eq(built_world.hash_state().hex_encode(), loaded.hash_state().hex_encode())


func test_official_course_07_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.entity_count(), ENTITY_COUNT)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result), str(result.get("issues", [])))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_07_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_07))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_07), COURSE_07_PATH)
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_07))


func test_course_07_layout_keeps_six_layer_gap_and_wide_footprint() -> void:
	var sixth: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_06_PATH)
	var seventh: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(sixth)
	assert_not_null(seventh)
	assert_ne(sixth.hash_state().hex_encode(), seventh.hash_state().hex_encode())
	assert_eq(seventh.portal_links().size(), 6)
	var floors: Dictionary = {}
	var max_abs: int = 0
	for entity_id: int in seventh.entity_ids():
		var record: SharedComponentRecord = seventh.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.TRANSFORM):
			continue
		var transform: Dictionary = record.components[SharedComponentNames.TRANSFORM]
		var x: int = transform.get("x", 0)
		var y: int = transform.get("y", 1)
		var z: int = transform.get("z", 0)
		max_abs = maxi(max_abs, maxi(absi(x), maxi(absi(y), absi(z))))
		if y % CELL != 0:
			continue
		floors[y / CELL] = true
	assert_true(floors.has(-7))
	assert_true(floors.has(-5))
	assert_true(floors.has(-3))
	assert_true(floors.has(-1))
	assert_true(floors.has(1))
	assert_true(floors.has(3))
	assert_true(floors.has(5))
	assert_gt(max_abs, 8 * CELL)
	assert_eq(PlayStubs.play_range_half_for(_compile(COURSE_07_PATH)), max_abs)
	assert_eq(PlayStubs.play_range_half_for(_compile(COURSE_01_PATH)), OutOfRangeReset.STUB_HALF)


func test_course_07_compiles_portal_lift_and_finish_bags() -> void:
	var bundle: SimulationBundle = _compile(COURSE_07_PATH)
	assert_not_null(bundle)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.portals.size(), 6)
	assert_eq(bundle.launches.size(), 0)
	assert_eq(bundle.pads.size(), 1)
	assert_eq(bundle.movers.size(), 3)
	var lift_count: int = 0
	for bag: Dictionary in bundle.movers:
		var entity_id: int = bag.get("entity_id", 0)
		if entity_id == 20 or entity_id == 21 or entity_id == 22:
			lift_count += 1
	assert_eq(lift_count, 3)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))


func test_higher_floors_do_not_hide_the_cell_under_the_locked_camera() -> void:
	var sixth: SimulationBundle = _compile(COURSE_06_PATH)
	var seventh: SimulationBundle = _compile(COURSE_07_PATH)
	assert_true(_cell_is_hidden(sixth, 0, -7, 0))
	assert_eq(_hidden_floor_count(seventh), 0)


func test_climb_script_finishes_via_three_portal_hops() -> void:
	var names: Array = Course07Scripts.climb_names()
	assert_true(names.has("wait"))
	assert_true(names.has("move+x"))
	assert_true(names.has("move-x"))
	assert_false(names.has("use_item"))
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(COURSE_07_PATH), names)
	assert_true(_ok(replay), str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_07.json"))


func _compile(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _hidden_floor_count(bundle: SimulationBundle) -> int:
	var packed: Dictionary = _solid_index(bundle)
	var cells: Array = packed["cells"]
	var buckets: Dictionary = packed["buckets"]
	var dir: Vector3 = PlaceholderSpec.CAMERA_OFFSET
	var hidden: int = 0
	for cell_raw: Variant in cells:
		var cell: Vector3i = cell_raw
		var origin: Vector3 = Vector3(float(cell.x), float(cell.y) + _RAY_Y, float(cell.z))
		if _camera_ray_hits_higher(cell, origin, dir, buckets):
			hidden += 1
	return hidden


func _cell_is_hidden(bundle: SimulationBundle, x: int, y: int, z: int) -> bool:
	var packed: Dictionary = _solid_index(bundle)
	var buckets: Dictionary = packed["buckets"]
	var cell: Vector3i = Vector3i(x, y, z)
	var origin: Vector3 = Vector3(float(x), float(y) + _RAY_Y, float(z))
	return _camera_ray_hits_higher(cell, origin, PlaceholderSpec.CAMERA_OFFSET, buckets)


func _solid_index(bundle: SimulationBundle) -> Dictionary:
	var cells: Array[Vector3i] = []
	for raw: Variant in bundle.solids:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var solid: Dictionary = raw
		var x: int = solid.get("x", 0) / CELL
		var y: int = solid.get("y", 0) / CELL
		var z: int = solid.get("z", 0) / CELL
		cells.append(Vector3i(x, y, z))
	var buckets: Dictionary = {}
	for cell: Vector3i in cells:
		var key: Vector2i = Vector2i(cell.x, cell.z)
		if not buckets.has(key):
			buckets[key] = []
		var column: Array = buckets[key]
		column.append(cell.y)
		buckets[key] = column
	return {"cells": cells, "buckets": buckets}


func _camera_ray_hits_higher(
	cell: Vector3i, origin: Vector3, dir: Vector3, buckets: Dictionary
) -> bool:
	var dx: int = -1
	while dx <= 14:
		var dz: int = -1
		while dz <= 14:
			var key: Vector2i = Vector2i(cell.x + dx, cell.z + dz)
			if buckets.has(key):
				var column: Array = buckets[key]
				for y_raw: Variant in column:
					var y: int = y_raw
					if y <= cell.y:
						continue
					var center: Vector3 = Vector3(float(key.x), float(y), float(key.y))
					if _ray_hits_box(origin, dir, center, _BOX_HALF):
						return true
			dz += 1
		dx += 1
	return false


func _ray_hits_box(origin: Vector3, dir: Vector3, center: Vector3, half: float) -> bool:
	var tmin: float = 0.0
	var tmax: float = 100000.0
	var axes: Array[int] = [0, 1, 2]
	for axis: int in axes:
		var o: float = origin[axis]
		var d: float = dir[axis]
		var c: float = center[axis]
		if absf(d) < 0.000001:
			if o < c - half or o > c + half:
				return false
			continue
		var inv: float = 1.0 / d
		var t1: float = (c - half - o) * inv
		var t2: float = (c + half - o) * inv
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		if t1 > tmin:
			tmin = t1
		if t2 < tmax:
			tmax = t2
		if tmin > tmax:
			return false
	return tmax > 0.001


func _ok(result: Dictionary) -> bool:
	return result.get("ok", false)
