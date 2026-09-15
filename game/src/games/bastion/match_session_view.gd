class_name BastionMatchSessionView
extends RefCounted

## 会话的只读视图：生成流水、存活单位位姿、权威状态哈希。拆出来只为让
## `BastionMatchSession` 低于 E9 400 行；公开 API 仍在会话门面。
##
## 哈希覆盖的范围就是这一号「什么算权威状态」的定义：tick、阶段、波次序号、
## 胜负、每队的核心血量 / 金币 / 漏怪数 / 击杀 / 完成击杀 tick / 本波已发赏金、
## 每座塔的槽位与等级与冷却与目标策略、每个已生效障碍、每只存活单位的位姿。
##
## 用 `StateHasher` 而不是 `Variant.hash()`：后者不保证版本间稳定，也不能进回放。

const WavesGd := preload("res://src/games/bastion/match_session_waves.gd")


static func spawn_log(session: BastionMatchSession, team_id: int) -> Array[Dictionary]:
	var team: Dictionary = session._team(team_id)
	var entries: Array[Dictionary] = []
	if team.is_empty() or not team.has("spawn_log"):
		return entries
	var records: Array = team["spawn_log"]
	for item: Variant in records:
		var record: Dictionary = item
		entries.append(record.duplicate(true))
	return entries


static func unit_states(session: BastionMatchSession, team_id: int) -> Array[Dictionary]:
	var team: Dictionary = session._team(team_id)
	var states: Array[Dictionary] = []
	if team.is_empty() or not team.has("leg_lengths"):
		return states
	var units: Array = team["units"]
	var path: PackedInt32Array = team["path"]
	var lengths: PackedInt64Array = team["leg_lengths"]
	for item: Variant in units:
		var unit: Dictionary = item
		var pose: Dictionary = WavesGd.position_of(unit, path, session._positions, lengths)
		states.append({
			"unit_id": unit["unit_id"],
			"prototype_id": unit["prototype_id"],
			"health": unit["health"],
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
		})
	return states


static func hash_state(session: BastionMatchSession) -> String:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(session.tick)
	hasher.write_s64(session.phase)
	hasher.write_s64(session.wave_index())
	hasher.write_s64(session.result)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = session._team(team_id)
		hasher.write_s64(team_id)
		for key: String in [
			"core_health", "gold", "leaked", "kills", "clear_tick", "wave_bounty"
		]:
			var scalar: int = team[key]
			hasher.write_s64(scalar)
		_feed_towers(hasher, team)
		_feed_obstacles(hasher, team)
		_feed_units(hasher, session, team_id)
	return hasher.digest_hex()


static func _feed_towers(hasher: StateHasher, team: Dictionary) -> void:
	var towers: Array = team["towers"]
	hasher.write_s64(towers.size())
	for item: Variant in towers:
		var tower: Dictionary = item
		for key: String in ["slot_id", "prototype_id", "level", "cooldown_left"]:
			var field: int = tower[key]
			hasher.write_s64(field)
		var priority: String = tower["target_priority"]
		hasher.write_string(priority)


static func _feed_obstacles(hasher: StateHasher, team: Dictionary) -> void:
	var obstacles: Array = team["obstacles"]
	hasher.write_s64(obstacles.size())
	for item: Variant in obstacles:
		var placement: Dictionary = item
		var node_id: int = placement["node_id"]
		var prototype_id: int = placement["prototype_id"]
		hasher.write_s64(node_id)
		hasher.write_s64(prototype_id)


static func _feed_units(
	hasher: StateHasher, session: BastionMatchSession, team_id: int
) -> void:
	var states: Array[Dictionary] = unit_states(session, team_id)
	hasher.write_s64(states.size())
	for state: Dictionary in states:
		for key: String in ["unit_id", "prototype_id", "health", "x", "y", "z"]:
			var field: int = state[key]
			hasher.write_s64(field)
