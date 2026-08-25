class_name MatchMoveFacing
extends RefCounted

## Discrete 8-way horizontal facing for lobby WASD (CD-21 §3 / §8).
## Signs of dx/dz pick a BAM yaw; W is world -Z at yaw 0. Dual-zero
## returns the omitted sentinel. Not atan2, not a product turn speed,
## and not Preview WASD.

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const YAW_OMITTED: int = -1
const YAW_FORWARD: int = 0
const YAW_FORWARD_LEFT: int = 8192
const YAW_LEFT: int = 16384
const YAW_BACK_LEFT: int = 24576
const YAW_BACK: int = 32768
const YAW_BACK_RIGHT: int = 40960
const YAW_RIGHT: int = 49152
const YAW_FORWARD_RIGHT: int = 57344


static func yaw_bam_from_dx_dz(dx: int, dz: int) -> int:
	if dx == 0 and dz == 0:
		return YAW_OMITTED
	var east: int = 0
	if dx > 0:
		east = 1
	elif dx < 0:
		east = -1
	var south: int = 0
	if dz > 0:
		south = 1
	elif dz < 0:
		south = -1
	if east == 0 and south == -1:
		return YAW_FORWARD
	if east == -1 and south == -1:
		return YAW_FORWARD_LEFT
	if east == -1 and south == 0:
		return YAW_LEFT
	if east == -1 and south == 1:
		return YAW_BACK_LEFT
	if east == 0 and south == 1:
		return YAW_BACK
	if east == 1 and south == 1:
		return YAW_BACK_RIGHT
	if east == 1 and south == 0:
		return YAW_RIGHT
	return YAW_FORWARD_RIGHT


static func move_axes(forward: bool, back: bool, left: bool, right: bool, step: int) -> Dictionary:
	if step < 1:
		return {}
	var dx: int = 0
	var dz: int = 0
	if right:
		dx += step
	if left:
		dx -= step
	if back:
		dz += step
	if forward:
		dz -= step
	if dx == 0 and dz == 0:
		return {}
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
		"yaw_bam": yaw_bam_from_dx_dz(dx, dz),
	}
