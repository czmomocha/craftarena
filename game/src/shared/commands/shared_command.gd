class_name SharedCommand
extends RefCounted

## 所有命令共用的 L0 信封。字段名单的所有者是 CD-42 §3.2。
## payload 必须能过 CanonicalPayload；PLAYER 的 intent 名必须在 PlayerIntentNames 内。

enum Kind {
	PLAYER = 1,
	EDIT = 2,
	ADMIN = 3,
	SYSTEM = 4,
}

var command_id: int = SharedIds.NULL_ID
var actor_id: int = SharedIds.NULL_ID
var sequence: int = 0
var target_tick: int = 0
var expected_revision: int = 0
var content_version: String = ""
var payload: Dictionary = {}
var trace_id: String = ""
var kind: int = 0


static func create(
	command_id: int,
	actor_id: int,
	sequence: int,
	target_tick: int,
	expected_revision: int,
	content_version: String,
	payload: Dictionary,
	trace_id: String,
	kind: int
) -> SharedCommand:
	if not SharedIds.is_valid(command_id):
		return null
	if not _actor_id_allowed(kind, actor_id):
		return null
	if sequence < 1:
		return null
	if target_tick < 0:
		return null
	if expected_revision < 0:
		return null
	if content_version.is_empty():
		return null
	if trace_id.is_empty():
		return null
	if not _kind_is_known(kind):
		return null
	if not CanonicalPayload.is_allowed(payload):
		return null
	if kind == Kind.PLAYER and not _player_intent_is_known(payload):
		return null
	var command: SharedCommand = SharedCommand.new()
	command.command_id = command_id
	command.actor_id = actor_id
	command.sequence = sequence
	command.target_tick = target_tick
	command.expected_revision = expected_revision
	command.content_version = content_version
	command.payload = payload.duplicate(true)
	command.trace_id = trace_id
	command.kind = kind
	return command


func feed_hasher(hasher: StateHasher) -> void:
	hasher.write_s64(kind)
	hasher.write_s64(command_id)
	hasher.write_s64(actor_id)
	hasher.write_s64(sequence)
	hasher.write_s64(target_tick)
	hasher.write_s64(expected_revision)
	hasher.write_string(content_version)
	hasher.write_string(trace_id)
	if not hasher.write_canonical(payload):
		push_error("SharedCommand payload must remain canonical after create()")


static func _kind_is_known(kind: int) -> bool:
	return kind == Kind.PLAYER or kind == Kind.EDIT or kind == Kind.ADMIN or kind == Kind.SYSTEM


static func _actor_id_allowed(kind: int, actor_id: int) -> bool:
	if kind == Kind.SYSTEM:
		return actor_id == SharedIds.NULL_ID or SharedIds.is_valid(actor_id)
	return SharedIds.is_valid(actor_id)


static func _player_intent_is_known(payload: Dictionary) -> bool:
	if not payload.has("intent"):
		return false
	var intent_value: Variant = payload["intent"]
	if typeof(intent_value) != TYPE_STRING:
		return false
	var intent_name: String = intent_value
	return PlayerIntentNames.contains(intent_name)
