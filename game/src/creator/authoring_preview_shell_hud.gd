class_name AuthoringPreviewShellHud
extends RefCounted

## Preview presentation: status dictionary + the connected= status line.
## Tokens stay untranslated. This is not a write gate.


static func build_view(
	preview: AuthoringPreview,
	map: AuthoringPreviewMap,
	window_visible: bool
) -> Dictionary:
	var entity_count: int = 0
	var connected: bool = false
	var preview_revision: int = 0
	var needs_restart: bool = false
	var playing: bool = false
	var accepted_count: int = 0
	var checkpoint_count: int = 0
	var floor_index: int = 0
	var finish_tick: int = -1
	var crate_alive: int = 0
	var crate_count: int = 0
	var hazard_alive: int = 0
	var hazard_count: int = 0
	var reach_ok: bool = true
	var reach_issue_count: int = 0
	if preview != null:
		connected = preview.connected
		preview_revision = preview.preview_revision
		needs_restart = preview.needs_restart
		playing = preview.is_playing()
		accepted_count = preview.play_accepted_count()
		checkpoint_count = preview.play_checkpoint_count()
		floor_index = preview.play_floor_index()
		finish_tick = preview.play_finish_tick()
		crate_alive = preview.play_destructible_alive_count()
		crate_count = preview.play_destructible_count()
		hazard_alive = preview.play_hazard_solid_count()
		hazard_count = preview.play_hazard_count()
		if preview.world != null:
			entity_count = preview.world.entity_count()
	if map != null:
		reach_ok = map.reachability_ok()
		reach_issue_count = map.reachability_issue_count()
	return {
		"connected": connected,
		"preview_revision": preview_revision,
		"entity_count": entity_count,
		"needs_restart": needs_restart,
		"playing": playing,
		"accepted_count": accepted_count,
		"checkpoint_count": checkpoint_count,
		"floor_index": floor_index,
		"finish_tick": finish_tick,
		"crate_alive": crate_alive,
		"crate_count": crate_count,
		"hazard_alive": hazard_alive,
		"hazard_count": hazard_count,
		"window_visible": window_visible,
		"reach_ok": reach_ok,
		"reach_issue_count": reach_issue_count,
	}


static func format_line(preview: AuthoringPreview, map: AuthoringPreviewMap) -> String:
	if preview == null:
		return ""
	var entity_count: int = 0
	if preview.world != null:
		entity_count = preview.world.entity_count()
	var reach_ok: bool = true
	var reach_issue_count: int = 0
	if map != null:
		reach_ok = map.reachability_ok()
		reach_issue_count = map.reachability_issue_count()
	return "connected=%s revision=%d entities=%d restart=%s playing=%s pads=%d/%d floor=%d finish=%d crates=%d/%d hazards=%d/%d solids=%d/%d reach_ok=%s issues=%d" % [
		str(preview.connected),
		preview.preview_revision,
		entity_count,
		str(preview.needs_restart),
		str(preview.is_playing()),
		preview.play_accepted_count(),
		preview.play_checkpoint_count(),
		preview.play_floor_index(),
		preview.play_finish_tick(),
		preview.play_destructible_alive_count(),
		preview.play_destructible_count(),
		preview.play_hazard_solid_count(),
		preview.play_hazard_count(),
		preview.play_solid_count(),
		preview.play_solid_count(),
		str(reach_ok),
		reach_issue_count,
	]
