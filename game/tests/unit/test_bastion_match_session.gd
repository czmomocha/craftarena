extends GutTest

## M6 D3：五阶段、镜像波次、核心伤害、胜负（全部离线，不碰协议与表现）。
##
## 本批里只有一条是**强断言范围**内的公平性事实，其余都是流程闭合：
##
##   **两侧波次逐字节等价。** 它不是风格偏好——BASTION 的 PvP 差异只允许来自
##   赛前布障、己方塔系与经济决策（CD-22 §5.2）。波次一旦两侧不同，这个玩法就
##   不成立了。断言比的是 (生成 tick, 原型, 血量, 速度, 赏金, 随机数) 全序列，
##   不含每队各自递增的本地 `unit_id`。
##
## 其余断言守的是：阶段只由权威 tick 与锁定推进（一处不读墙钟）、同输入同哈希、
## 核心归零即结束、双方都活时按 核心生命 → 漏怪数 → 完成击杀时间 依次比较。
##
## 本章**没有塔**，所以所有兵都会漏进核心——这不是设计缺陷，是 D4 之前的必然。
## 数值全是 `BastionPlayStubs` 的占位桩，断言一律不去钉具体伤害值。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const TEAM_A: int = 1
const TEAM_B: int = 2
const A_MID: int = 2
const A_FORK: int = 3
const A_BRANCH_NEAR: int = 7
const B_FORK: int = 9

## 灰盒的 `setup_ticks` / `prep_ticks` 都是上千拍，逐拍跑太慢。测试用一份把它们
## 压到个位数的同构蓝图——压的是节奏，不是拓扑。
const FAST_SETUP: int = 3
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40


# 1. 阶段机：只由权威 tick 与锁定推进。

func test_handshake_refuses_a_blueprint_whose_lane_is_already_sealed() -> void:
	var sealed: BastionBlueprintBundle = _sealed_bundle()
	var session: BastionMatchSession = BastionMatchSession.create(sealed, 7)
	assert_not_null(session)
	assert_eq(session.phase, BastionMatchSession.PHASE_HANDSHAKE)
	assert_false(session.begin_match(), "自己就封死的蓝图不该开局")
	assert_eq(session.phase, BastionMatchSession.PHASE_HANDSHAKE)
	# 握手没过就不许推进，推 tick 也停在原地。
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_HANDSHAKE)


func test_setup_ends_on_both_locks_not_on_wall_clock() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	assert_eq(session.phase, BastionMatchSession.PHASE_SETUP)
	assert_true(session.lock_setup(TEAM_A))
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_SETUP, "只锁一边不该推进")
	assert_false(session.lock_setup(TEAM_A), "锁过的一方不能再锁")
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)


func test_setup_also_ends_when_the_authoritative_countdown_runs_out() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	for _step: int in range(FAST_SETUP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP, "倒计时到了也要进准备建造")
	for _step: int in range(FAST_PREP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_WAVES)
	assert_eq(session.wave_index(), 1)
	assert_eq(session.total_waves(), 3)


func test_obstacles_are_only_accepted_during_setup_and_before_the_lock() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var barricade: int = BastionPrototypeCatalog.OBSTACLE_BARRICADE
	assert_true(session.try_place_obstacle(TEAM_A, A_MID, barricade))
	# 对手防区的槽不归本队。封路提案可以进 pending，揭示时才退点——那是 D5。
	assert_false(session.try_place_obstacle(TEAM_A, B_FORK, barricade))
	assert_true(session.lock_setup(TEAM_A))
	assert_false(
		session.try_place_obstacle(TEAM_A, A_BRANCH_NEAR, barricade),
		"锁定后不能再改（CD-22 §4.1 第 4 步）"
	)
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	assert_false(session.try_place_obstacle(TEAM_B, B_FORK, barricade), "阶段过了就不收")


func test_locked_obstacles_change_the_frozen_lane() -> void:
	var plain: BastionMatchSession = _fast_session()
	_run_to_waves(plain, [])
	var diverted: BastionMatchSession = _fast_session()
	_run_to_waves(diverted, [[TEAM_A, A_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER]])
	assert_ne(diverted.lane_path(TEAM_A), plain.lane_path(TEAM_A))
	# 只有放障碍那一侧的路变了。
	assert_eq(diverted.lane_path(TEAM_B), plain.lane_path(TEAM_B))


# 2. 镜像波次：两侧逐字节等价。

func test_both_sides_receive_byte_identical_waves() -> void:
	var session: BastionMatchSession = _fast_session()
	_run_to_waves(session, [])
	_run_until_settled(session)
	var left: Array[Dictionary] = session.spawn_log(TEAM_A)
	var right: Array[Dictionary] = session.spawn_log(TEAM_B)
	assert_gt(left.size(), 0, "一局下来必须真的生成过兵")
	assert_eq(left.size(), right.size())
	for index: int in range(left.size()):
		assert_eq(left[index], right[index], "第 %d 只兵两侧必须完全一致" % index)
	# 三张波次表的总兵数：6 + 10 + 4。
	assert_eq(left.size(), 20)


func test_a_different_seed_changes_the_roll_but_never_the_symmetry() -> void:
	var first: BastionMatchSession = _fast_session(11)
	_run_to_waves(first, [])
	_run_until_settled(first)
	var second: BastionMatchSession = _fast_session(12)
	_run_to_waves(second, [])
	_run_until_settled(second)
	var left: Array[Dictionary] = first.spawn_log(TEAM_A)
	var other: Array[Dictionary] = second.spawn_log(TEAM_A)
	var first_roll: int = left[0]["roll"]
	var other_roll: int = other[0]["roll"]
	assert_ne(first_roll, other_roll, "换种子必须换随机数，否则种子是摆设")
	# 换了种子，两侧仍然一模一样。
	assert_eq(second.spawn_log(TEAM_A), second.spawn_log(TEAM_B))


func test_same_input_gives_the_same_hash_every_run() -> void:
	var first: BastionMatchSession = _fast_session()
	var second: BastionMatchSession = _fast_session()
	_run_to_waves(first, [])
	_run_to_waves(second, [])
	for _step: int in range(120):
		first.commit_tick()
		second.commit_tick()
		assert_eq(first.hash_state(), second.hash_state())


func test_a_different_obstacle_gives_a_different_hash() -> void:
	var plain: BastionMatchSession = _fast_session()
	_run_to_waves(plain, [])
	var slowed: BastionMatchSession = _fast_session()
	_run_to_waves(slowed, [[TEAM_A, A_FORK, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE]])
	for _step: int in range(60):
		plain.commit_tick()
		slowed.commit_tick()
	assert_ne(plain.hash_state(), slowed.hash_state())


# 3. 核心伤害与胜负。

func test_units_reach_the_core_and_take_it_down_without_towers() -> void:
	var session: BastionMatchSession = _fast_session()
	_run_to_waves(session, [])
	var start_health: int = session.core_health(TEAM_A)
	assert_gt(start_health, 0)
	_run_until_settled(session)
	assert_eq(session.phase, BastionMatchSession.PHASE_SETTLED)
	# D4 之前没有塔，所以兵一定漏进核心。
	assert_gt(session.leaked(TEAM_A), 0)
	assert_lt(session.core_health(TEAM_A), start_health)


func test_the_side_whose_core_falls_first_loses() -> void:
	var session: BastionMatchSession = _fast_session()
	# A 队放一个减速地块：它的兵走得更久，核心晚一点挨打，于是 B 先倒。
	_run_to_waves(session, [[TEAM_A, A_FORK, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE]])
	_run_until_settled(session)
	assert_eq(session.phase, BastionMatchSession.PHASE_SETTLED)
	assert_eq(session.result, TEAM_A, "核心生命高的一方赢")
	assert_gt(session.core_health(TEAM_A), session.core_health(TEAM_B))


func test_a_perfectly_symmetric_match_is_a_draw() -> void:
	var session: BastionMatchSession = _fast_session()
	_run_to_waves(session, [])
	_run_until_settled(session)
	# 两侧波次等价、两侧都没塔、两侧都没布障 ⇒ 结果只能是平局。
	# 这条同时是镜像公平性的端到端证据。
	assert_eq(session.result, BastionMatchSession.RESULT_DRAW)
	assert_eq(session.core_health(TEAM_A), session.core_health(TEAM_B))
	assert_eq(session.leaked(TEAM_A), session.leaked(TEAM_B))


func test_settled_session_stops_advancing() -> void:
	var session: BastionMatchSession = _fast_session()
	_run_to_waves(session, [])
	_run_until_settled(session)
	var frozen: String = session.hash_state()
	var settled_tick: int = session.tick_index()
	for _step: int in range(10):
		session.commit_tick()
	assert_eq(session.tick_index(), settled_tick)
	assert_eq(session.hash_state(), frozen)


func test_time_limit_settles_the_match_even_with_both_cores_alive() -> void:
	var session: BastionMatchSession = _timed_out_session()
	_run_to_waves(session, [])
	for _step: int in range(200):
		if session.phase == BastionMatchSession.PHASE_SETTLED:
			break
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_SETTLED)
	assert_gt(session.core_health(TEAM_A), 0)
	assert_gt(session.core_health(TEAM_B), 0)


# --- helpers ---------------------------------------------------------------

func _graybox_json() -> Dictionary:
	var body: Dictionary = AuthoringDocument.load_json(GRAYBOX_PATH)
	assert_false(body.is_empty())
	return body


func _compile(body: Dictionary) -> BastionBlueprintBundle:
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


## 把节奏压短的同构灰盒。拓扑一格不动，只改 `bastion_config` 的四个 tick 值。
func _fast_session(p_seed: int = 7) -> BastionMatchSession:
	var body: Dictionary = _graybox_json()
	_retime(body, FAST_SETUP, FAST_PREP, FAST_CADENCE, 4000)
	var session: BastionMatchSession = BastionMatchSession.create(_compile(body), p_seed)
	assert_not_null(session)
	return session


## 局时短到波次跑不完就结算。
func _timed_out_session() -> BastionMatchSession:
	var body: Dictionary = _graybox_json()
	_retime(body, FAST_SETUP, FAST_PREP, FAST_CADENCE, 12)
	var session: BastionMatchSession = BastionMatchSession.create(_compile(body), 7)
	assert_not_null(session)
	return session


func _retime(
	body: Dictionary, setup_ticks: int, prep_ticks: int, cadence: int, time_limit: int
) -> void:
	var entities: Array = body["entities"]
	for item: Variant in entities:
		var entity: Dictionary = item
		var entity_id: int = entity["entity_id"]
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


## 放完给定障碍、双方锁定、走到镜像波次阶段的第一拍。
func _run_to_waves(session: BastionMatchSession, placements: Array) -> void:
	assert_true(session.begin_match())
	for item: Variant in placements:
		var placement: Array = item
		var team_id: int = placement[0]
		var node_id: int = placement[1]
		var prototype_id: int = placement[2]
		assert_true(
			session.try_place_obstacle(team_id, node_id, prototype_id),
			"夹具里的这次放置本应合法"
		)
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	for _step: int in range(FAST_PREP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_WAVES)


func _run_until_settled(session: BastionMatchSession) -> void:
	for _step: int in range(4000):
		if session.phase == BastionMatchSession.PHASE_SETTLED:
			return
		session.commit_tick()
	fail_test("对局没有在预算内结算")


func _sealed_bundle() -> BastionBlueprintBundle:
	var bundle: BastionBlueprintBundle = _compile(_graybox_json())
	var body: Dictionary = bundle.to_dictionary()
	var edges: Array = body["edges"]
	var kept: Array = []
	for item: Variant in edges:
		var edge: Dictionary = item
		var to_id: int = edge["to_id"]
		if to_id == 1:
			continue
		kept.append(edge)
	body["edges"] = kept
	var sealed: BastionBlueprintBundle = BastionBlueprintBundle.from_dictionary(body)
	assert_not_null(sealed)
	return sealed
