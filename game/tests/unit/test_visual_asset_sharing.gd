extends GutTest

## C4 第 7 章：单网格视觉资产走共享 `Mesh`，不走 `PackedScene.instantiate()`。
##
## 存在的理由是每帧与每次挂课程的成本。开发机实测（不是 CI 门禁，见 CD-53 §1.1）：
##
## | | 修复前 | 修复后 |
## |---|---|---|
## | 实例化 36 个地砖 | 55.9 ms | 0.18 ms |
## | `MatchSolidMap.apply_bundle` 挂课程 | 64.6 ms | 2.0 ms |
## | `AuthoringPreviewMap.rebuild`（Preview 每帧） | 74.3 ms | 8.0 ms |
##
## 这里断言的是**共享与隔离这对性质**，不是毫秒数：
##   共享——两个实例引用同一个 `Mesh` 对象（省的就是这个）；
##   隔离——改一个实例的颜色不许串到另一个（这是共享最容易踩的坑）。
## 外加一条回退：多网格 / 带 skin 的资产必须回到 instantiate，否则蒙皮资产
## 一进来就会静默丢层级。

const MULTI_MESH_PATH: String = "user://test_multi_mesh_asset.tscn"
const SKINNED_PATH: String = "user://test_skinned_asset.tscn"
const EPS: float = 0.0001


func before_each() -> void:
	SharedVisualAssetCatalog.clear_template_cache()


func after_each() -> void:
	SharedVisualAssetCatalog.clear_template_cache()
	for path: String in [MULTI_MESH_PATH, SKINNED_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- 共享 -------------------------------------------------------------------


func test_two_instances_share_one_mesh_object() -> void:
	var a: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	var b: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	var mesh_a: Mesh = _only_mesh(a)
	var mesh_b: Mesh = _only_mesh(b)
	assert_not_null(mesh_a)
	assert_not_null(mesh_b)
	assert_same(mesh_a, mesh_b, "两个实例没有共享同一份 Mesh，省下的开销就没了")
	assert_true(a != b, "两个实例本身必须是不同节点")
	a.free()
	b.free()


func test_character_also_shares_its_mesh() -> void:
	var a: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	var b: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_same(_only_mesh(a), _only_mesh(b))
	a.free()
	b.free()


## 层级必须仍是「根 Node3D + 子 MeshInstance3D」两层。
## 不是洁癖：`local_bounds` 对根节点跳过自身 transform（`is_root`），所以把带
## 非 identity transform 的网格当根返回，AABB 会算漏一层、`fit_tile_on_cell`
## 随之贴错。今天的资产恰好是 identity，这条断言是为了不依赖那个"恰好"。
func test_shared_instance_keeps_container_root_and_mesh_child() -> void:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(visual)
	if visual == null:
		return
	assert_null(visual as MeshInstance3D, "根不该直接是 MeshInstance3D")
	assert_eq(visual.get_child_count(), 1)
	assert_not_null(visual.get_child(0) as MeshInstance3D, "网格该在子节点上")
	visual.free()


## 共享路径必须和 instantiate 路径算出同一个 AABB，否则贴合会偏。
func test_shared_instance_reports_the_same_bounds_as_instantiate() -> void:
	var shared: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(shared)
	if shared == null:
		return
	var shared_bounds: AABB = SharedVisualAssetCatalog.local_bounds(shared)
	shared.free()
	# 直接走 PackedScene，绕开模板缓存
	var packed: PackedScene = load(SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var raw: Node3D = packed.instantiate() as Node3D
	assert_not_null(raw)
	if raw == null:
		return
	var raw_bounds: AABB = SharedVisualAssetCatalog.local_bounds(raw)
	raw.free()
	assert_almost_eq(shared_bounds.position.x, raw_bounds.position.x, EPS)
	assert_almost_eq(shared_bounds.position.y, raw_bounds.position.y, EPS)
	assert_almost_eq(shared_bounds.position.z, raw_bounds.position.z, EPS)
	assert_almost_eq(shared_bounds.size.x, raw_bounds.size.x, EPS)
	assert_almost_eq(shared_bounds.size.y, raw_bounds.size.y, EPS)
	assert_almost_eq(shared_bounds.size.z, raw_bounds.size.z, EPS)


# --- 隔离：共享 Mesh 最容易踩的坑 --------------------------------------------


## 座位色必须只染自己那一个实例。`tint` 走 `material_overlay`（MeshInstance3D
## 自己的属性），不碰 `Mesh`，所以共享是安全的——但这件事必须被钉住，因为哪天
## 有人改成 `mesh.surface_set_material()`，全场角色会一起变色，且测试不会报错。
func test_tinting_one_instance_does_not_bleed_into_another() -> void:
	var a: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	var b: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	SharedVisualAssetCatalog.tint(a, Color(1.0, 0.0, 0.0))
	SharedVisualAssetCatalog.tint(b, Color(0.0, 0.0, 1.0))
	var overlay_a: StandardMaterial3D = _overlay_of(a)
	var overlay_b: StandardMaterial3D = _overlay_of(b)
	assert_not_null(overlay_a)
	assert_not_null(overlay_b)
	if overlay_a == null or overlay_b == null:
		return
	assert_almost_eq(overlay_a.albedo_color.r, 1.0, EPS)
	assert_almost_eq(overlay_b.albedo_color.b, 1.0, EPS)
	assert_almost_eq(overlay_a.albedo_color.b, 0.0, EPS, "A 被 B 的颜色串了")
	# 共享的 Mesh 自己的 surface material 不该被任何一次 tint 改动
	var mesh: Mesh = _only_mesh(a)
	assert_same(mesh, _only_mesh(b))
	a.free()
	b.free()


## 缩放一个实例不许影响另一个：transform 在节点上，不在 Mesh 上。
func test_fitting_one_tile_does_not_move_another() -> void:
	var a: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_tile()
	var b: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_ne(a.scale.x, b.scale.x, "贴合过的实例与没贴合的不该同缩放")
	assert_almost_eq(b.scale.x, 1.0, EPS, "没贴合的实例被别人的缩放串了")
	a.free()
	b.free()


# --- 回退：不能扁平化的资产必须走 instantiate ---------------------------------


func test_multi_mesh_asset_falls_back_to_full_instantiate() -> void:
	assert_true(_save_multi_mesh_scene(), "测试资产存盘失败")
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(MULTI_MESH_PATH)
	assert_not_null(visual, "多网格资产该照搬整棵子树，不该返回 null")
	if visual == null:
		return
	assert_eq(
		_mesh_instances(visual).size(),
		2,
		"多网格资产被扁平化成一个网格了——共享 Mesh 表达不了多个 surface 的层级"
	)
	visual.free()


func test_skinned_asset_falls_back_to_full_instantiate() -> void:
	assert_true(_save_skinned_scene(), "测试资产存盘失败")
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(SKINNED_PATH)
	assert_not_null(visual)
	if visual == null:
		return
	# 蒙皮网格离开原层级就不是同一个东西，必须保住 Skeleton3D
	var skeletons: int = 0
	for child: Node in visual.get_children():
		if child is Skeleton3D:
			skeletons += 1
	assert_eq(skeletons, 1, "带 skin 的资产丢了 Skeleton3D，说明被错误扁平化")
	visual.free()


func test_missing_and_non_scene_paths_still_return_null() -> void:
	assert_null(SharedVisualAssetCatalog.try_instantiate(""))
	assert_null(SharedVisualAssetCatalog.try_instantiate("res://does_not_exist.glb"))
	assert_null(
		SharedVisualAssetCatalog.try_instantiate("res://content/official/traprush/course_01.json"),
		"非场景资源不该被当成视觉"
	)


## 判过一次不能扁平化，就不该每次再 instantiate 一遍去重判。
func test_template_verdict_is_cached_for_both_outcomes() -> void:
	assert_true(_save_multi_mesh_scene())
	var first: Node3D = SharedVisualAssetCatalog.try_instantiate(MULTI_MESH_PATH)
	assert_not_null(first)
	if first != null:
		first.free()
	var second: Node3D = SharedVisualAssetCatalog.try_instantiate(MULTI_MESH_PATH)
	assert_not_null(second, "第二次仍该拿到实例（缓存的是判定，不是实例）")
	if second != null:
		assert_eq(_mesh_instances(second).size(), 2)
		second.free()
	# 清缓存后仍然可用，不能因为清了就再也解析不出来
	SharedVisualAssetCatalog.clear_template_cache()
	var third: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(third)
	if third != null:
		third.free()


# --- helpers ------------------------------------------------------------------


func _save_multi_mesh_scene() -> bool:
	var root: Node3D = Node3D.new()
	for index: int in 2:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "mesh_%d" % index
		instance.mesh = BoxMesh.new()
		instance.position = Vector3(float(index), 0.0, 0.0)
		root.add_child(instance)
		instance.owner = root
	var packed: PackedScene = PackedScene.new()
	var packed_ok: int = packed.pack(root)
	root.free()
	if packed_ok != OK:
		return false
	return ResourceSaver.save(packed, MULTI_MESH_PATH) == OK


func _save_skinned_scene() -> bool:
	var root: Node3D = Node3D.new()
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	skeleton.owner = root
	skeleton.add_bone("root_bone")
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "skinned_mesh"
	instance.mesh = BoxMesh.new()
	skeleton.add_child(instance)
	instance.owner = root
	instance.skeleton = NodePath("..")
	var packed: PackedScene = PackedScene.new()
	var packed_ok: int = packed.pack(root)
	root.free()
	if packed_ok != OK:
		return false
	return ResourceSaver.save(packed, SKINNED_PATH) == OK


func _only_mesh(root: Node3D) -> Mesh:
	var found: Array[MeshInstance3D] = _mesh_instances(root)
	if found.size() != 1:
		return null
	return found[0].mesh


func _overlay_of(root: Node3D) -> StandardMaterial3D:
	for instance: MeshInstance3D in _mesh_instances(root):
		var overlay: StandardMaterial3D = instance.material_overlay as StandardMaterial3D
		if overlay != null:
			return overlay
	return null


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var instance: MeshInstance3D = root as MeshInstance3D
	if instance != null:
		found.append(instance)
	for child: Node in root.get_children():
		found.append_array(_mesh_instances(child))
	return found
