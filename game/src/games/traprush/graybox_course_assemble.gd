class_name TraprushGrayboxAssemble
extends RefCounted

## Assembles a TraprushGrayboxCourse from a layout dictionary.
## Public assemble() stays on the course facade so this file stays under E9.

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const Destructible := preload("res://src/games/traprush/destructible.gd")
const LayoutGd := preload("res://src/games/traprush/graybox_course_layout.gd")
const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")


static func try_assemble(layout: Dictionary) -> TraprushGrayboxCourse:
	var seed_read: Dictionary = LayoutGd._require_int(layout, "seed")
	var start_x_read: Dictionary = LayoutGd._require_int(layout, "start_x")
	var start_y_read: Dictionary = LayoutGd._require_int(layout, "start_y")
	var start_z_read: Dictionary = LayoutGd._require_int(layout, "start_z")
	var start_yaw_read: Dictionary = LayoutGd._require_int(layout, "start_yaw")
	var radius_read: Dictionary = LayoutGd._require_int(layout, "radius")
	var height_read: Dictionary = LayoutGd._require_int(layout, "cylinder_height")
	var health_read: Dictionary = LayoutGd._require_int(layout, "crate_max_health")
	var wall_read: Dictionary = LayoutGd._require_box(layout, "wall")
	var crate_box_read: Dictionary = LayoutGd._require_box(layout, "crate")
	var ids_read: Dictionary = LayoutGd._require_id_array(layout, "checkpoint_ids")
	var pads_read: Dictionary = LayoutGd._require_box_list(layout, "checkpoint_pads")
	var spawn_start_read: Dictionary = LayoutGd._require_named_pose(layout, "spawn_start")
	var poses_read: Dictionary = LayoutGd._require_pose_list(layout, "checkpoint_poses")
	var up_read: Dictionary = LayoutGd._require_portal(layout, "up_portal")
	var side_read: Dictionary = LayoutGd._require_portal(layout, "side_portal")
	var actor_read: Dictionary = LayoutGd._require_actor_id(layout)
	var version_read: Dictionary = LayoutGd._require_nonempty_string(layout, "content_version")
	var trace_read: Dictionary = LayoutGd._require_nonempty_string(layout, "trace_id")
	var capacity_read: Dictionary = LayoutGd._require_int(layout, "snapshot_capacity")
	var hazard_read: Dictionary = LayoutGd._require_box(layout, "hazard")
	var period_read: Dictionary = LayoutGd._require_int(layout, "hazard_period_ticks")
	var finish_read: Dictionary = LayoutGd._require_box(layout, "finish")
	if (
		not LayoutGd._flag(seed_read)
		or not LayoutGd._flag(start_x_read)
		or not LayoutGd._flag(start_y_read)
		or not LayoutGd._flag(start_z_read)
		or not LayoutGd._flag(start_yaw_read)
		or not LayoutGd._flag(radius_read)
		or not LayoutGd._flag(height_read)
		or not LayoutGd._flag(health_read)
		or not LayoutGd._flag(wall_read)
		or not LayoutGd._flag(crate_box_read)
		or not LayoutGd._flag(ids_read)
		or not LayoutGd._flag(pads_read)
		or not LayoutGd._flag(spawn_start_read)
		or not LayoutGd._flag(poses_read)
		or not LayoutGd._flag(up_read)
		or not LayoutGd._flag(side_read)
		or not LayoutGd._flag(actor_read)
		or not LayoutGd._flag(version_read)
		or not LayoutGd._flag(trace_read)
		or not LayoutGd._flag(capacity_read)
		or not LayoutGd._flag(hazard_read)
		or not LayoutGd._flag(period_read)
		or not LayoutGd._flag(finish_read)
	):
		return null
	var hazard_period_ticks: int = LayoutGd._value(period_read)
	if hazard_period_ticks < 1:
		return null
	var ring: SimSnapshotRing = SimSnapshotRing.create(LayoutGd._value(capacity_read))
	if ring == null:
		return null
	var crate_max_health: int = LayoutGd._value(health_read)
	var crate_obj: TraprushDestructible = Destructible.create(crate_max_health)
	if crate_obj == null:
		return null
	var ids: Array[int] = LayoutGd._ids_from(ids_read)
	var pad_boxes: Array[Dictionary] = LayoutGd._boxes_from(pads_read)
	if pad_boxes.size() != ids.size():
		return null
	var spawn_start: Dictionary = LayoutGd._pose_from(spawn_start_read)
	var checkpoint_poses: Array[Dictionary] = LayoutGd._poses_from(poses_read)
	var spawn: TraprushCheckpointSpawn = CheckpointSpawn.new(spawn_start, checkpoint_poses)
	var sim: SimulationWorld = SimulationWorld.new(LayoutGd._value(seed_read))
	var spawned_id: int = sim.spawn_capsule(
		LayoutGd._value(start_x_read),
		LayoutGd._value(start_y_read),
		LayoutGd._value(start_z_read),
		LayoutGd._value(start_yaw_read),
		LayoutGd._value(radius_read),
		LayoutGd._value(height_read)
	)
	if spawned_id < 1:
		return null
	var wall_id: int = sim.spawn_static_box(
		LayoutGd._int_at(wall_read, "x"),
		LayoutGd._int_at(wall_read, "y"),
		LayoutGd._int_at(wall_read, "z"),
		LayoutGd._int_at(wall_read, "half_x"),
		LayoutGd._int_at(wall_read, "half_y"),
		LayoutGd._int_at(wall_read, "half_z")
	)
	if wall_id < 1:
		return null
	var crate_id: int = sim.spawn_static_box(
		LayoutGd._int_at(crate_box_read, "x"),
		LayoutGd._int_at(crate_box_read, "y"),
		LayoutGd._int_at(crate_box_read, "z"),
		LayoutGd._int_at(crate_box_read, "half_x"),
		LayoutGd._int_at(crate_box_read, "half_y"),
		LayoutGd._int_at(crate_box_read, "half_z")
	)
	if crate_id < 1:
		return null
	var hazard_id: int = sim.spawn_static_box(
		LayoutGd._int_at(hazard_read, "x"),
		LayoutGd._int_at(hazard_read, "y"),
		LayoutGd._int_at(hazard_read, "z"),
		LayoutGd._int_at(hazard_read, "half_x"),
		LayoutGd._int_at(hazard_read, "half_y"),
		LayoutGd._int_at(hazard_read, "half_z")
	)
	if hazard_id < 1:
		return null
	var spawned_pad_ids: Array[int] = []
	spawned_pad_ids.resize(pad_boxes.size())
	for pad_index: int in range(pad_boxes.size()):
		var pad: Dictionary = pad_boxes[pad_index]
		var pad_id: int = sim.spawn_static_box(
			LayoutGd._int_at(pad, "x"),
			LayoutGd._int_at(pad, "y"),
			LayoutGd._int_at(pad, "z"),
			LayoutGd._int_at(pad, "half_x"),
			LayoutGd._int_at(pad, "half_y"),
			LayoutGd._int_at(pad, "half_z")
		)
		if pad_id < 1:
			return null
		if not sim.set_static_box_solid(pad_id, false):
			return null
		spawned_pad_ids[pad_index] = pad_id
	var finish_id: int = sim.spawn_static_box(
		LayoutGd._int_at(finish_read, "x"),
		LayoutGd._int_at(finish_read, "y"),
		LayoutGd._int_at(finish_read, "z"),
		LayoutGd._int_at(finish_read, "half_x"),
		LayoutGd._int_at(finish_read, "half_y"),
		LayoutGd._int_at(finish_read, "half_z")
	)
	if finish_id < 1:
		return null
	if not sim.set_static_box_solid(finish_id, false):
		return null
	var shove_target_id: int = 0
	if layout.has("shove_target"):
		var shove_pose_read: Dictionary = LayoutGd._require_named_pose(layout, "shove_target")
		if not LayoutGd._flag(shove_pose_read):
			return null
		var dummy_id: int = sim.spawn_capsule(
			LayoutGd._int_at(shove_pose_read, "x"),
			LayoutGd._int_at(shove_pose_read, "y"),
			LayoutGd._int_at(shove_pose_read, "z"),
			LayoutGd._int_at(shove_pose_read, "yaw_bam"),
			LayoutGd._value(radius_read),
			LayoutGd._value(height_read)
		)
		if dummy_id < 1:
			return null
		shove_target_id = dummy_id
	var graph: TraprushPortalGraph = PortalGraph.new()
	if not graph.add_link(LayoutGd._portal_from(up_read)):
		return null
	if not graph.add_link(LayoutGd._portal_from(side_read)):
		return null
	var course: TraprushGrayboxCourse = TraprushGrayboxCourse.new()
	course.world = sim
	course.entity_id = spawned_id
	course.track = CheckpointTrack.from_int_array(ids)
	course.wall_box_id = wall_id
	course.crate_box_id = crate_id
	course.hazard_box_id = hazard_id
	course.finish_box_id = finish_id
	course.finish_tick = -1
	course.shove_target_id = shove_target_id
	course.crate = crate_obj
	course.pad_box_ids = spawned_pad_ids
	course._spawn = spawn
	course._graph = graph
	course._checkpoint_ids = ids
	course.tape = SimReplayBuffer.new(LayoutGd._value(seed_read))
	course.snapshots = ring
	course._actor_id = LayoutGd._value(actor_read)
	course._content_version = LayoutGd._text(version_read)
	course._trace_id = LayoutGd._text(trace_read)
	course._next_command_seq = 1
	course._hazard_period_ticks = hazard_period_ticks
	if not course.snapshots.record(course.world):
		return null
	return course
