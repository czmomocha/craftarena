class_name AuthoringPreviewShellView
extends RefCounted

## Preview presentation: AuthoringPreviewMap under the Preview Window.
## Dirty-check rebuild stays on the map; this type only says when Play
## start/stop must force a rebuild, and paints pose / hazards / anim.

const MAP_NAME: String = "PreviewMap"

var map: AuthoringPreviewMap = null
var map_playing: bool = false


func clear() -> void:
	map = null
	map_playing = false


func map_alive() -> bool:
	return map != null and is_instance_valid(map)


func mount(window: Window) -> AuthoringPreviewMap:
	if window == null:
		return null
	if map_alive():
		return map
	map = AuthoringPreviewMap.new()
	map.name = MAP_NAME
	window.add_child(map)
	map_playing = false
	return map


func rebuild(shell: AuthoringPreviewShell) -> void:
	if not map_alive() or shell.preview == null:
		return
	var playing: bool = shell.preview.is_playing() and shell.preview.play_world != null
	if playing != map_playing:
		map.invalidate()
		map_playing = playing
	map.rebuild(shell.preview.world)
	if playing:
		map.show_player_pose(shell.preview.play_world.get_pose(shell.preview.player_id))
		map.mark_accepted_checkpoints(shell.preview.play_accepted_ids())
		apply_play_hazard_visibility(shell)
		apply_play_anim(shell)
	else:
		map.clear_player_pose()


func apply_play_anim(shell: AuthoringPreviewShell) -> void:
	if not map_alive() or shell.preview == null or not shell.preview.is_playing():
		return
	var facts: Dictionary = PlayAnimState.facts(
		shell.preview.play_airborne(),
		shell.sampler.play_moving,
		shell.preview.play_stun_remaining() > 0,
		shell.preview.play_portal_latched(),
		false,
		shell.preview.play_broke_this_tick()
	)
	map.set_anim_state(shell.play_anim.resolve(facts))


func apply_play_hazard_visibility(shell: AuthoringPreviewShell) -> void:
	if not map_alive() or shell.preview == null or not shell.preview.is_playing():
		return
	var lookup: Dictionary = {}
	for key: Variant in shell.preview.play_hazard_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		lookup[entity_id] = shell.preview.play_is_hazard_solid(entity_id)
	map.apply_hazard_visibility(lookup)
