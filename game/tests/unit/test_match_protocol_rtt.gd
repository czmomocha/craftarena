extends GutTest

## Protocol RTT sampler: injected clock, in-flight seq gate, rolling samples,
## optional JSONL. Does not lock Tick / snapshot / interpolation.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchProtocolRtt := preload("res://src/client/match_protocol_rtt.gd")

const LOG_PATH: String = "user://c3_protocol_rtt_test.jsonl"


func after_each() -> void:
	_remove_log()


func test_round_trip_records_rtt_and_percentiles() -> void:
	var sampler: MatchProtocolRtt = MatchProtocolRtt.new()
	sampler.probe_every_ms = 10
	var first: PackedByteArray = sampler.try_emit_ping(100)
	assert_eq(first, MatchFrameCodec.encode_ping(1, 100))
	assert_true(sampler.try_emit_ping(105).is_empty())
	var pong: PackedByteArray = MatchFrameCodec.echo_pong(first)
	var accepted: Dictionary = sampler.try_accept_pong(pong, 107)
	var accepted_ok: bool = accepted.get("ok", false)
	assert_true(accepted_ok)
	var rtt_ms: int = accepted.get("rtt_ms", -1)
	assert_eq(rtt_ms, 7)
	assert_eq(sampler.last_rtt_ms, 7)
	assert_eq(sampler.sample_count(), 1)
	assert_eq(sampler.percentile_ms(50), 7)
	assert_eq(sampler.percentile_ms(95), 7)
	var second: PackedByteArray = sampler.try_emit_ping(120)
	assert_eq(second, MatchFrameCodec.encode_ping(2, 120))
	var second_pong: Dictionary = sampler.try_accept_pong(MatchFrameCodec.echo_pong(second), 140)
	var second_ok: bool = second_pong.get("ok", false)
	assert_true(second_ok)
	assert_eq(sampler.sample_count(), 2)
	assert_eq(sampler.percentile_ms(50), 7)
	assert_eq(sampler.percentile_ms(90), 20)
	var view: Dictionary = sampler.status_view()
	var view_n: int = view.get("rtt_n", 0)
	var view_last: int = view.get("rtt_ms", -1)
	assert_eq(view_n, 2)
	assert_eq(view_last, 20)


func test_stale_pong_and_snapshot_are_rejected() -> void:
	var sampler: MatchProtocolRtt = MatchProtocolRtt.new()
	var ping: PackedByteArray = sampler.try_emit_ping(10)
	var wrong_seq: Dictionary = sampler.try_accept_pong(MatchFrameCodec.encode_pong(99, 10), 12)
	var wrong_seq_ok: bool = wrong_seq.get("ok", true)
	assert_false(wrong_seq_ok)
	var wrong_ms: Dictionary = sampler.try_accept_pong(MatchFrameCodec.encode_pong(1, 11), 12)
	var wrong_ms_ok: bool = wrong_ms.get("ok", true)
	assert_false(wrong_ms_ok)
	var snapshot_as_pong: Dictionary = sampler.try_accept_pong(MatchFrameCodec.encode_snapshot(1, [], []), 12)
	var snapshot_ok: bool = snapshot_as_pong.get("ok", true)
	assert_false(snapshot_ok)
	var early: Dictionary = sampler.try_accept_pong(MatchFrameCodec.echo_pong(ping), 9)
	var early_ok: bool = early.get("ok", true)
	assert_false(early_ok)
	assert_eq(sampler.sample_count(), 0)
	var late: Dictionary = sampler.try_accept_pong(MatchFrameCodec.echo_pong(ping), 14)
	var late_ok: bool = late.get("ok", false)
	assert_true(late_ok)
	assert_eq(sampler.last_rtt_ms, 4)


func test_loss_timeout_then_next_ping() -> void:
	var sampler: MatchProtocolRtt = MatchProtocolRtt.new()
	sampler.probe_every_ms = 10
	sampler.loss_timeout_ms = 50
	assert_false(sampler.try_emit_ping(0).is_empty())
	assert_true(sampler.try_emit_ping(40).is_empty())
	var next_ping: PackedByteArray = sampler.try_emit_ping(50)
	assert_eq(next_ping, MatchFrameCodec.encode_ping(2, 50))
	assert_eq(sampler.loss_count, 1)
	assert_eq(sampler.sample_count(), 0)


func test_jsonl_append_has_no_host() -> void:
	_remove_log()
	var sampler: MatchProtocolRtt = MatchProtocolRtt.new()
	sampler.log_path = LOG_PATH
	var ping: PackedByteArray = sampler.try_emit_ping(8)
	var logged: Dictionary = sampler.try_accept_pong(MatchFrameCodec.echo_pong(ping), 11)
	var logged_ok: bool = logged.get("ok", false)
	assert_true(logged_ok)
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	assert_not_null(file)
	var parsed: Variant = JSON.parse_string(file.get_line())
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var row: Dictionary = parsed
	var event_name: String = row.get("event", "")
	var logged_rtt: int = row.get("rtt_ms", -1)
	assert_eq(event_name, "protocol_rtt")
	assert_eq(logged_rtt, 3)
	assert_false(row.has("host"))
	assert_false(str(row).contains("127.0.0.1"))


func _remove_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var absolute: String = ProjectSettings.globalize_path(LOG_PATH)
	DirAccess.remove_absolute(absolute)
