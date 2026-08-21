extends GutTest

const SharedDomainEvent := preload("res://src/shared/events/shared_domain_event.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")


func test_valid_event_is_accepted() -> void:
	var event: SharedDomainEvent = SharedDomainEvent.create(
		11, 3, 9, 1, "CheckpointReached", {"index": 2}, "trace-1"
	)
	assert_not_null(event)
	assert_eq(event.event_id, 11)
	assert_eq(event.tick, 3)
	assert_eq(event.source_command_id, 1)


func test_system_event_may_omit_actor_and_command() -> void:
	var event: SharedDomainEvent = SharedDomainEvent.create(
		11, 0, 0, 0, "MatchStarted", {}, "trace-boot"
	)
	assert_not_null(event)


func test_invalid_event_id_or_empty_type_is_rejected() -> void:
	assert_null(SharedDomainEvent.create(0, 0, 0, 0, "MatchStarted", {}, "trace-1"))
	assert_null(SharedDomainEvent.create(11, 0, 0, 0, "", {}, "trace-1"))
	assert_null(SharedDomainEvent.create(11, -1, 0, 0, "MatchStarted", {}, "trace-1"))


func test_payload_object_is_rejected() -> void:
	var node: Node = Node.new()
	autofree(node)
	assert_null(SharedDomainEvent.create(11, 0, 0, 0, "Boom", {"who": node}, "trace-1"))


func test_feed_hasher_is_stable() -> void:
	var left: StateHasher = StateHasher.new()
	var right: StateHasher = StateHasher.new()
	var event: SharedDomainEvent = SharedDomainEvent.create(
		11, 3, 9, 1, "CheckpointReached", {"index": 2}, "trace-1"
	)
	event.feed_hasher(left)
	event.feed_hasher(right)
	assert_eq(left.digest_hex(), right.digest_hex())
