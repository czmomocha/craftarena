class_name AuthoringPreviewShellPlay
extends RefCounted

## Preview play verbs: copy caller stubs onto AuthoringPreview, then
## start / stop / advance / apply intent. The facade keeps the public
## try_* names and the re-entrancy busy flag.

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
	shell.preview.enable_play_range(shell.play_range_half)


func copy_hazard_hit_stubs(shell: AuthoringPreviewShell) -> void:
	if shell.preview == null:
		return
	shell.preview.play_hazard_knockback_step = shell.play_hazard_knockback_step
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
