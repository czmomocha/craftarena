class_name BastionFrameCodec
extends RefCounted

## BASTION 实时面二进制协议，仍是 v1：不升大版本，只加 type 5/6 与 intent id
## 7–12（2026-09-15 人类拍板，[CD-91 D.4](Confirmed-docs/90-reference/91-decision-log.md)
## 键 `bastion_realtime_frames`）。TRAPRUSH 的 type 1–4 布局一个字节不动；
## `MatchFrameCodec.decode_command` / `decode_snapshot` 先查 type，不符即拒，
## 所以旧客户端不会把本帧误读成位姿或箱子。
##
## 命令帧定长 35 字节，形状故意跟 TRAPRUSH 命令帧一样，只换 type 与 id：
## `[version:u8=1][type:u8=5][tick:s64][intent_id:u8][arg0:s64][arg1:s64][arg2:s64]`。
## 未使用的 arg 是保留字段，编解码都要求为零。
## intent_id：7=BuildTower / 8=UpgradeTower / 9=SellTower / 10=SetTowerPriority /
## 11=PlaceObstacle / 12=LockSetup。`DonateResourceIntent` 仍无 id（M7，1v1
## 没有队友）。`InteractIntent` 仍无 id。
##
## 快照帧变长、type=6，布局与裁剪见 `bastion_frame_snapshot.gd`。
## 字节序为 PackedByteArray 原生小端。Tick / 快照频率不在本文件锁定（CD-43 §4）。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SnapshotGd := preload("res://src/shared/protocol/bastion_frame_snapshot.gd")
const Priorities := preload("res://src/shared/schema/tower_target_priorities.gd")

const PROTOCOL_VERSION: int = 1
const FRAME_COMMAND: int = 5
const FRAME_SNAPSHOT: int = 6
const SNAPSHOT_HEADER: int = SnapshotGd.HEADER_SIZE

const INTENT_BUILD_TOWER: int = 7
const INTENT_UPGRADE_TOWER: int = 8
const INTENT_SELL_TOWER: int = 9
const INTENT_SET_PRIORITY: int = 10
const INTENT_PLACE_OBSTACLE: int = 11
const INTENT_LOCK_SETUP: int = 12

const _COMMAND_SIZE: int = 35
const _PRIORITY_FRONT: int = 1
const _PRIORITY_NEAREST: int = 2
const _PRIORITY_STRONGEST: int = 3
const _PRIORITY_WEAKEST: int = 4

const _INTENT_TO_ID: Dictionary = {
	"BuildTowerIntent": INTENT_BUILD_TOWER,
	"UpgradeTowerIntent": INTENT_UPGRADE_TOWER,
	"SellTowerIntent": INTENT_SELL_TOWER,
	"SetTowerPriorityIntent": INTENT_SET_PRIORITY,
	"PlaceObstacleIntent": INTENT_PLACE_OBSTACLE,
	"LockSetupIntent": INTENT_LOCK_SETUP,
}
const _ID_TO_INTENT: Dictionary = {
	INTENT_BUILD_TOWER: "BuildTowerIntent",
	INTENT_UPGRADE_TOWER: "UpgradeTowerIntent",
	INTENT_SELL_TOWER: "SellTowerIntent",
	INTENT_SET_PRIORITY: "SetTowerPriorityIntent",
	INTENT_PLACE_OBSTACLE: "PlaceObstacleIntent",
	INTENT_LOCK_SETUP: "LockSetupIntent",
}


static func encode_command(
	tick: int, intent_name: String, arg0: int, arg1: int, arg2: int
) -> PackedByteArray:
	if not _INTENT_TO_ID.has(intent_name):
		return PackedByteArray()
	if not _args_allowed(intent_name, arg0, arg1, arg2):
		return PackedByteArray()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_COMMAND_SIZE)
	bytes.encode_u8(0, PROTOCOL_VERSION)
	bytes.encode_u8(1, FRAME_COMMAND)
	bytes.encode_s64(2, tick)
	var intent_id: int = _INTENT_TO_ID[intent_name]
	bytes.encode_u8(10, intent_id)
	bytes.encode_s64(11, arg0)
	bytes.encode_s64(19, arg1)
	bytes.encode_s64(27, arg2)
	return bytes


static func decode_command(bytes: PackedByteArray) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bytes.size() != _COMMAND_SIZE:
		return failed
	if bytes.decode_u8(0) != PROTOCOL_VERSION:
		return failed
	if bytes.decode_u8(1) != FRAME_COMMAND:
		return failed
	var intent_id: int = bytes.decode_u8(10)
	if not _ID_TO_INTENT.has(intent_id):
		return failed
	var intent_name: String = _ID_TO_INTENT[intent_id]
	var arg0: int = bytes.decode_s64(11)
	var arg1: int = bytes.decode_s64(19)
	var arg2: int = bytes.decode_s64(27)
	if not _args_allowed(intent_name, arg0, arg1, arg2):
		return failed
	return {
		"ok": true,
		"tick": bytes.decode_s64(2),
		"intent": intent_name,
		"arg0": arg0,
		"arg1": arg1,
		"arg2": arg2,
	}


static func encode_snapshot(
	tick: int,
	phase: int,
	wave_index: int,
	result: int,
	teams: Array[Dictionary],
	viewer_team_id: int
) -> PackedByteArray:
	return SnapshotGd.encode(tick, phase, wave_index, result, teams, viewer_team_id)


static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	return SnapshotGd.decode(bytes)


static func priority_id(priority: String) -> int:
	match priority:
		Priorities.FRONT:
			return _PRIORITY_FRONT
		Priorities.NEAREST:
			return _PRIORITY_NEAREST
		Priorities.STRONGEST:
			return _PRIORITY_STRONGEST
		Priorities.WEAKEST:
			return _PRIORITY_WEAKEST
		_:
			return 0


static func priority_name(priority_code: int) -> String:
	match priority_code:
		_PRIORITY_FRONT:
			return Priorities.FRONT
		_PRIORITY_NEAREST:
			return Priorities.NEAREST
		_PRIORITY_STRONGEST:
			return Priorities.STRONGEST
		_PRIORITY_WEAKEST:
			return Priorities.WEAKEST
		_:
			return ""


static func _args_allowed(intent_name: String, arg0: int, arg1: int, arg2: int) -> bool:
	if arg2 != 0:
		return false
	if intent_name == PlayerIntentNames.LOCK_SETUP:
		return arg0 == 0 and arg1 == 0
	if intent_name == PlayerIntentNames.UPGRADE_TOWER or intent_name == PlayerIntentNames.SELL_TOWER:
		return arg1 == 0
	if intent_name == PlayerIntentNames.SET_TOWER_PRIORITY:
		return not priority_name(arg1).is_empty()
	if intent_name == PlayerIntentNames.BUILD_TOWER or intent_name == PlayerIntentNames.PLACE_OBSTACLE:
		return true
	return false
