extends GutTest

## M6 D1：BASTION L0 契约与蓝图编译。
##
## 这一批断言要证明的是四件后续每一章都会依赖的事，不是「字段能存进去」：
##
## 1. **九个原型之外一律拒绝**。2026-09-15 那次拍板只锁了「M6 用哪九个」，
##    CD-22 §4.2 / §5.1 / §5.2 三张表原文仍写着「不是锁定清单」。没有这条断言，
##    下一个 Agent 会从示例表里把电弧塔 / 护盾兵 / 视野雾区补全。
## 2. **`SimulationBundle` 一个字节没动**。金标钉住 `course_01` 编译产物的规范
##    摘要：TRAPRUSH 的 ContentHash 覆盖那份 `to_dictionary()`，动它就牵动已发布
##    内容与旧回放（宪法第六条）。两个 wire 互喂都必须被拒。
## 3. **蓝图是数据，不是代码**。float / NodePath 注入、未登记原型、超上限等级、
##    蓝图里预置塔、两侧预算不等、悬空边——每一条都有反例。
## 4. **同一份蓝图编译两次得到同一份 wire**。节点编号是推导的，回放与哈希能
##    自证的前提就在这里。
##
## 数值不在本批：白名单里那九个原型的伤害 / 血量 / 速度全是占位桩
## （CD-63 §1.3 仍延期），本章锁的是「哪九个」与「形状」。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCodes := preload("res://src/ugc/bastion_blueprint_codes.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionPlayStubs := preload("res://src/games/bastion/play_stubs.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const BUNDLE_FIXTURE_DIR: String = "res://content/test_fixtures/bastion/bundles"
const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536

## `course_01` 编译产物 `to_dictionary()` 的规范摘要。改了 TRAPRUSH 的 bundle
## 形状这条就红——那正是本章不许发生的事（宪法第六条）。
const COURSE_01_BUNDLE_DIGEST: String = (
	"864e28eb335816c7175963866fa83e43eeac89747197eb0279ba7489903db6e0"
)
## 22 个袋 + `schema_version` / `cell` / `source_revision` / `assets` 四个头字段。
const SIMULATION_BUNDLE_WIRE_KEYS: int = 26


# 1. 白名单金标：九个，且九个之外一律失败。

func test_catalog_pins_the_nine_m6_prototypes() -> void:
	assert_eq(BastionPrototypeCatalog.KINDS.size(), 9)
	assert_eq(BastionPrototypeCatalog.TOWER_IDS, PackedInt32Array([1, 2, 3]))
	assert_eq(BastionPrototypeCatalog.UNIT_IDS, PackedInt32Array([11, 12, 13]))
	assert_eq(BastionPrototypeCatalog.OBSTACLE_IDS, PackedInt32Array([21, 22, 23]))
	for prototype_id: int in BastionPrototypeCatalog.TOWER_IDS:
		assert_true(BastionPrototypeCatalog.is_tower(prototype_id))
	for prototype_id: int in BastionPrototypeCatalog.UNIT_IDS:
		assert_true(BastionPrototypeCatalog.is_unit(prototype_id))
	for prototype_id: int in BastionPrototypeCatalog.OBSTACLE_IDS:
		assert_true(BastionPrototypeCatalog.is_obstacle(prototype_id))
	# 升级树一期最多 3 级（CD-22 §5.1）。
	assert_eq(BastionPrototypeCatalog.MAX_TOWER_LEVEL, 3)
	assert_true(BastionPrototypeCatalog.level_is_valid(3))
	assert_false(BastionPrototypeCatalog.level_is_valid(4))
	assert_false(BastionPrototypeCatalog.level_is_valid(0))


func test_catalog_rejects_everything_outside_the_m6_minimum_set() -> void:
	# 电弧 / 增幅塔、护盾 / 支援 / 首领兵、护盾柱 / 干扰塔座 / 视野雾区
	# 都在 CD-22 的示例表里，都**不在 M6**。没有登记就必须查不到。
	for prototype_id: int in [4, 5, 6, 14, 15, 16, 24, 25, 26, 0, -1, 999]:
		assert_false(
			BastionPrototypeCatalog.has_prototype(prototype_id),
			"未拍板的原型 %d 不得出现在 M6 白名单里" % prototype_id
		)
		assert_eq(BastionPrototypeCatalog.kind_of(prototype_id), "")
	# 类别不能混：塔 id 放进障碍白名单一样不过。
	assert_false(BastionPrototypeCatalog.whitelist_is_valid(
		PackedInt32Array([1, 2]), BastionPrototypeCatalog.KIND_OBSTACLE
	))
	# 白名单必须非空且严格升序（wire 规范化：同一份内容只有一种字节形状）。
	assert_false(BastionPrototypeCatalog.whitelist_is_valid(
		PackedInt32Array([]), BastionPrototypeCatalog.KIND_TOWER
	))
	assert_false(BastionPrototypeCatalog.whitelist_is_valid(
		PackedInt32Array([2, 1]), BastionPrototypeCatalog.KIND_TOWER
	))
	assert_false(BastionPrototypeCatalog.whitelist_is_valid(
		PackedInt32Array([1, 1]), BastionPrototypeCatalog.KIND_TOWER
	))


# 2. 灰盒夹具：编译得到一张闭合的对称战场。

func test_graybox_blueprint_compiles_to_a_symmetric_battlefield() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	assert_eq(bundle.cell, CELL)
	assert_eq(bundle.cores.size(), 2)
	assert_eq(bundle.spawns.size(), 2)
	assert_eq(bundle.build_slots.size(), 6)
	assert_eq(bundle.obstacle_slots.size(), 6)
	# 每侧 7 个节点（主路 4 + 绕行 3），7 条有向边：主路 3 条 + 绕行 4 条。
	# 两条折线共用的那一段只留一条——去重发生在这里，不在作者那边。
	assert_eq(bundle.waypoints.size(), 14)
	assert_eq(bundle.edges.size(), 14)
	assert_eq(bundle.waves.size(), 3)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		assert_eq(bundle.node_ids_of(team_id).size(), 7)
		assert_eq(bundle.build_slot_ids(team_id).size(), 3)
		assert_eq(bundle.obstacle_slot_node_ids(team_id).size(), 3)
		assert_eq(bundle.spawn_node_ids(team_id).size(), 1)
		var core: Dictionary = bundle.core_of(team_id)
		assert_false(core.is_empty())
		assert_eq(_int_at(core, "max_health"), 20)
	# 分叉点真的有两条出边，否则分流门就是封路。
	var branch_out: int = 0
	for node_id: int in bundle.obstacle_slot_node_ids(BastionBlueprintBundle.TEAM_A):
		branch_out = maxi(branch_out, bundle.edges_from(node_id).size())
	assert_eq(branch_out, 2)


func test_graybox_economy_comes_from_the_single_stub_source() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	# 夹具的经济值必须与 `BastionPlayStubs.GRAYBOX_ECONOMY` 逐字段相等。
	# 两处漂移不会报错，只会让夹具与桩说的不是同一回事。
	for key: String in BastionBlueprintBundle.ECONOMY_KEYS:
		var expected: int = BastionPlayStubs.GRAYBOX_ECONOMY[key]
		assert_eq(bundle.economy_value(key), expected, key)


func test_waves_are_one_shared_table_ordered_by_entity_id() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	# 一张表、两队共用——镜像波次的公平性就靠这件事（CD-22 §5.2）。
	var indices: PackedInt32Array = PackedInt32Array()
	for wave: Dictionary in bundle.waves:
		indices.append(_int_at(wave, "index"))
		assert_true(BastionPrototypeCatalog.is_unit(_int_at(wave, "prototype_id")))
		assert_gt(_int_at(wave, "count"), 0)
	assert_eq(indices, PackedInt32Array([1, 2, 3]))
	assert_eq(_int_at(bundle.waves[0], "prototype_id"), BastionPrototypeCatalog.UNIT_SWIFT)
	assert_eq(_int_at(bundle.waves[1], "prototype_id"), BastionPrototypeCatalog.UNIT_SWARM)
	assert_eq(_int_at(bundle.waves[2], "prototype_id"), BastionPrototypeCatalog.UNIT_HEAVY)


func test_compiling_twice_gives_the_same_wire() -> void:
	var first: BastionBlueprintBundle = _compile_graybox()
	var second: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.digest_hex(), second.digest_hex())
	assert_false(first.digest_hex().is_empty())


func test_bundle_round_trips_through_its_own_wire() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var encoded: Dictionary = bundle.to_dictionary()
	assert_eq(encoded.size(), 12)
	var gameplay: String = encoded["gameplay"]
	assert_eq(gameplay, BastionBlueprintBundle.GAMEPLAY_ID)
	var decoded: BastionBlueprintBundle = BastionBlueprintBundle.from_dictionary(encoded)
	assert_not_null(decoded)
	assert_eq(decoded.digest_hex(), bundle.digest_hex())


# 3. 两个 wire 互不相认，且 TRAPRUSH 那份逐字节不变。

func test_traprush_bundle_is_rejected_by_the_bastion_decoder() -> void:
	var traprush: SimulationBundle = _compile_course_01()
	assert_not_null(traprush)
	assert_null(BastionBlueprintBundle.from_dictionary(traprush.to_dictionary()))
	# 反向也不认：BASTION 的 wire 键数与形状都不是 Bundle v2。
	var bastion: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bastion)
	assert_null(SimulationBundle.from_dictionary(bastion.to_dictionary()))


func test_simulation_bundle_wire_is_byte_identical_to_before_this_chapter() -> void:
	var traprush: SimulationBundle = _compile_course_01()
	assert_not_null(traprush)
	# 金标：TRAPRUSH 的 22 个袋与 `to_dictionary()` 在本章一个字节没动。
	assert_eq(_digest_of(traprush.to_dictionary()), COURSE_01_BUNDLE_DIGEST)
	assert_eq(traprush.to_dictionary().size(), SIMULATION_BUNDLE_WIRE_KEYS)


# 4. 反例：每一条拒绝理由都要能被单独指出来。

func test_unregistered_prototype_in_a_whitelist_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	# 4 号是 CD-22 示例表里的电弧塔，**不在 M6**。
	_slot_whitelist(body, 30, [1, 2, 4])
	_assert_problem(body, BastionBlueprintCodes.UNKNOWN_PROTOTYPE)


func test_tower_above_the_level_cap_and_tower_as_content_are_both_rejected() -> void:
	var above_cap: Dictionary = _graybox_json()
	_components(above_cap, 30)["tower"] = {
		"level": 4, "attack_range": CELL, "cooldown_ticks": 6, "target_priority": "front",
	}
	_assert_problem(above_cap, BastionBlueprintCodes.TOWER_LEVEL_ABOVE_CAP)
	var legal_level: Dictionary = _graybox_json()
	_components(legal_level, 30)["tower"] = {
		"level": 2, "attack_range": CELL, "cooldown_ticks": 6, "target_priority": "front",
	}
	# 等级合法也拒：建塔是玩法命令，不是蓝图内容（CD-22 §7.3）。
	_assert_problem(legal_level, BastionBlueprintCodes.TOWER_NOT_BLUEPRINT_CONTENT)


func test_missing_one_side_core_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	_drop_entity(body, 11)
	_assert_problem(body, BastionBlueprintCodes.MISSING_CORE)


func test_unequal_core_health_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	_components(body, 11)["health"] = {"current": 30, "maximum": 30, "invuln_ticks": 0}
	_assert_problem(body, BastionBlueprintCodes.CORE_HEALTH_MISMATCH)


func test_zero_obstacle_slots_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	for entity_id: int in [40, 41, 42, 43, 44, 45]:
		_drop_entity(body, entity_id)
	_assert_problem(body, BastionBlueprintCodes.MISSING_OBSTACLE_SLOT)


func test_unequal_side_budgets_are_rejected() -> void:
	var body: Dictionary = _graybox_json()
	_drop_entity(body, 35)
	_assert_problem(body, BastionBlueprintCodes.SLOT_BUDGET_MISMATCH)


func test_dangling_edge_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	# 把主路第二个点挪到斜对角：这条边在格网上接不到任何走得通的东西。
	var agent: Dictionary = _components(body, 50)["path_agent"]
	var points: Array = agent["waypoints"]
	points[1] = {"x": CELL, "y": 0, "z": -2 * CELL}
	_assert_problem(body, BastionBlueprintCodes.DANGLING_EDGE)


func test_route_must_start_at_a_spawn_and_end_at_the_core() -> void:
	var off_core: Dictionary = _graybox_json()
	var agent: Dictionary = _components(off_core, 50)["path_agent"]
	var points: Array = agent["waypoints"]
	points.remove_at(points.size() - 1)
	_assert_problem(off_core, BastionBlueprintCodes.ROUTE_NOT_AT_CORE)
	var off_spawn: Dictionary = _graybox_json()
	var other: Dictionary = _components(off_spawn, 50)["path_agent"]
	var other_points: Array = other["waypoints"]
	other_points.remove_at(0)
	_assert_problem(off_spawn, BastionBlueprintCodes.ROUTE_NOT_AT_SPAWN)


func test_blueprint_may_not_author_unit_numbers() -> void:
	var body: Dictionary = _graybox_json()
	# 单位速度是占位桩，落 `BastionPlayStubs` 一处；蓝图作者填了就拒。
	_components(body, 50)["path_agent"]["speed"] = CELL / 8
	_assert_problem(body, BastionBlueprintCodes.AUTHORED_UNIT_NUMBERS)


func test_prefilled_slot_occupant_is_rejected() -> void:
	var body: Dictionary = _graybox_json()
	_components(body, 30)["build_slot"]["occupant_id"] = 7
	_assert_problem(body, BastionBlueprintCodes.SLOT_OCCUPIED_IN_BLUEPRINT)


func test_build_slot_on_the_lane_and_obstacle_slot_off_the_lane_are_rejected() -> void:
	var on_lane: Dictionary = _graybox_json()
	_components(on_lane, 30)["transform"] = {"x": 0, "y": 0, "z": -4 * CELL, "yaw_bam": 0}
	_assert_problem(on_lane, BastionBlueprintCodes.BUILD_SLOT_ON_LANE)
	var off_lane: Dictionary = _graybox_json()
	_components(off_lane, 41)["transform"] = {"x": -3 * CELL, "y": 0, "z": -4 * CELL, "yaw_bam": 0}
	_assert_problem(off_lane, BastionBlueprintCodes.OBSTACLE_SLOT_OFF_LANE)


func test_diverter_on_a_single_exit_node_is_rejected_at_decode() -> void:
	var body: Dictionary = _graybox_json()
	# 42 号槽在主路上、只有一条出边；给它分流门就是封路（CD-22 §4.3）。
	_slot_whitelist(body, 42, [21, 22, 23])
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world)
	# 编译器的图闭合检查过得去，wire 解码这一层把它拦下来。
	assert_null(BastionBlueprintCompiler.compile(world))


func test_config_entity_must_be_exactly_one_with_exactly_eight_keys() -> void:
	var missing: Dictionary = _graybox_json()
	_drop_entity(missing, 1)
	_assert_problem(missing, BastionBlueprintCodes.MISSING_CONFIG)
	var short_keys: Dictionary = _graybox_json()
	var tallies: Dictionary = _components(short_keys, 1)["score"]["tallies"]
	tallies.erase("bounty_cap")
	_assert_problem(short_keys, BastionBlueprintCodes.BAD_CONFIG_KEYS)


func test_ambiguous_role_tags_are_rejected_instead_of_guessed() -> void:
	var body: Dictionary = _graybox_json()
	_components(body, 30)["zone"]["tags"] = ["bastion_build_slot", "bastion_obstacle_slot"]
	_assert_problem(body, BastionBlueprintCodes.AMBIGUOUS_ROLE)


func test_wire_rejects_float_and_nodepath_injection() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var fractional: Dictionary = bundle.to_dictionary()
	fractional["cell"] = 1.5
	assert_null(BastionBlueprintBundle.from_dictionary(fractional))
	var path_injected: Dictionary = bundle.to_dictionary()
	path_injected["gameplay"] = NodePath("res://src/ugc/bastion_blueprint_bundle.gd")
	assert_null(BastionBlueprintBundle.from_dictionary(path_injected))
	var wrong_gameplay: Dictionary = bundle.to_dictionary()
	wrong_gameplay["gameplay"] = "traprush"
	assert_null(BastionBlueprintBundle.from_dictionary(wrong_gameplay))
	var wrong_version: Dictionary = bundle.to_dictionary()
	wrong_version["schema_version"] = 2
	assert_null(BastionBlueprintBundle.from_dictionary(wrong_version))
	var extra_key: Dictionary = bundle.to_dictionary()
	extra_key["navmesh"] = []
	assert_null(BastionBlueprintBundle.from_dictionary(extra_key))


func test_wire_rejects_a_dangling_edge_reference() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var body: Dictionary = bundle.to_dictionary()
	var edges: Array = body["edges"]
	var first: Dictionary = edges[0]
	first["to_id"] = 9999
	assert_null(BastionBlueprintBundle.from_dictionary(body))


func test_wire_rejects_cross_team_edges() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var body: Dictionary = bundle.to_dictionary()
	var edges: Array = body["edges"]
	var first: Dictionary = edges[0]
	# 14 个节点里前 7 个属 A、后 7 个属 B（按 team 升序编号），跨队边必须被拒。
	first["to_id"] = 14
	assert_null(BastionBlueprintBundle.from_dictionary(body))


func test_wire_rejects_unbalanced_slot_counts() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var body: Dictionary = bundle.to_dictionary()
	var slots: Array = body["build_slots"]
	slots.remove_at(slots.size() - 1)
	assert_null(BastionBlueprintBundle.from_dictionary(body))


func test_wire_rejects_non_contiguous_wave_indices() -> void:
	var bundle: BastionBlueprintBundle = _compile_graybox()
	assert_not_null(bundle)
	var body: Dictionary = bundle.to_dictionary()
	var waves: Array = body["waves"]
	var second: Dictionary = waves[1]
	second["index"] = 5
	assert_null(BastionBlueprintBundle.from_dictionary(body))


# 5. 两侧读同一批夹具：GDScript 解码器与 content-validator 不许各自绿。

func test_wire_fixtures_decode_the_same_way_the_json_schema_side_judges_them() -> void:
	# 这些文件同时被 `tools/content-validator` 读。一侧拒、另一侧放行的反例等于
	# 没有反例——那正是 `validate_simulation_bundle.ts` 文件头写的那条理由。
	var accepted: int = _run_fixture_dir("valid", true)
	var rejected: int = _run_fixture_dir("invalid", false)
	assert_gt(accepted, 1, "至少要有两份正例（最小图 + 带分支的灰盒）")
	assert_gt(rejected, 20, "反例太少说明没覆盖住闭合规则")


# --- helpers ---------------------------------------------------------------

func _run_fixture_dir(kind: String, expect_valid: bool) -> int:
	var directory: String = "%s/%s" % [BUNDLE_FIXTURE_DIR, kind]
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	assert_gt(names.size(), 0, "读不到夹具目录 %s" % directory)
	var seen: int = 0
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		seen += 1
		var path: String = "%s/%s" % [directory, name]
		var body: Dictionary = AuthoringDocument.load_json(path)
		assert_false(body.is_empty(), "读不到 %s" % path)
		var bundle: BastionBlueprintBundle = BastionBlueprintBundle.from_dictionary(body)
		if expect_valid:
			assert_not_null(bundle, "%s 应当解码成功" % name)
		else:
			assert_null(bundle, "%s 应当被拒" % name)
	return seen



func _graybox_json() -> Dictionary:
	var body: Dictionary = AuthoringDocument.load_json(GRAYBOX_PATH)
	assert_false(body.is_empty(), "读不到灰盒夹具蓝图")
	return body


func _compile_graybox() -> BastionBlueprintBundle:
	var world: AuthoringWorld = AuthoringDocument.decode(_graybox_json())
	assert_not_null(world)
	var codes: PackedStringArray = BastionBlueprintCompiler.problems(world)
	assert_eq(codes, PackedStringArray([]), "灰盒夹具不该有问题码：%s" % str(codes))
	return BastionBlueprintCompiler.compile(world)


func _compile_course_01() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	return TraprushTopologyCompiler.compile(world)


## 改过的蓝图必须报出 `code`，并且 `compile()` 返回 null。
func _assert_problem(body: Dictionary, code: String) -> void:
	assert_true(BastionBlueprintCodes.contains(code), "%s 不在问题码清单里" % code)
	var world: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(world, "改动后的文档仍应是合法 AuthoringDocument")
	var codes: PackedStringArray = BastionBlueprintCompiler.problems(world)
	assert_true(codes.has(code), "期望问题码 %s，实际 %s" % [code, str(codes)])
	assert_null(BastionBlueprintCompiler.compile(world))


func _entity(body: Dictionary, entity_id: int) -> Dictionary:
	var entities: Array = body["entities"]
	for item: Variant in entities:
		var entity: Dictionary = item
		var current: int = entity["entity_id"]
		if current == entity_id:
			return entity
	fail_test("夹具里没有实体 %d" % entity_id)
	return {}


func _components(body: Dictionary, entity_id: int) -> Dictionary:
	var entity: Dictionary = _entity(body, entity_id)
	var components: Dictionary = entity["components"]
	return components


func _drop_entity(body: Dictionary, entity_id: int) -> void:
	var entities: Array = body["entities"]
	for index: int in range(entities.size()):
		var entity: Dictionary = entities[index]
		var current: int = entity["entity_id"]
		if current == entity_id:
			entities.remove_at(index)
			return
	fail_test("夹具里没有实体 %d" % entity_id)


func _slot_whitelist(body: Dictionary, entity_id: int, whitelist: Array) -> void:
	var slot: Dictionary = _components(body, entity_id)["build_slot"]
	slot["whitelist"] = whitelist


func _digest_of(body: Dictionary) -> String:
	var hasher: StateHasher = StateHasher.new()
	assert_true(hasher.write_canonical(body))
	return hasher.digest_hex()


func _int_at(body: Dictionary, key: String) -> int:
	var value: Variant = body.get(key, null)
	if typeof(value) != TYPE_INT:
		return -1
	return value
