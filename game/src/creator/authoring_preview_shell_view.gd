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
		apply_play_gate_visibility(shell)
		apply_play_movers(shell)
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


func apply_play_gate_visibility(shell: AuthoringPreviewShell) -> void:
	if not map_alive() or shell.preview == null or not shell.preview.is_playing():
		return
	var lookup: Dictionary = {}
	for item: Dictionary in shell.preview.play_gate_cycle:
		var entity_raw: Variant = item.get("entity_id", 0)
		if typeof(entity_raw) != TYPE_INT:
			continue
		var entity_id: int = entity_raw
		lookup[entity_id] = shell.preview.play_is_gate_solid(entity_id)
	map.apply_hazard_visibility(lookup)


## 开玩后 AuthoringWorld 指纹不变，脏检查会跳过 rebuild。大厅用
## MatchSolidMap.apply_tick 跟 tick 走；Preview 没有快照，直接读 play_world
## 里已经搬过的固体盒，否则电梯 / 往返平台看起来原地不动。
func apply_play_movers(shell: AuthoringPreviewShell) -> void:
	if not map_alive() or shell.preview == null or not shell.preview.is_playing():
		return
	if shell.preview.play_world == null:
		return
	for item: Dictionary in shell.preview.play_mover_cycle:
		var entity_raw: Variant = item.get("entity_id", 0)
		var box_raw: Variant = item.get("box_id", 0)
		if typeof(entity_raw) != TYPE_INT or typeof(box_raw) != TYPE_INT:
			continue
		var entity_id: int = entity_raw
		var box_id: int = box_raw
		var pose: Dictionary = shell.preview.play_world.static_box_pose(box_id)
		if pose.is_empty():
			continue
		var x_raw: Variant = pose.get("x", null)
		var y_raw: Variant = pose.get("y", null)
		var z_raw: Variant = pose.get("z", null)
		if typeof(x_raw) != TYPE_INT or typeof(y_raw) != TYPE_INT:
			continue
		if typeof(z_raw) != TYPE_INT:
			continue
		var x: int = x_raw
		var y: int = y_raw
		var z: int = z_raw
		map.apply_solid_pose(entity_id, x, y, z)
