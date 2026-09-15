extends GutTest

## M6 E3：BASTION 结算只在 PHASE_SETTLED 产出。HTTP 仍要 TRAPRUSH rows；
## teams[] 才是 1v1 名次。平局两侧 place=1。心跳是 snake_case。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionMatchSettlement := preload("res://src/games/bastion/match_settlement.gd")
const MatchServer := preload("res://src/server/match_server.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const TEAM_A: int = 1
const TEAM_B: int = 2
const FAST_SETUP: int = 3
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40


func test_try_build_refuses_setup() -> void:
	var session: BastionMatchSession = _timed_session()
	assert_true(session.begin_match())
	assert_eq(session.phase, BastionMatchSession.PHASE_SETUP)
	assert_false(BastionMatchSettlement.all_finished(session))
	var built: Dictionary = BastionMatchSettlement.try_build(session)
	var ok: bool = built.get("ok", true)
	assert_false(ok)


func test_timeout_settlement_has_rows_and_teams() -> void:
	var session: BastionMatchSession = _run_until_settled()
	assert_eq(session.phase, BastionMatchSession.PHASE_SETTLED)
	assert_true(BastionMatchSettlement.all_finished(session))
	var built: Dictionary = BastionMatchSettlement.try_build(session)
	var ok: bool = built.get("ok", false)
	var pad_total: int = built.get("pad_total", -1)
	assert_true(ok)
	assert_eq(pad_total, 0)
	var rows: Array = built.get("rows", [])
	assert_eq(rows.size(), 2)
	var row0: Dictionary = rows[0]
	var row1: Dictionary = rows[1]
	var accepted0: int = row0.get("accepted_count", -1)
	var accepted1: int = row1.get("accepted_count", -1)
	assert_eq(accepted0, 0)
	assert_eq(accepted1, 0)
	var teams: Array = built.get("teams", [])
	assert_eq(teams.size(), 2)
	var team0: Dictionary = teams[0]
	var team1: Dictionary = teams[1]
	var team_a: int = team0.get("team_id", 0)
	var team_b: int = team1.get("team_id", 0)
	assert_eq(team_a, TEAM_A)
	assert_eq(team_b, TEAM_B)
	var heartbeat: Dictionary = BastionMatchSettlement.to_heartbeat(built)
	assert_true(heartbeat.has("state_hash"))
	assert_true(heartbeat.has("pad_total"))
	assert_true(heartbeat.has("mvp_slot"))
	assert_false(heartbeat.has("stateHash"))
	var line: String = MatchServer._heartbeat_line("m1", session)
	var parsed: Variant = JSON.parse_string(line)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var event: Dictionary = parsed
	assert_true(event.has("settlement"))
	var settlement: Dictionary = event.get("settlement", {})
	assert_true(settlement.has("teams"))
	var settle_pad: int = settlement.get("pad_total", -1)
	assert_eq(settle_pad, 0)


func _timed_session() -> BastionMatchSession:
	var body: Dictionary = AuthoringDocument.load_json(GRAYBOX_PATH)
	_retime(body, FAST_SETUP, FAST_PREP, FAST_CADENCE, 12)
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	var session: BastionMatchSession = BastionMatchSession.create(bundle, 7)
	assert_not_null(session)
	return session


func _run_until_settled() -> BastionMatchSession:
	var session: BastionMatchSession = _timed_session()
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	for _step: int in range(4000):
		if session.phase == BastionMatchSession.PHASE_SETTLED:
			return session
		session.commit_tick()
	fail_test("灰盒应在短局时内结算")
	return session


func _retime(
	body: Dictionary, setup_ticks: int, prep_ticks: int, cadence: int, time_limit: int
) -> void:
	var entities: Array = body["entities"]
	for item: Variant in entities:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = item
		var entity_id: int = entity.get("entity_id", 0)
		if entity_id != 1:
			continue
		var components: Dictionary = entity["components"]
		var score: Dictionary = components["score"]
		var tallies: Dictionary = score["tallies"]
		tallies["setup_ticks"] = setup_ticks
		tallies["prep_ticks"] = prep_ticks
		tallies["wave_interval_ticks"] = cadence
		tallies["time_limit_ticks"] = time_limit
		return
	fail_test("夹具里没有 bastion_config 实体")
