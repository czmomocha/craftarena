extends GutTest

## 可玩性深化 轨 1「白名单移动件」：传送带。
## 不新增组件、不改 Component Schema v1：固体 + `zone.tags` 的 `conveyor` 标签
## + `transform.yaw_bam`。推送由服务端裁决，客户端不发送最终位置。

const ConveyorCycleGd := preload("res://src/games/traprush/conveyor_cycle.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const BELT_ID: int = 60
const FLOOR_ID: int = 61


# ---- 方向量化 ----

func test_yaw_quantises_to_four_world_directions() -> void:
	# 与 MatchMoveFacing 同一套 BAM 约定：yaw 0 = 世界 -Z。
	assert_eq(ConveyorCycleGd.direction_of(ConveyorCycleGd.YAW_FORWARD), Vector2i(0, -1))
	assert_eq(ConveyorCycleGd.direction_of(ConveyorCycleGd.YAW_LEFT), Vector2i(-1, 0))
	assert_eq(ConveyorCycleGd.direction_of(ConveyorCycleGd.YAW_BACK), Vector2i(0, 1))
	assert_eq(ConveyorCycleGd.direction_of(ConveyorCycleGd.YAW_RIGHT), Vector2i(1, 0))


func test_off_axis_yaw_snaps_to_the_nearest_of_the_four() -> void:
	# 斜推会让「我会被带到哪一格」在定点网格上不可预读，所以不做八向。
	assert_eq(ConveyorCycleGd.direction_of(Fixed.BAM_TURN / 8 - 1), Vector2i(0, -1))
	assert_eq(ConveyorCycleGd.direction_of(Fixed.BAM_TURN / 8 + 1), Vector2i(-1, 0))
	assert_eq(ConveyorCycleGd.direction_of(Fixed.BAM_TURN), Vector2i(0, -1), "整圈回到起点")
	assert_eq(ConveyorCycleGd.direction_of(-Fixed.BAM_TURN / 4), Vector2i(1, 0), "负角也归一")


# ---- 编译 ----

func test_conveyor_compiles_into_solids_plus_a_direction_bag() -> void:
	var bundle: SimulationBundleGd = _belt_bundle(ConveyorCycleGd.YAW_RIGHT)
	assert_not_null(bundle)
	assert_eq(bundle.conveyors.size(), 1)
	var bag: Dictionary = bundle.conveyors[0]
	var entity_id: int = bag["entity_id"]
	var yaw_bam: int = bag["yaw_bam"]
	assert_eq(entity_id, BELT_ID)
	assert_eq(yaw_bam, ConveyorCycleGd.YAW_RIGHT)
	var in_solids: bool = false
	for solid: Dictionary in bundle.solids:
		var solid_id: int = solid["entity_id"]
		if solid_id == BELT_ID:
			in_solids = true
	assert_true(in_solids, "几何住在 solids 袋里，方向袋只带 yaw")


func test_a_solid_without_the_tag_compiles_to_no_conveyor() -> void:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(_belt_record(BELT_ID, 0, ["solid"], 0)))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.conveyors.size(), 0)


func test_a_belt_that_also_moves_is_refused() -> void:
	# 自己在走 + 又把人往别处推：两段位移的先后顺序没有可解释的答案。
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(SharedComponentRecordGd.create(BELT_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "conveyor"],
		},
		"mover": {
			"path": [{"x": 0, "y": -CELL, "z": 0}, {"x": CELL, "y": -CELL, "z": 0}],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_key_still_decode() -> void:
	# 加袋不是 Schema 破坏性变更：省略与空数组等价。
	var bundle: SimulationBundleGd = _belt_bundle(ConveyorCycleGd.YAW_RIGHT)
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_CONVEYORS)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.conveyors.size(), 0)


func test_a_direction_bag_pointing_at_no_solid_is_refused() -> void:
	var bundle: SimulationBundleGd = _belt_bundle(ConveyorCycleGd.YAW_RIGHT)
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_CONVEYORS] = [{"entity_id": 999, "yaw_bam": 0}]
	assert_null(SimulationBundleGd.from_dictionary(body))


# ---- 权威推送 ----

func test_standing_on_a_belt_pushes_the_player_every_tick() -> void:
	var session: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	assert_eq(session.conveyor_count(), 1)
	var before: int = _pose_x(session)
	session.commit_tick()
	var after: int = _pose_x(session)
	assert_eq(after - before, TraprushPlayStubsGd.CONVEYOR_STEP, "顺着带子每 tick 推一步")


func test_a_zero_step_stub_keeps_the_belt_inert() -> void:
	var session: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	session.conveyor_step = 0
	var before: int = _pose_x(session)
	session.commit_tick()
	assert_eq(_pose_x(session), before, "步长是调用方注入的桩，0 表示不推")


func test_walking_against_the_belt_cannot_win() -> void:
	# 传送带步长是走路占位步长的两倍：逆行仍被带着往前一倍步长，走不回去。
	# 那个比值就是这块东西的全部玩法意义。
	var session: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	var before: int = _pose_x(session)
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNamesGd.MOVE,
		"dx": -PlaceholderSpec.MOVE_STEP,
		"dz": 0,
	}))
	session.commit_tick()
	assert_eq(
		_pose_x(session) - before,
		TraprushPlayStubsGd.CONVEYOR_STEP - PlaceholderSpec.MOVE_STEP,
		"逆行只抵消一半，净位移仍沿带子方向"
	)


func test_walking_with_the_belt_stacks() -> void:
	var session: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	var before: int = _pose_x(session)
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNamesGd.MOVE,
		"dx": PlaceholderSpec.MOVE_STEP,
		"dz": 0,
	}))
	session.commit_tick()
	assert_eq(
		_pose_x(session) - before,
		TraprushPlayStubsGd.CONVEYOR_STEP + PlaceholderSpec.MOVE_STEP
	)


func test_the_belt_does_not_move_a_player_who_is_not_standing_on_it() -> void:
	var session: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT, 4)
	var before: int = _pose_x(session)
	session.commit_tick()
	assert_eq(_pose_x(session), before, "站在别处不该被隔空推")


func test_two_sessions_with_the_same_belt_match_state_hash() -> void:
	var left: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	var right: TraprushMatchSessionGd = _belt_session(ConveyorCycleGd.YAW_RIGHT)
	for _index: int in range(8):
		left.commit_tick()
		right.commit_tick()
	assert_eq(left.hash_state(), right.hash_state())


func _pose_x(session: TraprushMatchSessionGd) -> int:
	var pose: Dictionary = session.player_pose(0)
	var x_value: int = pose.get("x", 0)
	return x_value


func _world_with_floor() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _belt_record(
	entity_id: int, cell_x: int, tags: Array, yaw_bam: int
) -> SharedComponentRecordGd:
	return SharedComponentRecordGd.create(entity_id, {
		"transform": {"x": cell_x * CELL, "y": -CELL, "z": 0, "yaw_bam": yaw_bam},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": tags,
		},
	})


func _belt_bundle(yaw_bam: int, belt_cell_x: int = 0) -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(_belt_record(BELT_ID, belt_cell_x, ["solid", "conveyor"], yaw_bam)))
	return TraprushTopologyCompilerGd.compile(world)


func _belt_session(yaw_bam: int, belt_cell_x: int = 0) -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = _belt_bundle(yaw_bam, belt_cell_x)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	# 重力桩会把人拉到带子顶面；本文件只关心水平推送，关掉下落免得混进 Y。
	session.fall_dy = 0
	return session
