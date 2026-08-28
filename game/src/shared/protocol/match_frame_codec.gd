class_name MatchFrameCodec
extends RefCounted

## 对局实时面二进制协议 v1（纯 GDScript，不绑定 ScenePath）。依据 CD-43 §1：
## 控制面走 JSON，实时命令与快照走版本化二进制 Schema。
## 命令帧定长 35 字节：[version:u8][type:u8=1][tick:s64][intent_id:u8]
## [dx:s64][dz:s64][yaw_bam:s64]。非 Move 意图的 dx/dz/yaw 是保留字段，
## 编码解码都要求为零；yaw_bam = -1 表示省略（与 MoveIntent 口径一致）。
## 快照帧变长：[version:u8][type:u8=2][tick:s64][player_count:u8]
## 随后每玩家 41 字节（x/y/z/yaw_bam s64×4 + accepted_count:u8 + finish_tick:s64），
## 再 [crate_count:u8] 与每箱 16 字节（entity_id:s64 + durability:s64，0 为已毁）。
## 探针帧定长 18 字节：[version:u8][type:u8=3 ping / 4 pong][seq:s64][client_send_ms:s64]。
## 服务端原样回显 seq 与 client_send_ms，不入命令队列、不推进仿真、不续租。
## 解码拒绝：版本不符、未知类型、截断、尾随字节、保留字段非零。
## 命令是规范的：同一逻辑帧恒得同一字节序列。字节序为 PackedByteArray 原生小端。
## 命令帧不带 slot：连接身份由服务端持有。SprintIntent id=6。Shove 已接线但无线上目标 id；
## Interact 仍未接线。新增 id / 帧类型属协议变更，旧解码器拒绝。Tick/快照频率不在本文件锁定（CD-43 §4）。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const PROTOCOL_VERSION: int = 1
const FRAME_COMMAND: int = 1
const FRAME_SNAPSHOT: int = 2
const FRAME_PING: int = 3
const FRAME_PONG: int = 4

const _COMMAND_SIZE: int = 35
const _SNAPSHOT_HEADER: int = 11
const _SNAPSHOT_PLAYER: int = 41
const _SNAPSHOT_CRATE: int = 16
const _PROBE_SIZE: int = 18
const _YAW_BAM_OMITTED: int = -1

const _INTENT_TO_ID: Dictionary = {
	"MoveIntent": 1,
	"JumpIntent": 2,
	"ResetToCheckpointIntent": 3,
	"UseItemIntent": 4,
	"ShoveIntent": 5,
	"SprintIntent": 6,
}
const _ID_TO_INTENT: Dictionary = {
	1: "MoveIntent",
	2: "JumpIntent",
	3: "ResetToCheckpointIntent",
	4: "UseItemIntent",
	5: "ShoveIntent",
	6: "SprintIntent",
}


static func encode_command(
	tick: int,
	intent_name: String,
	dx: int,
	dz: int,
	yaw_bam: int
) -> PackedByteArray:
	if not _INTENT_TO_ID.has(intent_name):
		return PackedByteArray()
	if intent_name != PlayerIntentNames.MOVE and (dx != 0 or dz != 0 or yaw_bam != 0):
		return PackedByteArray()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_COMMAND_SIZE)
	bytes.encode_u8(0, PROTOCOL_VERSION)
	bytes.encode_u8(1, FRAME_COMMAND)
	bytes.encode_s64(2, tick)
	var intent_id: int = _INTENT_TO_ID[intent_name]
	bytes.encode_u8(10, intent_id)
	bytes.encode_s64(11, dx)
	bytes.encode_s64(19, dz)
	bytes.encode_s64(27, yaw_bam)
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
	var dx: int = bytes.decode_s64(11)
	var dz: int = bytes.decode_s64(19)
	var yaw_bam: int = bytes.decode_s64(27)
	if intent_name != PlayerIntentNames.MOVE and (dx != 0 or dz != 0 or yaw_bam != 0):
		return failed
	return {
		"ok": true,
		"tick": bytes.decode_s64(2),
		"intent": intent_name,
		"dx": dx,
		"dz": dz,
		"yaw_bam": yaw_bam,
	}


static func encode_snapshot(
	tick: int,
	players: Array[Dictionary],
	crates: Array[Dictionary]
) -> PackedByteArray:
	if players.size() > 255 or crates.size() > 255:
		return PackedByteArray()
	var size: int = _SNAPSHOT_HEADER + players.size() * _SNAPSHOT_PLAYER + 1 + crates.size() * _SNAPSHOT_CRATE
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	bytes.encode_u8(0, PROTOCOL_VERSION)
	bytes.encode_u8(1, FRAME_SNAPSHOT)
	bytes.encode_s64(2, tick)
	bytes.encode_u8(10, players.size())
	var offset: int = _SNAPSHOT_HEADER
	for player: Dictionary in players:
		var accepted_count: int = player.get("accepted_count", -1)
		if accepted_count < 0 or accepted_count > 255:
			return PackedByteArray()
		var x: int = player.get("x", 0)
		var y: int = player.get("y", 0)
		var z: int = player.get("z", 0)
		var yaw_bam: int = player.get("yaw_bam", 0)
		var finish_tick: int = player.get("finish_tick", -1)
		bytes.encode_s64(offset, x)
		bytes.encode_s64(offset + 8, y)
		bytes.encode_s64(offset + 16, z)
		bytes.encode_s64(offset + 24, yaw_bam)
		bytes.encode_u8(offset + 32, accepted_count)
		bytes.encode_s64(offset + 33, finish_tick)
		offset += _SNAPSHOT_PLAYER
	bytes.encode_u8(offset, crates.size())
	offset += 1
	for crate: Dictionary in crates:
		var entity_id: int = crate.get("entity_id", 0)
		var durability: int = crate.get("durability", 0)
		bytes.encode_s64(offset, entity_id)
		bytes.encode_s64(offset + 8, durability)
		offset += _SNAPSHOT_CRATE
	return bytes


static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bytes.size() < _SNAPSHOT_HEADER + 1:
		return failed
	if bytes.decode_u8(0) != PROTOCOL_VERSION:
		return failed
	if bytes.decode_u8(1) != FRAME_SNAPSHOT:
		return failed
	var player_count: int = bytes.decode_u8(10)
	var crates_at: int = _SNAPSHOT_HEADER + player_count * _SNAPSHOT_PLAYER
	if bytes.size() < crates_at + 1:
		return failed
	var crate_count: int = bytes.decode_u8(crates_at)
	if bytes.size() != crates_at + 1 + crate_count * _SNAPSHOT_CRATE:
		return failed
	var players: Array[Dictionary] = []
	var offset: int = _SNAPSHOT_HEADER
	for index: int in range(player_count):
		players.append({
			"x": bytes.decode_s64(offset),
			"y": bytes.decode_s64(offset + 8),
			"z": bytes.decode_s64(offset + 16),
			"yaw_bam": bytes.decode_s64(offset + 24),
			"accepted_count": bytes.decode_u8(offset + 32),
			"finish_tick": bytes.decode_s64(offset + 33),
		})
		offset += _SNAPSHOT_PLAYER
	offset += 1
	var crates: Array[Dictionary] = []
	for index: int in range(crate_count):
		crates.append({
			"entity_id": bytes.decode_s64(offset),
			"durability": bytes.decode_s64(offset + 8),
		})
		offset += _SNAPSHOT_CRATE
	return {
		"ok": true,
		"tick": bytes.decode_s64(2),
		"players": players,
		"crates": crates,
	}


static func encode_ping(seq: int, client_send_ms: int) -> PackedByteArray:
	return _encode_probe(FRAME_PING, seq, client_send_ms)


static func encode_pong(seq: int, client_send_ms: int) -> PackedByteArray:
	return _encode_probe(FRAME_PONG, seq, client_send_ms)


static func decode_ping(bytes: PackedByteArray) -> Dictionary:
	return _decode_probe(bytes, FRAME_PING)


static func decode_pong(bytes: PackedByteArray) -> Dictionary:
	return _decode_probe(bytes, FRAME_PONG)


## 合法 ping 则编码对应 pong；其它帧返回空。服务端用它回显，不解析时钟。
static func echo_pong(bytes: PackedByteArray) -> PackedByteArray:
	var decoded: Dictionary = decode_ping(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return PackedByteArray()
	var seq: int = decoded.get("seq", 0)
	var client_send_ms: int = decoded.get("client_send_ms", 0)
	return encode_pong(seq, client_send_ms)


static func _encode_probe(frame_type: int, seq: int, client_send_ms: int) -> PackedByteArray:
	if seq < 1 or client_send_ms < 0:
		return PackedByteArray()
	if frame_type != FRAME_PING and frame_type != FRAME_PONG:
		return PackedByteArray()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_PROBE_SIZE)
	bytes.encode_u8(0, PROTOCOL_VERSION)
	bytes.encode_u8(1, frame_type)
	bytes.encode_s64(2, seq)
	bytes.encode_s64(10, client_send_ms)
	return bytes


static func _decode_probe(bytes: PackedByteArray, frame_type: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bytes.size() != _PROBE_SIZE:
		return failed
	if bytes.decode_u8(0) != PROTOCOL_VERSION:
		return failed
	if bytes.decode_u8(1) != frame_type:
		return failed
	var seq: int = bytes.decode_s64(2)
	var client_send_ms: int = bytes.decode_s64(10)
	if seq < 1 or client_send_ms < 0:
		return failed
	return {
		"ok": true,
		"seq": seq,
		"client_send_ms": client_send_ms,
	}
