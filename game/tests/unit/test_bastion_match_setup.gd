extends GutTest

## M6 D5：互设障碍阶段（离线：盲设 → 锁定 → 揭示 → 重验 → 退点）。
##
## D3 已经有阶段、锁定标志、倒计时。本章补齐 CD-22 §4.1 / §7.2 剩下的那一截：
## 点数预算、只放在预留槽、盲设视图、统一揭示、揭示后重验与退点、
## `MatchSetupState`、布障命令进回放。协议层裁剪是 E1，本批一个字节都不碰。
##
## 提交时立即拒的是槽位 / 白名单 / 预算 / 锁定——这些没有「等揭示再看」的合法
## 解释。封路提案可以先进 pending：pending **不是活图**，揭示时才上图，守卫在
## 那一刻 LIFO 撤销并退点。所以「任意时刻至少一条路」对活图始终成立，D5 的
## 「封死路径在揭示时被撤销并退点」也不会空转成 D3 已经测过的当场拒绝。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionMatchSetupState := preload("res://src/games/bastion/match_setup_state.gd")
const BastionPlayStubs := preload("res://src/games/bastion/play_stubs.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const TEAM_A: int = 1
const TEAM_B: int = 2
const A_MID: int = 2
const A_FORK: int = 3
const A_SPAWN: int = 4
const A_BRANCH_NEAR: int = 7
const B_FORK: int = 9

const FAST_SETUP: int = 3
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40

const E9_LINE_CAP: int = 400
const SETUP_PATHS: PackedStringArray = [
	"res://src/games/bastion/match_setup_state.gd",
	"res://src/games/bastion/match_session_setup.gd",
]


# 1. 提交时立即拒绝：预算、非槽位、锁定后改动。

func test_over_budget_placement_is_refused_immediately() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var barricade: int = BastionPrototypeCatalog.OBSTACLE_BARRICADE
	var slow: int = BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	var budget: int = _points_budget(session)
	assert_eq(budget, BastionPlayStubs.GRAYBOX_ECONOMY["obstacle_points"])
	assert_eq(session.setup_points_left(TEAM_A), budget)
	# 3 + 2 = 5，还在预算内。
	assert_true(session.try_place_obstacle(TEAM_A, A_MID, barricade))
	assert_true(session.try_place_obstacle(TEAM_A, A_FORK, slow))
	assert_eq(session.setup_points_spent(TEAM_A), 5)
	# 再放一个 2 点的减速地块会到 7，当场拒，pending 不动。
	assert_false(session.try_place_obstacle(TEAM_A, A_BRANCH_NEAR, slow))
	assert_eq(session.setup_points_spent(TEAM_A), 5)
	assert_eq(session.setup_points_left(TEAM_A), budget - 5)
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 2)


func test_non_slot_and_foreign_slot_are_refused() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var barricade: int = BastionPrototypeCatalog.OBSTACLE_BARRICADE
	assert_false(session.try_place_obstacle(TEAM_A, A_SPAWN, barricade), "出兵点不是障碍槽")
	assert_false(session.try_place_obstacle(TEAM_A, B_FORK, barricade), "对手防区的槽不归本队")
	assert_false(session.try_place_obstacle(TEAM_A, A_MID, BastionPrototypeCatalog.TOWER_ARROW))
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 0)
	assert_eq(session.setup_command_count(), 0, "被拒的意图不进回放磁带")


func test_changes_after_lock_are_refused() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var slow: int = BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	assert_true(session.try_place_obstacle(TEAM_A, A_MID, slow))
	assert_true(session.lock_setup(TEAM_A))
	assert_false(session.try_place_obstacle(TEAM_A, A_FORK, slow), "锁定后不能再改")
	assert_false(session.lock_setup(TEAM_A), "不能锁两次")
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 1)
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)
	assert_false(session.try_place_obstacle(TEAM_B, B_FORK, slow), "阶段过了就不收")
	assert_true(session.setup_revealed())


# 2. 盲设视图：揭示前只能看见自己的方案。

func test_setup_is_blind_until_reveal() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var slow: int = BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	var diverter: int = BastionPrototypeCatalog.OBSTACLE_DIVERTER
	assert_true(session.try_place_obstacle(TEAM_A, A_MID, slow))
	assert_true(session.try_place_obstacle(TEAM_B, B_FORK, diverter))
	var seen_by_a: Array[Dictionary] = session.visible_obstacles(TEAM_A)
	var seen_by_b: Array[Dictionary] = session.visible_obstacles(TEAM_B)
	assert_eq(seen_by_a.size(), 1)
	var seen_a_node: int = seen_by_a[0]["node_id"]
	assert_eq(seen_a_node, A_MID)
	assert_eq(seen_by_b.size(), 1)
	var seen_b_node: int = seen_by_b[0]["node_id"]
	assert_eq(seen_b_node, B_FORK)
	# 权威哈希两边都有，盲的只是视图。协议层裁剪是 E1，这里不得假装已经藏住。
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 1)
	assert_eq(session.setup_authority_obstacles(TEAM_B).size(), 1)
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	var revealed_a: Array[Dictionary] = session.visible_obstacles(TEAM_A)
	assert_eq(revealed_a.size(), 2, "揭示之后双方方案都可见")
	assert_true(_has_node(revealed_a, A_MID))
	assert_true(_has_node(revealed_a, B_FORK))
	assert_eq(session.visible_obstacles(TEAM_B).size(), 2)


# 3. 揭示时重验：封路撤销并退点。

func test_a_sealing_pair_is_revoked_at_reveal_and_refunded() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var barricade: int = BastionPrototypeCatalog.OBSTACLE_BARRICADE
	var cost: int = BastionPlayStubs.obstacle_point_cost(barricade)
	# 两个各自合法、合起来封死：提交时都进 pending。
	assert_true(session.try_place_obstacle(TEAM_A, A_MID, barricade))
	assert_true(session.try_place_obstacle(TEAM_A, A_BRANCH_NEAR, barricade))
	assert_eq(session.setup_points_spent(TEAM_A), cost * 2)
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 2)
	_lock_and_reveal(session)
	var kept: Array[Dictionary] = session.setup_authority_obstacles(TEAM_A)
	assert_eq(kept.size(), 1, "LIFO 只撤最后一条，主路障留下")
	var kept_node: int = kept[0]["node_id"]
	assert_eq(kept_node, A_MID)
	assert_eq(session.setup_points_spent(TEAM_A), cost)
	assert_eq(session.setup_points_refunded(TEAM_A), cost)
	assert_eq(
		session.setup_points_left(TEAM_A),
		_points_budget(session) - cost
	)
	# 活图用的是退点之后的 committed，所以准备建造阶段的兵线仍然走得通。
	assert_gt(session.lane_path(TEAM_A).size(), 1)


func test_a_lone_choke_barricade_is_also_revoked_at_reveal() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	var barricade: int = BastionPrototypeCatalog.OBSTACLE_BARRICADE
	# 分叉点一封，两条分支一起没。槽位合法，所以提案进 pending。
	assert_true(session.try_place_obstacle(TEAM_A, A_FORK, barricade))
	_lock_and_reveal(session)
	assert_eq(session.setup_authority_obstacles(TEAM_A).size(), 0)
	assert_eq(session.setup_points_spent(TEAM_A), 0)
	assert_eq(
		session.setup_points_refunded(TEAM_A),
		BastionPlayStubs.obstacle_point_cost(barricade)
	)


func test_a_legal_diverter_survives_reveal_and_freezes_the_lane() -> void:
	var plain: BastionMatchSession = _fast_session()
	_lock_and_reveal(plain)
	var diverted: BastionMatchSession = _fast_session()
	assert_true(diverted.begin_match())
	assert_true(diverted.try_place_obstacle(
		TEAM_A, A_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER
	))
	_lock_and_reveal(diverted)
	assert_eq(diverted.setup_authority_obstacles(TEAM_A).size(), 1)
	assert_eq(diverted.setup_points_refunded(TEAM_A), 0)
	assert_ne(diverted.lane_path(TEAM_A), plain.lane_path(TEAM_A))
	assert_eq(diverted.lane_path(TEAM_B), plain.lane_path(TEAM_B))


# 4. 回放能复现完整布障序列。

func test_replaying_the_setup_tape_reproduces_state_and_hash() -> void:
	var first: BastionMatchSession = _fast_session()
	assert_true(first.begin_match())
	assert_true(first.try_place_obstacle(
		TEAM_A, A_MID, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))
	assert_true(first.try_place_obstacle(
		TEAM_B, B_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER
	))
	assert_true(first.lock_setup(TEAM_A))
	assert_true(first.lock_setup(TEAM_B))
	first.commit_tick()
	assert_eq(first.phase, BastionMatchSession.PHASE_PREP)
	var tape: Array[Dictionary] = first.setup_commands()
	assert_gt(tape.size(), 0)
	var last_kind: int = tape[tape.size() - 1]["kind"]
	assert_eq(last_kind, BastionMatchSetupState.KIND_TICK)
	var second: BastionMatchSession = BastionMatchSession.replay_setup(
		first.bundle, first.seed, tape
	)
	assert_not_null(second)
	assert_eq(second.phase, first.phase)
	assert_eq(second.hash_state(), first.hash_state())
	assert_eq(second.setup_hash_tape(), first.setup_hash_tape())
	assert_eq(
		second.setup_authority_obstacles(TEAM_A).size(),
		first.setup_authority_obstacles(TEAM_A).size()
	)
	assert_eq(
		second.setup_authority_obstacles(TEAM_B).size(),
		first.setup_authority_obstacles(TEAM_B).size()
	)


func test_same_setup_tape_same_hash_every_run() -> void:
	var first: BastionMatchSession = _played_setup()
	var second: BastionMatchSession = _played_setup()
	assert_eq(first.hash_state(), second.hash_state())
	assert_eq(first.setup_hash_tape(), second.setup_hash_tape())
	assert_eq(first.setup_battlefield_hash(), second.setup_battlefield_hash())
	assert_false(first.setup_battlefield_hash().is_empty())


func test_a_different_placement_makes_a_different_tape() -> void:
	var slowed: BastionMatchSession = _fast_session()
	assert_true(slowed.begin_match())
	assert_true(slowed.try_place_obstacle(
		TEAM_A, A_MID, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))
	_lock_and_reveal(slowed)
	var diverted: BastionMatchSession = _fast_session()
	assert_true(diverted.begin_match())
	assert_true(diverted.try_place_obstacle(
		TEAM_A, A_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER
	))
	_lock_and_reveal(diverted)
	assert_ne(slowed.setup_hash_tape(), diverted.setup_hash_tape())
	assert_ne(slowed.setup_battlefield_hash(), diverted.setup_battlefield_hash())
	assert_ne(slowed.hash_state(), diverted.hash_state())


func test_countdown_reveal_without_locks_still_records_ticks() -> void:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	assert_true(session.try_place_obstacle(
		TEAM_A, A_MID, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))
	for _step: int in range(FAST_SETUP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)
	assert_true(session.setup_revealed())
	var tape: Array[Dictionary] = session.setup_commands()
	var ticks: int = 0
	for item: Dictionary in tape:
		var kind: int = item["kind"]
		if kind == BastionMatchSetupState.KIND_TICK:
			ticks += 1
	assert_eq(ticks, FAST_SETUP)
	var replayed: BastionMatchSession = BastionMatchSession.replay_setup(
		session.bundle, session.seed, tape
	)
	assert_eq(replayed.hash_state(), session.hash_state())
	assert_eq(replayed.setup_authority_obstacles(TEAM_A).size(), 1)


func test_setup_tape_freezes_once_revealed() -> void:
	var session: BastionMatchSession = _played_setup()
	var frozen: String = session.setup_hash_tape()
	var count: int = session.setup_command_count()
	session.commit_tick()
	session.commit_tick()
	assert_eq(session.setup_hash_tape(), frozen)
	assert_eq(session.setup_command_count(), count)


# 5. 文件拆分仍在 E9 行数以内。

func test_setup_files_stay_under_the_e9_line_cap() -> void:
	for path: String in SETUP_PATHS:
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


func _lock_and_reveal(session: BastionMatchSession) -> void:
	if session.phase == BastionMatchSession.PHASE_HANDSHAKE:
		assert_true(session.begin_match())
	if session.phase == BastionMatchSession.PHASE_SETUP:
		if not session.team_setup_locked(TEAM_A):
			assert_true(session.lock_setup(TEAM_A))
		if not session.team_setup_locked(TEAM_B):
			assert_true(session.lock_setup(TEAM_B))
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_PREP)
	assert_true(session.setup_revealed())


func _played_setup() -> BastionMatchSession:
	var session: BastionMatchSession = _fast_session()
	assert_true(session.begin_match())
	assert_true(session.try_place_obstacle(
		TEAM_A, A_MID, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))
	_lock_and_reveal(session)
	return session


func _points_budget(session: BastionMatchSession) -> int:
	return session.bundle.economy_value("obstacle_points")


func _has_node(placements: Array[Dictionary], node_id: int) -> bool:
	for item: Dictionary in placements:
		var current: int = item["node_id"]
		if current == node_id:
			return true
	return false
