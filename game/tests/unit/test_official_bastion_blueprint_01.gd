extends GutTest

## M6 E2：第一张官方 BASTION 蓝图 `blueprint_01`（对称双线）。
##
## 2026-09-15 人类拍板的是主题与机关组合，不是数值（CD-63 §1.3 / §1.4 仍延期）。
## 本批要钉住的是四件后续 E3 / E4 会依赖的事：
##
## 1. **id 白名单只认 `blueprint_01`，`res://` 路径一律拒绝**——照官方课那条。
##    匹配 HTTP 本刀不接线（E3），所以 `blueprint_01` 也不是一张 TRAPRUSH 课。
## 2. **编译零问题码，发布前可达性通过**。灰盒夹具已经是这张拓扑；官方图在
##    同一拓扑上把波次表扩到 5 波，不能把灰盒 3 波原样升格。
## 3. **两侧对称预算相等**，且覆盖 CD-61 §4.2：双方核心、每侧一条合法路、
##    每侧 3 个障碍槽、3 种塔 / 3 种兵白名单、互设障碍预算。
## 4. **5 波基础表在 5 分钟局时内能跑完**。`spawner` 一波一个原型，所以拍板里的
##    「快速+集群」「混合」落成第 3 / 第 5 波再出已出现过的类型，三种兵都见到。
##
## 经济数字是 `BastionPlayStubs.GRAYBOX_ECONOMY` 的占位桩，不当产品表。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionPathGuard := preload("res://src/games/bastion/path_guard.gd")
const BastionPlayStubs := preload("res://src/games/bastion/play_stubs.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")
const OfficialBlueprints := preload("res://src/shared/official_bastion_blueprints.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")

const BLUEPRINT_PATH: String = "res://content/official/bastion/blueprint_01.json"
const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const CELL: int = 65536
const TEAM_A: int = 1
const TEAM_B: int = 2
const FAST_SETUP: int = 3
const FAST_PREP: int = 2
const FAST_CADENCE: int = 40
const LAST_WAVE_TRAVEL_BUDGET: int = 600
const WAVE_RUN_TICK_BUDGET: int = 4000


func test_whitelist_accepts_blueprint_01_and_rejects_paths() -> void:
	assert_eq(OfficialBlueprints.DEFAULT_ID, "blueprint_01")
	assert_true(OfficialBlueprints.is_id("blueprint_01"))
	assert_eq(OfficialBlueprints.normalize_id("  blueprint_01  "), "blueprint_01")
	assert_eq(OfficialBlueprints.document_path("blueprint_01"), BLUEPRINT_PATH)
	assert_eq(OfficialBlueprints.default_path(), BLUEPRINT_PATH)
	assert_eq(OfficialBlueprints.all_match_ids(), OfficialBlueprints.MATCH_IDS)
	assert_false(OfficialBlueprints.is_id("blueprint_02"))
	assert_false(OfficialBlueprints.is_id("course_01"))
	assert_eq(OfficialBlueprints.normalize_id(""), "")
	assert_eq(OfficialBlueprints.normalize_id("res://content/official/bastion/blueprint_01.json"), "")
	assert_eq(OfficialBlueprints.document_path("res://content/official/bastion/blueprint_01.json"), "")
	assert_eq(OfficialBlueprints.document_path("blueprint_99"), "")
	# E3 之前匹配 HTTP 仍是 TRAPRUSH 课表。官方蓝图 id 不得被当成一张课。
	assert_false(OfficialCourses.is_id("blueprint_01"))
	assert_eq(OfficialCourses.normalize_id("blueprint_01"), "")


func test_official_blueprint_compiles_with_zero_problem_codes() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(BLUEPRINT_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.revision, 1)
	var codes: PackedStringArray = BastionBlueprintCompiler.problems(world)
	assert_eq(codes, PackedStringArray())
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(BastionPathGuard.problems(bundle), PackedStringArray())


func test_layout_is_symmetric_dual_lane_covering_the_fixture() -> void:
	var bundle: BastionBlueprintBundle = _compile_official()
	assert_eq(bundle.cores.size(), 2)
	assert_eq(bundle.spawns.size(), 2)
	assert_eq(bundle.build_slots.size(), 6)
	assert_eq(bundle.obstacle_slots.size(), 6)
	assert_eq(bundle.waves.size(), 5)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		assert_eq(bundle.node_ids_of(team_id).size(), 7)
		assert_eq(bundle.build_slot_ids(team_id).size(), 3)
		assert_eq(bundle.obstacle_slot_node_ids(team_id).size(), 3)
		assert_eq(bundle.spawn_node_ids(team_id).size(), 1)
		var core: Dictionary = bundle.core_of(team_id)
		assert_false(core.is_empty())
		assert_eq(_int_at(core, "max_health"), _int_at(bundle.core_of(TEAM_B), "max_health"))
	assert_eq(bundle.economy_value("obstacle_points"), BastionPlayStubs.GRAYBOX_ECONOMY["obstacle_points"])
	# 分叉点必须有两条出边，否则分流门就是封路。
	var branch_out: int = 0
	for node_id: int in bundle.obstacle_slot_node_ids(TEAM_A):
		branch_out = maxi(branch_out, bundle.edges_from(node_id).size())
	assert_eq(branch_out, 2)
	_assert_one_slot_allows_all_obstacles(bundle, TEAM_A)
	_assert_one_slot_allows_all_obstacles(bundle, TEAM_B)
	# 三种塔都在建造槽白名单里。
	var tower_seen: Dictionary[int, bool] = {}
	for slot: Dictionary in bundle.build_slots:
		var whitelist: PackedInt32Array = slot["whitelist"]
		for prototype_id: int in whitelist:
			assert_true(BastionPrototypeCatalog.is_tower(prototype_id))
			tower_seen[prototype_id] = true
	assert_eq(tower_seen.size(), 3)


func test_economy_stays_on_the_stub_source_and_five_minute_limit() -> void:
	var bundle: BastionBlueprintBundle = _compile_official()
	for key: String in BastionBlueprintBundle.ECONOMY_KEYS:
		assert_eq(bundle.economy_value(key), BastionPlayStubs.GRAYBOX_ECONOMY[key], key)
	assert_eq(bundle.economy_value("time_limit_ticks"), 18000)


func test_five_waves_cover_three_unit_types_in_the_boarded_order() -> void:
	var bundle: BastionBlueprintBundle = _compile_official()
	var prototypes: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()
	for wave: Dictionary in bundle.waves:
		assert_true(BastionPrototypeCatalog.is_unit(_int_at(wave, "prototype_id")))
		assert_gt(_int_at(wave, "count"), 0)
		prototypes.append(_int_at(wave, "prototype_id"))
		counts.append(_int_at(wave, "count"))
	assert_eq(prototypes, PackedInt32Array([
		BastionPrototypeCatalog.UNIT_SWIFT,
		BastionPrototypeCatalog.UNIT_SWARM,
		BastionPrototypeCatalog.UNIT_SWIFT,
		BastionPrototypeCatalog.UNIT_HEAVY,
		BastionPrototypeCatalog.UNIT_SWARM,
	]))
	assert_eq(counts, PackedInt32Array([6, 10, 8, 4, 12]))
	# 灰盒仍是 3 波：官方图不是把它升格。
	var graybox: BastionBlueprintBundle = _compile_path(GRAYBOX_PATH)
	assert_eq(graybox.waves.size(), 3)
	assert_ne(bundle.digest_hex(), graybox.digest_hex())


func test_wave_schedule_fits_inside_the_five_minute_limit() -> void:
	var bundle: BastionBlueprintBundle = _compile_official()
	var scheduled: int = _scheduled_wave_ticks(bundle)
	assert_gt(scheduled, 0)
	assert_lt(scheduled, bundle.economy_value("time_limit_ticks"))


func test_five_waves_can_finish_when_cores_outlast_the_table() -> void:
	# 官方核心生命 20 是占位桩。无塔会在前几波倒下，那证明不了「表能跑完」。
	# 本条只把核心抬高、把节奏压短，断言五波的兵都生成了；官方文件的 20 / 18000
	# 由上面的字段断言钉住。
	var body: Dictionary = AuthoringDocument.load_json(BLUEPRINT_PATH)
	assert_false(body.is_empty())
	_retime(body, FAST_SETUP, FAST_PREP, FAST_CADENCE, 18000)
	_set_core_health(body, 200)
	var session: BastionMatchSession = BastionMatchSession.create(_compile_body(body), 7)
	assert_not_null(session)
	assert_true(session.begin_match())
	assert_true(session.lock_setup(TEAM_A))
	assert_true(session.lock_setup(TEAM_B))
	session.commit_tick()
	for _step: int in range(FAST_PREP):
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_WAVES)
	for _step: int in range(WAVE_RUN_TICK_BUDGET):
		if session.phase == BastionMatchSession.PHASE_SETTLED:
			break
		session.commit_tick()
	assert_eq(session.phase, BastionMatchSession.PHASE_SETTLED)
	var spawned: Array[Dictionary] = session.spawn_log(TEAM_A)
	assert_eq(spawned.size(), 40)
	assert_eq(session.spawn_log(TEAM_B).size(), 40)
	assert_eq(session.total_waves(), 5)


func test_missing_path_and_extra_key_are_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/bastion/missing.json"))
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(BLUEPRINT_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	data["surface"] = "internal_dev"
	assert_null(AuthoringDocument.decode(data))


func _compile_official() -> BastionBlueprintBundle:
	return _compile_path(BLUEPRINT_PATH)


func _compile_path(path: String) -> BastionBlueprintBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _compile_body(body: Dictionary) -> BastionBlueprintBundle:
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _scheduled_wave_ticks(bundle: BastionBlueprintBundle) -> int:
	var cadence: int = bundle.economy_value("wave_interval_ticks")
	var total: int = 0
	var last_index: int = bundle.waves.size() - 1
	for index: int in range(bundle.waves.size()):
		var wave: Dictionary = bundle.waves[index]
		var count: int = wave["count"]
		var interval: int = wave["interval_ticks"]
		var spawn_span: int = interval * maxi(count - 1, 0)
		if index < last_index:
			total += maxi(spawn_span, cadence)
		else:
			total += spawn_span + LAST_WAVE_TRAVEL_BUDGET
	return total


func _assert_one_slot_allows_all_obstacles(bundle: BastionBlueprintBundle, team_id: int) -> void:
	var full: int = 0
	for slot: Dictionary in bundle.obstacle_slots:
		if _int_at(slot, "team_id") != team_id:
			continue
		var whitelist: PackedInt32Array = slot["whitelist"]
		if whitelist.size() == 3:
			assert_eq(whitelist, BastionPrototypeCatalog.OBSTACLE_IDS)
			full += 1
		else:
			assert_eq(whitelist.size(), 2)
			assert_true(whitelist.has(BastionPrototypeCatalog.OBSTACLE_BARRICADE))
			assert_true(whitelist.has(BastionPrototypeCatalog.OBSTACLE_SLOW_TILE))
			assert_false(whitelist.has(BastionPrototypeCatalog.OBSTACLE_DIVERTER))
	assert_eq(full, 1)


func _retime(
	body: Dictionary, setup_ticks: int, prep_ticks: int, cadence: int, time_limit: int
) -> void:
	var tallies: Dictionary = _tallies(body)
	tallies["setup_ticks"] = setup_ticks
	tallies["prep_ticks"] = prep_ticks
	tallies["wave_interval_ticks"] = cadence
	tallies["time_limit_ticks"] = time_limit


func _set_core_health(body: Dictionary, health: int) -> void:
	for entity_id: int in [10, 11]:
		var health_bag: Dictionary = _components(body, entity_id)["health"]
		health_bag["current"] = health
		health_bag["maximum"] = health


func _tallies(body: Dictionary) -> Dictionary:
	var score: Dictionary = _components(body, 1)["score"]
	var tallies: Dictionary = score["tallies"]
	return tallies


func _components(body: Dictionary, entity_id: int) -> Dictionary:
	var entities: Array = body["entities"]
	for item: Variant in entities:
		var entity: Dictionary = item
		var current: int = entity["entity_id"]
		if current == entity_id:
			var components: Dictionary = entity["components"]
			return components
	fail_test("蓝图里没有实体 %d" % entity_id)
	return {}


func _int_at(bag: Dictionary, key: String) -> int:
	var value: int = bag[key]
	return value
