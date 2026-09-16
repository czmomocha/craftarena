class_name BastionInteract
extends RefCounted

## Local selection only. Submitting an intent never mutates the field map;
## the gadget appears when the next authoritative snapshot says so.

const CodecGd := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const RouterGd := preload("res://src/games/bastion/audio_router.gd")

const KIND_NONE: String = ""
const KIND_BUILD: String = "build"
const KIND_OBSTACLE: String = "obstacle"

var selected_kind: String = KIND_NONE
var selected_id: int = 0
var last_event: String = ""


func reset() -> void:
	selected_kind = KIND_NONE
	selected_id = 0
	last_event = ""


func try_select(kind: String, id: int) -> bool:
	if kind != KIND_BUILD and kind != KIND_OBSTACLE:
		return false
	if id < 1:
		return false
	selected_kind = kind
	selected_id = id
	last_event = RouterGd.EVENT_SELECT
	return true


func encode_prototype(prototype_id: int) -> PackedByteArray:
	last_event = ""
	if selected_kind == KIND_BUILD:
		var bytes: PackedByteArray = CodecGd.encode_command(
			0, PlayerIntentNamesGd.BUILD_TOWER, selected_id, prototype_id, 0
		)
		if not bytes.is_empty():
			last_event = RouterGd.EVENT_CONFIRM
		return bytes
	if selected_kind == KIND_OBSTACLE:
		var placed: PackedByteArray = CodecGd.encode_command(
			0, PlayerIntentNamesGd.PLACE_OBSTACLE, selected_id, prototype_id, 0
		)
		if not placed.is_empty():
			last_event = RouterGd.EVENT_CONFIRM
		return placed
	return PackedByteArray()


func encode_lock() -> PackedByteArray:
	last_event = ""
	var bytes: PackedByteArray = CodecGd.encode_command(
		0, PlayerIntentNamesGd.LOCK_SETUP, 0, 0, 0
	)
	if not bytes.is_empty():
		last_event = RouterGd.EVENT_CONFIRM
	return bytes


func encode_upgrade() -> PackedByteArray:
	return _slot_command(PlayerIntentNamesGd.UPGRADE_TOWER)


func encode_sell() -> PackedByteArray:
	return _slot_command(PlayerIntentNamesGd.SELL_TOWER)


func _slot_command(intent_name: String) -> PackedByteArray:
	last_event = ""
	if selected_kind != KIND_BUILD or selected_id < 1:
		return PackedByteArray()
	var bytes: PackedByteArray = CodecGd.encode_command(0, intent_name, selected_id, 0, 0)
	if not bytes.is_empty():
		last_event = RouterGd.EVENT_CONFIRM
	return bytes
