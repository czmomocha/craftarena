class_name BastionFrameSnapshot
extends RefCounted

## BASTION 快照帧（v1 / type=6）。拆出来只为让 `BastionFrameCodec` 低于 E9 400 行。
## 公开入口仍是 `BastionFrameCodec.encode_snapshot` / `decode_snapshot`。
##
## `[version:u8=1][type:u8=6][tick:s64][phase:u8][wave_index:s64][result:u8]
## [team_count:u8]`，随后每队按 team_id 升序：
## team_id u8 + core_health/gold/leaked/kills s64×4 + locked u8 +
## tower_count u8 + 每塔 26 字节 + unit_count u8 + 每单位 48 字节 +
## obstacle_count u8 + 每障碍 17 字节。
##
## **裁剪是编码器的义务，不是调用方的礼貌。** 互设障碍阶段（phase=1）必须带
## 观察者 team_id，对方的障碍袋写成 count=0；缺观察者则整帧拒绝，防止误广播。
## 离开该阶段之后观察者被忽略，双方障碍都下发，同一逻辑帧恒得同一字节。

const Priorities := preload("res://src/shared/schema/tower_target_priorities.gd")

const PROTOCOL_VERSION: int = 1
const FRAME_SNAPSHOT: int = 6
const HEADER_SIZE: int = 21
const TOWER_SIZE: int = 26
const UNIT_SIZE: int = 48
const OBSTACLE_SIZE: int = 17
const PHASE_SETUP: int = 1
const PHASE_MAX: int = 4


static func encode(
	tick: int,
	phase: int,
	wave_index: int,
	result: int,
	teams: Array[Dictionary],
	viewer_team_id: int
) -> PackedByteArray:
	if phase < 0 or phase > PHASE_MAX or result < 0 or result > 255:
		return PackedByteArray()
	if teams.size() > 255:
		return PackedByteArray()
	if phase == PHASE_SETUP and not _viewer_is_present(teams, viewer_team_id):
		return PackedByteArray()
	var ordered: Array[Dictionary] = _sorted_teams(teams)
	var size: int = HEADER_SIZE
	for team: Dictionary in ordered:
		var piece: int = _team_size(phase, viewer_team_id, team)
		if piece < 0:
			return PackedByteArray()
		size += piece
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	bytes.encode_u8(0, PROTOCOL_VERSION)
	bytes.encode_u8(1, FRAME_SNAPSHOT)
	bytes.encode_s64(2, tick)
	bytes.encode_u8(10, phase)
	bytes.encode_s64(11, wave_index)
	bytes.encode_u8(19, result)
	bytes.encode_u8(20, ordered.size())
	var offset: int = HEADER_SIZE
	for team: Dictionary in ordered:
		offset = _write_team(bytes, offset, phase, viewer_team_id, team)
		if offset < 0:
			return PackedByteArray()
	return bytes


static func decode(bytes: PackedByteArray) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bytes.size() < HEADER_SIZE:
		return failed
	if bytes.decode_u8(0) != PROTOCOL_VERSION:
		return failed
	if bytes.decode_u8(1) != FRAME_SNAPSHOT:
		return failed
	var team_count: int = bytes.decode_u8(20)
	var teams: Array[Dictionary] = []
	var offset: int = HEADER_SIZE
	for _index: int in range(team_count):
		var parsed: Dictionary = _read_team(bytes, offset)
		if parsed.is_empty():
			return failed
		var team: Dictionary = parsed["team"]
		var next_offset: int = parsed["offset"]
		teams.append(team)
		offset = next_offset
	if offset != bytes.size():
		return failed
	return {
		"ok": true,
		"tick": bytes.decode_s64(2),
		"phase": bytes.decode_u8(10),
		"wave_index": bytes.decode_s64(11),
		"result": bytes.decode_u8(19),
		"teams": teams,
	}


static func _sorted_teams(teams: Array[Dictionary]) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []
	for team: Dictionary in teams:
		ordered.append(team)
	for index: int in range(ordered.size()):
		var best: int = index
		for other: int in range(index + 1, ordered.size()):
			var other_id: int = _int_of(ordered[other], "team_id")
			var best_id: int = _int_of(ordered[best], "team_id")
			if other_id < best_id:
				best = other
		if best != index:
			var swap: Dictionary = ordered[index]
			ordered[index] = ordered[best]
			ordered[best] = swap
	return ordered


static func _viewer_is_present(teams: Array[Dictionary], viewer_team_id: int) -> bool:
	for team: Dictionary in teams:
		if _int_of(team, "team_id") == viewer_team_id:
			return true
	return false


static func _visible_obstacles(
	phase: int, viewer_team_id: int, team_id: int, obstacles: Array
) -> Array:
	if phase == PHASE_SETUP and team_id != viewer_team_id:
		return []
	return obstacles


static func _team_size(phase: int, viewer_team_id: int, team: Dictionary) -> int:
	var towers: Array = _array_of(team, "towers")
	var units: Array = _array_of(team, "units")
	var obstacles: Array = _visible_obstacles(
		phase, viewer_team_id, _int_of(team, "team_id"), _array_of(team, "obstacles")
	)
	if towers.size() > 255 or units.size() > 255 or obstacles.size() > 255:
		return -1
	return (
		37
		+ towers.size() * TOWER_SIZE
		+ units.size() * UNIT_SIZE
		+ obstacles.size() * OBSTACLE_SIZE
	)


static func _write_team(
	bytes: PackedByteArray, offset: int, phase: int, viewer_team_id: int, team: Dictionary
) -> int:
	var team_id: int = _int_of(team, "team_id")
	if team_id < 1 or team_id > 255:
		return -1
	var towers: Array = _array_of(team, "towers")
	var units: Array = _array_of(team, "units")
	var obstacles: Array = _visible_obstacles(
		phase, viewer_team_id, team_id, _array_of(team, "obstacles")
	)
	bytes.encode_u8(offset, team_id)
	bytes.encode_s64(offset + 1, _int_of(team, "core_health"))
	bytes.encode_s64(offset + 9, _int_of(team, "gold"))
	bytes.encode_s64(offset + 17, _int_of(team, "leaked"))
	bytes.encode_s64(offset + 25, _int_of(team, "kills"))
	bytes.encode_u8(offset + 33, _int_of(team, "locked"))
	bytes.encode_u8(offset + 34, towers.size())
	offset += 35
	for item: Variant in towers:
		var tower: Dictionary = item
		var priority_code: int = _priority_id(_string_of(tower, "target_priority"))
		if priority_code < 1:
			return -1
		var level: int = _int_of(tower, "level")
		if level < 1 or level > 255:
			return -1
		bytes.encode_s64(offset, _int_of(tower, "slot_id"))
		bytes.encode_s64(offset + 8, _int_of(tower, "prototype_id"))
		bytes.encode_u8(offset + 16, level)
		bytes.encode_u8(offset + 17, priority_code)
		bytes.encode_s64(offset + 18, _int_of(tower, "cooldown_left"))
		offset += TOWER_SIZE
	bytes.encode_u8(offset, units.size())
	offset += 1
	for item: Variant in units:
		var unit: Dictionary = item
		bytes.encode_s64(offset, _int_of(unit, "unit_id"))
		bytes.encode_s64(offset + 8, _int_of(unit, "prototype_id"))
		bytes.encode_s64(offset + 16, _int_of(unit, "health"))
		bytes.encode_s64(offset + 24, _int_of(unit, "x"))
		bytes.encode_s64(offset + 32, _int_of(unit, "y"))
		bytes.encode_s64(offset + 40, _int_of(unit, "z"))
		offset += UNIT_SIZE
	bytes.encode_u8(offset, obstacles.size())
	offset += 1
	for item: Variant in obstacles:
		var obstacle: Dictionary = item
		bytes.encode_s64(offset, _int_of(obstacle, "node_id"))
		bytes.encode_s64(offset + 8, _int_of(obstacle, "prototype_id"))
		bytes.encode_u8(offset + 16, team_id)
		offset += OBSTACLE_SIZE
	return offset


static func _read_team(bytes: PackedByteArray, offset: int) -> Dictionary:
	if offset + 35 > bytes.size():
		return {}
	var team_id: int = bytes.decode_u8(offset)
	var tower_count: int = bytes.decode_u8(offset + 34)
	var cursor: int = offset + 35
	if cursor + tower_count * TOWER_SIZE + 1 > bytes.size():
		return {}
	var towers: Array[Dictionary] = []
	for _tower_i: int in range(tower_count):
		var priority_name: String = _priority_name(bytes.decode_u8(cursor + 17))
		if priority_name.is_empty():
			return {}
		towers.append({
			"slot_id": bytes.decode_s64(cursor),
			"prototype_id": bytes.decode_s64(cursor + 8),
			"level": bytes.decode_u8(cursor + 16),
			"target_priority": priority_name,
			"cooldown_left": bytes.decode_s64(cursor + 18),
		})
		cursor += TOWER_SIZE
	var unit_count: int = bytes.decode_u8(cursor)
	cursor += 1
	if cursor + unit_count * UNIT_SIZE + 1 > bytes.size():
		return {}
	var units: Array[Dictionary] = []
	for _unit_i: int in range(unit_count):
		units.append({
			"unit_id": bytes.decode_s64(cursor),
			"prototype_id": bytes.decode_s64(cursor + 8),
			"health": bytes.decode_s64(cursor + 16),
			"x": bytes.decode_s64(cursor + 24),
			"y": bytes.decode_s64(cursor + 32),
			"z": bytes.decode_s64(cursor + 40),
		})
		cursor += UNIT_SIZE
	var obstacle_count: int = bytes.decode_u8(cursor)
	cursor += 1
	if cursor + obstacle_count * OBSTACLE_SIZE > bytes.size():
		return {}
	var obstacles: Array[Dictionary] = []
	for _obs_i: int in range(obstacle_count):
		obstacles.append({
			"node_id": bytes.decode_s64(cursor),
			"prototype_id": bytes.decode_s64(cursor + 8),
			"team_id": bytes.decode_u8(cursor + 16),
		})
		cursor += OBSTACLE_SIZE
	return {
		"offset": cursor,
		"team": {
			"team_id": team_id,
			"core_health": bytes.decode_s64(offset + 1),
			"gold": bytes.decode_s64(offset + 9),
			"leaked": bytes.decode_s64(offset + 17),
			"kills": bytes.decode_s64(offset + 25),
			"locked": bytes.decode_u8(offset + 33),
			"towers": towers,
			"units": units,
			"obstacles": obstacles,
		},
	}


static func _int_of(body: Dictionary, key: String) -> int:
	if not body.has(key):
		return 0
	var value: int = body[key]
	return value


static func _string_of(body: Dictionary, key: String) -> String:
	if not body.has(key):
		return ""
	var value: String = body[key]
	return value


static func _array_of(body: Dictionary, key: String) -> Array:
	if not body.has(key):
		return []
	var value: Array = body[key]
	return value


static func _priority_id(priority: String) -> int:
	match priority:
		Priorities.FRONT:
			return 1
		Priorities.NEAREST:
			return 2
		Priorities.STRONGEST:
			return 3
		Priorities.WEAKEST:
			return 4
		_:
			return 0


static func _priority_name(priority_code: int) -> String:
	match priority_code:
		1:
			return Priorities.FRONT
		2:
			return Priorities.NEAREST
		3:
			return Priorities.STRONGEST
		4:
			return Priorities.WEAKEST
		_:
			return ""
