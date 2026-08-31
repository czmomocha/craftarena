extends GutTest

## Preview 每帧重建的脏检查守卫。
##
## Preview play 每帧调 AuthoringPreviewMap.rebuild，而 AuthoringWorld 在一局试玩里
## 不变，所以之前每帧都 free + new 整棵节点树（49 实体开发机约 6.7 ms）。这批断言
## 钉的是「什么时候必须真重建、什么时候必须跳过」这对性质，**不是**耗时阈值
## （CD-53 §1.1 不建自动性能门禁）。
##
## 同时钉住脏检查引入的三个新义务：
## - 世界指纹变了（revision / 实体数 / 格宽 / 换实例 / 换视觉资产路径）必须重建；
## - 跳过重建之后，检查点标记与玩家标记仍然要跟上（幂等而不是只追加）；
## - 自己改过节点树（显隐）而世界没变时，必须 invalidate() 才能回到默认。

const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _map: AuthoringPreviewMap = null
var _shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_unchanged_world_reuses_the_same_nodes() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	assert_true(world.put(_record_transform(2, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)
	var first_id: int = _map.placeholder_node(1).get_instance_id()

	for _index: int in range(5):
		_map.rebuild(world)

	assert_eq(_map.rebuild_count(), 1, "世界没变却又重建了整棵节点树")
	assert_eq(_map.skipped_rebuild_count(), 5)
	assert_eq(_map.mapped_count(), 2)
	assert_eq(_map.placeholder_node(1).get_instance_id(), first_id, "占位盒被换成了新节点")


func test_revision_change_rebuilds() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)

	assert_true(world.put(_record_transform(2, CELL, 0, 0)))
	_map.rebuild(world)

	assert_eq(_map.rebuild_count(), 2)
	assert_eq(_map.mapped_count(), 2)
	assert_not_null(_map.placeholder_node(2))


func test_another_world_instance_at_the_same_revision_rebuilds() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)

	# duplicate() 保留 revision：只比 revision 会把回滚快照 / Preview 克隆当成「没变」。
	var clone: AuthoringWorld = world.duplicate()
	assert_not_null(clone)
	assert_eq(clone.revision, world.revision)
	_map.rebuild(clone)

	assert_eq(_map.rebuild_count(), 2)


func test_restore_to_the_same_revision_still_rebuilds() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	assert_true(world.put(_record_transform(2, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)
	assert_eq(_map.mapped_count(), 2)

	# try_restore 直接写 revision，能撞回同一个值；实体数这条把它接住。
	var records: Array[SharedComponentRecord] = [_record_transform(3, 0, 0, 0)]
	assert_true(world.try_restore(records, world.revision, CELL))
	_map.rebuild(world)

	assert_eq(_map.rebuild_count(), 2)
	assert_eq(_map.mapped_count(), 1)
	assert_null(_map.placeholder_node(1))
	assert_not_null(_map.placeholder_node(3))


func test_changing_the_tile_asset_path_rebuilds() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_solid(11, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)

	_map.tile_scene_path = ""
	_map.rebuild(world)

	assert_eq(_map.rebuild_count(), 2)
	assert_null(_map.placeholder_visual_node(11), "回退成占位盒之后还挂着地块视觉")


func test_invalidate_forces_one_rebuild() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 1)

	_map.invalidate()
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 2)
	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 2)


func test_null_world_clears_once_then_skips() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	_map.rebuild(null)
	assert_eq(_map.mapped_count(), 0)
	assert_eq(_map.rebuild_count(), 2)

	_map.rebuild(null)
	assert_eq(_map.rebuild_count(), 2)

	_map.rebuild(world)
	assert_eq(_map.rebuild_count(), 3)
	assert_eq(_map.mapped_count(), 1)


func test_accepted_marks_follow_the_set_without_a_rebuild() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_record_checkpoint(2, 1, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.checkpoint_node(1).text, "0")

	_map.mark_accepted_checkpoints(PackedInt32Array([1]))
	assert_eq(_map.checkpoint_node(1).text, "0*")
	assert_eq(_map.checkpoint_node(2).text, "1")

	# 幂等：再标一次不会变成 "0**"。
	_map.mark_accepted_checkpoints(PackedInt32Array([1]))
	assert_eq(_map.checkpoint_node(1).text, "0*")

	# R 复位把验收集合缩回空。rebuild 会被跳过，所以只能靠这里把 * 去掉。
	_map.rebuild(world)
	_map.mark_accepted_checkpoints(PackedInt32Array())
	assert_eq(_map.rebuild_count(), 1)
	assert_eq(_map.checkpoint_node(1).text, "0", "跳过重建之后留着陈旧的验收标记")
	assert_eq(_map.checkpoint_node(2).text, "1")


func test_player_marker_is_reused_across_frames() -> void:
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.show_player_pose({"x": 0, "y": 0, "z": 0, "yaw": 0})
	var marker: MeshInstance3D = _map.player_node()
	assert_not_null(marker)
	if marker == null:
		return
	var marker_id: int = marker.get_instance_id()

	_map.show_player_pose({"x": CELL, "y": 0, "z": 0, "yaw": 16384})

	var moved: MeshInstance3D = _map.player_node()
	assert_not_null(moved)
	if moved == null:
		return
	assert_eq(moved.get_instance_id(), marker_id, "玩家标记每帧被重建")
	assert_almost_eq(moved.position.x, 1.0, EPS)
	assert_almost_eq(moved.rotation.y, PI / 2.0, EPS)

	_map.show_player_pose({})
	assert_null(_map.player_node())


func test_player_marker_is_rebuilt_when_the_asset_path_changes() -> void:
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.show_player_pose({"x": 0, "y": 0, "z": 0})
	var first: MeshInstance3D = _map.player_node()
	assert_not_null(first)
	if first == null:
		return
	var first_id: int = first.get_instance_id()

	_map.character_scene_path = ""
	_map.show_player_pose({"x": 0, "y": 0, "z": 0})

	var second: MeshInstance3D = _map.player_node()
	assert_not_null(second)
	if second == null:
		return
	assert_ne(second.get_instance_id(), first_id, "换了视觉资产路径却复用了旧标记")
	assert_null(_map.player_visual_node())
	assert_eq(second.layers, 1)


func test_hazard_visibility_needs_invalidate_to_come_back() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_hazard(6, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	_map.apply_hazard_visibility({6: false})
	assert_false(_map.placeholder_node(6).visible)

	# 世界没变，脏检查跳过：显隐是别人改的，rebuild 不该假装它已经复位。
	_map.rebuild(world)
	assert_false(_map.placeholder_node(6).visible)

	_map.invalidate()
	_map.rebuild(world)
	assert_true(_map.placeholder_node(6).visible)


func test_preview_shell_skips_refreshes_that_change_nothing() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	var map: AuthoringPreviewMap = _shell.map
	assert_not_null(map)
	if map == null:
		return
	var after_open: int = map.rebuild_count()
	assert_true(after_open >= 1)

	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_checkpoint(1, 0, 0, 0, 0))))
	assert_eq(map.rebuild_count(), after_open + 1)

	# 重放同一条命令：expected_revision 已过期，世界不变，不该再重建一次。
	assert_false(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_checkpoint(1, 0, 0, 0, 0))))
	assert_eq(map.rebuild_count(), after_open + 1, "被拒的补丁也在重建整棵节点树")
	assert_eq(map.checkpoint_count(), 1)


func _record_transform(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
	})


func _record_solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": ["solid"],
		},
	})


func _record_hazard(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})


func _record_checkpoint(
	entity_id: int,
	order: int,
	x: int,
	y: int,
	z: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})


func _place_checkpoint(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"checkpoint": {
					"order": order,
					"respawn_dx": 0,
					"respawn_dy": 0,
					"respawn_dz": 0,
				},
			},
		},
	}


func _edit(command_id: int, expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		2,
		command_id,
		0,
		expected_revision,
		"content-v1",
		payload,
		"trace-preview-rebuild-diff",
		SharedCommand.Kind.EDIT
	)
