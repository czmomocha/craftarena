class_name TraprushTopologyCompiler
extends RefCounted

## Compiles an AuthoringWorld into a v2 TRAPRUSH SimulationBundle.
## Whole-world topology, not an incremental subgraph. Dangling portals are
## omitted. A checkpoint or a classified two_way / one_way portal without
## source or dest transform fails the whole compile. Portal bags include the
## source occupancy pose (x/y/z) and dest landing pose. Finish occupancy is
## a zone whose tags include "finish"; missing transform or two finish
## zones fail the whole compile. Checkpoint or portal on the same entity
## as a finish zone also fails. Destructible bags need transform and
## durability; sharing an entity with checkpoint, portal, finish, hazard, or
## solid fails. Hazard bags need transform and cooldown_ticks; sharing an
## entity with checkpoint, portal, finish, destructible, or solid fails.
## Solid bags need transform and zone.tags including "solid"; sharing an
## entity with checkpoint, portal, finish, destructible, or hazard fails.
## Pickup bags need transform and inventory.item_state of bomb or dash;
## sharing an entity with checkpoint, portal, finish, destructible, hazard,
## or solid fails. Finish and solid tags together fail. Not a new EDIT op.
## Never settlement.
##
## v2 (ADR-0006): every occupancy bag carries the `gameplay_asset` reference it
## was authored with, and the used assets are stamped into the bundle's `assets`
## bag with their authoritative collision resolved at this world's `cell`.
##
## The reference is validated against `SharedGameplayAssetCatalog` here and
## nowhere else: this is the publish gate (Q5 = A, creators pick an `asset_id`,
## they never author dimensions). `has_version` demands the catalog's *current*
## version, so once the platform changes an asset's collision, content that
## referenced the old version stops compiling and must be republished as a new
## content version — which is exactly CD-31 §5's "GameplayAsset 变化必须生成新
## 内容版本". Already-published bundles keep running because they carry their
## own geometry.
##
## Entities without a `gameplay_asset` component default to the built-in
## lattice-cell asset, so the three official courses and every existing
## AuthoringWorld compile to byte-identical occupancy.
##
## `zone.shape` is **not** read here. Since v2 the authoritative collision comes
## from the asset, and `zone` goes back to CD-42 §1's original meaning (触发与
## 查询区域). Before v2 the shape a creator authored was silently discarded,
## which is the defect ADR-0006 §1.3 exists to close.
##
## Collaborators are TraprushTopologyCompilerBags / Fields so this file stays
## under E9 400 lines. Public compile() stays on this type.

const BagsGd := preload("res://src/ugc/traprush_topology_compiler_bags.gd")
const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")

const FINISH_ZONE_TAG: String = "finish"
const SOLID_ZONE_TAG: String = "solid"


static func compile(world: AuthoringWorld) -> SimulationBundle:
	if world == null or world.grid == null:
		return null
	var used_assets: Dictionary[int, int] = {}
	var occupancy: Dictionary = BagsGd.collect_occupancy(world, used_assets)
	if not occupancy.get("ok", false):
		return null
	var portal_result: Dictionary = BagsGd.collect_portals(world, used_assets)
	if not portal_result.get("ok", false):
		return null
	var finish_list: Array = occupancy["finish"]
	if finish_list.size() > 1:
		return null
	var assets: Array[Dictionary] = FieldsGd.asset_entries(used_assets, world.grid.cell)
	if assets.is_empty() and not used_assets.is_empty():
		return null
	var body: Dictionary = {
		SimulationBundle.FIELD_SCHEMA_VERSION: SimulationBundle.SCHEMA_VERSION,
		SimulationBundle.FIELD_CELL: world.grid.cell,
		SimulationBundle.FIELD_SOURCE_REVISION: world.revision,
		SimulationBundle.FIELD_ASSETS: assets,
		SimulationBundle.FIELD_PADS: occupancy["pads"],
		SimulationBundle.FIELD_PORTALS: portal_result["portals"],
		SimulationBundle.FIELD_FINISH: finish_list,
		SimulationBundle.FIELD_DESTRUCTIBLES: occupancy["destructibles"],
		SimulationBundle.FIELD_HAZARDS: occupancy["hazards"],
		SimulationBundle.FIELD_SOLIDS: occupancy["solids"],
		SimulationBundle.FIELD_PICKUPS: occupancy["pickups"],
	}
	return SimulationBundle.from_dictionary(body)
