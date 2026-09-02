class_name TraprushMatchSession
extends RefCounted

## TRAPRUSH 对局会话门面：一份编译拓扑装进共享权威 SimulationWorld，1~8 名玩家。
## 协作者是 TraprushMatchBootstrap / Intents / Scan / View，使本文件低于 E9 400 行。
## 依据 CD-21 §4.2/§6/§8 与 CD-43 §3.1：检查点与冲线由服务端占用判定。
## commit_tick 先积分再 world.tick（与灰盒相同）。MatchRealtime 在积分与
## world.tick 之间应用意图。周期机关在 world.tick() 之后切换固体。
## 占用扫描顺序：垫→门→垫→终点。无网络、无结算、不在线写入。
## 公开 API 仍在本门面上。

const Gravity := preload("res://src/games/traprush/gravity.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const TraprushMatchBootstrapGd := preload("res://src/games/traprush/match_session_bootstrap.gd")
const TraprushMatchIntentsGd := preload("res://src/games/traprush/match_session_intents.gd")
const TraprushMatchScanGd := preload("res://src/games/traprush/match_session_scan.gd")
const TraprushMatchViewGd := preload("res://src/games/traprush/match_session_view.gd")

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

var intents: TraprushMatchIntentsGd = TraprushMatchIntentsGd.new()
var scan: TraprushMatchScanGd = TraprushMatchScanGd.new()
var view: TraprushMatchViewGd = TraprushMatchViewGd.new()

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
var _spawn: TraprushCheckpointSpawn = null
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
	return TraprushMatchBootstrapGd.try_create(
		bundle, seed, count, spawn_offsets, radius, cylinder_height
	)


func player_count() -> int:
	return view.player_count(self)


func checkpoint_count() -> int:
	return view.checkpoint_count(self)


func tick_index() -> int:
	return view.tick_index(self)


func player_capsule_id(slot: int) -> int:
	return view.player_capsule_id(self, slot)


func player_pose(slot: int) -> Dictionary:
	return view.player_pose(self, slot)


func player_supported_by_solid(slot: int) -> bool:
	return view.player_supported_by_solid(self, slot)


func player_accepted_count(slot: int) -> int:
	return view.player_accepted_count(self, slot)


func player_last_accepted_id(slot: int) -> int:
	return view.player_last_accepted_id(self, slot)


func player_finish_tick(slot: int) -> int:
	return view.player_finish_tick(self, slot)


func player_bomb_count(slot: int) -> int:
	return view.player_bomb_count(self, slot)


func player_dash_count(slot: int) -> int:
	return view.player_dash_count(self, slot)


func player_stun_remaining(slot: int) -> int:
	return view.player_stun_remaining(self, slot)


func player_last_shove_tick(slot: int) -> int:
	return view.player_tick_field(self, slot, "last_shove_tick")


func player_last_use_item_tick(slot: int) -> int:
	return view.player_tick_field(self, slot, "last_use_item_tick")


func player_shoved_this_tick(slot: int) -> bool:
	return player_last_shove_tick(slot) == tick_index()


func player_broke_this_tick(slot: int) -> bool:
	return player_last_use_item_tick(slot) == tick_index()


func player_portal_latched(slot: int) -> bool:
	return view.player_portal_latched(self, slot)


func player_vy(slot: int) -> int:
	return view.player_vy(self, slot)


func player_airborne(slot: int) -> bool:
	return view.player_airborne(self, slot)


func destructible_alive_count() -> int:
	return view.destructible_alive_count(self)


func hazard_count() -> int:
	return view.hazard_count(self)


func is_hazard_solid(entity_id: int) -> bool:
	return view.is_hazard_solid(self, entity_id)


func destructible_states() -> Array[Dictionary]:
	return view.destructible_states(self)


func apply_player_intent(slot: int, payload: Dictionary) -> bool:
	return intents.apply(self, slot, payload)


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
	return view.hash_state(self)


func _player_at(slot: int) -> Dictionary:
	if slot < 0 or slot >= _players.size():
		return {}
	return _players[slot]


func _accept_player_pads(player: Dictionary) -> void:
	scan.accept_player_pads(self, player)


func _resolve_player_portals(player: Dictionary) -> bool:
	return scan.resolve_player_portals(self, player)


func _accept_player_finish(player: Dictionary) -> void:
	scan.accept_player_finish(self, player)


func _reset_player_if_out_of_range(player: Dictionary) -> bool:
	return scan.reset_player_if_out_of_range(self, player)


func _resolve_player_hazards(player: Dictionary) -> bool:
	return scan.resolve_player_hazards(self, player)


func _player_stunned(player: Dictionary) -> bool:
	return scan.player_stunned(player)


func _tick_stuns() -> void:
	scan.tick_stuns(self)


func _grant_player_pickups(player: Dictionary) -> void:
	scan.grant_player_pickups(self, player)
