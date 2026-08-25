class_name MatchSnapshotFollow
extends RefCounted

## Latest-authoritative snapshot follower (CD-43).
## Applies a decoded match snapshot as the current presentation state.
## Newer or equal tick replaces; older tick is ignored; a bad frame keeps
## the previous good snapshot. No interpolation, prediction, or correction.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")

var has_snapshot: bool = false
var tick: int = -1
var players: Array = []
var crates: Array = []


func apply_frame(bytes: PackedByteArray) -> bool:
	var decoded: Dictionary = MatchFrameCodec.decode_snapshot(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	var next_tick: int = decoded.get("tick", -1)
	if has_snapshot and next_tick < tick:
		return false
	var next_players: Variant = decoded.get("players", [])
	var next_crates: Variant = decoded.get("crates", [])
	if typeof(next_players) != TYPE_ARRAY or typeof(next_crates) != TYPE_ARRAY:
		return false
	players = next_players
	crates = next_crates
	tick = next_tick
	has_snapshot = true
	return true


func status_view() -> Dictionary:
	return {
		"has_snapshot": has_snapshot,
		"tick": tick,
		"player_count": players.size(),
		"crate_count": crates.size(),
	}


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false
