class_name SharedDomainEvent
extends RefCounted

## 服务端事务应用后产生的领域事件。命令管线见 CD-42 §3.3。

var event_id: int = SharedIds.NULL_ID
var tick: int = 0
var actor_id: int = SharedIds.NULL_ID
var source_command_id: int = SharedIds.NULL_ID
var event_type: String = ""
var payload: Dictionary = {}
var trace_id: String = ""


static func create(
	event_id: int,
	tick: int,
	actor_id: int,
	source_command_id: int,
	event_type: String,
	payload: Dictionary,
	trace_id: String
) -> SharedDomainEvent:
	if not SharedIds.is_valid(event_id):
		return null
	if tick < 0:
		return null
	if actor_id != SharedIds.NULL_ID and not SharedIds.is_valid(actor_id):
		return null
	if source_command_id != SharedIds.NULL_ID and not SharedIds.is_valid(source_command_id):
		return null
	if event_type.is_empty():
		return null
	if trace_id.is_empty():
		return null
	if not CanonicalPayload.is_allowed(payload):
		return null
	var event: SharedDomainEvent = SharedDomainEvent.new()
	event.event_id = event_id
	event.tick = tick
	event.actor_id = actor_id
	event.source_command_id = source_command_id
	event.event_type = event_type
	event.payload = payload.duplicate(true)
	event.trace_id = trace_id
	return event


func feed_hasher(hasher: StateHasher) -> void:
	hasher.write_s64(event_id)
	hasher.write_s64(tick)
	hasher.write_s64(actor_id)
	hasher.write_s64(source_command_id)
	hasher.write_string(event_type)
	hasher.write_string(trace_id)
	if not hasher.write_canonical(payload):
		push_error("SharedDomainEvent payload must remain canonical after create()")
