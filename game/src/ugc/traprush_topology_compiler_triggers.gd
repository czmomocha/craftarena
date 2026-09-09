class_name TraprushTopologyCompilerTriggers
extends RefCounted

## Switch / gate occupancy bags for topology compile.
## Public compile() stays on TraprushTopologyCompiler so bags stays under E9.

const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")


## 开关 / 门：固体 + 标签 + 已有 `interactable.link_group`。
## 与 conveyor / launch / mover 互斥。两者都没有标签时是成功的空操作。
static func try_append(
	entity_id: int,
	record: SharedComponentRecord,
	mover_bag: Dictionary,
	has_conveyor: bool,
	has_launch: bool,
	switch_list: Array[Dictionary],
	gate_list: Array[Dictionary]
) -> bool:
	var has_switch: bool = FieldsGd.has_switch_tag(record)
	var has_gate: bool = FieldsGd.has_gate_tag(record)
	if has_switch and has_gate:
		return false
	if not has_switch and not has_gate:
		return true
	if has_conveyor or has_launch:
		return false
	if not mover_bag.is_empty():
		return false
	var link_group: int = FieldsGd.interactable_link_group(record)
	if link_group < 0:
		return false
	var bag: Dictionary = {"entity_id": entity_id, "link_group": link_group}
	if has_switch:
		switch_list.append(bag)
	else:
		gate_list.append(bag)
	return true
