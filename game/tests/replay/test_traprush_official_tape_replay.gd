extends GutTest

## CD-53 §2.4 里已经落地的回放路径：相同种子、同一份官方课、同一串输入，
## 必须得到相同关键状态哈希与相同快照字节。
##
## 覆盖：官方 course_01 的传送 + 检查点 + 冲线（+X 五步捷径仍走通；更长安全路
## 由 C3 第 5 章的语义课测试覆盖）；周期关键快照
## 以每 tick 的 `hash_state` 对照第二轮，不是把世界从环形缓冲恢复再继续
## ——`SimSnapshotRing` 只存哈希副本，恢复执行尚未实现，本章不假装它存在。
##
## 仍未实现、因此不写假绿的 §2.4 项：版本不匹配拒绝播放（没有独立回放文件
## 格式）、P0/P1 PatchHash 按原顺序重放（M4）、BASTION 回放（冻结）。
## 灰盒 PLAYER/SYSTEM 磁带回放仍在 `tests/unit/test_traprush_graybox_course.gd`；
## 本目录收的是对局会话这一层。
##
## `--bot-run` 的搜索不进这里，也不进 CI。沿路地板后三张课的 completable
## 由 `tests/unit/test_traprush_official_path_floors.gd` 覆盖。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const FINISH_STEPS: int = 5
const MATCH_SEED: int = 1


func test_same_course_same_seed_same_tape_match_hash_and_snapshots() -> void:
	var left: Dictionary = _run_two_player_tape(COURSE_01_PATH, MATCH_SEED)
	var right: Dictionary = _run_two_player_tape(COURSE_01_PATH, MATCH_SEED)
	assert_true(_flag(left, "ok"))
	assert_true(_flag(right, "ok"))
	_assert_hash_tape_matches(left, right)
	assert_eq(_int_at(left, "finish0"), 4)
	assert_eq(_int_at(right, "finish0"), 4)
	assert_eq(_int_at(left, "finish1"), 4)


func test_extra_move_on_one_side_diverges_hash() -> void:
	var baseline: Dictionary = _run_two_player_tape(COURSE_01_PATH, MATCH_SEED)
	assert_true(_flag(baseline, "ok"))
	var drifted: MatchRealtime = _two_player_realtime(COURSE_01_PATH, MATCH_SEED)
	assert_eq(drifted.add_player(), 0)
	assert_eq(drifted.add_player(), 1)
	var move: PackedByteArray = _move_cell()
	for _step: int in range(FINISH_STEPS):
		assert_true(drifted.accept_command(0, move))
		assert_true(drifted.accept_command(1, move))
		drifted.commit_tick()
	assert_true(drifted.accept_command(1, MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, 0, CELL, -1)))
	drifted.commit_tick()
	var baseline_hash: String = str(baseline.get("final_hash", ""))
	assert_ne(drifted.session.hash_state(), baseline_hash)


func test_different_official_course_same_tape_diverges_hash() -> void:
	var first: Dictionary = _run_two_player_tape(COURSE_01_PATH, MATCH_SEED)
	var second: Dictionary = _run_two_player_tape(COURSE_02_PATH, MATCH_SEED)
	assert_true(_flag(first, "ok"))
	assert_true(_flag(second, "ok"))
	assert_ne(str(first.get("final_hash", "")), str(second.get("final_hash", "")))


func test_different_seed_same_tape_still_matches_on_v1_topology() -> void:
	# v1 官方课没有 RNG 消费点。不同种子必须仍走出同一份哈希，避免把「未接线的
	# 种子」说成已经影响权威状态。真随机一旦进仿真，这条就要改成「必须分叉」。
	var left: Dictionary = _run_two_player_tape(COURSE_01_PATH, 1)
	var right: Dictionary = _run_two_player_tape(COURSE_01_PATH, 99)
	assert_true(_flag(left, "ok"))
	assert_true(_flag(right, "ok"))
	_assert_hash_tape_matches(left, right)


func _run_two_player_tape(course_path: String, seed: int) -> Dictionary:
	var realtime: MatchRealtime = _two_player_realtime(course_path, seed)
	if realtime == null:
		return {"ok": false}
	if realtime.add_player() != 0:
		return {"ok": false}
	if realtime.add_player() != 1:
		return {"ok": false}
	var move: PackedByteArray = _move_cell()
	var hashes: PackedStringArray = PackedStringArray()
	var frame_hexes: PackedStringArray = PackedStringArray()
	for _step: int in range(FINISH_STEPS):
		if not realtime.accept_command(0, move):
			return {"ok": false}
		if not realtime.accept_command(1, move):
			return {"ok": false}
		realtime.commit_tick()
		hashes.append(realtime.session.hash_state())
		frame_hexes.append(realtime.snapshot_frame().hex_encode())
	return {
		"ok": true,
		"hash_tape": "\n".join(hashes),
		"frame_tape": "\n".join(frame_hexes),
		"hash_steps": hashes.size(),
		"final_hash": realtime.session.hash_state(),
		"finish0": realtime.session.player_finish_tick(0),
		"finish1": realtime.session.player_finish_tick(1),
	}


func _assert_hash_tape_matches(left: Dictionary, right: Dictionary) -> void:
	assert_eq(_int_at(left, "hash_steps"), FINISH_STEPS)
	assert_eq(_int_at(right, "hash_steps"), FINISH_STEPS)
	assert_eq(str(left.get("hash_tape", "")), str(right.get("hash_tape", "x")))
	assert_eq(str(left.get("frame_tape", "")), str(right.get("frame_tape", "x")))
	assert_eq(str(left.get("final_hash", "")), str(right.get("final_hash", "x")))


func _flag(result: Dictionary, key: String) -> bool:
	var value: bool = result.get(key, false)
	return value


func _int_at(result: Dictionary, key: String) -> int:
	var value: int = result.get(key, -1)
	return value


func _two_player_realtime(course_path: String, seed: int) -> MatchRealtime:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(course_path)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = []
	for index: int in range(2):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		seed,
		2,
		offsets,
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	assert_not_null(session)
	return MatchRealtime.create(session)


func _move_cell() -> PackedByteArray:
	return MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
