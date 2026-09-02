class_name TraprushCourseProbeSearch
extends RefCounted

## A* expansion, scripted replay, and session helpers for the completion probe.
## Public run_path / run_bundle stay on the probe facade so this file stays under E9.

const HeuristicGd := preload("res://src/games/traprush/course_completion_probe_heuristic.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


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
		return TraprushCourseCompletionProbe._invalid(TraprushCourseCompletionProbe.REASON_SESSION_FAILED, forbid_portal_ids)
	var ticks_used: int = 0
	ticks_used += _settle_to_floor(session)
	var path: PackedByteArray = PackedByteArray()
	var start: Dictionary = _node_from(session, path)
	if session.player_finish_tick(0) >= 0:
		return TraprushCourseCompletionProbe._completable(start, checkpoints, 0, ticks_used, forbid_portal_ids)
	var visited: Dictionary = {_state_key(session, bundle, action_count): true}
	var best: Dictionary = start
	var expansions: int = 0
	while path.size() < max_depth:
		if ticks_used + 1 > max_ticks:
			var budget_accepted: int = best["accepted"]
			var target: Dictionary = HeuristicGd._target_for(
				budget_accepted, pads, finish, checkpoints
			)
			return TraprushCourseCompletionProbe._not_completable(
				TraprushCourseCompletionProbe.REASON_BUDGET_EXHAUSTED,
				checkpoints,
				best,
				target,
				expansions,
				ticks_used,
				forbid_portal_ids
			)
		expansions += 1
		var ranked: PackedInt32Array = HeuristicGd._rank_ground_actions(
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
				return TraprushCourseCompletionProbe._completable(
					next, checkpoints, expansions, ticks_used, forbid_portal_ids
				)
			var key: String = _state_key(session, bundle, action_count)
			if visited.has(key) or _skip_unsupported(session, action_count):
				session = _replay(bundle, prefix)
				ticks_used += prefix.size()
				if session == null:
					return TraprushCourseCompletionProbe._invalid(TraprushCourseCompletionProbe.REASON_SESSION_FAILED, forbid_portal_ids)
				continue
			visited[key] = true
			path = next_path
			if _is_better(next, best):
				best = next
			stepped = true
			break
		if not stepped:
			var stuck_accepted: int = best["accepted"]
			var stuck_target: Dictionary = HeuristicGd._target_for(
				stuck_accepted, pads, finish, checkpoints
			)
			var reason: String = TraprushCourseCompletionProbe.REASON_SEARCH_EXHAUSTED
			if ticks_used + 1 > max_ticks:
				reason = TraprushCourseCompletionProbe.REASON_BUDGET_EXHAUSTED
			return TraprushCourseCompletionProbe._not_completable(
				reason,
				checkpoints,
				best,
				stuck_target,
				expansions,
				ticks_used,
				forbid_portal_ids
			)
	var depth_accepted: int = best["accepted"]
	var depth_target: Dictionary = HeuristicGd._target_for(
		depth_accepted, pads, finish, checkpoints
	)
	return TraprushCourseCompletionProbe._not_completable(
		TraprushCourseCompletionProbe.REASON_SEARCH_EXHAUSTED,
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
	while used < TraprushCourseCompletionProbe._SETTLE_MAX_TICKS:
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
		return TraprushCourseCompletionProbe._invalid(TraprushCourseCompletionProbe.REASON_SESSION_FAILED, forbid_portal_ids)
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
			return TraprushCourseCompletionProbe._completable(
				_node_from(session, path), checkpoints, path.size(), ticks_used, forbid_portal_ids
			)
	return TraprushCourseCompletionProbe._not_completable(
		TraprushCourseCompletionProbe.REASON_SEARCH_EXHAUSTED,
		checkpoints,
		_node_from(session, path),
		{},
		path.size(),
		ticks_used,
		forbid_portal_ids
	)


static func _apply_action(session: TraprushMatchSession, action: int) -> bool:
	if action == TraprushCourseCompletionProbe._ACTION_WAIT:
		session.commit_tick()
		return true
	var payload: Dictionary = {}
	if action == TraprushCourseCompletionProbe._ACTION_JUMP:
		payload = {"intent": PlayerIntentNames.JUMP}
	elif action == TraprushCourseCompletionProbe._ACTION_USE_ITEM:
		payload = {"intent": PlayerIntentNames.USE_ITEM}
	else:
		payload = {
			"intent": PlayerIntentNames.MOVE,
			"dx": TraprushCourseCompletionProbe._DIR_X[action] * Fixed.SCALE,
			"dz": TraprushCourseCompletionProbe._DIR_Z[action] * Fixed.SCALE,
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
		TraprushCourseCompletionProbe._MATCH_SEED,
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
	if action_count > TraprushCourseCompletionProbe._ACTION_JUMP:
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
	if action_count > TraprushCourseCompletionProbe._ACTION_WAIT:
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
	if action_count > TraprushCourseCompletionProbe._ACTION_JUMP:
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
		return value / TraprushCourseCompletionProbe._BUCKET
	return -(((-value) + TraprushCourseCompletionProbe._BUCKET - 1) / TraprushCourseCompletionProbe._BUCKET)


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
