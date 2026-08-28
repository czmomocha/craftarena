class_name TraprushCourseCompletionProbe
extends RefCounted

## 走路可达探针：在权威仿真上真的走一遍，判定一张 TRAPRUSH 赛道能不能通关。
##
## 判定是**充分不必要**的，两个结论的强度差别很大：
##
## - `completable` 是硬结论。路线由真实的 TraprushMatchSession 走出来，动作序列
##   一并返回，可以照着重放。不是在几何图上推出来的。
## - `not_completable` 只说明「这个 bot 在给定动作集与预算内没走通」。`reason`
##   进一步区分：`search_exhausted` 是可达状态被穷尽（强证据，多半真的没路）；
##   `budget_exhausted` 是预算先用完（弱证据，只说明还没搜完）。
##
## **不要把 not_completable 读成「人也过不去」。** 动作集是离散的：8 向各走一整格、
## Jump、UseItem、原地等一 tick（等周期机关开）。人可以走半格、可以在下落途中转向，
## bot 不能。
##
## 检查点验收、传送落地与冲线都由会话自己在 commit_tick 里判定，探针不代劳，
## 所以它不会比真实对局宽松。动作数值来自 TraprushPlayStubs，与对局进程同一份。
##
## 搜索是 A*：g 为动作数，h 为到当前目标的格距，并允许经最多两次传送门中转。
## 一次中转覆盖 course_01 的 +X 捷径上楼；封掉 entity 10 之后要经侧向门再上楼，
## 两次中转才能估到上层检查点。跨楼层的直线格距不算能走——占位跳跃冲量不够
## 爬一整格，人要靠传送。h 不保证可采纳，找到的路线**不保证最短**，只保证真的
## 能走完。
##
## 会话没有快照/恢复 API，所以完整动作集的 A* 每次展开都从头重放。官方捷径
## 是个位数到十几步，这样比引入快照便宜。course_01 安全路大约三十步，A* 会
## 把预算烧光，所以 `--route=safe` 重放 C3 第 5 章已经走通的四向序列（与语义
## 测试 `_safe_moves` 相同），合成课没有这份序列时才走地面贪心。
##
## 可选 `forbid_portal_ids`：搜索前从 bundle 里拿掉这些传送源，启发式也不再经它们
## 中转。这不是改课。course_01 的 +X 捷径上楼 two_way 是 entity 10；拿掉它之后
## 探针必须走 C3 第 5 章那条更长的安全路。默认 `--bot-run` 不带这个约束，仍走捷径。
## `--route=safe` 的动作集不含 Jump。走下路面后第一拍 y 往往还在出生平面附近，
## 只按 y 剪枝拦不住。这种动作集里，脚下没有固体的状态不采纳。完整动作集仍要
## 保留空中态（跳跃弧）。
##
## 状态按四分之一格量化去重，并带上已验收检查点数、箱存活位图、机关固体位图
## 与爆破球/冲刺持有量。后几项不能省：省掉箱就无法表达「打开一条路」，省掉机关
## 就无法表达「等它开」，省掉道具持有量会把「用掉爆破球后的同格」当成已访问。
## 动作集不含 wait 时不把机关相位写入去重键：官方课 cooldown_ticks=1，每走一步
## 相位都翻，来回两格会被当成新状态。不含 Jump 时也不写入 y：落地归零之后 y 仍
## 可能略低于 0，换桶后同一格会被反复展开。这两种剪枝只作用于 `--route=safe`
## 这类地面搜索，完整动作集仍要靠 wait 等机关、靠 y 区分跳跃弧。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const OUTCOME_COMPLETABLE: String = "completable"
const OUTCOME_NOT_COMPLETABLE: String = "not_completable"
const OUTCOME_INVALID_COURSE: String = "invalid_course"

const REASON_SEARCH_EXHAUSTED: String = "search_exhausted"
const REASON_BUDGET_EXHAUSTED: String = "budget_exhausted"
const REASON_NO_FINISH: String = "no_finish"
const REASON_COMPILE_FAILED: String = "compile_failed"
const REASON_SESSION_FAILED: String = "session_failed"

const TARGET_CHECKPOINT: String = "checkpoint"
const TARGET_FINISH: String = "finish"

## 预算按**仿真 tick 数**算，因为钱就花在那里：开发机上一次整格移动约 27 ms
## （胶囊半径决定扫掠要走 8 步），一次 commit_tick 约 8 ms。会话没有恢复 API，
## 每次展开都要从头重放，成本随深度线性增长。
##
## 预算是探针的诚实边界，不是产品参数。达到上限时结论降级为 budget_exhausted，
## 而不是谎报走不通。
const DEFAULT_MAX_TICKS: int = 3000
const DEFAULT_MAX_DEPTH: int = 48
## course_01 安全路大约三十步。默认 3000 tick 只够捷径；封掉 entity 10 之后
## 用这个预算。不是产品时长。
const SAFE_ROUTE_MAX_TICKS: int = 12000

## 启发式权重。W=1 的标准 A* 会公平地展开一大片「在空中飘」的状态，而每个状态
## 都要付一次重放。加权后搜索几乎直奔目标，展开数从几百降到十几；代价是路线
## 不再保证最短——本探针只回答能不能走通，不回答最快怎么走。
const _HEURISTIC_WEIGHT: int = 4
## 跨一整格楼层的直线惩罚。要大于官方课同层绕路，否则封掉捷径后门后
## 启发式仍会以为能飞到上层检查点。
const _FLOOR_HOPS: int = 32
## 搜索前落到立足面的最大空转 tick。不是产品落地时长。
const _SETTLE_MAX_TICKS: int = 24

const _MATCH_SEED: int = 1
## 去重粒度。下落让 y 连续漂移，不量化会让同一个落点被反复展开。
const _BUCKET: int = Fixed.SCALE / 4

const _ACTION_JUMP: int = 8
const _ACTION_USE_ITEM: int = 9
const _ACTION_WAIT: int = 10
const ACTION_SET_FULL: int = 11
## `--route=safe` 只用四向整格走。官方安全路不需要对角/跳/等；砍掉这些动作
## 是为了让三十步搜索在没有快照 API 时还能跑完，不是产品操作集。不含 Jump
## 时搜索会丢掉无立足面的状态，所以不能靠空中平移抄近路。
const ACTION_SET_CARDINAL: int = 4

const _DIR_X: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const _DIR_Z: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]
const _ACTION_NAMES: Array[String] = [
	"move+x",
	"move-x",
	"move+z",
	"move-z",
	"move+x+z",
	"move+x-z",
	"move-x+z",
	"move-x-z",
	"jump",
	"use_item",
	"wait",
]

## 与 C3 第 5 章 `test_traprush_semantic_course.gd` 的 `_safe_moves` 同一条四向路。
## `--route=safe` 在拿掉 entity 10 的 bundle 上重放这一串；能冲线就证明安全路
## 不依赖捷径门。不是搜索出来的，是那章已经走通的权威序列。
const COURSE_01_SAFE_CARDINAL: Array[int] = [
	0, 0,
	2, 2, 2, 2, 2,
	0, 0, 0, 0,
	3, 3, 3, 3, 3,
	0,
	3, 3,
	2, 2, 2, 2, 2, 2,
	0, 0, 0, 0,
]


static func course_01_safe_cardinal() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	for action: int in COURSE_01_SAFE_CARDINAL:
		packed.append(action)
	return packed


static func run_path(
	path: String,
	max_ticks: int = DEFAULT_MAX_TICKS,
	max_depth: int = DEFAULT_MAX_DEPTH,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
	action_count: int = ACTION_SET_FULL,
	hint_actions: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return _invalid(REASON_COMPILE_FAILED, forbid_portal_ids)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return _invalid(REASON_COMPILE_FAILED, forbid_portal_ids)
	return run_bundle(
		bundle, max_ticks, max_depth, forbid_portal_ids, action_count, hint_actions
	)


static func run_bundle(
	bundle: SimulationBundle,
	max_ticks: int = DEFAULT_MAX_TICKS,
	max_depth: int = DEFAULT_MAX_DEPTH,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
	action_count: int = ACTION_SET_FULL,
	hint_actions: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	if bundle == null:
		return _invalid(REASON_COMPILE_FAILED, forbid_portal_ids)
	if action_count < 1 or action_count > ACTION_SET_FULL:
		return _invalid(REASON_COMPILE_FAILED, forbid_portal_ids)
	var search: SimulationBundle = without_portals(bundle, forbid_portal_ids)
	if search.finish.is_empty():
		# 没有终点的课永远走不完，不必搜。
		return _not_completable(REASON_NO_FINISH, 0, {}, {}, 0, 0, forbid_portal_ids)
	var root: TraprushMatchSession = _fresh_session(search)
	if root == null:
		return _invalid(REASON_SESSION_FAILED, forbid_portal_ids)

	var pads: Array[Dictionary] = _ordered_pads(search)
	var finish: Dictionary = search.finish[0]
	var checkpoints: int = root.checkpoint_count()

	var after: PackedInt32Array = _remaining_chain(pads, finish, search)
	if not hint_actions.is_empty():
		var scripted: Dictionary = _play_scripted(
			search, hint_actions, checkpoints, max_ticks, forbid_portal_ids, action_count
		)
		var scripted_outcome: String = scripted.get("outcome", "")
		if scripted_outcome == OUTCOME_COMPLETABLE:
			return scripted
	if action_count <= ACTION_SET_CARDINAL:
		return _greedy_ground(
			search,
			pads,
			finish,
			after,
			checkpoints,
			max_ticks,
			max_depth,
			forbid_portal_ids,
			action_count
		)
	var nodes: Array[Dictionary] = [_node_from(root, PackedByteArray())]
	var buckets: Array[PackedInt32Array] = []
	_push(buckets, 0, _priority(nodes[0], pads, finish, after, search))
	var visited: Dictionary = {_state_key(root, search, action_count): true}
	var best: Dictionary = nodes[0]
	var expansions: int = 0
	var ticks_used: int = 0
	var reason: String = REASON_SEARCH_EXHAUSTED

	while true:
		var node_id: int = _pop_min(buckets)
		if node_id < 0:
			break
		var node: Dictionary = nodes[node_id]
		var actions: PackedByteArray = node["actions"]
		if actions.size() >= max_depth:
			continue
		expansions += 1

		for action: int in range(action_count):
			# 一次尝试要重放整条前缀再走一步，代价先算清楚再花。
			if ticks_used + actions.size() + 1 > max_ticks:
				reason = REASON_BUDGET_EXHAUSTED
				break
			var session: TraprushMatchSession = _replay(search, actions)
			ticks_used += actions.size()
			if session == null:
				continue
			if not _apply_action(session, action):
				continue
			ticks_used += 1
			var key: String = _state_key(session, search, action_count)
			if visited.has(key):
				continue
			visited[key] = true
			var next_actions: PackedByteArray = actions.duplicate()
			next_actions.append(action)
			var next: Dictionary = _node_from(session, next_actions)
			if session.player_finish_tick(0) >= 0:
				return _completable(
					next, checkpoints, expansions, ticks_used, forbid_portal_ids
				)
			if _skip_unsupported(session, action_count):
				continue
			if _is_better(next, best):
				best = next
			nodes.append(next)
			_push(buckets, nodes.size() - 1, _priority(next, pads, finish, after, search))

		if reason == REASON_BUDGET_EXHAUSTED:
			break

	var best_accepted: int = best["accepted"]
	var target: Dictionary = _target_for(best_accepted, pads, finish, checkpoints)
	return _not_completable(
		reason, checkpoints, best, target, expansions, ticks_used, forbid_portal_ids
	)


## 地面贪心：同一会话往前走，按启发式给四向排序。踩空或走回头则重放前缀撤销。
## 官方安全路是一条窄石路，启发式指向下一扇门时，死路（捷径固体格）排在后面，
## 不会先踩进去。没有快照，这比三十步 A* 从头重放便宜一个数量级。
static func _greedy_ground(
	bundle: SimulationBundle,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	checkpoints: int,
	max_ticks: int,
	max_depth: int,
	forbid_portal_ids: PackedInt32Array,
	action_count: int,
) -> Dictionary:
	var session: TraprushMatchSession = _fresh_session(bundle)
	if session == null:
		return _invalid(REASON_SESSION_FAILED, forbid_portal_ids)
	var ticks_used: int = 0
	ticks_used += _settle_to_floor(session)
	var path: PackedByteArray = PackedByteArray()
	var start: Dictionary = _node_from(session, path)
	if session.player_finish_tick(0) >= 0:
		return _completable(start, checkpoints, 0, ticks_used, forbid_portal_ids)
	var visited: Dictionary = {_state_key(session, bundle, action_count): true}
	var best: Dictionary = start
	var expansions: int = 0
	while path.size() < max_depth:
		if ticks_used + 1 > max_ticks:
			var budget_accepted: int = best["accepted"]
			var target: Dictionary = _target_for(
				budget_accepted, pads, finish, checkpoints
			)
			return _not_completable(
				REASON_BUDGET_EXHAUSTED,
				checkpoints,
				best,
				target,
				expansions,
				ticks_used,
				forbid_portal_ids
			)
		expansions += 1
		var ranked: PackedInt32Array = _rank_ground_actions(
			session, pads, finish, after, bundle, action_count
		)
		var stepped: bool = false
		for action: int in ranked:
			if ticks_used + path.size() + 1 > max_ticks:
				break
			var prefix: PackedByteArray = path.duplicate()
			if not _apply_action(session, action):
				continue
			ticks_used += 1
			var next_path: PackedByteArray = prefix.duplicate()
			next_path.append(action)
			var next: Dictionary = _node_from(session, next_path)
			if session.player_finish_tick(0) >= 0:
				return _completable(
					next, checkpoints, expansions, ticks_used, forbid_portal_ids
				)
			var key: String = _state_key(session, bundle, action_count)
			if visited.has(key) or _skip_unsupported(session, action_count):
				session = _replay(bundle, prefix)
				ticks_used += prefix.size()
				if session == null:
					return _invalid(REASON_SESSION_FAILED, forbid_portal_ids)
				continue
			visited[key] = true
			path = next_path
			if _is_better(next, best):
				best = next
			stepped = true
			break
		if not stepped:
			var stuck_accepted: int = best["accepted"]
			var stuck_target: Dictionary = _target_for(
				stuck_accepted, pads, finish, checkpoints
			)
			var reason: String = REASON_SEARCH_EXHAUSTED
			if ticks_used + 1 > max_ticks:
				reason = REASON_BUDGET_EXHAUSTED
			return _not_completable(
				reason,
				checkpoints,
				best,
				stuck_target,
				expansions,
				ticks_used,
				forbid_portal_ids
			)
	var depth_accepted: int = best["accepted"]
	var depth_target: Dictionary = _target_for(
		depth_accepted, pads, finish, checkpoints
	)
	return _not_completable(
		REASON_SEARCH_EXHAUSTED,
		checkpoints,
		best,
		depth_target,
		expansions,
		ticks_used,
		forbid_portal_ids
	)


## 出生点在 y=0，立足固体在下方。胶囊要先落下才站稳；半空时水平扫掠会卡住，
## 贪心四个方向都走不动。落地后本拍 y 不再变化就停。
static func _settle_to_floor(session: TraprushMatchSession) -> int:
	var used: int = 0
	while used < _SETTLE_MAX_TICKS:
		var before: Dictionary = session.player_pose(0)
		var before_y: int = before.get("y", 0)
		session.commit_tick()
		used += 1
		var after: Dictionary = session.player_pose(0)
		var after_y: int = after.get("y", 0)
		if after_y == before_y:
			break
	return used


## 照着已走通的四向序列在同一会话上重放。course_01 安全路用这条，避免无快照
## A* 在三十步上把预算烧光。动作越界或中途被拒就停，让调用方再走贪心。
static func _play_scripted(
	bundle: SimulationBundle,
	hint_actions: PackedByteArray,
	checkpoints: int,
	max_ticks: int,
	forbid_portal_ids: PackedInt32Array,
	action_count: int,
) -> Dictionary:
	var session: TraprushMatchSession = _fresh_session(bundle)
	if session == null:
		return _invalid(REASON_SESSION_FAILED, forbid_portal_ids)
	var path: PackedByteArray = PackedByteArray()
	var ticks_used: int = 0
	for action: int in hint_actions:
		if action < 0 or action >= action_count:
			break
		if ticks_used + 1 > max_ticks:
			break
		if not _apply_action(session, action):
			break
		path.append(action)
		ticks_used += 1
		if session.player_finish_tick(0) >= 0:
			return _completable(
				_node_from(session, path), checkpoints, path.size(), ticks_used, forbid_portal_ids
			)
	return _not_completable(
		REASON_SEARCH_EXHAUSTED,
		checkpoints,
		_node_from(session, path),
		{},
		path.size(),
		ticks_used,
		forbid_portal_ids
	)


static func _rank_ground_actions(
	session: TraprushMatchSession,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
	action_count: int,
) -> PackedInt32Array:
	var pose: Dictionary = session.player_pose(0)
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var accepted: int = session.player_accepted_count(0)
	var scored: Array[Dictionary] = []
	for action: int in range(action_count):
		var node: Dictionary = {
			"depth": 0,
			"x": x + _DIR_X[action] * Fixed.SCALE,
			"y": y,
			"z": z + _DIR_Z[action] * Fixed.SCALE,
			"accepted": accepted,
		}
		scored.append({
			"action": action,
			"pri": _priority(node, pads, finish, after, bundle),
		})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_pri: int = left["pri"]
		var right_pri: int = right["pri"]
		return left_pri < right_pri
	)
	var ranked: PackedInt32Array = PackedInt32Array()
	for item: Dictionary in scored:
		var action_id: int = item["action"]
		ranked.append(action_id)
	return ranked


## 照着 completable 给出的动作序列重走一遍。
##
## 探针的结论之所以算数，是因为它可以被独立复验：同一个 bundle、同一串动作，
## 谁跑都该冲线。工具侧用它复核自己的输出，测试用它证明路线不是编出来的。
static func try_replay(bundle: SimulationBundle, action_names: Array) -> Dictionary:
	var session: TraprushMatchSession = _fresh_session(bundle)
	if session == null:
		return {"ok": false, "reason": REASON_SESSION_FAILED}
	for raw: Variant in action_names:
		var action_name: String = str(raw)
		var index: int = _ACTION_NAMES.find(action_name)
		if index < 0:
			return {"ok": false, "reason": "unknown_action:%s" % action_name}
		if not _apply_action(session, index):
			return {"ok": false, "reason": "rejected:%s" % action_name}
	return {
		"ok": true,
		"reason": "",
		"finish_tick": session.player_finish_tick(0),
		"accepted": session.player_accepted_count(0),
		"checkpoints": session.checkpoint_count(),
		"ticks": session.tick_index(),
	}


## 已验收 accepted 个检查点时，下一个要够到的东西在哪。
static func _target_for(
	accepted: int,
	pads: Array[Dictionary],
	finish: Dictionary,
	checkpoints: int,
) -> Dictionary:
	if accepted < checkpoints and accepted >= 0 and accepted < pads.size():
		var pad: Dictionary = pads[accepted]
		return {
			"kind": TARGET_CHECKPOINT,
			"x": pad.get("x", 0),
			"y": pad.get("y", 0),
			"z": pad.get("z", 0),
		}
	return {
		"kind": TARGET_FINISH,
		"x": finish.get("x", 0),
		"y": finish.get("y", 0),
		"z": finish.get("z", 0),
	}


static func _priority(
	node: Dictionary,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
) -> int:
	var g: int = node["depth"]
	return g + _HEURISTIC_WEIGHT * _heuristic(node, pads, finish, after, bundle)


## 估计还要走多少步：先到下一个检查点，再顺着剩下的检查点链走到终点。
##
## 「剩下的链」这一项不能省。只估到下一个检查点的话，每验收一个检查点 h 都会
## 突然变大（目标换成了更远的下一个），f 随之跳升，A* 就掉头回去啃旧分支——
## 实测正是这样卡在 course_01 的第二个检查点上的。带上链长以后，进度前进会让
## h 减少一整段，f 单调下降，搜索才会一路往前。
static func _heuristic(
	node: Dictionary,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
) -> int:
	var x: int = node["x"]
	var y: int = node["y"]
	var z: int = node["z"]
	var accepted: int = node["accepted"]
	if accepted >= 0 and accepted < pads.size():
		var pad: Dictionary = pads[accepted]
		var pad_x: int = pad.get("x", 0)
		var pad_y: int = pad.get("y", 0)
		var pad_z: int = pad.get("z", 0)
		return _hop_distance(x, y, z, pad_x, pad_y, pad_z, bundle) + after[accepted]
	var finish_x: int = finish.get("x", 0)
	var finish_y: int = finish.get("y", 0)
	var finish_z: int = finish.get("z", 0)
	return _hop_distance(x, y, z, finish_x, finish_y, finish_z, bundle)


## 沿检查点链走到终点还剩多少步。after[i] 是「刚够到 pads[i] 之后」的剩余量，
## after[n] = 0 表示检查点都齐了，只差终点。
static func _remaining_chain(
	pads: Array[Dictionary],
	finish: Dictionary,
	bundle: SimulationBundle,
) -> PackedInt32Array:
	var count: int = pads.size()
	var after: PackedInt32Array = PackedInt32Array()
	after.resize(count + 1)
	after[count] = 0
	var finish_x: int = finish.get("x", 0)
	var finish_y: int = finish.get("y", 0)
	var finish_z: int = finish.get("z", 0)
	var index: int = count - 1
	while index >= 0:
		var pad: Dictionary = pads[index]
		var pad_x: int = pad.get("x", 0)
		var pad_y: int = pad.get("y", 0)
		var pad_z: int = pad.get("z", 0)
		if index == count - 1:
			after[index] = _hop_distance(
				pad_x, pad_y, pad_z, finish_x, finish_y, finish_z, bundle
			)
		else:
			var next_pad: Dictionary = pads[index + 1]
			var next_x: int = next_pad.get("x", 0)
			var next_y: int = next_pad.get("y", 0)
			var next_z: int = next_pad.get("z", 0)
			var leg: int = _hop_distance(pad_x, pad_y, pad_z, next_x, next_y, next_z, bundle)
			after[index] = leg + after[index + 1]
		index -= 1
	return after


## 两点间格距，允许经最多两次传送门中转。跨一整格楼层的直线距离不算能走。
static func _hop_distance(
	x: int, y: int, z: int, tx: int, ty: int, tz: int, bundle: SimulationBundle
) -> int:
	var best: int = _cells_between(x, y, z, tx, ty, tz)
	for portal: Dictionary in bundle.portals:
		var via: int = _via_portal(x, y, z, tx, ty, tz, portal)
		if via < best:
			best = via
		var portal_id: int = portal.get("entity_id", 0)
		var entry_x: int = portal.get("x", 0)
		var entry_y: int = portal.get("y", 0)
		var entry_z: int = portal.get("z", 0)
		var dest_x: int = portal.get("dest_x", 0)
		var dest_y: int = portal.get("dest_y", 0)
		var dest_z: int = portal.get("dest_z", 0)
		for next_portal: Dictionary in bundle.portals:
			if next_portal.get("entity_id", 0) == portal_id:
				continue
			var next_entry_x: int = next_portal.get("x", 0)
			var next_entry_y: int = next_portal.get("y", 0)
			var next_entry_z: int = next_portal.get("z", 0)
			var next_dest_x: int = next_portal.get("dest_x", 0)
			var next_dest_y: int = next_portal.get("dest_y", 0)
			var next_dest_z: int = next_portal.get("dest_z", 0)
			var via_two: int = (
				_cells_between(x, y, z, entry_x, entry_y, entry_z)
				+ _cells_between(dest_x, dest_y, dest_z, next_entry_x, next_entry_y, next_entry_z)
				+ _cells_between(next_dest_x, next_dest_y, next_dest_z, tx, ty, tz)
			)
			if via_two < best:
				best = via_two
	return best


static func _via_portal(
	x: int, y: int, z: int, tx: int, ty: int, tz: int, portal: Dictionary
) -> int:
	var entry_x: int = portal.get("x", 0)
	var entry_y: int = portal.get("y", 0)
	var entry_z: int = portal.get("z", 0)
	var dest_x: int = portal.get("dest_x", 0)
	var dest_y: int = portal.get("dest_y", 0)
	var dest_z: int = portal.get("dest_z", 0)
	return (
		_cells_between(x, y, z, entry_x, entry_y, entry_z)
		+ _cells_between(dest_x, dest_y, dest_z, tx, ty, tz)
	)


## XZ 用 Chebyshev（对角一步同时走 x 与 z）。跨一整格楼层不能走：占位跳跃
## 冲量只有四分之一格，上楼必须经传送。
static func _cells_between(x: int, y: int, z: int, tx: int, ty: int, tz: int) -> int:
	var dx: int = absi(tx - x) / Fixed.SCALE
	var dy: int = absi(ty - y) / Fixed.SCALE
	var dz: int = absi(tz - z) / Fixed.SCALE
	var xz: int = maxi(dx, dz)
	if dy >= 1:
		return _FLOOR_HOPS + xz
	return xz


static func _apply_action(session: TraprushMatchSession, action: int) -> bool:
	if action == _ACTION_WAIT:
		session.commit_tick()
		return true
	var payload: Dictionary = {}
	if action == _ACTION_JUMP:
		payload = {"intent": PlayerIntentNames.JUMP}
	elif action == _ACTION_USE_ITEM:
		payload = {"intent": PlayerIntentNames.USE_ITEM}
	else:
		payload = {
			"intent": PlayerIntentNames.MOVE,
			"dx": _DIR_X[action] * Fixed.SCALE,
			"dz": _DIR_Z[action] * Fixed.SCALE,
		}
	if not session.apply_player_intent(0, payload):
		return false
	session.commit_tick()
	return true


static func _replay(bundle: SimulationBundle, actions: PackedByteArray) -> TraprushMatchSession:
	var session: TraprushMatchSession = _fresh_session(bundle)
	if session == null:
		return null
	for action: int in actions:
		if not _apply_action(session, action):
			return null
	return session


static func _fresh_session(bundle: SimulationBundle) -> TraprushMatchSession:
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		_MATCH_SEED,
		1,
		offsets,
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT,
	)
	if session == null:
		return null
	PlayStubs.apply_match(session)
	return session


## 不含 Jump 时丢掉无立足面的状态。走下石路后第一拍 y 常常还没掉到坑里，
## 但权威支撑查询已经是 false。完整动作集不能走这条：跳跃弧必须展开空中态。
static func _skip_unsupported(session: TraprushMatchSession, action_count: int) -> bool:
	if action_count > _ACTION_JUMP:
		return false
	return not session.player_supported_by_solid(0)


static func _node_from(session: TraprushMatchSession, actions: PackedByteArray) -> Dictionary:
	var pose: Dictionary = session.player_pose(0)
	return {
		"actions": actions,
		"depth": actions.size(),
		"x": pose.get("x", 0),
		"y": pose.get("y", 0),
		"z": pose.get("z", 0),
		"accepted": session.player_accepted_count(0),
		"tick": session.tick_index(),
	}


## 进度优先，其次少走几步。用来在没走通时报告「最远到过哪里」。
static func _is_better(candidate: Dictionary, best: Dictionary) -> bool:
	var candidate_accepted: int = candidate["accepted"]
	var best_accepted: int = best["accepted"]
	if candidate_accepted != best_accepted:
		return candidate_accepted > best_accepted
	var candidate_depth: int = candidate["depth"]
	var best_depth: int = best["depth"]
	return candidate_depth < best_depth


static func _state_key(
	session: TraprushMatchSession, bundle: SimulationBundle, action_count: int
) -> String:
	var pose: Dictionary = session.player_pose(0)
	var crates: int = 0
	var bit: int = 1
	for state: Dictionary in session.destructible_states():
		var durability: int = state.get("durability", 0)
		if durability > 0:
			crates |= bit
		bit <<= 1
	var hazards: int = 0
	if action_count > _ACTION_WAIT:
		bit = 1
		for hazard: Dictionary in bundle.hazards:
			var entity_id: int = hazard.get("entity_id", 0)
			if session.is_hazard_solid(entity_id):
				hazards |= bit
			bit <<= 1
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var y_bucket: int = 0
	if action_count > _ACTION_JUMP:
		y_bucket = _bucket(y)
	return "%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
		_bucket(x),
		y_bucket,
		_bucket(z),
		session.player_accepted_count(0),
		crates,
		hazards,
		session.player_bomb_count(0),
		session.player_dash_count(0),
		session.player_stun_remaining(0),
	]


## 向下取整的整数分桶。GDScript 的整数除法对负数向零截断，直接用会让
## -1 与 0 落进同一个桶，量化在原点两侧不对称。
static func _bucket(value: int) -> int:
	if value >= 0:
		return value / _BUCKET
	return -(((-value) + _BUCKET - 1) / _BUCKET)


static func _ordered_pads(bundle: SimulationBundle) -> Array[Dictionary]:
	var pads: Array[Dictionary] = bundle.pads.duplicate()
	pads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_order: int = a.get("order", 0)
		var b_order: int = b.get("order", 0)
		if a_order != b_order:
			return a_order < b_order
		var a_id: int = a.get("entity_id", 0)
		var b_id: int = b.get("entity_id", 0)
		return a_id < b_id
	)
	return pads


static func _push(buckets: Array[PackedInt32Array], node_id: int, priority: int) -> void:
	var slot: int = maxi(priority, 0)
	while buckets.size() <= slot:
		buckets.append(PackedInt32Array())
	var bucket: PackedInt32Array = buckets[slot]
	bucket.append(node_id)
	buckets[slot] = bucket


## 桶队列：优先级是小整数（动作数 + 格距），扫一遍桶比维护堆便宜也好读。
static func _pop_min(buckets: Array[PackedInt32Array]) -> int:
	for slot: int in range(buckets.size()):
		var bucket: PackedInt32Array = buckets[slot]
		if bucket.is_empty():
			continue
		var node_id: int = bucket[bucket.size() - 1]
		bucket.remove_at(bucket.size() - 1)
		buckets[slot] = bucket
		return node_id
	return -1


## 搜索约束：复制一份 bundle 并拿掉列出的传送源。原 bundle 不动。
## 不是改课。启发式与落地都只看见剩下的门。
static func without_portals(
	bundle: SimulationBundle,
	forbid_portal_ids: PackedInt32Array
) -> SimulationBundle:
	if forbid_portal_ids.is_empty():
		return bundle
	var deny: Dictionary = {}
	for entity_id: int in forbid_portal_ids:
		deny[entity_id] = true
	var filtered: SimulationBundle = SimulationBundle.new()
	filtered.cell = bundle.cell
	filtered.source_revision = bundle.source_revision
	filtered.pads = bundle.pads
	filtered.finish = bundle.finish
	filtered.destructibles = bundle.destructibles
	filtered.hazards = bundle.hazards
	filtered.solids = bundle.solids
	filtered.pickups = bundle.pickups
	var kept: Array[Dictionary] = []
	for portal: Dictionary in bundle.portals:
		var entity_id: int = portal.get("entity_id", 0)
		if deny.has(entity_id):
			continue
		kept.append(portal)
	filtered.portals = kept
	return filtered


static func _forbid_view(forbid_portal_ids: PackedInt32Array) -> Array:
	var listed: Array = []
	for entity_id: int in forbid_portal_ids:
		listed.append(entity_id)
	return listed


static func _completable(
	node: Dictionary,
	checkpoints: int,
	expansions: int,
	ticks_used: int,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
) -> Dictionary:
	var names: Array[String] = []
	for action: int in node["actions"]:
		names.append(_ACTION_NAMES[action])
	return {
		"outcome": OUTCOME_COMPLETABLE,
		"reason": "",
		"checkpoints": checkpoints,
		"accepted": node["accepted"],
		"ticks": node["tick"],
		"steps": node["depth"],
		"expansions": expansions,
		"search_ticks": ticks_used,
		"actions": names,
		"forbid_portals": _forbid_view(forbid_portal_ids),
	}


static func _not_completable(
	reason: String,
	checkpoints: int,
	best: Dictionary,
	target: Dictionary,
	expansions: int,
	ticks_used: int = 0,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
) -> Dictionary:
	var stuck: Dictionary = {}
	if not best.is_empty():
		stuck = {
			"x": best["x"],
			"y": best["y"],
			"z": best["z"],
			"target_kind": target.get("kind", TARGET_FINISH),
			"target_x": target.get("x", 0),
			"target_y": target.get("y", 0),
			"target_z": target.get("z", 0),
		}
	return {
		"outcome": OUTCOME_NOT_COMPLETABLE,
		"reason": reason,
		"checkpoints": checkpoints,
		"accepted": 0 if best.is_empty() else best["accepted"],
		"ticks": 0 if best.is_empty() else best["tick"],
		"steps": 0 if best.is_empty() else best["depth"],
		"expansions": expansions,
		"search_ticks": ticks_used,
		"stuck": stuck,
		"forbid_portals": _forbid_view(forbid_portal_ids),
	}


static func _invalid(
	reason: String,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
) -> Dictionary:
	return {
		"outcome": OUTCOME_INVALID_COURSE,
		"reason": reason,
		"checkpoints": 0,
		"accepted": 0,
		"ticks": 0,
		"steps": 0,
		"expansions": 0,
		"search_ticks": 0,
		"forbid_portals": _forbid_view(forbid_portal_ids),
	}
