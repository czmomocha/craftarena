class_name TraprushMatchSession
extends RefCounted

## TRAPRUSH 对局会话：一份编译拓扑装进共享权威 SimulationWorld，1~8 名玩家。
## 依据 CD-21 §4.2/§6/§8 与 CD-43 §3.1：检查点与冲线由服务端占用判定，
## 客户端不得发送完成断言。每玩家独立 CheckpointTrack / finish_tick /
## 传送门闩；可破坏箱全员共享（一人破坏，全员可走）。
## 出生偏移、跳跃/支撑/道具伤害与触达数值由调用方传入，不锁产品数值。
## Move |dx|/|dz| 不得超过 MOVE_STEP_MAX（Fixed.SCALE，每命令一格）：超限整条
## 拒绝，不裁剪。这是防瞬移门禁，不是产品速度。Preview IntentStepper 不经此门。
## Shove 无线上目标 id：服务端在 SHOVE_REACH_MAX 邻域内选最近其它胶囊，沿 XZ
## 远离施术者用调用方 shove_step 推开。shove_step 不得超过 SHOVE_STEP_MAX。
## 冷却是调用方 tick，不是产品秒数。力度不从命令帧读取。
## UseItem 要有爆破球；Sprint 要有冲刺。拾取由服务端占用扫描授予，每种最多 1 个，
## 每个 pickup 实体每玩家只拾一次。命中只看调用方 reach，不读客户端命中断言。
## 冲刺沿胶囊 yaw 做 8 向水平位移，步长不得超过 SHOVE_STEP_MAX（与 Move 同一格上限）。
## 出界复位：range_enabled 时用调用方 AABB（闭区间）经 TraprushOutOfRangeReset
## 写回最近检查点落点。不计数 N。复位后写入调用方 respawn_stun_ticks（对局 /
## Solo 由 PlayStubs 注入 D5 1.0 s 换算 tick；Preview 仍是 1 次 Advance）。
## 不锁 CD-43 Tick Hz。默认关闭。
## 下落：调用方 fall_dy 是每 tick 重力加速度，经 TraprushGravity.integrate
## 写入胶囊 vy。默认 0（2 人 Headless 冲线夹具不走路板，不能默认下落）。
## commit_tick 先积分再 world.tick（与灰盒相同）。MatchRealtime 在积分与
## world.tick 之间应用意图，避免同一拍 Jump 被立刻落下。不锁产品重力。
## 周期机关：commit_tick 在 world.tick() 之后按已有 cooldown_ticks 切换固体。
## 意图不推进 tick，故不切换。不读 Authoring damage/knockback。固体半周期占用
## 重叠由 TraprushHazardHit 裁决：先注入击退，仍重叠则环境失败复位并写硬直。
## 语义与 AuthoringPreview 试玩逐字对齐：同一 IntentStepper、同一占用扫描
## 顺序（垫→门→垫→终点）。无网络、无结算、不在线写入。
## 直播名次由 TraprushStanding 从 accepted_count / finish_tick 派生。
## 全员冲线后可由 TraprushMatchSettlement 生成写库 payload；本会话不 HTTP。
## 路径距离排序仍待。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const DestructibleBreak := preload("res://src/games/traprush/destructible_break.gd")
const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const Gravity := preload("res://src/games/traprush/gravity.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const HazardHit := preload("res://src/games/traprush/hazard_hit.gd")
const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const ShoveApply := preload("res://src/games/traprush/shove_apply.gd")
const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")
const ShoveIntent := preload("res://src/games/traprush/shove_intent.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const PickupAccept := preload("res://src/games/traprush/pickup_accept.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const SprintApply := preload("res://src/games/traprush/sprint_apply.gd")
const SprintIntent := preload("res://src/games/traprush/sprint_intent.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")
const TopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")
const TraprushDestructible := preload("res://src/games/traprush/destructible.gd")
const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")

const MAX_PLAYERS: int = 8
## 每条 Move 命令每轴上限。等于 Fixed.SCALE（1 格）。不是产品速度。
const MOVE_STEP_MAX: int = Fixed.SCALE
## 每条 Shove 的调用方步长上限与选目标邻域。等于 Fixed.SCALE（1 格）。不是产品力度。
const SHOVE_STEP_MAX: int = Fixed.SCALE
const SHOVE_REACH_MAX: int = Fixed.SCALE
const SPRINT_STEP_MAX: int = Fixed.SCALE

var jump_dy: int = 0
var support_dy: int = 0
var fall_dy: int = 0
var use_item_damage: int = 0
var use_item_reach_dx: int = 0
var use_item_reach_dy: int = 0
var use_item_reach_dz: int = 0
var shove_step: int = 0
var shove_cooldown_ticks: int = 1
var sprint_step: int = 0
var item_cooldown_ticks: int = 1
var hazard_knockback_step: int = 0
var respawn_stun_ticks: int = 0
var range_enabled: bool = false
var range_min_x: int = 0
var range_max_x: int = 0
var range_min_y: int = 0
var range_max_y: int = 0
var range_min_z: int = 0
var range_max_z: int = 0

var _world: SimulationWorld = null
var _graph: TraprushPortalGraph = null
var _pad_ids: Dictionary = {}
var _portal_ids: Dictionary = {}
var _finish_ids: Dictionary = {}
var _crate_ids: Dictionary = {}
var _crate_health: Dictionary = {}
var _hazard_ids: Dictionary = {}
var _hazard_cycle: Array[Dictionary] = []
var _pickup_ids: Dictionary = {}
var _pickup_kinds: Dictionary = {}
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
	var hazards_raw: Variant = loaded.get("hazard_ids", {})
	if typeof(hazards_raw) != TYPE_DICTIONARY:
		return null
	var hazard_ids: Dictionary = hazards_raw
	var cycle: Array[Dictionary] = HazardCycle.entries_from(bundle.hazards, hazard_ids)
	if cycle.size() != bundle.hazards.size():
		return null
	session._hazard_ids = hazard_ids
	session._hazard_cycle = cycle
	var pickups_raw: Variant = loaded.get("pickup_ids", {})
	if typeof(pickups_raw) != TYPE_DICTIONARY:
		return null
	session._pickup_ids = pickups_raw
	session._pickup_kinds = _pickup_kinds_from_bundle(bundle)
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
			"last_shove_tick": -1,
			"last_use_item_tick": -1,
			"last_sprint_tick": -1,
			"bomb": 0,
			"dash": 0,
			"taken": {},
			"stun_remaining": 0,
		})
	for player: Dictionary in session._players:
		session._accept_player_pads(player)
		session._resolve_player_portals(player)
		session._accept_player_finish(player)
		session._grant_player_pickups(player)
	return session


func player_count() -> int:
	return _players.size()


func checkpoint_count() -> int:
	return _ordered_ids.size()


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


## 用本会话的 support_dy 问权威世界：这名玩家脚下现在有没有固体。
## 探针在不含 Jump 的动作集里用它丢掉坠落态；Jump 判定走同一条查询。
func player_supported_by_solid(slot: int) -> bool:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return false
	var capsule_id: int = player["capsule_id"]
	return _world.is_supported_by_solid(capsule_id, support_dy)


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


func player_bomb_count(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return 0
	var bomb: int = player.get("bomb", 0)
	return bomb


func player_dash_count(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return 0
	var dash: int = player.get("dash", 0)
	return dash


func player_stun_remaining(slot: int) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return 0
	var stun_raw: Variant = player.get("stun_remaining", 0)
	if typeof(stun_raw) != TYPE_INT:
		return 0
	var stun: int = stun_raw
	return stun


func player_last_shove_tick(slot: int) -> int:
	return _player_tick_field(slot, "last_shove_tick")


func player_last_use_item_tick(slot: int) -> int:
	return _player_tick_field(slot, "last_use_item_tick")


func player_shoved_this_tick(slot: int) -> bool:
	return player_last_shove_tick(slot) == tick_index()


func player_broke_this_tick(slot: int) -> bool:
	return player_last_use_item_tick(slot) == tick_index()


func player_portal_latched(slot: int) -> bool:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return false
	var latch_raw: Variant = player.get("latch", {})
	if typeof(latch_raw) != TYPE_DICTIONARY:
		return false
	var latch: Dictionary = latch_raw
	return not latch.is_empty()


func player_vy(slot: int) -> int:
	if _world == null:
		return 0
	var capsule_id: int = player_capsule_id(slot)
	if capsule_id < 1:
		return 0
	return _world.get_vy(capsule_id)


## 表现层用的空中判定。接触探针半格（占用盒顶到出生格面的空隙），
## 不用本会话 Jump 的 1 格 support_dy。
func player_airborne(slot: int) -> bool:
	if _world == null:
		return false
	var capsule_id: int = player_capsule_id(slot)
	if capsule_id < 1:
		return false
	return PlayAnimState.is_airborne(
		player_vy(slot),
		_world.is_supported_by_solid(capsule_id, PlayAnimState.CONTACT_DY)
	)


func _player_tick_field(slot: int, key: String) -> int:
	var player: Dictionary = _player_at(slot)
	if player.is_empty():
		return -1
	var raw: Variant = player.get(key, -1)
	if typeof(raw) != TYPE_INT:
		return -1
	var tick: int = raw
	return tick


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


func hazard_count() -> int:
	return _hazard_ids.size()


func is_hazard_solid(entity_id: int) -> bool:
	if _world == null or not _hazard_ids.has(entity_id):
		return false
	var box_raw: Variant = _hazard_ids[entity_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	return _world.is_static_box_solid(box_id)


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
	var reset_ok: bool = CheckpointSpawn.is_reset_intent(payload)
	if _player_stunned(player) and not reset_ok:
		return false
	var use_decoded: Dictionary = UseItemIntent.decode(payload)
	var use_ok: bool = use_decoded.get("ok", false)
	if use_ok:
		return _try_use_item(player, payload)
	var sprint_decoded: Dictionary = SprintIntent.decode(payload)
	var sprint_ok: bool = sprint_decoded.get("ok", false)
	if sprint_ok:
		return _try_sprint(player, payload)
	var shove_decoded: Dictionary = ShoveIntent.decode(payload)
	var shove_ok: bool = shove_decoded.get("ok", false)
	if shove_ok:
		return _try_shove(slot, player, payload)
	var move_decoded: Dictionary = MoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	if move_ok:
		var move_dx: int = move_decoded.get("dx", 0)
		var move_dz: int = move_decoded.get("dz", 0)
		if not move_step_allowed(move_dx, move_dz):
			return false
	var jump_decoded: Dictionary = JumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	if not move_ok and not reset_ok and not jump_ok:
		return false
	var capsule_id: int = player["capsule_id"]
	if move_ok and _resolve_player_portals(player):
		_resolve_player_hazards(player)
		_reset_player_if_out_of_range(player)
		_grant_player_pickups(player)
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
	_resolve_player_hazards(player)
	_reset_player_if_out_of_range(player)
	_accept_player_pads(player)
	_resolve_player_portals(player)
	_accept_player_pads(player)
	_accept_player_finish(player)
	_grant_player_pickups(player)
	return true


func apply_player_falls() -> void:
	if _world == null:
		return
	for player: Dictionary in _players:
		var capsule_id: int = player["capsule_id"]
		Gravity.integrate(_world, capsule_id, fall_dy)
		_resolve_player_hazards(player)
		_reset_player_if_out_of_range(player)


func advance_sim_tick() -> void:
	if _world == null:
		return
	_tick_stuns()
	_world.tick()
	HazardCycle.apply(_world, _hazard_cycle)
	for player: Dictionary in _players:
		_resolve_player_hazards(player)
		_reset_player_if_out_of_range(player)
		_accept_player_pads(player)
		_resolve_player_portals(player)
		_accept_player_pads(player)
		_accept_player_finish(player)
		_grant_player_pickups(player)


func commit_tick() -> void:
	apply_player_falls()
	advance_sim_tick()


func enable_play_range(half: int) -> void:
	if half < 1:
		range_enabled = false
		return
	range_enabled = true
	range_min_x = -half
	range_max_x = half
	range_min_y = -half
	range_max_y = half
	range_min_z = -half
	range_max_z = half


static func move_step_allowed(dx: int, dz: int) -> bool:
	if dx > MOVE_STEP_MAX or dx < -MOVE_STEP_MAX:
		return false
	if dz > MOVE_STEP_MAX or dz < -MOVE_STEP_MAX:
		return false
	return true


static func shove_step_allowed(step: int) -> bool:
	if step < 0:
		return false
	if step > SHOVE_STEP_MAX:
		return false
	return true


static func sprint_step_allowed(step: int) -> bool:
	if step < 0:
		return false
	if step > SPRINT_STEP_MAX:
		return false
	return true


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
		var last_shove_tick: int = player.get("last_shove_tick", -1)
		hasher.write_s64(last_shove_tick)
		var last_use_item_tick: int = player.get("last_use_item_tick", -1)
		hasher.write_s64(last_use_item_tick)
		var last_sprint_tick: int = player.get("last_sprint_tick", -1)
		hasher.write_s64(last_sprint_tick)
		var bomb: int = player.get("bomb", 0)
		hasher.write_s64(bomb)
		var dash: int = player.get("dash", 0)
		hasher.write_s64(dash)
		var taken: Dictionary = player.get("taken", {})
		var taken_ids: Array[int] = []
		for taken_key: Variant in taken.keys():
			if typeof(taken_key) != TYPE_INT:
				continue
			var taken_id: int = taken_key
			taken_ids.append(taken_id)
		taken_ids.sort()
		hasher.write_s64(taken_ids.size())
		for taken_id: int in taken_ids:
			hasher.write_s64(taken_id)
		var stun_raw: Variant = player.get("stun_remaining", 0)
		var stun: int = 0
		if typeof(stun_raw) == TYPE_INT:
			stun = stun_raw
		hasher.write_s64(stun)
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
		_grant_player_pickups(player)
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


func _try_shove(slot: int, player: Dictionary, payload: Dictionary) -> bool:
	if not shove_step_allowed(shove_step):
		return false
	if shove_cooldown_ticks < 1:
		return false
	var target_slot: int = _pick_shove_target_slot(slot)
	if target_slot < 0:
		return false
	var target: Dictionary = _player_at(target_slot)
	if target.is_empty():
		return false
	var actor_id: int = player["capsule_id"]
	var target_id: int = target["capsule_id"]
	var impulse: Dictionary = _shove_impulse(actor_id, target_id)
	if impulse.is_empty():
		return false
	var last_tick: int = player.get("last_shove_tick", -1)
	var now_tick: int = 0
	if _world != null:
		now_tick = _world.tick_index
	var impulse_dx: int = impulse["dx"]
	var impulse_dz: int = impulse["dz"]
	var result: Dictionary = ShoveApply.apply(
		_world,
		actor_id,
		target_id,
		payload,
		now_tick,
		last_tick,
		shove_cooldown_ticks,
		impulse_dx,
		impulse_dz
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var shoved: bool = result.get("shoved", false)
	if shoved:
		player["last_shove_tick"] = now_tick
		_resolve_player_hazards(target)
		_reset_player_if_out_of_range(target)
		_accept_player_pads(target)
		_resolve_player_portals(target)
		_accept_player_pads(target)
		_accept_player_finish(target)
		_grant_player_pickups(target)
	return true


func _pick_shove_target_slot(actor_slot: int) -> int:
	var actor_pose: Dictionary = player_pose(actor_slot)
	if actor_pose.is_empty():
		return -1
	var best_slot: int = -1
	var best_cheb: int = 0
	var best_man: int = 0
	for slot: int in range(player_count()):
		if slot == actor_slot:
			continue
		var pose: Dictionary = player_pose(slot)
		if pose.is_empty():
			continue
		var reach: Dictionary = _xz_delta(actor_pose, pose)
		if reach.is_empty():
			continue
		var dx: int = reach["dx"]
		var dy: int = reach["dy"]
		var dz: int = reach["dz"]
		if not _within_shove_reach(dx, dy, dz):
			continue
		var cheb: int = _chebyshev_xz(dx, dz)
		var man: int = _manhattan_xz(dx, dz)
		if best_slot < 0:
			best_slot = slot
			best_cheb = cheb
			best_man = man
			continue
		if cheb < best_cheb:
			best_slot = slot
			best_cheb = cheb
			best_man = man
			continue
		if cheb == best_cheb and man < best_man:
			best_slot = slot
			best_man = man
			continue
		if cheb == best_cheb and man == best_man and slot < best_slot:
			best_slot = slot
	return best_slot


func _shove_impulse(actor_id: int, target_id: int) -> Dictionary:
	if _world == null:
		return {}
	var actor_pose: Dictionary = _world.get_pose(actor_id)
	var target_pose: Dictionary = _world.get_pose(target_id)
	if actor_pose.is_empty() or target_pose.is_empty():
		return {}
	var reach: Dictionary = _xz_delta(actor_pose, target_pose)
	if reach.is_empty():
		return {}
	var dx_delta: int = reach["dx"]
	var dz_delta: int = reach["dz"]
	var dx: int = 0
	var dz: int = 0
	if dx_delta > 0:
		dx = shove_step
	elif dx_delta < 0:
		dx = -shove_step
	if dz_delta > 0:
		dz = shove_step
	elif dz_delta < 0:
		dz = -shove_step
	if dx == 0 and dz == 0 and shove_step != 0:
		return {}
	return {"dx": dx, "dz": dz}


static func _xz_delta(from_pose: Dictionary, to_pose: Dictionary) -> Dictionary:
	var from_x: int = from_pose.get("x", 0)
	var from_y: int = from_pose.get("y", 0)
	var from_z: int = from_pose.get("z", 0)
	var to_x: int = to_pose.get("x", 0)
	var to_y: int = to_pose.get("y", 0)
	var to_z: int = to_pose.get("z", 0)
	var sub_x: FixedResult = Fixed.try_sub(to_x, from_x)
	var sub_y: FixedResult = Fixed.try_sub(to_y, from_y)
	var sub_z: FixedResult = Fixed.try_sub(to_z, from_z)
	if not sub_x.ok or not sub_y.ok or not sub_z.ok:
		return {}
	return {"dx": sub_x.value, "dy": sub_y.value, "dz": sub_z.value}


static func _within_shove_reach(dx: int, dy: int, dz: int) -> bool:
	if dx > SHOVE_REACH_MAX or dx < -SHOVE_REACH_MAX:
		return false
	if dy > SHOVE_REACH_MAX or dy < -SHOVE_REACH_MAX:
		return false
	if dz > SHOVE_REACH_MAX or dz < -SHOVE_REACH_MAX:
		return false
	return true


static func _chebyshev_xz(dx: int, dz: int) -> int:
	var ax: int = dx
	if ax < 0:
		ax = -ax
	var az: int = dz
	if az < 0:
		az = -az
	if ax > az:
		return ax
	return az


static func _manhattan_xz(dx: int, dz: int) -> int:
	var ax: int = dx
	if ax < 0:
		ax = -ax
	var az: int = dz
	if az < 0:
		az = -az
	var sum: FixedResult = Fixed.try_add(ax, az)
	if not sum.ok:
		return SHOVE_REACH_MAX
	return sum.value


func _reset_player_if_out_of_range(player: Dictionary) -> bool:
	if not range_enabled:
		return false
	if _world == null or _spawn == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var track: CheckpointTrack = player["track"]
	var result: Dictionary = OutOfRangeReset.try_apply(
		_world,
		capsule_id,
		_spawn,
		track,
		range_min_y,
		range_max_y,
		range_min_x,
		range_max_x,
		range_min_z,
		range_max_z
	)
	var reset: bool = result.get("reset", false)
	if reset:
		player["latch"] = {}
		player["stun_remaining"] = respawn_stun_ticks
	return reset


func _resolve_player_hazards(player: Dictionary) -> bool:
	if _world == null or _spawn == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var track: CheckpointTrack = player["track"]
	var result: Dictionary = HazardHit.try_apply(
		_world,
		capsule_id,
		_hazard_cycle,
		hazard_knockback_step,
		_spawn,
		track
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var reset: bool = result.get("reset", false)
	if reset:
		player["latch"] = {}
		player["stun_remaining"] = respawn_stun_ticks
	return reset


func _player_stunned(player: Dictionary) -> bool:
	var stun_raw: Variant = player.get("stun_remaining", 0)
	if typeof(stun_raw) != TYPE_INT:
		return false
	var stun: int = stun_raw
	return stun > 0


func _tick_stuns() -> void:
	for player: Dictionary in _players:
		var stun_raw: Variant = player.get("stun_remaining", 0)
		if typeof(stun_raw) != TYPE_INT:
			continue
		var stun: int = stun_raw
		if stun < 1:
			continue
		player["stun_remaining"] = stun - 1


func _try_use_item(player: Dictionary, payload: Dictionary) -> bool:
	if item_cooldown_ticks < 1:
		return false
	var now_tick: int = 0
	if _world != null:
		now_tick = _world.tick_index
	var last_tick: int = player.get("last_use_item_tick", -1)
	if not ShoveGate.can_shove(now_tick, last_tick, item_cooldown_ticks):
		return true
	var bomb: int = player.get("bomb", 0)
	if bomb < 1:
		return false
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
			player["bomb"] = bomb - 1
			player["last_use_item_tick"] = now_tick
			return true
	return false


func _try_sprint(player: Dictionary, payload: Dictionary) -> bool:
	if not sprint_step_allowed(sprint_step):
		return false
	if item_cooldown_ticks < 1:
		return false
	var dash: int = player.get("dash", 0)
	if dash < 1:
		return false
	var capsule_id: int = player["capsule_id"]
	var last_tick: int = player.get("last_sprint_tick", -1)
	var now_tick: int = 0
	if _world != null:
		now_tick = _world.tick_index
	var result: Dictionary = SprintApply.apply(
		_world,
		capsule_id,
		payload,
		now_tick,
		last_tick,
		item_cooldown_ticks,
		sprint_step
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var sprinted: bool = result.get("sprinted", false)
	if sprinted:
		player["dash"] = dash - 1
		player["last_sprint_tick"] = now_tick
		_resolve_player_hazards(player)
		_reset_player_if_out_of_range(player)
		_accept_player_pads(player)
		_resolve_player_portals(player)
		_accept_player_pads(player)
		_accept_player_finish(player)
		_grant_player_pickups(player)
	return true


func _grant_player_pickups(player: Dictionary) -> void:
	var capsule_id: int = player["capsule_id"]
	var taken_raw: Variant = player.get("taken", {})
	var taken: Dictionary = {}
	if typeof(taken_raw) == TYPE_DICTIONARY:
		taken = taken_raw
	var bomb: int = player.get("bomb", 0)
	var dash: int = player.get("dash", 0)
	var granted: Dictionary = PickupAccept.try_grant(
		_world,
		capsule_id,
		_pickup_ids,
		_pickup_kinds,
		taken,
		bomb,
		dash
	)
	var granted_ok: bool = granted.get("ok", false)
	if not granted_ok:
		return
	var next_bomb_raw: Variant = granted.get("bomb", bomb)
	if typeof(next_bomb_raw) == TYPE_INT:
		player["bomb"] = next_bomb_raw
	var next_dash_raw: Variant = granted.get("dash", dash)
	if typeof(next_dash_raw) == TYPE_INT:
		player["dash"] = next_dash_raw
	var next_taken_raw: Variant = granted.get("taken", taken)
	if typeof(next_taken_raw) == TYPE_DICTIONARY:
		player["taken"] = next_taken_raw


static func _pickup_kinds_from_bundle(bundle: SimulationBundle) -> Dictionary:
	var kinds: Dictionary = {}
	if bundle == null:
		return kinds
	for item: Dictionary in bundle.pickups:
		var entity_id: int = item["entity_id"]
		var kind: String = item["kind"]
		kinds[entity_id] = kind
	return kinds


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
