extends GutTest

## slow 层：官方赛道在权威仿真上「走得通」的搜索类断言。
##
## 这里的每一条都要在 `SimulationWorld` 上跑一次完整的 `CourseCompletionProbe`
## 搜索。分层的时候它们占整套 GUT 的六成以上（course_03 单次约 77 秒），所以单独
## 拿出来，好让本地日常循环可以 `npm run test:gut:fast` 跳过这一层。
##
## **它们仍然是每次 PR 的门禁**（`ci.yml` 的 `godot` job 跑四个目录）。分层是为了
## 本地能少跑一层，不是为了把哪一层挪出合并门禁——2026-09-01 的定点数快路径把这
## 一层压到 7 秒之后，更没有理由挪。口径见 CD-53 §4.1。
##
## 用例逐条从 unit 层搬来，断言一条没改，只是换了目录。出处标在每个函数上，
## 因为「为什么这条不在它该在的文件里」是读代码时第一个会问的问题。
##
## 便宜的断言**没有**跟着搬走：沿路地板数量、必经格有支撑、待机不复位、走路
## 不掉、走下路面才复位这些仍留在 `tests/unit/test_traprush_official_path_floors.gd`，
## 它们是 C3 的核心玩法保证，必须留在每次 PR 的门禁里。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const CourseProbeCache := preload("res://tests/support/course_probe_cache.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const COURSE_02: String = "res://content/official/traprush/course_02.json"
const COURSE_03: String = "res://content/official/traprush/course_03.json"
const SHORTCUT_PORTAL: int = 10


## 原 `tests/unit/test_traprush_official_path_floors.gd`（纠偏 C3 第 2 章）。
func test_official_courses_are_completable_on_the_authority() -> void:
	_assert_completable(COURSE_01)
	_assert_completable(COURSE_02)
	_assert_completable(COURSE_03)


## 原 `tests/unit/test_traprush_course_completion_probe.gd`（纠偏 C2 第 1 章）。
func test_official_course_01_is_completable() -> void:
	var result: Dictionary = CourseProbeCache.run_path(COURSE_01)
	var outcome: String = result["outcome"]
	var accepted: int = result["accepted"]
	var checkpoints: int = result["checkpoints"]
	var steps: int = result["steps"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE)
	assert_eq(accepted, checkpoints)
	assert_gt(steps, 0)


## 原 `tests/unit/test_traprush_course_completion_probe.gd`（纠偏 C2 第 1 章）。
func test_reported_route_replays_to_a_finish() -> void:
	var result: Dictionary = CourseProbeCache.run_path(COURSE_01)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE)
	var actions: Array = result["actions"]
	var bundle: SimulationBundle = _compile(COURSE_01)
	assert_not_null(bundle)
	var replay: Dictionary = CourseCompletionProbe.try_replay(bundle, actions)
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_true(ok, reason)
	var finish_tick: int = replay["finish_tick"]
	var replay_accepted: int = replay["accepted"]
	var replay_checkpoints: int = replay["checkpoints"]
	assert_true(finish_tick >= 0, "finish_tick=%d" % finish_tick)
	assert_eq(replay_accepted, replay_checkpoints)


## 原 `tests/unit/test_traprush_semantic_course.gd`（纠偏 C3 第 5 章）。
## 默认探针仍走 +X 捷径；封掉 entity 10 的安全路由由下一条覆盖。
func test_bot_still_completes_on_the_authority() -> void:
	var result: Dictionary = CourseProbeCache.run_path(COURSE_01)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(COURSE_01), actions)
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_true(ok, reason)
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)
	assert_lte(actions.size(), 12)


## 原 `tests/unit/test_traprush_course_routes.gd`（纠偏 C3 第 7 章）。
func test_course_01_safe_script_finishes_without_shortcut_portal() -> void:
	var forbid: PackedInt32Array = PackedInt32Array([SHORTCUT_PORTAL])
	var result: Dictionary = CourseProbeCache.run_path(
		COURSE_01,
		CourseCompletionProbe.SAFE_ROUTE_MAX_TICKS,
		CourseCompletionProbe.DEFAULT_MAX_DEPTH,
		forbid,
		CourseCompletionProbe.ACTION_SET_CARDINAL,
		CourseCompletionProbe.course_01_safe_cardinal()
	)
	var outcome: String = result["outcome"]
	var reason: String = result.get("reason", "")
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, reason)
	var steps: int = result["steps"]
	assert_gte(steps, 20)
	var forbid_view: Array = result["forbid_portals"]
	assert_eq(forbid_view, [SHORTCUT_PORTAL])
	var bundle: SimulationBundle = _compile(COURSE_01)
	assert_not_null(bundle)
	var filtered: SimulationBundle = CourseCompletionProbe.without_portals(bundle, forbid)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(filtered, actions)
	var replay_ok: bool = replay["ok"]
	assert_true(replay_ok, str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func _assert_completable(path: String) -> void:
	var result: Dictionary = CourseProbeCache.run_path(path)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, path)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(path), actions)
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_true(ok, "%s %s" % [path, reason])
	var finish_tick: int = replay["finish_tick"]
	assert_true(finish_tick >= 0, "%s finish_tick=%d" % [path, finish_tick])


func _compile(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle
