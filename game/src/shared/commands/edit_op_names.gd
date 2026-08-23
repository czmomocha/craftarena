class_name EditOpNames
extends RefCounted

## EDIT 命令 payload.op 白名单。名字覆盖 CD-32 链路里的摆放 / 删除 / 改组件。
## payload 其余字段见 CD-42 §3.3；Undo 反向命令由 AuthoringSession 派生，不新增 op。

const PLACE: String = "place"
const REMOVE: String = "remove"
const SET_COMPONENT: String = "set_component"

const ALL: PackedStringArray = [
	PLACE,
	REMOVE,
	SET_COMPONENT,
]


static func contains(op_name: String) -> bool:
	return ALL.has(op_name)
