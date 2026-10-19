class_name AuthoringPreviewShellPlay
extends RefCounted

## Preview play verbs: copy caller stubs onto AuthoringPreview, then
## start / stop / advance / apply intent. The facade keeps the public
## try_* names and the re-entrancy busy flag.

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func copy_use_item_stubs(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_use_item_damage = shell.play_use_item_damage
	shell.preview.play_use_item_reach_dx = shell.play_use_item_reach_dx
	shell.preview.play_use_item_reach_dy = shell.play_use_item_reach_dy
	shell.preview.play_use_item_reach_dz = shell.play_use_item_reach_dz


func copy_sprint_stubs(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_sprint_step = shell.play_sprint_step
	shell.preview.play_item_cooldown_ticks = shell.play_item_cooldown_ticks


func copy_jump_stubs(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_jump_dy = shell.play_jump_dy
	shell.preview.play_support_dy = shell.play_support_dy


func copy_fall_stub(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_fall_dy = shell.play_fall_dy


func copy_play_range_stub(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	var half: int = shell.play_range_half
	if half == OutOfRangeReset.STUB_HALF:
		half = OutOfRangeReset.half_covering(_world_max_abs(shell.preview.world))
	shell.preview.enable_play_range(half)


func copy_hazard_hit_stubs(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_hazard_knockback_step = shell.play_hazard_knockback_step
	shell.preview.play_conveyor_step = shell.play_conveyor_step
	shell.preview.play_ice_step = shell.play_ice_step
	shell.preview.play_launch_dy = shell.play_launch_dy
	shell.preview.play_launch_xz = shell.play_launch_xz
	shell.preview.play_respawn_stun_ticks = shell.play_respawn_stun_ticks


func copy_start_stubs(shell: AuthoringPreviewShell) -> void:
	copy_use_item_stubs(shell)
	copy_sprint_stubs(shell)
	copy_jump_stubs(shell)
	copy_fall_stub(shell)
	copy_play_range_stub(shell)
	copy_hazard_hit_stubs(shell)


func reset_intent() -> Dictionary:
	return {"intent": PlayerIntentNames.RESET_TO_CHECKPOINT}


func use_item_intent() -> Dictionary:
	return {"intent": PlayerIntentNames.USE_ITEM}


func sprint_intent() -> Dictionary:
	return {"intent": PlayerIntentNames.SPRINT}


func jump_intent() -> Dictionary:
	return {"intent": PlayerIntentNames.JUMP}


func _world_max_abs(world: AuthoringWorld) -> int:
	if world == null:
		return 0
	var max_abs: int = 0
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			continue
		if record.components.has(SharedComponentNames.TRANSFORM):
			max_abs = _fold_pose(max_abs, record.components[SharedComponentNames.TRANSFORM])
		if record.components.has(SharedComponentNames.MOVER):
			var mover_raw: Variant = record.components[SharedComponentNames.MOVER]
			if typeof(mover_raw) == TYPE_DICTIONARY:
				var mover: Dictionary = mover_raw
				var path_raw: Variant = mover.get("path", [])
				if typeof(path_raw) == TYPE_ARRAY:
					var path: Array = path_raw
					for point_raw: Variant in path:
						max_abs = _fold_pose(max_abs, point_raw)
	return max_abs


func _fold_pose(max_abs: int, raw: Variant) -> int:
	if typeof(raw) != TYPE_DICTIONARY:
		return max_abs
	var pose: Dictionary = raw
	for axis_name: String in ["x", "y", "z"]:
		var value: Variant = pose.get(axis_name, 0)
		if typeof(value) != TYPE_INT:
			continue
		var number: int = value
		var axis: int = absi(number)
		if axis > max_abs:
			max_abs = axis
	return max_abs
