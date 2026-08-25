class_name MatchRealtime
extends RefCounted

## 对局实时核心：包在 TraprushMatchSession 外的连接槽位与命令队列。
## 依据 CD-43 §3：服务器权威快照模型——命令帧里的 tick 只解码不信任，
## 意图在服务端自己的 commit_tick 边界按到达顺序应用；快照帧编码全部已配置
## 槽位（含未占用）与可破坏箱耐久。槽位 0..N-1 按需占用，断开即释放占用（仿真进度保留，同一席位可再占用）。
## 每占用槽位每个 commit_tick 至多入队一条命令（先到先得），后到的同槽命令拒绝。
## 断开丢弃该槽已排队命令，避免旧意图落到新连接。这是位置伪造门禁：同 tick
## 连发多条 Move 不能在一次仿真步里叠成瞬移。墙钟发送速率仍待（CD-63）。
## 本类不碰 socket：传输是 match_server.gd 的薄层；网络正确性测试保持手动
## （CD-91 D.8 manual_network_tests）。全员冲线后允许生成结算 payload；
## 不在线写入、不 HTTP。

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")

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


## 占用指定席位。已占用则失败。用于网关带上的票据 seat。
func occupy_slot(slot: int) -> bool:
	if session == null:
		return false
	if slot < 0 or slot >= session.player_count():
		return false
	if _occupied.has(slot):
		return false
	_occupied[slot] = true
	return true


## 从 WebSocket 请求 URL 读 `slot` 查询。缺席位不算错误；非法值拒绝。
static func parse_requested_slot(raw: String) -> Dictionary:
	var text: String = raw.strip_edges()
	var query: String = text
	var q_index: int = text.find("?")
	if q_index >= 0:
		query = text.substr(q_index + 1)
	var frag: int = query.find("#")
	if frag >= 0:
		query = query.substr(0, frag)
	var found: bool = false
	var slot_value: int = -1
	for part: String in query.split("&"):
		var eq: int = part.find("=")
		if eq <= 0:
			continue
		if part.substr(0, eq) != "slot":
			continue
		var value: String = part.substr(eq + 1).uri_decode().strip_edges()
		found = true
		if not value.is_valid_int():
			return {"present": true, "ok": false}
		slot_value = value.to_int()
		if slot_value < 0 or slot_value > 7:
			return {"present": true, "ok": false}
	if not found:
		return {"present": false, "ok": true}
	return {"present": true, "ok": true, "slot": slot_value}


func remove_player(slot: int) -> bool:
	if not _occupied.has(slot):
		return false
	_occupied.erase(slot)
	_drop_queued(slot)
	return true


func occupied_count() -> int:
	return _occupied.size()


func is_occupied(slot: int) -> bool:
	return _occupied.has(slot)


func pending_count() -> int:
	return _queue.size()


## 解码二进制命令帧并入队（FIFO），下一 commit_tick 才应用。
## 拒绝：槽位未占用、该槽本 tick 已有排队、帧不可解码（含快照帧）。
func accept_command(slot: int, bytes: PackedByteArray) -> bool:
	if session == null:
		return false
	if not _occupied.has(slot):
		return false
	if _queue_has_slot(slot):
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


func allows_settlement() -> bool:
	return TraprushMatchSettlement.all_finished(session)


func allows_online_writes() -> bool:
	return false


func _queue_has_slot(slot: int) -> bool:
	for item: Dictionary in _queue:
		var queued_slot: int = item["slot"]
		if queued_slot == slot:
			return true
	return false


func _drop_queued(slot: int) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in _queue:
		var queued_slot: int = item["slot"]
		if queued_slot != slot:
			kept.append(item)
	_queue = kept


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
