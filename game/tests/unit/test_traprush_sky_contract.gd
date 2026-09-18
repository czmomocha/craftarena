extends GutTest

## TRAPRUSH 天空选择的契约（2026-09-17 人类拍板）。承载是**第 20 个 component**
## `environment` + SimulationBundle 的**第 23 个袋**（空时省略）。
##
## 本文件的重点是 `sky_catalog.gd` 文件头那张三级门禁表：解码不查目录、编译查目录、
## 渲染回退。三条各有正反例，别把它们合并成一条。
##
## 「已发布内容逐字节不变」的金标（`COURSE_01_BUNDLE_DIGEST` 与 26 键）住在
## `test_bastion_blueprint_contract.gd`，本文件不复制那两个常量，只复核让金标成立
## 的那条性质——空 `environment` 不 emit。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const ContentSign := preload("res://src/ugc/content_sign.gd")
const SharedComponentNames := preload("res://src/shared/schema/component_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SharedSkyCatalog := preload("res://src/shared/sky_catalog.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
## 22 个袋 + 四个头字段。加了 `environment` 之后**没选天空的内容仍是这个数**。
const WIRE_KEYS_WITHOUT_SKY: int = 26
const SKY_ENTITY_ID: int = 90
## 目录里没有的 id。解码接受它、编译拒绝它，这个差别就是本刀的设计。
const UNKNOWN_SKY_ID: int = 7


# 1. 天空目录本身。

func test_catalog_is_append_only_and_bounded() -> void:
	# `SKY_ID_MAX` 与表长必须同步：它被镜像到 TS，是 content-validator 的上界。
	assert_eq(SharedSkyCatalog.SKY_ID_MAX, SharedSkyCatalog.TEXTURE_PATHS.size() - 1)
	assert_eq(SharedSkyCatalog.DEFAULT_SKY_ID, 0)
	assert_true(SharedSkyCatalog.is_known(SharedSkyCatalog.DEFAULT_SKY_ID))
	assert_true(SharedSkyCatalog.is_known(SharedSkyCatalog.SKY_ID_MAX))
	assert_false(SharedSkyCatalog.is_known(UNKNOWN_SKY_ID))
	assert_false(SharedSkyCatalog.is_known(-1))


func test_texture_path_resolves_known_ids_and_blanks_the_rest() -> void:
	assert_eq(
		SharedSkyCatalog.texture_path(0), "res://content/assets/sky/sky_pastel_ridge.png"
	)
	assert_eq(
		SharedSkyCatalog.texture_path(1), "res://content/assets/sky/sky_lowpoly_mesa.png"
	)
	# 未知 id 回空串，让调用方回退默认天空，而不是崩在缺图上。
	assert_eq(SharedSkyCatalog.texture_path(UNKNOWN_SKY_ID), "")
	assert_eq(SharedSkyCatalog.texture_path(-1), "")
	# 两张 `.png` 已于本刀入库，所以这里是真断言，不是「入不入库都为真」的烟测：
	# 每个已登记 id 都必须有图，未登记的 id 必须没有。尺寸、比例与体积归
	# `test_sky_texture_budget.gd`，本条只管「在不在」。
	for sky_id: int in range(SharedSkyCatalog.SKY_ID_MAX + 1):
		assert_true(SharedSkyCatalog.has_texture(sky_id), "已登记的天空 %d 缺图" % sky_id)
	assert_false(SharedSkyCatalog.has_texture(UNKNOWN_SKY_ID))
	assert_false(SharedSkyCatalog.has_texture(-1))


# 2. 组件：只做结构校验，不查目录。

func test_environment_is_the_twentieth_whitelisted_component() -> void:
	assert_eq(SharedComponentNames.ALL.size(), 20)
	assert_true(SharedComponentNames.contains(SharedComponentNames.ENVIRONMENT))
	# 视觉路径不是组件字段：只有语义 id 进契约（ADR-0006 Q4 = A）。
	assert_false(SharedComponentNames.contains("sky"))
	assert_false(SharedComponentNames.contains("skybox"))


func test_environment_component_accepts_exactly_one_non_negative_int() -> void:
	assert_not_null(_record(SKY_ENTITY_ID, {"sky_id": 0}))
	assert_not_null(_record(SKY_ENTITY_ID, {"sky_id": SharedSkyCatalog.SKY_ID_MAX}))
	# 多一个键 / 少一个键 / float / 负数 / 字符串一律拒。
	assert_null(_record(SKY_ENTITY_ID, {"sky_id": 0, "texture": "res://a.png"}))
	assert_null(_record(SKY_ENTITY_ID, {}))
	assert_null(_record(SKY_ENTITY_ID, {"sky": 0}))
	assert_null(_record(SKY_ENTITY_ID, {"sky_id": 0.5}))
	assert_null(_record(SKY_ENTITY_ID, {"sky_id": -1}))
	assert_null(_record(SKY_ENTITY_ID, {"sky_id": "0"}))


func test_component_layer_does_not_consult_the_sky_catalog() -> void:
	# 结构合法就通过。「认不认识这个 id」是编译期的事，不是记录级的事——
	# 与 `gameplay_asset` 同一条分工（ADR-0006 Q5），草稿允许引用未登记的天空。
	assert_false(SharedSkyCatalog.is_known(UNKNOWN_SKY_ID))
	assert_not_null(_record(SKY_ENTITY_ID, {"sky_id": UNKNOWN_SKY_ID}))


func test_environment_needs_no_transform() -> void:
	# 天空不是摆在格子上的东西。带 transform 也不会被读，缺 transform 不算错。
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record(SKY_ENTITY_ID, {"sky_id": 0})))
	assert_eq(world.entity_count(), 1)


# 3. Bundle wire：解码接受任何 >= 0，至多一个条目。

func test_bundle_round_trips_one_sky() -> void:
	var body: Dictionary = _body_with_sky(1)
	var bundle: SimulationBundle = SimulationBundle.from_dictionary(body)
	assert_not_null(bundle)
	assert_eq(bundle.environment.size(), 1)
	assert_eq(_int_at(bundle.environment[0], "entity_id"), SKY_ENTITY_ID)
	assert_eq(_int_at(bundle.environment[0], "sky_id"), 1)
	var encoded: Dictionary = bundle.to_dictionary()
	var restored: SimulationBundle = SimulationBundle.from_dictionary(encoded)
	assert_not_null(restored)
	assert_eq(_int_at(restored.environment[0], "sky_id"), 1)


func test_decode_accepts_a_sky_id_the_catalog_no_longer_knows() -> void:
	# 已发布内容必须按它发布时的形状裁决（ADR-0006 §1.4）。目录之后改了、
	# 老内容就开不起来，是这条门禁分工要避免的事。
	var bundle: SimulationBundle = SimulationBundle.from_dictionary(_body_with_sky(UNKNOWN_SKY_ID))
	assert_not_null(bundle)
	assert_eq(_int_at(bundle.environment[0], "sky_id"), UNKNOWN_SKY_ID)


func test_decode_rejects_two_skies_and_malformed_entries() -> void:
	var two: Dictionary = _empty_body()
	two[SimulationBundle.FIELD_ENVIRONMENT] = [
		{"entity_id": SKY_ENTITY_ID, "sky_id": 0},
		{"entity_id": SKY_ENTITY_ID + 1, "sky_id": 1},
	]
	assert_null(SimulationBundle.from_dictionary(two))
	assert_null(_decode_entry({"entity_id": SKY_ENTITY_ID, "sky_id": 0, "asset_id": 1}))
	assert_null(_decode_entry({"entity_id": SKY_ENTITY_ID}))
	assert_null(_decode_entry({"sky_id": 0}))
	assert_null(_decode_entry({"entity_id": 0, "sky_id": 0}))
	assert_null(_decode_entry({"entity_id": SKY_ENTITY_ID, "sky_id": -1}))
	var wrong_type: Dictionary = _empty_body()
	wrong_type[SimulationBundle.FIELD_ENVIRONMENT] = {"sky_id": 0}
	assert_null(SimulationBundle.from_dictionary(wrong_type))


func test_wire_without_the_key_still_decodes() -> void:
	# 已发布内容回归：不带该键的 v2 wire 与空数组等价。
	var bundle: SimulationBundle = SimulationBundle.from_dictionary(_empty_body())
	assert_not_null(bundle)
	assert_eq(bundle.environment.size(), 0)


func test_to_dictionary_omits_an_empty_sky_bag() -> void:
	var without: SimulationBundle = SimulationBundle.from_dictionary(_empty_body())
	assert_not_null(without)
	var bare: Dictionary = without.to_dictionary()
	assert_false(bare.has(SimulationBundle.FIELD_ENVIRONMENT))
	assert_eq(bare.size(), WIRE_KEYS_WITHOUT_SKY)
	var with_sky: SimulationBundle = SimulationBundle.from_dictionary(_body_with_sky(0))
	assert_not_null(with_sky)
	var full: Dictionary = with_sky.to_dictionary()
	assert_true(full.has(SimulationBundle.FIELD_ENVIRONMENT))
	assert_eq(full.size(), WIRE_KEYS_WITHOUT_SKY + 1)


# 3b. ContentHash：本刀真正会砸到已发布内容的那条链路。

func test_content_hash_of_content_published_before_this_chapter_is_unchanged() -> void:
	# 开局时 `match_session_bootstrap` 用 `ContentSign.hash_hex(bundle)` **重算**
	# `content_hash`，`content_catalog.open_*` 拿它与签名时那个值比对，不等就
	# `REASON_HASH_MISMATCH` 拒开局。所以「加了第 23 个袋」一旦改变任何已发布内容
	# 的哈希，那份内容就再也开不起来（宪法第六条）。
	#
	# 「发布于本刀之前」在这里的具体形状 = 一份**不带** `environment` 键的 26 键
	# v2 wire；官方课编译出来正好是这个形状。它逐字节不变由
	# `test_bastion_blueprint_contract.gd` 的 `COURSE_01_BUNDLE_DIGEST` 钉住，本条
	# 不复制那个常量，只证明「解码 → 再编码 → 再哈希」这条路径保住了它。
	var published: Dictionary = _compile_course_01().to_dictionary()
	assert_false(published.has(SimulationBundle.FIELD_ENVIRONMENT))
	assert_eq(published.size(), WIRE_KEYS_WITHOUT_SKY)
	var published_hash: String = _digest_of(published)
	assert_true(ContentSign.hex_ok(published_hash))

	var decoded: SimulationBundle = SimulationBundle.from_dictionary(published)
	assert_not_null(decoded)
	assert_eq(decoded.environment.size(), 0)
	assert_eq(ContentSign.hash_hex(decoded), published_hash)

	# 显式写了空数组的 wire 必须算出同一个哈希，否则「省略 == 空数组」只在解码侧
	# 成立、在哈希侧不成立，而后者才是开局门禁读的那个数。
	var explicit_empty: Dictionary = published.duplicate(true)
	explicit_empty[SimulationBundle.FIELD_ENVIRONMENT] = []
	var from_empty: SimulationBundle = SimulationBundle.from_dictionary(explicit_empty)
	assert_not_null(from_empty)
	assert_eq(ContentSign.hash_hex(from_empty), published_hash)

	# 反面。没有这一条，上面三条可以靠「哈希恒定」这种假绿一起通过。
	var skied: SimulationBundle = SimulationBundle.from_dictionary(_course_01_with_sky(1))
	assert_not_null(skied)
	assert_ne(ContentSign.hash_hex(skied), published_hash)


func test_a_course_that_picks_a_sky_still_hashes_and_opens() -> void:
	# `environment` 是 v2 wire 里第一个「空时省略」的袋，所以它要走两条此前没人
	# 走过的路：`CanonicalPayload.is_allowed` 认不认这个袋（不认就 `hash_failed`，
	# 选了天空的内容永远开不起来），以及开局重算的哈希是否等于签名时那个值。
	var bundle: SimulationBundle = SimulationBundle.from_dictionary(_course_01_with_sky(1))
	assert_not_null(bundle)
	var signed_hash: String = ContentSign.hash_hex(bundle)
	assert_true(ContentSign.hex_ok(signed_hash), "带天空的 bundle 必须能算出哈希")
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle, 1, 1, _spawn_offsets(1), PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session, "带天空的官方课必须能开局")
	assert_eq(session.content_hash, signed_hash)


# 4. 编译：这里**是**发布门禁，所以查目录。

func test_course_01_compiles_without_the_sky_key() -> void:
	# 官方课没选天空，所以编译产物与本刀之前逐字节一致。金标断言在
	# test_bastion_blueprint_contract.gd，这里只钉住它成立的那条性质。
	var bundle: SimulationBundle = _compile_course_01()
	assert_not_null(bundle)
	assert_eq(bundle.environment.size(), 0)
	var encoded: Dictionary = bundle.to_dictionary()
	assert_false(encoded.has(SimulationBundle.FIELD_ENVIRONMENT))
	assert_eq(encoded.size(), WIRE_KEYS_WITHOUT_SKY)


func test_compiler_emits_the_bag_for_a_legal_sky() -> void:
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_world_with_sky(1))
	assert_not_null(bundle)
	assert_eq(bundle.environment.size(), 1)
	assert_eq(_int_at(bundle.environment[0], "entity_id"), SKY_ENTITY_ID)
	assert_eq(_int_at(bundle.environment[0], "sky_id"), 1)
	# 天空没有几何，所以不注册资产，也不进任何占用袋。
	assert_eq(bundle.assets.size(), 0)
	assert_eq(bundle.solids.size(), 0)
	assert_eq(bundle.to_dictionary().size(), WIRE_KEYS_WITHOUT_SKY + 1)


func test_compiler_rejects_an_unregistered_sky_id() -> void:
	assert_null(TraprushTopologyCompiler.compile(_world_with_sky(UNKNOWN_SKY_ID)))


func test_compiler_rejects_two_environment_entities() -> void:
	var world: AuthoringWorld = _world_with_sky(0)
	assert_true(world.put(_record(SKY_ENTITY_ID + 1, {"sky_id": 1})))
	assert_null(TraprushTopologyCompiler.compile(world))


func _record(entity_id: int, body: Dictionary) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		SharedComponentNames.ENVIRONMENT: body,
	})


func _world_with_sky(sky_id: int) -> AuthoringWorld:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = _record(SKY_ENTITY_ID, {"sky_id": sky_id})
	assert_not_null(record)
	assert_true(world.put(record))
	return world


func _empty_body() -> Dictionary:
	return {
		SimulationBundle.FIELD_SCHEMA_VERSION: SimulationBundle.SCHEMA_VERSION,
		SimulationBundle.FIELD_CELL: CELL,
		SimulationBundle.FIELD_SOURCE_REVISION: 0,
		SimulationBundle.FIELD_ASSETS: [],
		SimulationBundle.FIELD_PADS: [],
		SimulationBundle.FIELD_PORTALS: [],
		SimulationBundle.FIELD_FINISH: [],
		SimulationBundle.FIELD_DESTRUCTIBLES: [],
		SimulationBundle.FIELD_HAZARDS: [],
		SimulationBundle.FIELD_SOLIDS: [],
		SimulationBundle.FIELD_PICKUPS: [],
	}


func _body_with_sky(sky_id: int) -> Dictionary:
	var body: Dictionary = _empty_body()
	body[SimulationBundle.FIELD_ENVIRONMENT] = [
		{"entity_id": SKY_ENTITY_ID, "sky_id": sky_id},
	]
	return body


func _decode_entry(entry: Dictionary) -> SimulationBundle:
	var body: Dictionary = _empty_body()
	body[SimulationBundle.FIELD_ENVIRONMENT] = [entry]
	return SimulationBundle.from_dictionary(body)


func _compile_course_01() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	return TraprushTopologyCompiler.compile(world)


## 官方课的 wire 加一片天。作者侧的 `.json` 不动——本刀没给官方课选天空，
## 改它会让金标 `COURSE_01_BUNDLE_DIGEST` 变色。
func _course_01_with_sky(sky_id: int) -> Dictionary:
	var body: Dictionary = _compile_course_01().to_dictionary()
	body[SimulationBundle.FIELD_ENVIRONMENT] = [
		{"entity_id": SKY_ENTITY_ID, "sky_id": sky_id},
	]
	return body


func _spawn_offsets(count: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for index: int in range(count):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	return offsets


## 与 `ContentSign.hash_bundle` 用的是同一个规范编码器，但喂的是**编译产物**那份
## dict；上面的断言比的是它与「解码再编码」那份是否逐字节相同，所以不是同义反复。
func _digest_of(body: Dictionary) -> String:
	var hasher: StateHasher = StateHasher.new()
	assert_true(hasher.write_canonical(body))
	return hasher.digest_hex()


func _int_at(body: Dictionary, key: String) -> int:
	var value: Variant = body.get(key, null)
	if typeof(value) != TYPE_INT:
		return -1
	return value
