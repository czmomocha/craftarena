class_name MatchRealtime
extends RefCounted

## 对局实时核心：包在 TraprushMatchSession 外的连接槽位与命令队列。
## 依据 CD-43 §3：服务器权威快照模型——命令帧里的 tick 只解码不信任，
## 意图在服务端自己的 commit_tick 边界按到达顺序应用；快照帧编码全部已配置
## 槽位（含未占用）与可破坏箱耐久。槽位 0..N-1 按需占用，断开即释放。
## 本类不碰 socket：传输是 match_server.gd 的薄层；网络正确性测试保持手动
## （CD-91 D.8 manual_network_tests）。无结算、不在线写入。
## 防伪造校验（速率/合法性门禁）是后续章节，本类只保证帧可解码、槽位已占用。

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")

const _YAW_BAM_OMITTED: int = -1

var session: TraprushMatchSession = null

var _occupied: Dictionary = {}
var _queue: Array[Dictionary] = []


static func create(match_session: TraprushMatchSession) -> MatchRealtime:
	if match_session == null:
		return null
	var realtime: MatchRealtime = MatchRealtime.new()
	realtime.session = match_session
	return realtime


## 占用最小的空槽位；满员（达到会话配置人数）返回 -1。
func add_player() -> int:
	if session == null:
		return -1
	for slot: int in range(session.player_count()):
		if not _occupied.has(slot):
			_occupied[slot] = true
			return slot
	return -1


func remove_player(slot: int) -> bool:
	if not _occupied.has(slot):
		return false
	_occupied.erase(slot)
	return true


func occupied_count() -> int:
	return _occupied.size()


func is_occupied(slot: int) -> bool:
	return _occupied.has(slot)


## 解码二进制命令帧并入队（FIFO），下一 commit_tick 才应用。
## 拒绝：槽位未占用、帧不可解码。
func accept_command(slot: int, bytes: PackedByteArray) -> bool:
	if session == null:
		return false
	if not _occupied.has(slot):
		return false
	var decoded: Dictionary = MatchFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	_queue.append({"slot": slot, "payload": _payload_from(decoded)})
	return true


## 按到达顺序应用已排队命令，然后推进会话 tick（含占用扫描）。
func commit_tick() -> void:
	if session == null:
		return
	var pending: Array[Dictionary] = _queue
	_queue = []
	for item: Dictionary in pending:
		var slot: int = item["slot"]
		if not _occupied.has(slot):
			continue
		var payload: Dictionary = item["payload"]
		session.apply_player_intent(slot, payload)
	session.commit_tick()


## 当前状态的快照帧：全部已配置槽位（含未占用）+ 可破坏箱耐久。
func snapshot_frame() -> PackedByteArray:
	if session == null:
		return PackedByteArray()
	var players: Array[Dictionary] = []
	for slot: int in range(session.player_count()):
		var pose: Dictionary = session.player_pose(slot)
		players.append({
			"x": pose.get("x", 0),
			"y": pose.get("y", 0),
			"z": pose.get("z", 0),
			"yaw_bam": pose.get("yaw", 0),
			"accepted_count": session.player_accepted_count(slot),
			"finish_tick": session.player_finish_tick(slot),
		})
	return MatchFrameCodec.encode_snapshot(
		session.tick_index(),
		players,
		session.destructible_states()
	)


static func _payload_from(decoded: Dictionary) -> Dictionary:
	var intent_name: String = decoded.get("intent", "")
	if intent_name == PlayerIntentNames.MOVE:
		var payload: Dictionary = {
			"intent": intent_name,
			"dx": decoded.get("dx", 0),
			"dz": decoded.get("dz", 0),
		}
		var yaw_bam: int = decoded.get("yaw_bam", _YAW_BAM_OMITTED)
		if yaw_bam != _YAW_BAM_OMITTED:
			payload["yaw_bam"] = yaw_bam
		return payload
	return {"intent": intent_name}
