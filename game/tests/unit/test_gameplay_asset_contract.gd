extends GutTest

## GameplayAsset 契约（[ADR-0006]，人类 2026-08-29 按 Q1=B / Q2=A / Q3=A / Q4=A /
## Q5=A / Q6=A 整包拍板）。
##
## 这一批断言要证明的不是"字段能存进去"，而是四件会被后续章反复依赖的事：
##
## 1. **v1 迁移逐字节等价**：老内容按"占满一格"迁移后，占用与旧 `cell / 2` 完全
##    一样——在任意 `cell` 下都一样。这是"不许顺手改数值"的守门断言。
## 2. **权威碰撞真的与视觉盒解耦**：bundle 里换一组碰撞尺寸，占用就变，且完全
##    不碰任何视觉代码。今天两者数值相等只是因为唯一内置资产就是占满一格。
## 3. **改碰撞必须升版本**（CD-31 §5）：目录的 (asset_id, gameplay_version, 几何)
##    被金标钉住。谁改了几何忘了升版本，这里会红。
## 4. **创作者不能自填尺寸**（Q5）：编译期只认目录里登记的 id 与当前版本。
##
## 回放哈希不在本批：形状不进 `hash_state`（只有 tick 与每实体 x/y/z/yaw/vy），
## 所以本章不改哈希算法。跨版本回放会因为轨迹不同而分叉，这正是形状必须绑定到
## 不可变版本的理由（ADR-0006 §1.4）。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SharedGameplayAssetCatalog := preload("res://src/shared/schema/gameplay_asset_catalog.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const LATTICE_ID: int = 1
const LATTICE_VERSION: int = 1


# 1. 目录金标：改几何忘了升版本，这条先红。

func test_catalog_pins_lattice_geometry_to_its_gameplay_version() -> void:
	assert_eq(SharedGameplayAssetCatalog.LATTICE_CELL_ID, LATTICE_ID)
	assert_eq(SharedGameplayAssetCatalog.LATTICE_CELL_VERSION, LATTICE_VERSION)
	assert_eq(SharedGameplayAssetCatalog.current_version(LATTICE_ID), LATTICE_VERSION)
	assert_true(SharedGameplayAssetCatalog.has_version(LATTICE_ID, LATTICE_VERSION))
	# 占满一格的半长是 cell / 2，且**随 cell 缩放**，不是写死的 32768。
	var at_one_cell: Dictionary = SharedGameplayAssetCatalog.try_collision(
		LATTICE_ID, LATTICE_VERSION, CELL
	)
	assert_eq(_text_at(at_one_cell, "kind"), "box")
	assert_eq(_int_at(at_one_cell, "hx"), CELL / 2)
	assert_eq(_int_at(at_one_cell, "hy"), CELL / 2)
	assert_eq(_int_at(at_one_cell, "hz"), CELL / 2)
	var at_double_cell: Dictionary = SharedGameplayAssetCatalog.try_collision(
		LATTICE_ID, LATTICE_VERSION, 2 * CELL
	)
	assert_eq(_int_at(at_double_cell, "hx"), CELL)
	# 一期挂点只留字段位，仿真不消费。
	var points: Array[Dictionary] = SharedGameplayAssetCatalog.try_attach_points(
		LATTICE_ID, LATTICE_VERSION
	)
	assert_eq(points.size(), 0)


func test_catalog_rejects_unknown_asset_and_stale_version() -> void:
	assert_false(SharedGameplayAssetCatalog.has_asset(9))
	assert_eq(SharedGameplayAssetCatalog.current_version(9), 0)
	assert_false(SharedGameplayAssetCatalog.has_version(9, 1))
	assert_false(SharedGameplayAssetCatalog.has_version(LATTICE_ID, LATTICE_VERSION + 1))
	assert_false(SharedGameplayAssetCatalog.has_version(LATTICE_ID, 0))
	assert_true(SharedGameplayAssetCatalog.try_collision(9, 1, CELL).is_empty())
	assert_true(SharedGameplayAssetCatalog.try_entry(LATTICE_ID, LATTICE_VERSION, 0).is_empty())


# 2. v1 → v2 迁移：占用逐字节不变。

func test_v1_bundle_migrates_to_lattice_asset_without_changing_occupancy() -> void:
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(_v1_solid_body(CELL))
	assert_not_null(decoded)
	assert_eq(decoded.assets.size(), 1)
	var entry: Dictionary = decoded.assets[0]
	assert_eq(_int_at(entry, "asset_id"), LATTICE_ID)
	assert_eq(_int_at(entry, "gameplay_version"), LATTICE_VERSION)
	assert_eq(_int_at(decoded.asset_collision(LATTICE_ID), "hx"), CELL / 2)
	var solid: Dictionary = decoded.solids[0]
	assert_eq(_int_at(solid, "asset_id"), LATTICE_ID)
	assert_eq(_int_at(solid, "gameplay_version"), LATTICE_VERSION)
	# 迁移是单向的：编码回去只会是 v2。
	assert_eq(_int_at(decoded.to_dictionary(), "schema_version"), SimulationBundle.SCHEMA_VERSION)
	# 占用与旧 cell / 2 行为一致：贴着格边缘仍相交，离开一格就不相交。
	var loaded: Dictionary = TraprushTopologyLoader.try_load(decoded, 1)
	assert_true(_flag(loaded))
	var world: SimulationWorld = loaded["world"]
	var solid_ids: Dictionary = loaded["solid_ids"]
	var box_id: int = solid_ids[70]
	assert_true(_overlaps_at(world, box_id, CELL / 2, 0, 0))
	assert_false(_overlaps_at(world, box_id, CELL, 0, 0))


func test_v1_migration_scales_with_cell_instead_of_hardcoding_32768() -> void:
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(_v1_solid_body(2 * CELL))
	assert_not_null(decoded)
	var collision: Dictionary = decoded.asset_collision(LATTICE_ID)
	assert_eq(_int_at(collision, "hx"), CELL)
	assert_eq(_int_at(collision, "hy"), CELL)
	assert_eq(_int_at(collision, "hz"), CELL)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(decoded, 1)
	assert_true(_flag(loaded))
	var world: SimulationWorld = loaded["world"]
	var solid_ids: Dictionary = loaded["solid_ids"]
	var box_id: int = solid_ids[70]
	assert_true(_overlaps_at(world, box_id, CELL, 0, 0))
	assert_false(_overlaps_at(world, box_id, 2 * CELL, 0, 0))


func test_official_course_01_compiles_to_lattice_asset_only() -> void:
	var bundle: SimulationBundle = _compile_course(COURSE_01_PATH)
	assert_not_null(bundle)
	assert_eq(bundle.assets.size(), 1)
	var entry: Dictionary = bundle.assets[0]
	assert_eq(_int_at(entry, "asset_id"), LATTICE_ID)
	assert_eq(_int_at(bundle.asset_collision(LATTICE_ID), "hx"), CELL / 2)
	for solid: Dictionary in bundle.solids:
		assert_eq(_int_at(solid, "asset_id"), LATTICE_ID)
		assert_eq(_int_at(solid, "gameplay_version"), LATTICE_VERSION)


# 3. 权威碰撞与视觉盒解耦：换尺寸就换占用，且没碰任何视觉代码。

func test_loader_uses_bundle_collision_not_the_one_metre_visual_box() -> void:
	var slim_half: int = CELL / 4
	var asset: Dictionary = _box_asset(2, 3, slim_half, CELL / 2, slim_half)
	var body: Dictionary = _v2_body(CELL, [asset], [_solid_bag(70, 0, 0, 0, 2, 3)])
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(body)
	assert_not_null(decoded)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(decoded, 1)
	assert_true(_flag(loaded))
	var world: SimulationWorld = loaded["world"]
	var solid_ids: Dictionary = loaded["solid_ids"]
	var box_id: int = solid_ids[70]
	# 占满一格时 CELL / 2 处相交；这条资产只有 CELL / 4 宽，所以不再相交。
	assert_false(_overlaps_at(world, box_id, CELL / 2, 0, 0))
	assert_true(_overlaps_at(world, box_id, slim_half, 0, 0))
	# Y 轴仍是半格：三个轴各自独立，不是被同一个 cell / 2 绑住。
	assert_true(_overlaps_at(world, box_id, 0, CELL / 2, 0))
	assert_false(_overlaps_at(world, box_id, 0, CELL, 0))


func test_same_bundle_can_mix_two_assets_with_different_collision() -> void:
	var slim_half: int = CELL / 4
	var body: Dictionary = _v2_body(CELL, [
		_box_asset(LATTICE_ID, LATTICE_VERSION, CELL / 2, CELL / 2, CELL / 2),
		_box_asset(7, 4, slim_half, slim_half, slim_half),
	], [
		_solid_bag(70, 0, 0, 0, LATTICE_ID, LATTICE_VERSION),
		_solid_bag(71, 4 * CELL, 0, 0, 7, 4),
	])
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.assets.size(), 2)
	assert_eq(_int_at(decoded.asset_collision(7), "hx"), slim_half)
	assert_true(decoded.asset_collision(9).is_empty())
	var loaded: Dictionary = TraprushTopologyLoader.try_load(decoded, 1)
	assert_true(_flag(loaded))
	var world: SimulationWorld = loaded["world"]
	var solid_ids: Dictionary = loaded["solid_ids"]
	var wide_id: int = solid_ids[70]
	var slim_id: int = solid_ids[71]
	assert_true(_overlaps_at(world, wide_id, CELL / 2, 0, 0))
	assert_false(_overlaps_at(world, slim_id, 4 * CELL + CELL / 2, 0, 0))
	assert_true(_overlaps_at(world, slim_id, 4 * CELL + slim_half, 0, 0))


# 4. 引用闭合与准入。

func test_bundle_rejects_broken_asset_references() -> void:
	var lattice: Dictionary = _box_asset(LATTICE_ID, LATTICE_VERSION, CELL / 2, CELL / 2, CELL / 2)
	# 引用了不存在的资产。
	var missing: Dictionary = _v2_body(CELL, [lattice], [_solid_bag(70, 0, 0, 0, 9, 1)])
	assert_null(SimulationBundle.from_dictionary(missing))
	# 版本与资产表不一致。
	var mismatched: Dictionary = _v2_body(
		CELL, [lattice], [_solid_bag(70, 0, 0, 0, LATTICE_ID, 2)]
	)
	assert_null(SimulationBundle.from_dictionary(mismatched))
	# 声明了却没人引用：wire 形状必须规范，不许夹带。
	var unused: Dictionary = _v2_body(CELL, [lattice], [])
	assert_null(SimulationBundle.from_dictionary(unused))
	# 资产表必须按 asset_id 严格升序（顺带排掉重复 id）。
	var out_of_order: Dictionary = _v2_body(CELL, [
		_box_asset(7, 4, CELL / 2, CELL / 2, CELL / 2),
		lattice,
	], [
		_solid_bag(70, 0, 0, 0, LATTICE_ID, LATTICE_VERSION),
		_solid_bag(71, CELL, 0, 0, 7, 4),
	])
	assert_null(SimulationBundle.from_dictionary(out_of_order))


func test_bundle_rejects_malformed_asset_entries() -> void:
	var lattice: Dictionary = _box_asset(LATTICE_ID, LATTICE_VERSION, CELL / 2, CELL / 2, CELL / 2)
	var solids: Array = [_solid_bag(70, 0, 0, 0, LATTICE_ID, LATTICE_VERSION)]
	var no_attach: Dictionary = lattice.duplicate(true)
	no_attach.erase("attach_points")
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [no_attach], solids)))
	# 视觉网格不进 bundle（Q4）：多一个 mesh 键就整包拒。
	var visual: Dictionary = lattice.duplicate(true)
	visual["mesh"] = "res://art/box.glb"
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [visual], solids)))
	var bad_kind: Dictionary = lattice.duplicate(true)
	bad_kind["collision"] = {"kind": "mesh", "hx": 1, "hy": 1, "hz": 1}
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [bad_kind], solids)))
	var duplicate_point: Dictionary = lattice.duplicate(true)
	duplicate_point["attach_points"] = [
		{"name": "muzzle", "dx": 0, "dy": 0, "dz": 0},
		{"name": "muzzle", "dx": 1, "dy": 0, "dz": 0},
	]
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [duplicate_point], solids)))
	var unnamed_point: Dictionary = lattice.duplicate(true)
	unnamed_point["attach_points"] = [{"name": "", "dx": 0, "dy": 0, "dz": 0}]
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [unnamed_point], solids)))


func test_bundle_rejects_bags_missing_the_asset_reference() -> void:
	var lattice: Dictionary = _box_asset(LATTICE_ID, LATTICE_VERSION, CELL / 2, CELL / 2, CELL / 2)
	var bag: Dictionary = _solid_bag(70, 0, 0, 0, LATTICE_ID, LATTICE_VERSION)
	bag.erase("gameplay_version")
	assert_null(SimulationBundle.from_dictionary(_v2_body(CELL, [lattice], [bag])))


func test_loader_rejects_non_box_collision_instead_of_approximating_it() -> void:
	var sphere: Dictionary = {
		"asset_id": LATTICE_ID,
		"gameplay_version": LATTICE_VERSION,
		"collision": {"kind": "sphere", "radius": CELL / 2},
		"attach_points": [],
	}
	var body: Dictionary = _v2_body(
		CELL, [sphere], [_solid_bag(70, 0, 0, 0, LATTICE_ID, LATTICE_VERSION)]
	)
	# Schema 层接受球（CD-42 §1.1 白名单），加载层明确拒绝，而不是拿盒子近似。
	var decoded: SimulationBundle = SimulationBundle.from_dictionary(body)
	assert_not_null(decoded)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(decoded, 1)
	assert_false(_flag(loaded))


func test_compiler_only_accepts_registered_assets_at_current_version() -> void:
	var registered: AuthoringWorld = AuthoringWorld.new()
	assert_true(registered.put(_solid_record(70, 0, LATTICE_ID, LATTICE_VERSION)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(registered)
	assert_not_null(bundle)
	assert_eq(bundle.assets.size(), 1)
	var solid: Dictionary = bundle.solids[0]
	assert_eq(_int_at(solid, "asset_id"), LATTICE_ID)
	var unknown: AuthoringWorld = AuthoringWorld.new()
	assert_true(unknown.put(_solid_record(70, 0, 9, 1)))
	assert_null(TraprushTopologyCompiler.compile(unknown))
	var stale: AuthoringWorld = AuthoringWorld.new()
	assert_true(stale.put(_solid_record(70, 0, LATTICE_ID, LATTICE_VERSION + 1)))
	assert_null(TraprushTopologyCompiler.compile(stale))


func test_component_record_accepts_reference_and_rejects_authored_dimensions() -> void:
	var reference: SharedComponentRecord = SharedComponentRecord.create(70, {
		"gameplay_asset": {"asset_id": 1, "gameplay_version": 1},
	})
	assert_not_null(reference)
	assert_null(SharedComponentRecord.create(70, {
		"gameplay_asset": {"asset_id": 1, "gameplay_version": 1, "hx": 16384},
	}))
	assert_null(SharedComponentRecord.create(70, {
		"gameplay_asset": {"asset_id": 0, "gameplay_version": 1},
	}))
	assert_null(SharedComponentRecord.create(70, {
		"gameplay_asset": {"asset_id": 1, "gameplay_version": 0},
	}))
	assert_null(SharedComponentRecord.create(70, {"gameplay_asset": {"asset_id": 1}}))


func _compile_course(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	assert_not_null(world)
	return TraprushTopologyCompiler.compile(world)


func _overlaps_at(world: SimulationWorld, box_id: int, x: int, y: int, z: int) -> bool:
	var capsule_id: int = world.spawn_capsule(x, y, z, 0, 1, 1)
	var overlapping: PackedInt32Array = world.overlapping_static_boxes(capsule_id)
	for entry: int in overlapping:
		if entry == box_id:
			return true
	return false


func _int_at(body: Dictionary, key: String) -> int:
	var value: Variant = body.get(key, null)
	if typeof(value) != TYPE_INT:
		return -1
	return value


func _text_at(body: Dictionary, key: String) -> String:
	var value: Variant = body.get(key, null)
	if typeof(value) != TYPE_STRING:
		return ""
	return value


func _flag(result: Dictionary) -> bool:
	var value: Variant = result.get("ok", false)
	if typeof(value) != TYPE_BOOL:
		return false
	return value


func _box_asset(
	asset_id: int, gameplay_version: int, half_x: int, half_y: int, half_z: int
) -> Dictionary:
	return {
		"asset_id": asset_id,
		"gameplay_version": gameplay_version,
		"collision": {"kind": "box", "hx": half_x, "hy": half_y, "hz": half_z},
		"attach_points": [],
	}


func _solid_bag(
	entity_id: int, x: int, y: int, z: int, asset_id: int, gameplay_version: int
) -> Dictionary:
	return {
		"entity_id": entity_id,
		"x": x,
		"y": y,
		"z": z,
		"asset_id": asset_id,
		"gameplay_version": gameplay_version,
	}


func _v2_body(cell: int, assets: Array, solids: Array) -> Dictionary:
	return {
		"schema_version": 2,
		"cell": cell,
		"source_revision": 0,
		"assets": assets,
		"pads": [],
		"portals": [],
		"finish": [],
		"destructibles": [],
		"hazards": [],
		"solids": solids,
		"pickups": [],
	}


## 没有 `assets` 键、袋里也没有资产引用的旧 wire 形状。
func _v1_solid_body(cell: int) -> Dictionary:
	return {
		"schema_version": 1,
		"cell": cell,
		"source_revision": 0,
		"pads": [],
		"portals": [],
		"finish": [],
		"destructibles": [],
		"hazards": [],
		"solids": [{"entity_id": 70, "x": 0, "y": 0, "z": 0}],
		"pickups": [],
	}


func _solid_record(
	entity_id: int, x: int, asset_id: int, gameplay_version: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid"],
		},
		"gameplay_asset": {"asset_id": asset_id, "gameplay_version": gameplay_version},
	})
