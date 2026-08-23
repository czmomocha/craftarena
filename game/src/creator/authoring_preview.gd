class_name AuthoringPreview
extends RefCounted

## Independent Preview session (CD-32 §4). AuthoringSession stays open.
## Applies P0–P2 EditCommand patches at a safe point; failure restores the
## pre-patch world. P3 waits for Rule VM. P4 sets needs_restart.
## Never settlement or online writes. No Godot Window in this slice.

var world: AuthoringWorld = null
var preview_revision: int = 0
var connected: bool = false
var needs_restart: bool = false
var _in_tick: bool = false


func connect_from(session: AuthoringSession) -> bool:
	if session == null or session.world == null:
		return false
	var cloned: AuthoringWorld = session.world.duplicate()
	if cloned == null:
		return false
	world = cloned
	preview_revision = 0
	connected = true
	needs_restart = false
	_in_tick = false
	return true


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
