class_name TraprushMatchSession
extends RefCounted

## TRAPRUSH 对局会话：一份编译拓扑装进共享权威 SimulationWorld，1~8 名玩家。
## 依据 CD-21 §4.2/§6/§8 与 CD-43 §3.1：检查点与冲线由服务端占用判定，
## 客户端不得发送完成断言。每玩家独立 CheckpointTrack / finish_tick /
## 传送门闩；可破坏箱全员共享（一人破坏，全员可走）。
## 出生偏移、跳跃/支撑/道具伤害与触达数值由调用方传入，不锁产品数值。
## 语义与 AuthoringPreview 试玩逐字对齐：同一 IntentStepper、同一占用扫描
## 顺序（垫→门→垫→终点）。无网络、无结算、不在线写入。
## 直播名次由 TraprushStanding 从 accepted_count / finish_tick 派生；
## 本会话仍不写结算。路径距离排序仍待。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const DestructibleBreak := preload("res://src/games/traprush/destructible_break.gd")
const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")
const TopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")
const TraprushDestructible := preload("res://src/games/traprush/destructible.gd")
const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")

const MAX_PLAYERS: int = 8

var jump_dy: int = 0
var support_dy: int = 0
var use_item_damage: int = 0
var use_item_reach_dx: int = 0
var use_item_reach_dy: int = 0
var use_item_reach_dz: int = 0

var _world: SimulationWorld = null
var _graph: TraprushPortalGraph = null
var _pad_ids: Dictionary = {}
var _portal_ids: Dictionary = {}
var _finish_ids: Dictionary = {}
var _crate_ids: Dictionary = {}
var _crate_health: Dictionary = {}
var _spawn: CheckpointSpawn = null
var _ordered_ids: PackedInt32Array = PackedInt32Array()
var _players: Array[Dictionary] = []


static func create(
	bundle: SimulationBundle,
	seed: int,
	count: int,
	spawn_offsets: Array,
	radius: int,
	cylinder_height: int
) -> TraprushMatchSession:
	if bundle == null:
		return null
	if count < 1 or count > MAX_PLAYERS:
		return null
	if spawn_offsets.size() < count:
		return null
	if radius < 1 or cylinder_height < 1:
		return null
	var loaded: Dictionary = TopologyLoader.try_load(bundle, seed)
	if not loaded.get("ok", false):
		return null
	var ordered: PackedInt32Array = _ordered_checkpoint_ids(bundle)
	var start: Dictionary = _start_pose_from_bundle(bundle)
	if start.is_empty():
		return null
	var spawn: CheckpointSpawn = _spawn_from_bundle(bundle, ordered, start)
	if spawn == null:
		return null
	var session: TraprushMatchSession = TraprushMatchSession.new()
	session._world = loaded["world"]
	session._graph = loaded["graph"]
	session._pad_ids = loaded["pad_ids"]
	session._portal_ids = loaded["portal_ids"]
	session._finish_ids = loaded["finish_ids"]
	session._crate_ids = loaded["destructible_ids"]
	session._crate_health = _destructible_ledgers(bundle)
	session._spawn = spawn
	session._ordered_ids = ordered
	var start_x: int = start["x"]
	var start_y: int = start["y"]
	var start_z: int = start["z"]
	for slot: int in range(count):
		var offset_raw: Variant = spawn_offsets[slot]
		if typeof(offset_raw) != TYPE_DICTIONARY:
			return null
		var offset: Dictionary = offset_raw
		var pose: Dictionary = _offset_pose(start_x, start_y, start_z, offset)
		if pose.is_empty():
			return null
		var pose_x: int = pose["x"]
		var pose_y: int = pose["y"]
		var pose_z: int = pose["z"]
		var capsule_id: int = session._world.spawn_capsule(
			pose_x, pose_y, pose_z, 0, radius, cylinder_height
		)
		if capsule_id < 1:
			return null
		session._players.append({
			"capsule_id": capsule_id,
			"track": CheckpointTrack.new(ordered),
			"finish_tick": -1,
			"latch": {},
		})
	for player: Dictionary in session._players:
		session._accept_player_pads(player)
		session._resolve_player_portals(player)
		session._accept_player_finish(player)
	return session


func player_count() -> int:
	return _players.size()


func tick_index() -> int:
	if _world == null:
		return 0
	return _world.tick_index


func player_capsule_id(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return 0
	var capsule_id: int = player["capsule_id"]
	return capsule_id


func player_pose(slot: int) -> Dictionary:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return {}
	var capsule_id: int = player["capsule_id"]
	return _world.get_pose(capsule_id)


func player_accepted_count(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return 0
	var track: CheckpointTrack = player["track"]
	return track.completed_count()


func player_last_accepted_id(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return -1
	var track: CheckpointTrack = player["track"]
	return track.last_accepted_id()


func player_finish_tick(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return -1
	var finish_tick: int = player["finish_tick"]
	return finish_tick


func destructible_alive_count() -> int:
	var alive: int = 0
	for key: Variant in _crate_health.keys():
		var crate_raw: Variant = _crate_health[key]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		if not crate.is_destroyed():
			alive += 1
	return alive


## 快照用：全部可破坏箱的当前耐久（含已毁的 0），按 entity_id 升序。
func destructible_states() -> Array[Dictionary]:
	var ids: Array[int] = []
	for key: Variant in _crate_health.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	var states: Array[Dictionary] = []
	for crate_id: int in ids:
		var crate_raw: Variant = _crate_health[crate_id]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		states.append({"entity_id": crate_id, "durability": crate.current_health()})
	return states


func apply_player_intent(slot: int, payload: Dictionary) -> bool:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return false
	var use_decoded: Dictionary = UseItemIntent.decode(payload)
	var use_ok: bool = use_decoded.get("ok", false)
	if use_ok:
		return _try_use_item(player, payload)
	var move_decoded: Dictionary = MoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	var jump_decoded: Dictionary = JumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	var reset_ok: bool = CheckpointSpawn.is_reset_intent(payload)
	if not move_ok and not reset_ok and not jump_ok:
		return false
	var capsule_id: int = player["capsule_id"]
	if move_ok and _resolve_player_portals(player):
		return true
	var track: CheckpointTrack = player["track"]
	var stepped: Dictionary = IntentStepper.apply(
		_world,
		capsule_id,
		payload,
		jump_dy,
		_spawn,
		track,
		support_dy
	)
	var stepped_ok: bool = stepped.get("ok", false)
	if not stepped_ok:
		return false
	if reset_ok:
		player["latch"] = {}
	_accept_player_pads(player)
	_resolve_player_portals(player)
	_accept_player_pads(player)
	_accept_player_finish(player)
	return true


func commit_tick() -> void:
	if _world == null:
		return
	_world.tick()
	for player: Dictionary in _players:
		_accept_player_pads(player)
		_resolve_player_portals(player)
		_accept_player_pads(player)
		_accept_player_finish(player)


func hash_state() -> String:
	var hasher: StateHasher = StateHasher.new()
	if _world != null:
		hasher.write_string(_world.hash_state().hex_encode())
	for player: Dictionary in _players:
		var track: CheckpointTrack = player["track"]
		hasher.write_s64(track.completed_count())
		var finish_tick: int = player["finish_tick"]
		hasher.write_s64(finish_tick)
		var latch: Dictionary = player["latch"]
		var latched: Array[int] = []
		for key: Variant in latch.keys():
			if typeof(key) != TYPE_INT:
				continue
			var entity_id: int = key
			latched.append(entity_id)
		latched.sort()
		hasher.write_s64(latched.size())
		for entity_id: int in latched:
			hasher.write_s64(entity_id)
	return hasher.digest_hex()


func _player_at(slot: int) -> Dictionary:
	if slot < 0 or slot >= _players.size():
		return {}
	return _players[slot]


func _accept_player_pads(player: Dictionary) -> void:
	var track: CheckpointTrack = player["track"]
	var capsule_id: int = player["capsule_id"]
	for index: int in range(_ordered_ids.size()):
		var checkpoint_id: int = _ordered_ids[index]
		if not _pad_ids.has(checkpoint_id):
			continue
		var box_raw: Variant = _pad_ids[checkpoint_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var ok: bool = PadAccept.try_accept_on_pad(
			_world,
			capsule_id,
			track,
			checkpoint_id,
			box_id
		)
		if ok:
			_accept_player_finish(player)


func _resolve_player_portals(player: Dictionary) -> bool:
	if _graph == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var latch: Dictionary = player["latch"]
	var overlapping: Array[int] = []
	for key: Variant in _portal_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var box_raw: Variant = _portal_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		if _world.overlaps_static_box(capsule_id, box_id):
			overlapping.append(entity_id)
	overlapping.sort()
	var next_latch: Dictionary = {}
	for entity_id: int in overlapping:
		if latch.has(entity_id):
			next_latch[entity_id] = true
	player["latch"] = next_latch
	for entity_id: int in overlapping:
		if next_latch.has(entity_id):
			continue
		var landed: Dictionary = PortalLanding.try_land_exit(
			_world,
			capsule_id,
			_graph,
			entity_id
		)
		var land_ok: bool = landed.get("ok", false)
		if not land_ok:
			continue
		var did_land: bool = landed.get("landed", false)
		if not did_land:
			return true
		next_latch[entity_id] = true
		var dest_raw: Variant = landed.get("dest_id", 0)
		if typeof(dest_raw) == TYPE_INT:
			var dest_id: int = dest_raw
			if dest_id >= 1:
				next_latch[dest_id] = true
		_accept_player_pads(player)
		_accept_player_finish(player)
		return false
	return false


func _accept_player_finish(player: Dictionary) -> void:
	var finish_tick: int = player["finish_tick"]
	if finish_tick != -1:
		return
	var track: CheckpointTrack = player["track"]
	var capsule_id: int = player["capsule_id"]
	for key: Variant in _finish_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var box_raw: Variant = _finish_ids[key]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var crossed: Dictionary = FinishAccept.try_cross(
			_world,
			capsule_id,
			track,
			box_id
		)
		var crossed_ok: bool = crossed.get("ok", false)
		if crossed_ok:
			player["finish_tick"] = _world.tick_index
			return


func _try_use_item(player: Dictionary, payload: Dictionary) -> bool:
	var capsule_id: int = player["capsule_id"]
	var ids: Array[int] = []
	for key: Variant in _crate_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	for crate_id: int in ids:
		if not _crate_health.has(crate_id):
			continue
		var box_raw: Variant = _crate_ids[crate_id]
		var crate_raw: Variant = _crate_health[crate_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		if not (crate_raw is TraprushDestructible):
			continue
		var box_id: int = box_raw
		var crate: TraprushDestructible = crate_raw
		var broken: Dictionary = DestructibleBreak.try_use_item(
			_world,
			capsule_id,
			payload,
			crate,
			box_id,
			use_item_damage,
			use_item_reach_dx,
			use_item_reach_dy,
			use_item_reach_dz
		)
		var broken_ok: bool = broken.get("ok", false)
		if broken_ok:
			return true
	return false


static func _offset_pose(start_x: int, start_y: int, start_z: int, offset: Dictionary) -> Dictionary:
	if (
		not offset.has("dx")
		or not offset.has("dy")
		or not offset.has("dz")
	):
		return {}
	if (
		typeof(offset["dx"]) != TYPE_INT
		or typeof(offset["dy"]) != TYPE_INT
		or typeof(offset["dz"]) != TYPE_INT
	):
		return {}
	var dx: int = offset["dx"]
	var dy: int = offset["dy"]
	var dz: int = offset["dz"]
	var x_add: FixedResult = Fixed.try_add(start_x, dx)
	var y_add: FixedResult = Fixed.try_add(start_y, dy)
	var z_add: FixedResult = Fixed.try_add(start_z, dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
	}


static func _ordered_checkpoint_ids(bundle: SimulationBundle) -> PackedInt32Array:
	var pads: Array[Dictionary] = []
	for pad: Dictionary in bundle.pads:
		pads.append(pad)
	pads.sort_custom(_pad_order_less)
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(pads.size())
	for index: int in range(pads.size()):
		var pad: Dictionary = pads[index]
		var entity_id: int = pad["entity_id"]
		ids[index] = entity_id
	return ids


static func _pad_order_less(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = left["order"]
	var right_order: int = right["order"]
	if left_order != right_order:
		return left_order < right_order
	var left_id: int = left["entity_id"]
	var right_id: int = right["entity_id"]
	return left_id < right_id


static func _start_pose_from_bundle(bundle: SimulationBundle) -> Dictionary:
	var found: bool = false
	var best_order: int = 0
	var best_id: int = 0
	var best_x: int = 0
	var best_y: int = 0
	var best_z: int = 0
	var best_dx: int = 0
	var best_dy: int = 0
	var best_dz: int = 0
	for pad: Dictionary in bundle.pads:
		var entity_id: int = pad["entity_id"]
		var order: int = pad["order"]
		var pad_x: int = pad["x"]
		var pad_y: int = pad["y"]
		var pad_z: int = pad["z"]
		var dx: int = pad["respawn_dx"]
		var dy: int = pad["respawn_dy"]
		var dz: int = pad["respawn_dz"]
		if (
			not found
			or order < best_order
			or (order == best_order and entity_id < best_id)
		):
			found = true
			best_order = order
			best_id = entity_id
			best_x = pad_x
			best_y = pad_y
			best_z = pad_z
			best_dx = dx
			best_dy = dy
			best_dz = dz
	if not found:
		return {}
	var x_add: FixedResult = Fixed.try_add(best_x, best_dx)
	var y_add: FixedResult = Fixed.try_add(best_y, best_dy)
	var z_add: FixedResult = Fixed.try_add(best_z, best_dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
	}


static func _spawn_from_bundle(
	bundle: SimulationBundle,
	ordered: PackedInt32Array,
	start: Dictionary
) -> CheckpointSpawn:
	var start_pose: Dictionary = {
		"ok": true,
		"x": start["x"],
		"y": start["y"],
		"z": start["z"],
		"yaw_bam": 0,
	}
	var by_id: Dictionary = {}
	for pad: Dictionary in bundle.pads:
		var pad_id: int = pad["entity_id"]
		by_id[pad_id] = pad
	var poses: Array[Dictionary] = []
	for index: int in range(ordered.size()):
		var entity_id: int = ordered[index]
		if not by_id.has(entity_id):
			return null
		var pad_raw: Variant = by_id[entity_id]
		if typeof(pad_raw) != TYPE_DICTIONARY:
			return null
		var pad: Dictionary = pad_raw
		var pose: Dictionary = _respawn_pose(pad)
		if pose.is_empty():
			return null
		poses.append(pose)
	return CheckpointSpawn.new(start_pose, poses)


static func _respawn_pose(pad: Dictionary) -> Dictionary:
	if (
		not pad.has("x")
		or not pad.has("y")
		or not pad.has("z")
		or not pad.has("respawn_dx")
		or not pad.has("respawn_dy")
		or not pad.has("respawn_dz")
	):
		return {}
	if (
		typeof(pad["x"]) != TYPE_INT
		or typeof(pad["y"]) != TYPE_INT
		or typeof(pad["z"]) != TYPE_INT
		or typeof(pad["respawn_dx"]) != TYPE_INT
		or typeof(pad["respawn_dy"]) != TYPE_INT
		or typeof(pad["respawn_dz"]) != TYPE_INT
	):
		return {}
	var pad_x: int = pad["x"]
	var pad_y: int = pad["y"]
	var pad_z: int = pad["z"]
	var dx: int = pad["respawn_dx"]
	var dy: int = pad["respawn_dy"]
	var dz: int = pad["respawn_dz"]
	var x_add: FixedResult = Fixed.try_add(pad_x, dx)
	var y_add: FixedResult = Fixed.try_add(pad_y, dy)
	var z_add: FixedResult = Fixed.try_add(pad_z, dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"ok": true,
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
		"yaw_bam": 0,
	}


static func _destructible_ledgers(bundle: SimulationBundle) -> Dictionary:
	var ledgers: Dictionary = {}
	for item: Dictionary in bundle.destructibles:
		var crate_id: int = item["entity_id"]
		var durability: int = item["durability"]
		if durability < 1:
			continue
		var crate: TraprushDestructible = TraprushDestructible.create(durability)
		if crate == null:
			return {}
		ledgers[crate_id] = crate
	return ledgers
