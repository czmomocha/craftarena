class_name TraprushPickupKinds
extends RefCounted

## v1 TRAPRUSH 拾取 kind 白名单。Authoring `inventory.item_state` 必须是
## 这两个字符串之一才编进 SimulationBundle.pickups。不发明槽位、叠加或
## 产品道具表（CD-63）；本刀只锁爆破球与冲刺两个占位名字。

const BOMB: String = "bomb"
const DASH: String = "dash"


static func contains(kind: String) -> bool:
	return kind == BOMB or kind == DASH
