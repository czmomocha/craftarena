extends GutTest

## M6 E1：BASTION 实时帧与意图 id。
##
## 这一批要钉住的不是「字段能编进去」，是三件协议层一旦做错就藏不住的事：
##
## 1. **TRAPRUSH 帧一个字节不动。** type 1–4 的编解码仍在 `MatchFrameCodec`；
##    BASTION 走 type 5/6。两边互喂必须被拒，旧客户端不会把塔/兵读成位姿。
## 2. **六个 M6 意图有线上 id，DonateResource / Interact 没有。** 后者一个是 M7，
##    一个是 TRAPRUSH 里仍未接线的开关门。没有这条，下一个 Agent 会把
##    `DonateResourceIntent` 顺手编进 1v1。
## 3. **布障阶段的服务端裁剪。** 编码器吃的是权威 pending（双方都在），写出的
##    字节只含观察者自己的放置；揭示之后同一份权威才变成双方都在的快照。
##    若裁剪只发生在会话视图上、编码器原样下发，协议层就等于没藏。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionFrameCodec := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionMatchSessionWire := preload("res://src/games/bastion/match_session_wire.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedTowerTargetPriorities := preload("res://src/shared/schema/tower_target_priorities.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const TEAM_A: int = 1
const TEAM_B: int = 2
const A_MID: int = 2
const B_FORK: int = 9
const FAST_SETUP: int = 3
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40
const E9_LINE_CAP: int = 400
const CODEC_PATHS: PackedStringArray = [
	"res://src/shared/protocol/bastion_frame_codec.gd",
	"res://src/shared/protocol/bastion_frame_snapshot.gd",
	"res://src/games/bastion/match_session_wire.gd",
]


func test_command_round_trip_m6_intents() -> void:
	_assert_command(PlayerIntentNames.BUILD_TOWER, 30, 1, 0, 7)
	_assert_command(PlayerIntentNames.UPGRADE_TOWER, 31, 0, 0, 8)
	_assert_command(PlayerIntentNames.SELL_TOWER, 32, 0, 0, 9)
	_assert_command(PlayerIntentNames.SET_TOWER_PRIORITY, 30, 2, 0, 10)
	_assert_command(PlayerIntentNames.PLACE_OBSTACLE, 2, 21, 0, 11)
	_assert_command(PlayerIntentNames.LOCK_SETUP, 0, 0, 0, 12)


func test_command_encode_rejects_unwired_and_traprush_intents() -> void:
	assert_eq(
		BastionFrameCodec.encode_command(1, PlayerIntentNames.DONATE_RESOURCE, 0, 0, 0).size(),
		0
	)
	assert_eq(
		BastionFrameCodec.encode_command(1, PlayerIntentNames.INTERACT, 0, 0, 0).size(),
		0
	)
	assert_eq(
		BastionFrameCodec.encode_command(1, PlayerIntentNames.MOVE, 0, 0, 0).size(),
		0
	)
	assert_eq(
		MatchFrameCodec.encode_command(1, PlayerIntentNames.BUILD_TOWER, 0, 0, 0).size(),
		0
	)
	assert_eq(
		MatchFrameCodec.encode_command(1, PlayerIntentNames.PLACE_OBSTACLE, 0, 0, 0).size(),
		0
	)


func test_command_decode_rejects_nonzero_reserved() -> void:
	var bytes: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.LOCK_SETUP, 0, 0, 0
	)
	bytes.encode_s64(11, 1)
	var decoded: Dictionary = BastionFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", true)
	assert_false(decoded_ok)


func test_set_priority_round_trip_uses_whitelist_codes() -> void:
	var nearest: int = BastionFrameCodec.priority_id(SharedTowerTargetPriorities.NEAREST)
	var bytes: PackedByteArray = BastionFrameCodec.encode_command(
		2, PlayerIntentNames.SET_TOWER_PRIORITY, 30, nearest, 0
	)
	var decoded: Dictionary = BastionFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_true(decoded_ok)
	var arg1: int = decoded.get("arg1", -1)
	assert_eq(arg1, 2)
	assert_eq(BastionFrameCodec.priority_name(2), SharedTowerTargetPriorities.NEAREST)
	assert_eq(BastionFrameCodec.encode_command(
		2, PlayerIntentNames.SET_TOWER_PRIORITY, 30, 9, 0
	).size(), 0)


func test_traprush_and_bastion_frames_reject_each_other() -> void:
	var jump: PackedByteArray = MatchFrameCodec.encode_command(
		1, PlayerIntentNames.JUMP, 0, 0, 0
	)
	assert_eq(jump.size(), 35)
	assert_eq(jump.decode_u8(1), MatchFrameCodec.FRAME_COMMAND)
	var as_bastion: Dictionary = BastionFrameCodec.decode_command(jump)
	var as_bastion_ok: bool = as_bastion.get("ok", true)
	assert_false(as_bastion_ok)
	var build: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.BUILD_TOWER, 30, 1, 0
	)
	var as_traprush: Dictionary = MatchFrameCodec.decode_command(build)
	var as_traprush_ok: bool = as_traprush.get("ok", true)
	assert_false(as_traprush_ok)
	var trap_snap: PackedByteArray = MatchFrameCodec.encode_snapshot(1, [], [])
	var trap_as_bastion: Dictionary = BastionFrameCodec.decode_snapshot(trap_snap)
	var trap_as_bastion_ok: bool = trap_as_bastion.get("ok", true)
	assert_false(trap_as_bastion_ok)
	var empty_teams: Array[Dictionary] = []
	var bastion_snap: PackedByteArray = BastionFrameCodec.encode_snapshot(
		1, BastionMatchSession.PHASE_PREP, 0, 0, empty_teams, 0
	)
	assert_eq(bastion_snap.size(), BastionFrameCodec.SNAPSHOT_HEADER)
	var bastion_as_trap: Dictionary = MatchFrameCodec.decode_snapshot(bastion_snap)
	var bastion_as_trap_ok: bool = bastion_as_trap.get("ok", true)
	assert_false(bastion_as_trap_ok)


func test_snapshot_round_trip_and_canonical() -> void:
	var teams: Array[Dictionary] = [_team_body(TEAM_A, 80, true), _team_body(TEAM_B, 90, false)]
	teams[0]["towers"] = [{
		"slot_id": 30,
		"prototype_id": 1,
		"level": 2,
		"target_priority": SharedTowerTargetPriorities.FRONT,
		"cooldown_left": 3,
	}]
	teams[0]["units"] = [{
		"unit_id": 7,
		"prototype_id": 11,
		"health": 4,
		"x": 65536,
		"y": 0,
		"z": -65536,
	}]
	teams[1]["obstacles"] = [{"node_id": 9, "prototype_id": 21}]
	var first: PackedByteArray = BastionFrameCodec.encode_snapshot(
		12, BastionMatchSession.PHASE_WAVES, 2, 0, teams, 0
	)
	var second: PackedByteArray = BastionFrameCodec.encode_snapshot(
		12, BastionMatchSession.PHASE_WAVES, 2, 0, teams, TEAM_A
	)
	assert_eq(first, second)
	var decoded: Dictionary = BastionFrameCodec.decode_snapshot(first)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_true(decoded_ok)
	var tick: int = decoded.get("tick", -1)
	var phase: int = decoded.get("phase", -1)
	var wave_index: int = decoded.get("wave_index", -1)
	assert_eq(tick, 12)
	assert_eq(phase, BastionMatchSession.PHASE_WAVES)
	assert_eq(wave_index, 2)
	var got_teams: Array = decoded.get("teams", [])
	assert_eq(got_teams.size(), 2)
	var a: Dictionary = got_teams[0]
	var a_id: int = a.get("team_id", 0)
	var a_health: int = a.get("core_health", 0)
	assert_eq(a_id, TEAM_A)
	assert_eq(a_health, 80)
	var towers: Array = a.get("towers", [])
	assert_eq(towers.size(), 1)
	var tower: Dictionary = towers[0]
	var priority: String = tower.get("target_priority", "")
	assert_eq(priority, SharedTowerTargetPriorities.FRONT)
	var units: Array = a.get("units", [])
	var unit: Dictionary = units[0]
	var unit_x: int = unit.get("x", 0)
	assert_eq(unit_x, 65536)
	var b: Dictionary = got_teams[1]
	var obstacles: Array = b.get("obstacles", [])
	assert_eq(obstacles.size(), 1)
	var obstacle: Dictionary = obstacles[0]
	var owner: int = obstacle.get("team_id", 0)
	assert_eq(owner, TEAM_B)


func test_setup_snapshot_clips_opponent_obstacles() -> void:
	var teams: Array[Dictionary] = [_team_body(TEAM_A, 100, false), _team_body(TEAM_B, 100, false)]
	teams[0]["obstacles"] = [{"node_id": A_MID, "prototype_id": 22}]
	teams[1]["obstacles"] = [{"node_id": B_FORK, "prototype_id": 21}]
	var for_a: PackedByteArray = BastionFrameCodec.encode_snapshot(
		3, BastionMatchSession.PHASE_SETUP, 0, 0, teams, TEAM_A
	)
	var for_b: PackedByteArray = BastionFrameCodec.encode_snapshot(
		3, BastionMatchSession.PHASE_SETUP, 0, 0, teams, TEAM_B
	)
	assert_ne(for_a, for_b)
	var seen_a: Dictionary = BastionFrameCodec.decode_snapshot(for_a)
	var seen_b: Dictionary = BastionFrameCodec.decode_snapshot(for_b)
	var seen_a_ok: bool = seen_a.get("ok", false)
	assert_true(seen_a_ok)
	var teams_a: Array = seen_a.get("teams", [])
	assert_eq(teams_a.size(), 2, "裁剪只动障碍袋，双方核心仍在帧里")
	assert_eq(_obstacle_nodes(seen_a, TEAM_A), PackedInt32Array([A_MID]))
	assert_eq(_obstacle_nodes(seen_a, TEAM_B), PackedInt32Array())
	assert_eq(_obstacle_nodes(seen_b, TEAM_B), PackedInt32Array([B_FORK]))
	assert_eq(_obstacle_nodes(seen_b, TEAM_A), PackedInt32Array())
	var leaked: PackedByteArray = BastionFrameCodec.encode_snapshot(
		3, BastionMatchSession.PHASE_SETUP, 0, 0, teams, 0
	)
	assert_eq(leaked.size(), 0, "布障阶段必须带观察者，禁止无裁剪广播")


func test_session_wire_clips_pending_and_reveals_both() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	assert_true(session.try_place_obstacle(
		TEAM_A, A_MID, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))
	assert_true(session.try_place_obstacle(
		TEAM_B, B_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER
	))
	var authority: Array[Dictionary] = BastionMatchSessionWire.snapshot_teams(session)
	var team_a: Dictionary = authority[0]
	var team_b: Dictionary = authority[1]
	var a_pending: Array = team_a["obstacles"]
	var b_pending: Array = team_b["obstacles"]
	assert_eq(a_pending.size(), 1)
	assert_eq(b_pending.size(), 1)
	var for_a: PackedByteArray = BastionMatchSessionWire.encode_snapshot(session, TEAM_A)
	var for_b: PackedByteArray = BastionMatchSessionWire.encode_snapshot(session, TEAM_B)
	var seen_a: Dictionary = BastionFrameCodec.decode_snapshot(for_a)
	var seen_b: Dictionary = BastionFrameCodec.decode_snapshot(for_b)
	assert_eq(_obstacle_nodes(seen_a, TEAM_A), PackedInt32Array([A_MID]))
	assert_eq(_obstacle_nodes(seen_a, TEAM_B), PackedInt32Array())
	assert_eq(_obstacle_nodes(seen_b, TEAM_B), PackedInt32Array([B_FORK]))
	assert_eq(_obstacle_nodes(seen_b, TEAM_A), PackedInt32Array())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)
	var revealed_a: PackedByteArray = BastionMatchSessionWire.encode_snapshot(session, TEAM_A)
	var revealed_b: PackedByteArray = BastionMatchSessionWire.encode_snapshot(session, TEAM_B)
	assert_eq(revealed_a, revealed_b)
	var revealed: Dictionary = BastionFrameCodec.decode_snapshot(revealed_a)
	assert_eq(_obstacle_nodes(revealed, TEAM_A), PackedInt32Array([A_MID]))
	assert_eq(_obstacle_nodes(revealed, TEAM_B), PackedInt32Array([B_FORK]))


func test_reject_wrong_version_unknown_type_truncation_trailing() -> void:
	var command: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.LOCK_SETUP, 0, 0, 0
	)
	command[0] = 2
	var versioned: Dictionary = BastionFrameCodec.decode_command(command)
	var versioned_ok: bool = versioned.get("ok", true)
	assert_false(versioned_ok)
	var typed: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.LOCK_SETUP, 0, 0, 0
	)
	typed[1] = 1
	var typed_decoded: Dictionary = BastionFrameCodec.decode_command(typed)
	var typed_ok: bool = typed_decoded.get("ok", true)
	assert_false(typed_ok)
	var cut: Dictionary = BastionFrameCodec.decode_command(typed.slice(0, typed.size() - 1))
	var cut_ok: bool = cut.get("ok", true)
	assert_false(cut_ok)
	var longer: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.LOCK_SETUP, 0, 0, 0
	)
	longer.append(0)
	var longer_decoded: Dictionary = BastionFrameCodec.decode_command(longer)
	var longer_ok: bool = longer_decoded.get("ok", true)
	assert_false(longer_ok)
	var empty_teams: Array[Dictionary] = []
	var snap: PackedByteArray = BastionFrameCodec.encode_snapshot(
		1, BastionMatchSession.PHASE_PREP, 0, 0, empty_teams, 0
	)
	snap[0] = 0
	var snap_decoded: Dictionary = BastionFrameCodec.decode_snapshot(snap)
	var snap_ok: bool = snap_decoded.get("ok", true)
	assert_false(snap_ok)
	var long_snap: PackedByteArray = snap.duplicate()
	long_snap.append(0)
	var long_decoded: Dictionary = BastionFrameCodec.decode_snapshot(long_snap)
	var long_ok: bool = long_decoded.get("ok", true)
	assert_false(long_ok)


func test_codec_files_stay_under_the_e9_line_cap() -> void:
	for path: String in CODEC_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行" % path)


func _assert_command(
	intent_name: String, arg0: int, arg1: int, arg2: int, intent_id: int
) -> void:
	var bytes: PackedByteArray = BastionFrameCodec.encode_command(
		4, intent_name, arg0, arg1, arg2
	)
	assert_eq(bytes.size(), 35, intent_name)
	assert_eq(bytes.decode_u8(0), 1)
	assert_eq(bytes.decode_u8(1), BastionFrameCodec.FRAME_COMMAND)
	assert_eq(bytes.decode_u8(10), intent_id)
	var decoded: Dictionary = BastionFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_true(decoded_ok, intent_name)
	var tick: int = decoded.get("tick", -1)
	var got_intent: String = decoded.get("intent", "")
	var got0: int = decoded.get("arg0", -1)
	var got1: int = decoded.get("arg1", -1)
	var got2: int = decoded.get("arg2", -1)
	assert_eq(tick, 4)
	assert_eq(got_intent, intent_name)
	assert_eq(got0, arg0)
	assert_eq(got1, arg1)
	assert_eq(got2, arg2)


func _team_body(team_id: int, health: int, locked: bool) -> Dictionary:
	return {
		"team_id": team_id,
		"core_health": health,
		"gold": 200,
		"leaked": 0,
		"kills": 0,
		"locked": 1 if locked else 0,
		"towers": [],
		"units": [],
		"obstacles": [],
	}


func _obstacle_nodes(decoded: Dictionary, team_id: int) -> PackedInt32Array:
	var nodes: PackedInt32Array = PackedInt32Array()
	var teams: Array = decoded.get("teams", [])
	for item: Variant in teams:
		var team: Dictionary = item
		var current_id: int = team.get("team_id", 0)
		if current_id != team_id:
			continue
		var obstacles: Array = team.get("obstacles", [])
		for obstacle_item: Variant in obstacles:
			var obstacle: Dictionary = obstacle_item
			var node_id: int = obstacle.get("node_id", 0)
			nodes.append(node_id)
	return nodes


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func _graybox_json() -> Dictionary:
	var body: Dictionary = AuthoringDocument.load_json(GRAYBOX_PATH)
	assert_false(body.is_empty())
	return body


func _fast_session() -> BastionMatchSession:
	var body: Dictionary = _graybox_json()
	var entities: Array = body["entities"]
	for item: Variant in entities:
		var entity: Dictionary = item
		var entity_id: int = entity["entity_id"]
		if entity_id != 1:
			continue
		var components: Dictionary = entity["components"]
		var score: Dictionary = components["score"]
		var tallies: Dictionary = score["tallies"]
		tallies["setup_ticks"] = FAST_SETUP
		tallies["prep_ticks"] = FAST_PREP
		tallies["wave_interval_ticks"] = FAST_CADENCE
		tallies["time_limit_ticks"] = 4000
		break
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world)
	var session: BastionMatchSession = BastionMatchSession.create(
		BastionBlueprintCompiler.compile(world), 7
	)
	assert_not_null(session)
	return session
