extends GutTest

## Match server process entry: MatchHost spawns one headless Godot process per
## match (CD-44 §3). The entry parses --match-id/--port/--course/--players/
## --max-ticks, boots a TraprushMatchSession from the course, ticks with the
## engine physics loop (not a locked product tick rate), prints structured
## heartbeat JSON and exits 0 at --max-ticks or 1 on bad config.
## Boot applies Solo-matching action stubs (jump/support/fall/use-item). Official
## course_01 crate is in reach from spawn. Spawn-underfoot solids make Jump
## hop at slot 0 after settle. Fall accel is a caller stub, not product gravity.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Fixed := preload("res://src/shared/fixed/fixed.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const MatchServer := preload("res://src/server/match_server.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536


func test_parse_user_args_accepts_key_value_only() -> void:
	var options: Dictionary = MatchServer._parse_user_args([
		"--match-id=m1",
		"--port=42000",
		"--course=res://x.json",
		"--players=2",
		"--max-ticks=30",
		"--bare",
		"positional",
		"--=empty",
	])
	assert_eq(options.size(), 5)
	var match_id: String = options.get("match-id", "")
	var players: String = options.get("players", "")
	assert_eq(match_id, "m1")
	assert_eq(players, "2")


func test_boot_config_requires_valid_fields() -> void:
	var ok: Dictionary = MatchServer._boot_config({
		"match-id": "m1",
		"port": "42000",
		"course": COURSE_01_PATH,
		"players": "2",
		"max-ticks": "30",
	})
	var config_ok: bool = ok.get("ok", false)
	assert_true(config_ok)
	var empty_ok: bool = MatchServer._boot_config({}).get("ok", true)
	assert_false(empty_ok)
	var zero_ok: bool = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "0",
	}).get("ok", true)
	assert_false(zero_ok)
	var nine_ok: bool = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "9",
	}).get("ok", true)
	assert_false(nine_ok)
	var negative_ticks_ok: bool = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
		"max-ticks": "-1",
	}).get("ok", true)
	assert_false(negative_ticks_ok)
	var missing_course_ok: bool = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": "res://nope.json", "players": "2",
	}).get("ok", true)
	assert_false(missing_course_ok)
	var no_ticks: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var no_ticks_ok: bool = no_ticks.get("ok", false)
	assert_true(no_ticks_ok)
	var max_ticks: int = no_ticks.get("max_ticks", -1)
	assert_eq(max_ticks, 0)


func test_boot_session_from_config() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	assert_not_null(session)
	assert_eq(session.player_count(), 2)
	assert_eq(session.player_accepted_count(0), 1)
	assert_eq(session.player_accepted_count(1), 1)
	var pose0: Dictionary = session.player_pose(0)
	var pose1: Dictionary = session.player_pose(1)
	var x0: int = pose0.get("x", 0)
	var z0: int = pose0.get("z", 0)
	var x1: int = pose1.get("x", 0)
	var z1: int = pose1.get("z", 0)
	assert_ne(Vector3i(x0, 0, z0), Vector3i(x1, 0, z1))
	assert_eq(session.jump_dy, Fixed.SCALE / 4)
	assert_eq(session.support_dy, -Fixed.SCALE)
	assert_eq(session.fall_dy, -Fixed.SCALE / 16)
	assert_eq(session.use_item_damage, 1)
	assert_eq(session.use_item_reach_dx, 0)
	assert_eq(session.use_item_reach_dy, 0)
	assert_eq(session.use_item_reach_dz, Fixed.SCALE)
	assert_eq(session.shove_step, Fixed.SCALE / 4)
	assert_eq(session.shove_cooldown_ticks, 1)
	assert_true(session.range_enabled)
	assert_eq(session.range_max_x, 8 * Fixed.SCALE)
	assert_eq(session.range_min_x, -8 * Fixed.SCALE)


func test_boot_session_use_item_breaks_course_01_crate() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "1",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	assert_not_null(session)
	assert_eq(session.destructible_alive_count(), 1)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_eq(realtime.add_player(), 0)
	assert_true(realtime.accept_command(
		0,
		MatchFrameCodec.encode_command(0, PlayerIntentNames.USE_ITEM, 0, 0, 0)
	))
	realtime.commit_tick()
	assert_eq(session.destructible_alive_count(), 0)
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	var snapshot_ok: bool = snapshot.get("ok", false)
	assert_true(snapshot_ok)
	var crates: Array = snapshot.get("crates", [])
	assert_eq(crates.size(), 1)
	var crate: Dictionary = crates[0]
	var durability: int = crate.get("durability", -1)
	assert_eq(durability, 0)


func test_boot_session_jump_hops_on_course_01_spawn_footing() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "1",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	assert_not_null(session)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_eq(realtime.add_player(), 0)
	realtime.commit_tick()
	assert_eq(realtime.last_valid_input_tick(), -1)
	for _settle: int in range(8):
		realtime.commit_tick()
	var rest: Dictionary = session.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	assert_true(realtime.accept_command(
		0,
		MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)
	))
	realtime.commit_tick()
	var hopped: Dictionary = session.player_pose(0)
	var hopped_y: int = hopped.get("y", 2)
	assert_eq(hopped_y, rest_y + Fixed.SCALE / 4)
	assert_eq(realtime.last_valid_input_tick(), session.tick_index())
	# 出生点 hop 不再撞上楼 two_way（上层已偏到 z=-3*CELL）。落地与弧线由
	# test_traprush_gravity.gd 的合成地板覆盖。


func test_boot_session_shove_pushes_other_spawn_capsule() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	assert_not_null(session)
	var before: Dictionary = session.player_pose(1)
	var before_z: int = before.get("z", 1)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_eq(realtime.add_player(), 0)
	assert_true(realtime.accept_command(
		0,
		MatchFrameCodec.encode_command(0, PlayerIntentNames.SHOVE, 0, 0, 0)
	))
	realtime.commit_tick()
	var after: Dictionary = session.player_pose(1)
	var after_z: int = after.get("z", 2)
	assert_eq(after_z, before_z - Fixed.SCALE / 4)
	assert_eq(realtime.last_valid_input_tick(), 1)


func test_boot_session_rejects_bad_config() -> void:
	assert_null(MatchServer.boot_session({}))
	assert_null(MatchServer.boot_session({"ok": false}))


func test_heartbeat_line_is_structured_json() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	session.commit_tick()
	var line: String = MatchServer._heartbeat_line("m1", session)
	var parsed: Variant = JSON.parse_string(line)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var event: Dictionary = parsed
	var event_name: String = event.get("event", "")
	var event_match_id: String = event.get("match_id", "")
	assert_eq(event_name, "match_tick")
	assert_eq(event_match_id, "m1")
	var tick: int = event.get("tick", -1)
	assert_eq(tick, 1)
	var players: int = event.get("players", -1)
	assert_eq(players, 2)
	var state_hash: String = event.get("hash", "")
	assert_eq(state_hash, session.hash_state())
	assert_false(event.has("settlement"))
	var valid_input_tick: int = event.get("valid_input_tick", 99)
	assert_eq(valid_input_tick, -1)


func test_heartbeat_line_reports_valid_input_tick() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var session: TraprushMatchSession = MatchServer.boot_session(config)
	session.commit_tick()
	var line: String = MatchServer._heartbeat_line("m1", session, 4)
	var parsed: Variant = JSON.parse_string(line)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var event: Dictionary = parsed
	var valid_input_tick: int = event.get("valid_input_tick", -1)
	assert_eq(valid_input_tick, 4)


func test_same_boot_same_hash_after_ticks() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var first: TraprushMatchSession = MatchServer.boot_session(config)
	var second: TraprushMatchSession = MatchServer.boot_session(config)
	for index: int in range(10):
		first.commit_tick()
		second.commit_tick()
	assert_eq(first.hash_state(), second.hash_state())
