class_name AuthoringPreview
extends RefCounted

## Independent Preview session facade (CD-32 §4). AuthoringSession stays open.
## Collaborators are AuthoringPreviewBootstrap / Intents / Scan / View so
## this file stays under E9 400 lines. Public API stays on this type.
## Applies P0–P2 EditCommand patches at a safe point; failure restores the
## pre-patch world. P3 waits for Rule VM. P4 sets needs_restart.
## try_start_play compiles the Preview world into a v1 TRAPRUSH topology
## bundle, loads SimulationWorld, and spawns on the lowest-order pad.
## try_advance_play integrates caller play_fall_dy then ticks; occupancy
## order is pad→portal→pad→finish. try_apply_play_intent does not tick.
## Never settlement or online writes. Window host is AuthoringPreviewShell.

const Gravity := preload("res://src/games/traprush/gravity.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const AuthoringPreviewBootstrapGd := preload("res://src/creator/authoring_preview_bootstrap.gd")
const AuthoringPreviewIntentsGd := preload("res://src/creator/authoring_preview_intents.gd")
const AuthoringPreviewScanGd := preload("res://src/creator/authoring_preview_scan.gd")
const AuthoringPreviewViewGd := preload("res://src/creator/authoring_preview_view.gd")

var world: AuthoringWorld = null
var preview_revision: int = 0
var connected: bool = false
var needs_restart: bool = false
var play_world: SimulationWorld = null
var play_graph: TraprushPortalGraph = null
var play_pad_ids: Dictionary = {}
var play_portal_ids: Dictionary = {}
var play_finish_ids: Dictionary = {}
var play_destructible_ids: Dictionary = {}
var play_destructible_health: Dictionary = {}
var play_hazard_ids: Dictionary = {}
var play_hazard_cycle: Array[Dictionary] = []
var play_solid_ids: Dictionary = {}
var play_pickup_ids: Dictionary = {}
var play_pickup_kinds: Dictionary = {}
var play_bomb: int = 0
var play_dash: int = 0
var play_taken: Dictionary = {}
var play_last_use_item_tick: int = -1
var play_last_sprint_tick: int = -1
var play_track: TraprushCheckpointTrack = null
var play_spawn: TraprushCheckpointSpawn = null
var play_cell: int = 0
var player_id: int = 0
var play_use_item_damage: int = 0
var play_use_item_reach_dx: int = 0
var play_use_item_reach_dy: int = 0
var play_use_item_reach_dz: int = 0
var play_jump_dy: int = 0
var play_support_dy: int = 0
var play_fall_dy: int = 0
var play_sprint_step: int = 0
var play_item_cooldown_ticks: int = 1
var play_hazard_knockback_step: int = 0
var play_respawn_stun_ticks: int = 0
var play_range_enabled: bool = false
var play_range_min_x: int = 0
var play_range_max_x: int = 0
var play_range_min_y: int = 0
var play_range_max_y: int = 0
var play_range_min_z: int = 0
var play_range_max_z: int = 0
var _in_tick: bool = false
var _playing: bool = false
var _portal_latch: Dictionary = {}
var _play_finish_tick: int = -1
var _play_stun_remaining: int = 0

var intents: AuthoringPreviewIntentsGd = AuthoringPreviewIntentsGd.new()
var scan: AuthoringPreviewScanGd = AuthoringPreviewScanGd.new()
var view: AuthoringPreviewViewGd = AuthoringPreviewViewGd.new()


func connect_from(session: AuthoringSession) -> bool:
	return AuthoringPreviewBootstrapGd.connect_from(self, session)


func is_safe_point() -> bool:
	return connected and not needs_restart and not _in_tick


func enter_tick() -> bool:
	if not connected or needs_restart:
		return false
	_in_tick = true
	return true


func leave_tick() -> void:
	_in_tick = false


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func is_playing() -> bool:
	return _playing and play_world != null


func try_start_play(seed: int, radius: int = 0, cylinder_height: int = 0) -> bool:
	return AuthoringPreviewBootstrapGd.try_start_play(self, seed, radius, cylinder_height)


func try_stop_play() -> bool:
	return AuthoringPreviewBootstrapGd.try_stop_play(self)


func try_advance_play() -> bool:
	if not is_playing():
		return false
	_tick_play_stun()
	Gravity.integrate(play_world, player_id, play_fall_dy)
	_resolve_play_hazards()
	_reset_play_if_out_of_range()
	play_world.tick()
	HazardCycle.apply(play_world, play_hazard_cycle)
	_resolve_play_hazards()
	_reset_play_if_out_of_range()
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_pads()
	_accept_overlapping_play_finish()
	_grant_play_pickups()
	return true


func try_apply_play_intent(payload: Dictionary) -> bool:
	return intents.apply(self, payload)


func enable_play_range(half: int) -> void:
	if half < 1:
		play_range_enabled = false
		return
	play_range_enabled = true
	play_range_min_x = -half
	play_range_max_x = half
	play_range_min_y = -half
	play_range_max_y = half
	play_range_min_z = -half
	play_range_max_z = half


func try_accept_play_checkpoint(checkpoint_id: int) -> bool:
	return scan.try_accept_play_checkpoint(self, checkpoint_id)


func play_accepted_count() -> int:
	return view.play_accepted_count(self)


func play_checkpoint_count() -> int:
	return view.play_checkpoint_count(self)


func play_last_accepted_id() -> int:
	return view.play_last_accepted_id(self)


func play_accepted_ids() -> PackedInt32Array:
	return view.play_accepted_ids(self)


func play_floor_index() -> int:
	return view.play_floor_index(self)


func play_finish_tick() -> int:
	return view.play_finish_tick(self)


func play_destructible_count() -> int:
	return view.play_destructible_count(self)


func play_hazard_count() -> int:
	return view.play_hazard_count(self)


func play_hazard_solid_count() -> int:
	return view.play_hazard_solid_count(self)


func play_solid_count() -> int:
	return view.play_solid_count(self)


func play_is_hazard_solid(entity_id: int) -> bool:
	return view.play_is_hazard_solid(self, entity_id)


func play_destructible_alive_count() -> int:
	return view.play_destructible_alive_count(self)


func try_cross_play_finish() -> bool:
	return scan.try_cross_play_finish(self)


func try_apply_patch(level: String, command: SharedCommand) -> bool:
	if not connected or needs_restart:
		return false
	if _in_tick:
		return false
	if not PreviewPatchLevels.contains(level):
		return false
	if level == PreviewPatchLevels.P4:
		needs_restart = true
		return false
	if level == PreviewPatchLevels.P3:
		return false
	if command == null or command.kind != SharedCommand.Kind.EDIT:
		return false
	if world == null:
		return false
	if command.expected_revision != world.revision:
		return false
	var classified: String = PreviewPatchLevels.classify(command, world)
	if classified.is_empty():
		return false
	if PreviewPatchLevels.rank(classified) > PreviewPatchLevels.rank(level):
		return false
	var snapshot: AuthoringWorld = world.duplicate()
	if snapshot == null:
		return false
	if not _apply_edit(command):
		world = snapshot
		return false
	preview_revision += 1
	return true


func play_bomb_count() -> int:
	return view.play_bomb_count(self)


func play_dash_count() -> int:
	return view.play_dash_count(self)


func play_stun_remaining() -> int:
	return view.play_stun_remaining(self)


func play_supported_by_solid() -> bool:
	return view.play_supported_by_solid(self)


func play_portal_latched() -> bool:
	return view.play_portal_latched(self)


func play_broke_this_tick() -> bool:
	return view.play_broke_this_tick(self)


func play_vy() -> int:
	return view.play_vy(self)


func play_airborne() -> bool:
	return view.play_airborne(self)


func _apply_edit(command: SharedCommand) -> bool:
	var decoded: EditPayload = EditPayload.decode(command.payload)
	if not decoded.ok:
		return false
	if not _preconditions(decoded):
		return false
	return _apply_decoded(decoded)


func _preconditions(decoded: EditPayload) -> bool:
	match decoded.op:
		EditOpNames.PLACE:
			return decoded.record != null and not world.has_entity(decoded.record.entity_id)
		EditOpNames.REMOVE:
			return world.has_entity(decoded.entity_id)
		EditOpNames.SET_COMPONENT:
			return decoded.record != null and world.has_entity(decoded.record.entity_id)
		_:
			return false


func _apply_decoded(decoded: EditPayload) -> bool:
	match decoded.op:
		EditOpNames.PLACE:
			return world.put(decoded.record)
		EditOpNames.REMOVE:
			return world.remove(decoded.entity_id)
		EditOpNames.SET_COMPONENT:
			return world.replace(decoded.record)
		_:
			return false


func _reset_play_if_out_of_range() -> bool:
	return scan.reset_play_if_out_of_range(self)


func _resolve_play_hazards() -> bool:
	return scan.resolve_play_hazards(self)


func _play_stunned() -> bool:
	return scan.play_stunned(self)


func _tick_play_stun() -> void:
	scan.tick_play_stun(self)


func _accept_overlapping_play_pads() -> void:
	scan.accept_overlapping_play_pads(self)


func _resolve_play_portals() -> bool:
	return scan.resolve_play_portals(self)


func _accept_overlapping_play_finish() -> void:
	scan.accept_overlapping_play_finish(self)


func _grant_play_pickups() -> void:
	scan.grant_play_pickups(self)
