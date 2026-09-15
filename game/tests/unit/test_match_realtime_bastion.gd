extends GutTest

## M6 E3：对局进程对 BASTION 走 type 5 命令、按席位单播裁剪 type 6。
## TRAPRUSH type 1 在这条路径上被拒。SETUP 观察者是队伍 1/2，不是席位号。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionFrameCodec := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtimeBastion := preload("res://src/server/match_realtime_bastion.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const A_MID: int = 2
const TEAM_A: int = 1
const TEAM_B: int = 2


func test_rejects_traprush_command_frames() -> void:
	var realtime: MatchRealtimeBastion = _realtime()
	assert_eq(realtime.add_player(), 0)
	var jump: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)
	assert_false(realtime.accept_command(0, jump))


func test_place_obstacle_from_seat_zero_maps_to_team_a() -> void:
	var realtime: MatchRealtimeBastion = _realtime()
	assert_eq(realtime.add_player(), 0)
	assert_eq(realtime.add_player(), 1)
	var place: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.PLACE_OBSTACLE, A_MID, BastionPrototypeCatalog.OBSTACLE_BARRICADE, 0
	)
	assert_true(realtime.accept_command(0, place))
	realtime.commit_tick()
	var session: BastionMatchSession = realtime.session
	var pending: Array[Dictionary] = session.setup_authority_obstacles(TEAM_A)
	assert_eq(pending.size(), 1)
	var node_id: int = pending[0].get("node_id", 0)
	assert_eq(node_id, A_MID)


func test_setup_snapshot_clips_per_seat() -> void:
	var realtime: MatchRealtimeBastion = _realtime()
	assert_eq(realtime.add_player(), 0)
	assert_eq(realtime.add_player(), 1)
	var place: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.PLACE_OBSTACLE, A_MID, BastionPrototypeCatalog.OBSTACLE_BARRICADE, 0
	)
	assert_true(realtime.accept_command(0, place))
	realtime.commit_tick()
	var for_a: Dictionary = BastionFrameCodec.decode_snapshot(realtime.snapshot_frame_for(0))
	var for_b: Dictionary = BastionFrameCodec.decode_snapshot(realtime.snapshot_frame_for(1))
	var a_ok: bool = for_a.get("ok", false)
	var b_ok: bool = for_b.get("ok", false)
	assert_true(a_ok)
	assert_true(b_ok)
	assert_eq(_obstacle_nodes(for_a, TEAM_A), PackedInt32Array([A_MID]))
	assert_eq(_obstacle_nodes(for_a, TEAM_B), PackedInt32Array())
	assert_eq(_obstacle_nodes(for_b, TEAM_A), PackedInt32Array())
	assert_eq(_obstacle_nodes(for_b, TEAM_B), PackedInt32Array())


func test_one_command_per_tick_and_occupancy() -> void:
	var realtime: MatchRealtimeBastion = _realtime()
	assert_eq(realtime.add_player(), 0)
	assert_false(realtime.occupy_slot(0))
	assert_eq(realtime.add_player(), 1)
	assert_eq(realtime.add_player(), -1)
	var lock: PackedByteArray = BastionFrameCodec.encode_command(
		1, PlayerIntentNames.LOCK_SETUP, 0, 0, 0
	)
	assert_true(realtime.accept_command(0, lock))
	assert_false(realtime.accept_command(0, lock))
	assert_true(realtime.remove_player(1))
	assert_eq(realtime.occupied_count(), 1)


func _realtime() -> MatchRealtimeBastion:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(GRAYBOX_PATH)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	var session: BastionMatchSession = BastionMatchSession.create(bundle, 7)
	assert_not_null(session)
	assert_true(session.begin_match())
	var realtime: MatchRealtimeBastion = MatchRealtimeBastion.create(session) as MatchRealtimeBastion
	assert_not_null(realtime)
	return realtime


func _obstacle_nodes(decoded: Dictionary, team_id: int) -> PackedInt32Array:
	var nodes: PackedInt32Array = PackedInt32Array()
	var teams: Array = decoded.get("teams", [])
	for item: Variant in teams:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var team: Dictionary = item
		var seen_team: int = team.get("team_id", 0)
		if seen_team != team_id:
			continue
		var obstacles: Array = team.get("obstacles", [])
		for obstacle_item: Variant in obstacles:
			if typeof(obstacle_item) != TYPE_DICTIONARY:
				continue
			var obstacle: Dictionary = obstacle_item
			var node_id: int = obstacle.get("node_id", 0)
			nodes.append(node_id)
	return nodes
