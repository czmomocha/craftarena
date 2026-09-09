class_name SimulationBundle
extends RefCounted

## v2 TRAPRUSH topology compile of AuthoringWorld. Field list owner: CD-42 §3.4.
## Collaborators are SimulationBundleDecode / SimulationBundleBags so this file
## stays under E9 400 lines. Public API stays on this type. content-validator
## reads FIELD_* and SCHEMA_VERSION from this file only.
## Pads, two_way / one_way portals, at most one finish occupancy bag,
## destructible / hazard / always-solid / pickup occupancy bags.
## Dangling portals are omitted. Portal bags include source occupancy and dest
## landing pose. Hazard bags use cooldown_ticks as a half-period.
##
## v2 adds the `assets` bag and every entity bag carries `asset_id` +
## `gameplay_version` (ADR-0006, Q1 = B). v1 still decodes (CD-31 §6) and
## migrates to the built-in lattice-cell asset. `to_dictionary` always emits v2.
## `from_dictionary` rejects a bag whose pair is missing from `assets`. Assets
## must be strictly ascending by `asset_id` and every entry must be referenced.
## Not a signed binary. Not a Rule VM graph.

const DecodeGd := preload("res://src/ugc/simulation_bundle_decode.gd")

const SCHEMA_VERSION: int = 2
## 仍可解码、迁移到当前版本的旧 wire 版本（CD-31 §6）。
const MIGRATED_FROM_VERSION: int = 1
const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_CELL: String = "cell"
const FIELD_SOURCE_REVISION: String = "source_revision"
const FIELD_ASSETS: String = "assets"
const FIELD_PADS: String = "pads"
const FIELD_PORTALS: String = "portals"
const FIELD_FINISH: String = "finish"
const FIELD_DESTRUCTIBLES: String = "destructibles"
const FIELD_HAZARDS: String = "hazards"
const FIELD_SOLIDS: String = "solids"
const FIELD_PICKUPS: String = "pickups"
const FIELD_MOVERS: String = "movers"
const FIELD_CONVEYORS: String = "conveyors"
const FIELD_LAUNCHES: String = "launches"
const FIELD_SWITCHES: String = "switches"
const FIELD_GATES: String = "gates"
const FIELD_ENERGY_WALLS: String = "energy_walls"
## v2 里**可省略**的袋。省略与空数组等价，所以旧内容（三张官方课、任何已存的
## AuthoringDocument）不重新编译也照常解码。加袋因此不是 Schema 破坏性变更。
const OPTIONAL_FIELDS: PackedStringArray = [
	FIELD_MOVERS,
	FIELD_CONVEYORS,
	FIELD_LAUNCHES,
	FIELD_SWITCHES,
	FIELD_GATES,
	FIELD_ENERGY_WALLS,
]

var cell: int = 0
var source_revision: int = 0
var assets: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var finish: Array[Dictionary] = []
var destructibles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var solids: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var movers: Array[Dictionary] = []
## 传送带：几何在 `solids` 里，本袋只带方向。见 `TraprushConveyorCycle` 文件头。
var conveyors: Array[Dictionary] = []
## 弹射垫：几何在 `solids` 里，本袋只带方向。见 `TraprushLaunchCycle` 文件头。
var launches: Array[Dictionary] = []
## 踩区开关 / 门：几何在 `solids` 里，本袋只带 `link_group`。见 `TraprushGateCycle`。
var switches: Array[Dictionary] = []
var gates: Array[Dictionary] = []
## 能量墙：几何在 `destructibles` 里，本袋只带 `entity_id`。打碎走已有 UseItem。
var energy_walls: Array[Dictionary] = []


static func from_dictionary(data: Dictionary) -> SimulationBundle:
	return DecodeGd.from_dictionary(data)


func to_dictionary() -> Dictionary:
	var asset_list: Array = []
	for entry: Dictionary in assets:
		asset_list.append(entry.duplicate(true))
	var pad_list: Array = []
	for pad: Dictionary in pads:
		pad_list.append(pad.duplicate(true))
	var portal_list: Array = []
	for portal: Dictionary in portals:
		portal_list.append(portal.duplicate(true))
	var finish_list: Array = []
	for item: Dictionary in finish:
		finish_list.append(item.duplicate(true))
	var destructible_list: Array = []
	for item: Dictionary in destructibles:
		destructible_list.append(item.duplicate(true))
	var hazard_list: Array = []
	for item: Dictionary in hazards:
		hazard_list.append(item.duplicate(true))
	var solid_list: Array = []
	for item: Dictionary in solids:
		solid_list.append(item.duplicate(true))
	var pickup_list: Array = []
	for item: Dictionary in pickups:
		pickup_list.append(item.duplicate(true))
	var mover_list: Array = []
	for item: Dictionary in movers:
		mover_list.append(item.duplicate(true))
	var conveyor_list: Array = []
	for item: Dictionary in conveyors:
		conveyor_list.append(item.duplicate(true))
	var launch_list: Array = []
	for item: Dictionary in launches:
		launch_list.append(item.duplicate(true))
	var switch_list: Array = []
	for item: Dictionary in switches:
		switch_list.append(item.duplicate(true))
	var gate_list: Array = []
	for item: Dictionary in gates:
		gate_list.append(item.duplicate(true))
	var energy_wall_list: Array = []
	for item: Dictionary in energy_walls:
		energy_wall_list.append(item.duplicate(true))
	return {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_CELL: cell,
		FIELD_SOURCE_REVISION: source_revision,
		FIELD_ASSETS: asset_list,
		FIELD_PADS: pad_list,
		FIELD_PORTALS: portal_list,
		FIELD_FINISH: finish_list,
		FIELD_DESTRUCTIBLES: destructible_list,
		FIELD_HAZARDS: hazard_list,
		FIELD_SOLIDS: solid_list,
		FIELD_PICKUPS: pickup_list,
		FIELD_MOVERS: mover_list,
		FIELD_CONVEYORS: conveyor_list,
		FIELD_LAUNCHES: launch_list,
		FIELD_SWITCHES: switch_list,
		FIELD_GATES: gate_list,
		FIELD_ENERGY_WALLS: energy_wall_list,
	}


## 该 asset_id 在本 bundle 内的权威碰撞袋；未引用的 id 返回空字典。
## 权威几何来自 bundle 自身，**不查** `SharedGameplayAssetCatalog`：已发布内容
## 必须按它发布时的形状裁决（ADR-0006 §1.4）。
func asset_collision(asset_id: int) -> Dictionary:
	for entry: Dictionary in assets:
		var entry_id: int = entry["asset_id"]
		if entry_id == asset_id:
			var collision: Dictionary = entry["collision"]
			return collision.duplicate(true)
	return {}
