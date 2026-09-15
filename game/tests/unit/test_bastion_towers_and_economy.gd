extends GutTest

## M6 D4：炮塔与经济（建造 / 升级 / 出售 / 目标优先级 / 自动开火 / 赏金）。
##
## **这一批直接对着 CD-61 §2 M6 的验收句写**：「非法封路、伪造金币和伪造建造均被
## 拒绝」。封路是 D2 那一批，本批负责另外两件：四类伪造各一条反例——非白名单
## 原型、非本方槽位、余额不足、超 3 级升级。四条都在服务端判，客户端提交的只有
## 意图（宪法第二条）。
##
## 其余断言守的是：赏金上限真的生效（不是延后发）、基础收入按波到账、目标优先级
## 平局按 `unit_id` 破、同输入同哈希。
##
## 数值一律不钉死：伤害 / 造价 / 返还比例都是 `BastionPlayStubs` 的占位桩
## （CD-63 §1.3 仍延期）。断言只比「相对关系」与「谁付了钱」。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionPlayStubs := preload("res://src/games/bastion/play_stubs.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const TEAM_A: int = 1
const TEAM_B: int = 2
## A 队三个建造槽，全部在兵线旁边（x = -2 格）。30 号紧挨出兵点那一段。
const A_SLOT_NEAR: int = 30
const A_SLOT_MID: int = 31
const A_SLOT_CORE: int = 32
const B_SLOT_NEAR: int = 33

const FAST_SETUP: int = 2
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40

const E9_LINE_CAP: int = 400
const SPLIT_PATHS: PackedStringArray = [
	"res://src/ugc/bastion_blueprint_bundle.gd",
	"res://src/ugc/bastion_blueprint_decode.gd",
	"res://src/ugc/bastion_blueprint_decode_bags.gd",
	"res://src/ugc/bastion_blueprint_compiler.gd",
	"res://src/ugc/bastion_blueprint_compiler_bags.gd",
	"res://src/ugc/bastion_blueprint_compiler_graph.gd",
	"res://src/ugc/bastion_prototype_catalog.gd",
	"res://src/ugc/bastion_blueprint_codes.gd",
	"res://src/simulation/fixed_graph_search.gd",
	"res://src/games/bastion/play_stubs.gd",
	"res://src/games/bastion/path_guard.gd",
	"res://src/games/bastion/match_session.gd",
	"res://src/games/bastion/match_session_waves.gd",
	"res://src/games/bastion/match_session_towers.gd",
	"res://src/games/bastion/match_session_view.gd",
	"res://src/games/bastion/match_setup_state.gd",
	"res://src/games/bastion/match_session_setup.gd",
]


# 1. 四类伪造建造，各一条反例。

func test_building_a_prototype_outside_the_slot_whitelist_is_refused() -> void:
	var session: BastionMatchSession = _session_in_prep()
	# 4 号是 CD-22 示例表里的电弧塔：不在 M6 白名单，更不在这个槽的白名单。
	assert_false(session.try_build_tower(TEAM_A, A_SLOT_NEAR, 4))
	# 障碍原型也不行：白名单分类别，不是一张大表。
	assert_false(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.OBSTACLE_BARRICADE
	))
	assert_eq(session.tower_count(TEAM_A), 0)
	assert_eq(session.gold(TEAM_A), _initial_gold())


func test_building_on_the_opponent_slot_is_refused() -> void:
	var session: BastionMatchSession = _session_in_prep()
	assert_false(session.try_build_tower(
		TEAM_A, B_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	assert_false(session.try_build_tower(
		TEAM_A, 9999, BastionPrototypeCatalog.TOWER_ARROW
	))
	assert_eq(session.tower_count(TEAM_A), 0)
	assert_eq(session.tower_count(TEAM_B), 0)
	assert_eq(session.gold(TEAM_A), _initial_gold())


func test_building_without_the_gold_is_refused_and_charges_nothing() -> void:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 10})
	assert_eq(session.gold(TEAM_A), 10)
	assert_false(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	# 先验后扣：余额不足时一分钱都不许少。
	assert_eq(session.gold(TEAM_A), 10)
	assert_eq(session.tower_count(TEAM_A), 0)


func test_upgrading_past_level_three_is_refused() -> void:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 1000})
	assert_true(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	assert_eq(_level(session, A_SLOT_NEAR), 1)
	assert_true(session.try_upgrade_tower(TEAM_A, A_SLOT_NEAR))
	assert_true(session.try_upgrade_tower(TEAM_A, A_SLOT_NEAR))
	assert_eq(_level(session, A_SLOT_NEAR), BastionPrototypeCatalog.MAX_TOWER_LEVEL)
	var before: int = session.gold(TEAM_A)
	assert_false(session.try_upgrade_tower(TEAM_A, A_SLOT_NEAR), "3 级封顶（CD-22 §5.1）")
	assert_eq(session.gold(TEAM_A), before, "被拒的升级不许扣钱")
	# 空槽也不能升。
	assert_false(session.try_upgrade_tower(TEAM_A, A_SLOT_MID))


# 2. 金币事务。

func test_build_upgrade_and_sell_move_exactly_the_stubbed_amounts() -> void:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 1000})
	var arrow: int = BastionPrototypeCatalog.TOWER_ARROW
	var start: int = session.gold(TEAM_A)
	assert_true(session.try_build_tower(TEAM_A, A_SLOT_NEAR, arrow))
	var after_build: int = session.gold(TEAM_A)
	assert_eq(start - after_build, BastionPlayStubs.tower_build_cost(arrow))
	assert_true(session.try_upgrade_tower(TEAM_A, A_SLOT_NEAR))
	var after_upgrade: int = session.gold(TEAM_A)
	assert_eq(after_build - after_upgrade, BastionPlayStubs.tower_upgrade_cost(arrow, 1))
	assert_true(session.try_sell_tower(TEAM_A, A_SLOT_NEAR))
	var after_sell: int = session.gold(TEAM_A)
	assert_eq(after_sell - after_upgrade, BastionPlayStubs.tower_sell_refund(arrow, 2))
	assert_eq(session.tower_count(TEAM_A), 0)
	# 返还比例是占位桩，不是产品经济：只断言「拆了比不拆亏」。
	assert_lt(after_sell, start)
	# 槽位空出来之后可以重建。
	assert_true(session.try_build_tower(TEAM_A, A_SLOT_NEAR, arrow))


func test_one_slot_holds_one_tower() -> void:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 1000})
	var arrow: int = BastionPrototypeCatalog.TOWER_ARROW
	assert_true(session.try_build_tower(TEAM_A, A_SLOT_NEAR, arrow))
	assert_false(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_CANNON
	))
	assert_eq(session.tower_count(TEAM_A), 1)


func test_building_is_refused_before_the_battlefield_version_is_locked() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	assert_eq(session.phase, BastionMatchSession.PHASE_SETUP)
	assert_false(
		session.try_build_tower(TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW),
		"互设障碍阶段战场版本还没锁定，不收建造"
	)


# 3. 目标优先级。

func test_all_four_priorities_are_accepted_and_anything_else_is_not() -> void:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 1000})
	assert_true(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	for priority: String in SharedTowerTargetPriorities.ALL:
		assert_true(session.try_set_tower_priority(TEAM_A, A_SLOT_NEAR, priority), priority)
		var tower: Dictionary = session.tower_at(TEAM_A, A_SLOT_NEAR)
		var stored: String = tower["target_priority"]
		assert_eq(stored, priority)
	assert_false(session.try_set_tower_priority(TEAM_A, A_SLOT_NEAR, "closest_to_core"))
	assert_false(session.try_set_tower_priority(TEAM_A, A_SLOT_MID, "front"))


func test_a_perfect_tie_is_broken_by_the_smallest_unit_id() -> void:
	# 一波三只同 tick 生成、属性相同、位置相同 ⇒ 四种策略下都是平局。
	# 平局必须永远落在最小 `unit_id` 上，否则回放对不上。
	var session: BastionMatchSession = _session_in_prep(
		{"initial_gold": 1000}, {"interval_ticks": 0, "max_alive": 3}
	)
	assert_true(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	_advance_to_waves(session)
	session.commit_tick()
	var states: Array[Dictionary] = session.unit_states(TEAM_A)
	assert_eq(states.size(), 3, "三只应当在同一拍生成")
	var damaged: Array[int] = []
	var lowest: int = 0
	for state: Dictionary in states:
		var unit_id: int = state["unit_id"]
		if lowest == 0 or unit_id < lowest:
			lowest = unit_id
		var health: int = state["health"]
		if health < BastionPlayStubs.unit_max_health(BastionPrototypeCatalog.UNIT_SWIFT):
			damaged.append(unit_id)
	assert_eq(damaged.size(), 1, "箭塔不溅射，一拍只该打一只")
	assert_eq(damaged[0], lowest)


func test_changing_the_priority_changes_the_authoritative_outcome() -> void:
	var front: BastionMatchSession = _armed_session(SharedTowerTargetPriorities.FRONT)
	var weakest: BastionMatchSession = _armed_session(SharedTowerTargetPriorities.WEAKEST)
	var diverged: bool = false
	for _step: int in range(160):
		front.commit_tick()
		weakest.commit_tick()
		if front.hash_state() != weakest.hash_state():
			diverged = true
			break
	assert_true(diverged, "目标策略必须真的改变裁决结果，否则那四个名字是摆设")


func test_same_tower_setup_gives_the_same_hash_every_run() -> void:
	var first: BastionMatchSession = _armed_session(SharedTowerTargetPriorities.NEAREST)
	var second: BastionMatchSession = _armed_session(SharedTowerTargetPriorities.NEAREST)
	for _step: int in range(160):
		first.commit_tick()
		second.commit_tick()
		assert_eq(first.hash_state(), second.hash_state())


# 4. 开火、赏金与收入。

func test_towers_kill_units_and_keep_the_core_alive() -> void:
	var session: BastionMatchSession = _fast_session({"initial_gold": 1000})
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	for slot_id: int in [A_SLOT_NEAR, A_SLOT_MID, A_SLOT_CORE]:
		assert_true(session.try_build_tower(
			TEAM_A, slot_id, BastionPrototypeCatalog.TOWER_ARROW
		))
	_advance_to_waves(session)
	_run_until_settled(session)
	assert_gt(session.kills(TEAM_A), 0, "有塔就该有击杀")
	assert_eq(session.kills(TEAM_B), 0, "对面没建塔，不该凭空有击杀")
	assert_lt(session.leaked(TEAM_A), session.leaked(TEAM_B))
	assert_gt(session.core_health(TEAM_A), session.core_health(TEAM_B))
	assert_eq(session.result, TEAM_A)


func test_towers_never_reach_into_the_other_teams_lane() -> void:
	var session: BastionMatchSession = _fast_session({"initial_gold": 1000})
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	for slot_id: int in [A_SLOT_NEAR, A_SLOT_MID, A_SLOT_CORE]:
		assert_true(session.try_build_tower(
			TEAM_A, slot_id, BastionPrototypeCatalog.TOWER_CANNON
		))
	_advance_to_waves(session)
	_run_until_settled(session)
	# 对面一只没死、核心照样被打光：塔不跨区（CD-22 §5.2）。
	assert_eq(session.kills(TEAM_B), 0)
	assert_eq(session.core_health(TEAM_B), 0)


func test_base_income_lands_once_per_wave() -> void:
	var session: BastionMatchSession = _session_in_prep()
	var before: int = session.gold(TEAM_A)
	_advance_to_waves(session)
	session.commit_tick()
	var income: int = _economy(session, "base_income")
	assert_eq(session.gold(TEAM_A) - before, income, "第一波开波即到账")
	var after_first: int = session.gold(TEAM_A)
	session.commit_tick()
	assert_eq(session.gold(TEAM_A), after_first, "同一波不许再发一次")


func test_kill_bounty_stops_at_the_per_wave_cap() -> void:
	# 上限压到一只兵的赏金以下：第一只就把额度用完，后面的击杀一分不发。
	var bounty: int = BastionPlayStubs.unit_bounty(BastionPrototypeCatalog.UNIT_SWIFT)
	var cap: int = bounty - 1
	var session: BastionMatchSession = _fast_session({"initial_gold": 1000, "bounty_cap": cap})
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	for slot_id: int in [A_SLOT_NEAR, A_SLOT_MID, A_SLOT_CORE]:
		assert_true(session.try_build_tower(
			TEAM_A, slot_id, BastionPrototypeCatalog.TOWER_ARROW
		))
	_advance_to_waves(session)
	var spent: int = session.gold(TEAM_A)
	var income: int = _economy(session, "base_income")
	var waves: int = session.total_waves()
	_run_until_settled(session)
	assert_gt(session.kills(TEAM_A), 1, "本例要有多次击杀才说明得了问题")
	# 收入 = 每波基础收入 + 每波最多 cap 的赏金。超出的部分**不发**，不是延后发。
	var ceiling: int = spent + waves * (income + cap)
	assert_lte(session.gold(TEAM_A), ceiling)
	assert_gt(session.gold(TEAM_A), spent)


# 5. 文件拆分仍在 E9 行数以内。

func test_bastion_files_stay_under_the_e9_line_cap() -> void:
	for path: String in SPLIT_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行" % path)


# --- helpers ---------------------------------------------------------------

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


func _fast_session(
	economy: Dictionary = {}, wave: Dictionary = {}
) -> BastionMatchSession:
	var body: Dictionary = _graybox_json()
	var tallies: Dictionary = _tallies(body)
	tallies["setup_ticks"] = FAST_SETUP
	tallies["prep_ticks"] = FAST_PREP
	tallies["wave_interval_ticks"] = FAST_CADENCE
	tallies["time_limit_ticks"] = 4000
	for key: String in economy:
		tallies[key] = economy[key]
	if not wave.is_empty():
		var spawner: Dictionary = _components(body, 60)["spawner"]
		for key: String in wave:
			spawner[key] = wave[key]
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	var session: BastionMatchSession = BastionMatchSession.create(bundle, 7)
	assert_not_null(session)
	return session


## 双方都锁定、已进入准备建造阶段的会话。
func _session_in_prep(
	economy: Dictionary = {}, wave: Dictionary = {}
) -> BastionMatchSession:
	var session: BastionMatchSession = _fast_session(economy, wave)
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)
	return session


## A 队在最靠近出兵点那个槽上建一座箭塔、设定目标策略，并推进到波次阶段。
func _armed_session(priority: String) -> BastionMatchSession:
	var session: BastionMatchSession = _session_in_prep({"initial_gold": 1000})
	assert_true(session.try_build_tower(
		TEAM_A, A_SLOT_NEAR, BastionPrototypeCatalog.TOWER_ARROW
	))
	assert_true(session.try_set_tower_priority(TEAM_A, A_SLOT_NEAR, priority))
	_advance_to_waves(session)
	return session


func _advance_to_waves(session: BastionMatchSession) -> void:
	for _step: int in range(FAST_PREP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_WAVES)


func _run_until_settled(session: BastionMatchSession) -> void:
	for _step: int in range(4000):
		if session.phase == BastionMatchSession.PHASE_SETTLED:
			return
		session.commit_tick()
	fail_test("对局没有在预算内结算")


func _initial_gold() -> int:
	return BastionPlayStubs.GRAYBOX_ECONOMY["initial_gold"]


func _economy(session: BastionMatchSession, key: String) -> int:
	return session.bundle.economy_value(key)


func _level(session: BastionMatchSession, slot_id: int) -> int:
	var tower: Dictionary = session.tower_at(TEAM_A, slot_id)
	if tower.is_empty():
		return 0
	var level: int = tower["level"]
	return level


func _components(body: Dictionary, entity_id: int) -> Dictionary:
	var entities: Array = body["entities"]
	for item: Variant in entities:
		var entity: Dictionary = item
		var current: int = entity["entity_id"]
		if current == entity_id:
			var components: Dictionary = entity["components"]
			return components
	fail_test("夹具里没有实体 %d" % entity_id)
	return {}


func _tallies(body: Dictionary) -> Dictionary:
	var score: Dictionary = _components(body, 1)["score"]
	var tallies: Dictionary = score["tallies"]
	return tallies
