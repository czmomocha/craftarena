class_name AuthoringSession
extends RefCounted

## CD-32 链路：EditCommand → AuthoringWorld → Revision 或完整拒绝。
## Undo/Redo 对成功命令应用反向 payload，不新增第四个 op。
## Lattice / floor / portal_link 由 AuthoringWorld 在 put/replace 上拒绝。
## 发布前通路 / 循环走 evaluate_reachability。
## Preview 是独立 AuthoringPreview 会话，不在 try_apply 上推 Patch。
## AuthoringDocument 是桌面/Web 共同快照；surface 只约束工具，不写入文档。

var world: AuthoringWorld = AuthoringWorld.new()
var surface: String = AuthoringSurfaceNames.DESKTOP_FULL
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


static func create(p_surface: String) -> AuthoringSession:
	if not AuthoringSurfaceNames.contains(p_surface):
		return null
	var session: AuthoringSession = AuthoringSession.new()
	session.surface = p_surface
	return session


func export_document() -> Dictionary:
	return AuthoringDocument.encode(world)


func import_document(data: Dictionary) -> bool:
	var loaded: AuthoringWorld = AuthoringDocument.decode(data)
	if loaded == null:
		return false
	world = loaded
	_undo.clear()
	_redo.clear()
	return true


func try_apply(command: SharedCommand) -> bool:
	if command == null:
		return false
	if command.kind != SharedCommand.Kind.EDIT:
		return false
	if command.expected_revision != world.revision:
		return false
	var decoded: EditPayload = EditPayload.decode(command.payload)
	if not decoded.ok:
		return false
	if not _preconditions(decoded):
		return false
	var inverse: Dictionary = EditPayload.inverse(command.payload, world)
	if inverse.is_empty():
		return false
	if not _apply_decoded(decoded):
		return false
	var entry: Dictionary = {
		"forward": command.payload.duplicate(true),
		"inverse": inverse.duplicate(true),
	}
	_undo.append(entry)
	_redo.clear()
	return true


func undo() -> bool:
	if _undo.is_empty():
		return false
	var entry: Dictionary = _undo[_undo.size() - 1]
	_undo.remove_at(_undo.size() - 1)
	if not _apply_payload(entry["inverse"]):
		_undo.append(entry)
		return false
	_redo.append(entry)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var entry: Dictionary = _redo[_redo.size() - 1]
	_redo.remove_at(_redo.size() - 1)
	if not _apply_payload(entry["forward"]):
		_redo.append(entry)
		return false
	_undo.append(entry)
	return true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func evaluate_reachability() -> Dictionary:
	return AuthoringReachability.evaluate(world)


func _apply_payload(payload: Variant) -> bool:
	if typeof(payload) != TYPE_DICTIONARY:
		return false
	var body: Dictionary = payload
	var decoded: EditPayload = EditPayload.decode(body)
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
