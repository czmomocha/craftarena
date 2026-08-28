class_name MatchProtocolRtt
extends RefCounted

## Client-side protocol RTT sampler (C3 ch.6). Ping/pong bytes come from
## MatchFrameCodec; this type owns seq, in-flight gate, samples, and optional
## JSONL. It does not lock Tick / snapshot / interpolation (CD-43 §4).
## probe_every_ms is injected so it is not a new HEARTBEAT_EVERY_TICKS copy.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")

const DEFAULT_PROBE_EVERY_MS: int = 1000
const DEFAULT_LOSS_TIMEOUT_MS: int = 5000
const MAX_SAMPLES: int = 2048

var probe_every_ms: int = DEFAULT_PROBE_EVERY_MS
var loss_timeout_ms: int = DEFAULT_LOSS_TIMEOUT_MS
var log_path: String = ""
var last_rtt_ms: int = -1
var loss_count: int = 0

var _last_seq: int = 0
var _last_send_ms: int = -1
var _awaiting: bool = false
var _samples: PackedInt32Array = PackedInt32Array()


func reset() -> void:
	last_rtt_ms = -1
	loss_count = 0
	_last_seq = 0
	_last_send_ms = -1
	_awaiting = false
	_samples = PackedInt32Array()


func sample_count() -> int:
	return _samples.size()


func percentile_ms(pct: int) -> int:
	if _samples.is_empty():
		return -1
	if pct < 0 or pct > 100:
		return -1
	var ranked: PackedInt32Array = _samples.duplicate()
	ranked.sort()
	var index: int = (pct * ranked.size() + 99) / 100 - 1
	if index < 0:
		index = 0
	if index >= ranked.size():
		index = ranked.size() - 1
	return ranked[index]


func try_emit_ping(now_ms: int) -> PackedByteArray:
	if now_ms < 0:
		return PackedByteArray()
	if _awaiting:
		if now_ms - _last_send_ms < loss_timeout_ms:
			return PackedByteArray()
		_awaiting = false
		loss_count += 1
		_append_log({
			"event": "protocol_rtt_loss",
			"seq": _last_seq,
			"t_ms": now_ms,
		})
	if _last_send_ms >= 0 and now_ms - _last_send_ms < probe_every_ms:
		return PackedByteArray()
	_last_seq += 1
	_last_send_ms = now_ms
	_awaiting = true
	return MatchFrameCodec.encode_ping(_last_seq, now_ms)


func try_accept_pong(bytes: PackedByteArray, now_ms: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var decoded: Dictionary = MatchFrameCodec.decode_pong(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return failed
	if not _awaiting:
		return failed
	var seq: int = decoded.get("seq", -1)
	var send_ms: int = decoded.get("client_send_ms", -1)
	if seq != _last_seq or send_ms != _last_send_ms:
		return failed
	if now_ms < send_ms:
		return failed
	var rtt_ms: int = now_ms - send_ms
	_awaiting = false
	last_rtt_ms = rtt_ms
	if _samples.size() >= MAX_SAMPLES:
		_samples.remove_at(0)
	_samples.append(rtt_ms)
	_append_log({
		"event": "protocol_rtt",
		"seq": seq,
		"rtt_ms": rtt_ms,
		"t_ms": now_ms,
	})
	return {"ok": true, "seq": seq, "rtt_ms": rtt_ms}


func status_view() -> Dictionary:
	return {
		"rtt_ms": last_rtt_ms,
		"rtt_n": _samples.size(),
		"rtt_p50_ms": percentile_ms(50),
		"rtt_p90_ms": percentile_ms(90),
		"rtt_p95_ms": percentile_ms(95),
		"rtt_lost": loss_count,
	}


static func append_jsonl(path: String, payload: Dictionary) -> bool:
	var target: String = path.strip_edges()
	if target == "":
		return false
	var file: FileAccess = null
	if FileAccess.file_exists(target):
		file = FileAccess.open(target, FileAccess.READ_WRITE)
		if file == null:
			return false
		file.seek_end()
	else:
		file = FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			return false
	file.store_line(JSON.stringify(payload))
	return true


func _append_log(payload: Dictionary) -> void:
	if log_path.strip_edges() == "":
		return
	append_jsonl(log_path, payload)
