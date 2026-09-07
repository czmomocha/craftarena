class_name SharedVisualAssetCatalogIds
extends RefCounted

## asset_id → 场景表。未知 id 由调用方回退袋类型。本文件不 preload 目录
## 门面，避免与 visual_asset_catalog.gd 循环引用。

const BAG_TILE: String = "tile"
const BAG_CHECKPOINT: String = "checkpoint"
const BAG_FINISH: String = "finish"
const BAG_CRATE: String = "crate"
const BAG_HAZARD: String = "hazard"
const BAG_PORTAL: String = "portal"
const BAG_PICKUP_BOMB: String = "pickup_bomb"
const BAG_PICKUP_DASH: String = "pickup_dash"
const BAG_SPAWN: String = "spawn"


## 一期唯一内置资产仍是 lattice-cell（id=1）。空路径 = 用袋类型。
static func scene_for_asset_id(asset_id: int) -> String:
	if asset_id == SharedGameplayAssetCatalog.LATTICE_CELL_ID:
		return ""
	return ""
