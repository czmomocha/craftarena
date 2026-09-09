class_name TraprushTopologyCompilerObstacles
extends RefCounted

## Roller / rubble / obstacle_core occupancy bags.
## Public compile() stays on TraprushTopologyCompiler so bags stays under E9.

const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")


static func try_append_roller(
	entity_id: int, record: SharedComponentRecord, roller_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_roller_tag(record):
		return true
	if FieldsGd.has_solid_tag(record):
		return false
	if FieldsGd.has_flame_tag(record):
		return false
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_lift_tag(record) or FieldsGd.has_spike_tag(record):
		return false
	if FieldsGd.has_crusher_tag(record) or FieldsGd.has_energy_wall_tag(record):
		return false
	if FieldsGd.has_rubble_tag(record) or FieldsGd.has_obstacle_core_tag(record):
		return false
	if FieldsGd.has_pendulum_tag(record) or FieldsGd.has_ice_tag(record):
		return false
	roller_list.append({"entity_id": entity_id})
	return true


static func try_append_rubble(
	entity_id: int, record: SharedComponentRecord, rubble_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_rubble_tag(record):
		return true
	return _append_destructible_kind(entity_id, record, rubble_list, true)


static func try_append_obstacle_core(
	entity_id: int, record: SharedComponentRecord, core_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_obstacle_core_tag(record):
		return true
	return _append_destructible_kind(entity_id, record, core_list, false)


static func try_append_pendulum(
	entity_id: int,
	record: SharedComponentRecord,
	mover_bag: Dictionary,
	pendulum_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_pendulum_tag(record):
		return true
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_lift_tag(record) or FieldsGd.has_spike_tag(record):
		return false
	if FieldsGd.has_crusher_tag(record) or FieldsGd.has_ice_tag(record):
		return false
	if FieldsGd.has_flame_tag(record) or FieldsGd.has_roller_tag(record):
		return false
	if mover_bag.is_empty():
		return false
	var path: Array = mover_bag["path"]
	if not SimulationBundleBags.path_is_horizontal(path):
		return false
	pendulum_list.append({"entity_id": entity_id})
	return true


static func try_append_ice(
	entity_id: int, record: SharedComponentRecord, ice_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_ice_tag(record):
		return true
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_lift_tag(record) or FieldsGd.has_spike_tag(record):
		return false
	if FieldsGd.has_crusher_tag(record) or FieldsGd.has_pendulum_tag(record):
		return false
	if record.components.has(SharedComponentNames.MOVER):
		return false
	var yaw_bam: int = FieldsGd.transform_yaw_bam(record)
	if yaw_bam < 0:
		return false
	ice_list.append({"entity_id": entity_id, "yaw_bam": yaw_bam})
	return true


static func _append_destructible_kind(
	entity_id: int,
	record: SharedComponentRecord,
	bag_list: Array[Dictionary],
	is_rubble: bool
) -> bool:
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_lift_tag(record) or FieldsGd.has_solid_tag(record):
		return false
	if FieldsGd.has_spike_tag(record) or FieldsGd.has_crusher_tag(record):
		return false
	if FieldsGd.has_flame_tag(record) or FieldsGd.has_roller_tag(record):
		return false
	if FieldsGd.has_pendulum_tag(record) or FieldsGd.has_ice_tag(record):
		return false
	if FieldsGd.has_energy_wall_tag(record):
		return false
	if is_rubble and FieldsGd.has_obstacle_core_tag(record):
		return false
	if not is_rubble and FieldsGd.has_rubble_tag(record):
		return false
	bag_list.append({"entity_id": entity_id})
	return true
