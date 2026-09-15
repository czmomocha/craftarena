class_name BastionMatchSetupState
extends RefCounted

## 单局互设障碍产生的对局级状态（CD-22 §7.2 的 `MatchSetupState`）。
## **不是内容**：不进发布系统、不产生新版本、进入准备建造后冻结。
##
## 盲设只在本对象的只读视图上成立：`visible_placements(viewer)` 在揭示前只返回
## 观察者自己的 pending。权威哈希含双方 pending，否则回放对不上。协议层怎么把
## 对方布局藏住是 E1 / [CD-63 §1.6](Confirmed-docs/60-plan/63-open-decisions.md)，
## 本章一个字节都不碰。
##
## 提交时立即拒：非槽位、超预算、锁定后改动、未知原型。封路提案可以进 pending，
## 因为 pending 不是活图；揭示时整表重跑预算与 D2 可达性，非法放置 LIFO 撤销
## 并退还点数（CD-22 §4.1 第 6、7 步）。
##
## 布障命令进本对象自己的磁带，不走 `SharedCommand`：五个 BASTION 意图还没有
## 线上 id（E1），把准备阶段命令塞进 L0 信封等于提前发明协议。

const CatalogGd := preload("res://src/ugc/bastion_prototype_catalog.gd")
const GuardGd := preload("res://src/games/bastion/path_guard.gd")
const StubsGd := preload("res://src/games/bastion/play_stubs.gd")
const _Self := preload("res://src/games/bastion/match_setup_state.gd")

const KIND_PLACE: int = 1
const KIND_LOCK: int = 2
const KIND_TICK: int = 3

var points_budget: int = 0
var revealed: bool = false
var _battlefield_hash: String = ""
var _teams: Dictionary[int, Dictionary] = {}
var _commands: Array[Dictionary] = []


static func create(bundle: BastionBlueprintBundle) -> _Self:
	if bundle == null:
		return null
	var budget: int = bundle.economy_value("obstacle_points")
	if budget < 1:
		return null
	var state: _Self = _Self.new()
	state.points_budget = budget
	for team_id: int in BastionBlueprintBundle.TEAMS:
		state._teams[team_id] = {
			"locked": false,
			"pending": [],
			"committed": [],
			"spent": 0,
			"refunded": 0,
		}
	return state


func try_place(
	bundle: BastionBlueprintBundle, team_id: int, node_id: int, prototype_id: int, tick: int
) -> bool:
	if revealed:
		return false
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return false
	var locked: bool = team["locked"]
	if locked:
		return false
	if not CatalogGd.is_obstacle(prototype_id):
		return false
	var cost: int = StubsGd.obstacle_point_cost(prototype_id)
	if cost < 1:
		return false
	var spent: int = team["spent"]
	if spent + cost > points_budget:
		return false
	var pending: Array = team["pending"]
	var candidate: Dictionary = {"node_id": node_id, "prototype_id": prototype_id}
	if not GuardGd.slot_allows_placement(bundle, team_id, pending, candidate):
		return false
	pending.append(candidate)
	team["spent"] = spent + cost
	_append_command(KIND_PLACE, tick, team_id, node_id, prototype_id)
	return true


func try_lock(team_id: int, tick: int) -> bool:
	if revealed:
		return false
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return false
	var locked: bool = team["locked"]
	if locked:
		return false
	team["locked"] = true
	_append_command(KIND_LOCK, tick, team_id, 0, 0)
	return true


func record_tick(tick: int) -> void:
	if revealed:
		return
	_append_command(KIND_TICK, tick, 0, 0, 0)


func both_locked() -> bool:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = _team(team_id)
		var locked: bool = team["locked"]
		if not locked:
			return false
	return true


func is_locked(team_id: int) -> bool:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return false
	var locked: bool = team["locked"]
	return locked


## 揭示：把 pending 变成 committed，重跑预算与可达性，非法放置从尾部撤并退点。
func reveal(bundle: BastionBlueprintBundle) -> void:
	if revealed:
		return
	for team_id: int in BastionBlueprintBundle.TEAMS:
		_reveal_team(bundle, team_id)
	revealed = true
	_battlefield_hash = _hash_committed()


func points_spent(team_id: int) -> int:
	return _team_int(team_id, "spent")


func points_refunded(team_id: int) -> int:
	return _team_int(team_id, "refunded")


func points_left(team_id: int) -> int:
	return points_budget - points_spent(team_id)


## 权威侧看到的放置：揭示前是 pending，揭示后是 committed。
func authority_placements(team_id: int) -> Array[Dictionary]:
	var team: Dictionary = _team(team_id)
	var out: Array[Dictionary] = []
	if team.is_empty():
		return out
	var source: Array = team["committed"] if revealed else team["pending"]
	for item: Variant in source:
		var placement: Dictionary = item
		out.append(placement.duplicate(true))
	return out


## 观察者可见的放置。揭示前只有自己的 pending；揭示后是双方 committed。
func visible_placements(viewer_team_id: int) -> Array[Dictionary]:
	if not revealed:
		return authority_placements(viewer_team_id)
	var out: Array[Dictionary] = []
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = _team(team_id)
		var committed: Array = team["committed"]
		for item: Variant in committed:
			var placement: Dictionary = item
			var copy: Dictionary = placement.duplicate(true)
			copy["team_id"] = team_id
			out.append(copy)
	return out


func command_log() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in _commands:
		out.append(item.duplicate(true))
	return out


func command_count() -> int:
	return _commands.size()


func battlefield_hash() -> String:
	return _battlefield_hash


func hash_tape() -> String:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(points_budget)
	for item: Dictionary in _commands:
		hasher.write_s64(_int_of(item, "kind"))
		hasher.write_s64(_int_of(item, "tick"))
		hasher.write_s64(_int_of(item, "team_id"))
		hasher.write_s64(_int_of(item, "node_id"))
		hasher.write_s64(_int_of(item, "prototype_id"))
	return hasher.digest_hex()


func feed_hasher(hasher: StateHasher) -> void:
	hasher.write_s64(1 if revealed else 0)
	hasher.write_s64(points_budget)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		hasher.write_s64(team_id)
		hasher.write_s64(1 if is_locked(team_id) else 0)
		hasher.write_s64(points_spent(team_id))
		hasher.write_s64(points_refunded(team_id))
		var placements: Array[Dictionary] = authority_placements(team_id)
		hasher.write_s64(placements.size())
		for placement: Dictionary in placements:
			hasher.write_s64(_int_of(placement, "node_id"))
			hasher.write_s64(_int_of(placement, "prototype_id"))


func _reveal_team(bundle: BastionBlueprintBundle, team_id: int) -> void:
	var team: Dictionary = _team(team_id)
	team["locked"] = true
	var working: Array = []
	var pending: Array = team["pending"]
	for item: Variant in pending:
		var placement: Dictionary = item
		working.append(placement.duplicate(true))
	var refunded: int = 0
	while not _proposal_is_valid(bundle, team_id, working):
		if working.is_empty():
			break
		var last: Dictionary = working.pop_back()
		refunded += StubsGd.obstacle_point_cost(_int_of(last, "prototype_id"))
	team["committed"] = working
	team["pending"] = []
	team["spent"] = _cost_of(working)
	team["refunded"] = refunded


func _proposal_is_valid(bundle: BastionBlueprintBundle, team_id: int, working: Array) -> bool:
	if _cost_of(working) > points_budget:
		return false
	return GuardGd.lanes_are_open(bundle, team_id, working)


func _cost_of(working: Array) -> int:
	var total: int = 0
	for item: Variant in working:
		var placement: Dictionary = item
		total += StubsGd.obstacle_point_cost(_int_of(placement, "prototype_id"))
	return total


func _hash_committed() -> String:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(points_budget)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		hasher.write_s64(team_id)
		var team: Dictionary = _team(team_id)
		hasher.write_s64(_int_of(team, "spent"))
		hasher.write_s64(_int_of(team, "refunded"))
		var committed: Array = team["committed"]
		hasher.write_s64(committed.size())
		for item: Variant in committed:
			var placement: Dictionary = item
			hasher.write_s64(_int_of(placement, "node_id"))
			hasher.write_s64(_int_of(placement, "prototype_id"))
	return hasher.digest_hex()


func _append_command(
	kind: int, tick: int, team_id: int, node_id: int, prototype_id: int
) -> void:
	_commands.append({
		"kind": kind,
		"tick": tick,
		"team_id": team_id,
		"node_id": node_id,
		"prototype_id": prototype_id,
	})


func _team(team_id: int) -> Dictionary:
	if not _teams.has(team_id):
		return {}
	return _teams[team_id]


func _team_int(team_id: int, key: String) -> int:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return 0
	return _int_of(team, key)


static func _int_of(body: Dictionary, key: String) -> int:
	var value: int = body[key]
	return value
