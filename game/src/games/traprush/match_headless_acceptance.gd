class_name TraprushMatchHeadlessAcceptance
extends RefCounted

## CD-61 §4.1 的 2 人 Headless 对局夹具：官方 course_01 编进 TraprushMatchSession，
## 经 MatchRealtime 占用两个槽位，每槽每 tick 一条 Move 跑完冲线。
## 同磁带同快照字节；同 tick 连发 Move 只应用第一条。名次由 TraprushStanding
## 从快照派生。全员冲线后生成结算 payload（不 HTTP）。无在线写、不锁 Tick Hz /
## 插值 / 路径距离。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")
const TraprushStanding := preload("res://src/games/traprush/standing.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const FINISH_STEPS: int = 5


static func try_run() -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var gate: Dictionary = _run_flood_gate()
	if not gate.get("ok", false):
		return failed
	var race: Dictionary = _run_two_player_finish()
	if not race.get("ok", false):
		return failed
	var replay: Dictionary = _run_replay_match()
	if not replay.get("ok", false):
		return failed
	return {
		"ok": true,
		"flood_applied_cells": gate.get("applied_cells", 0),
		"finish0": race.get("finish0", -1),
		"finish1": race.get("finish1", -1),
		"mvp_slot": race.get("mvp_slot", -1),
		"replay_match": true,
		"allows_settlement": race.get("allows_settlement", false),
		"settlement_hash": race.get("settlement_hash", ""),
		"allows_online_writes": false,
	}


static func _run_flood_gate() -> Dictionary:
	var realtime: MatchRealtime = _two_player_realtime()
	if realtime == null:
		return {"ok": false}
	var slot: int = realtime.add_player()
	if slot != 0:
		return {"ok": false}
	var before: Dictionary = realtime.session.player_pose(slot)
	var before_x: int = before.get("x", -1)
	var accepted: int = 0
	for _index: int in range(FINISH_STEPS):
		if realtime.accept_command(slot, _move_cell()):
			accepted += 1
	if accepted != 1:
		return {"ok": false}
	if realtime.pending_count() != 1:
		return {"ok": false}
	realtime.commit_tick()
	var after: Dictionary = realtime.session.player_pose(slot)
	var after_x: int = after.get("x", -1)
	if after_x != before_x + CELL:
		return {"ok": false}
	if realtime.allows_settlement() or realtime.allows_online_writes():
		return {"ok": false}
	return {"ok": true, "applied_cells": 1}


static func _run_two_player_finish() -> Dictionary:
	var realtime: MatchRealtime = _two_player_realtime()
	if realtime == null:
		return {"ok": false}
	if realtime.add_player() != 0:
		return {"ok": false}
	if realtime.add_player() != 1:
		return {"ok": false}
	for _step: int in range(FINISH_STEPS):
		if not realtime.accept_command(0, _move_cell()):
			return {"ok": false}
		if not realtime.accept_command(1, _move_cell()):
			return {"ok": false}
		if realtime.accept_command(0, _move_cell()):
			return {"ok": false}
		realtime.commit_tick()
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	if not snapshot.get("ok", false):
		return {"ok": false}
	var players_raw: Variant = snapshot.get("players", [])
	if typeof(players_raw) != TYPE_ARRAY:
		return {"ok": false}
	var players: Array = players_raw
	if players.size() != 2:
		return {"ok": false}
	var p0: Dictionary = players[0]
	var p1: Dictionary = players[1]
	var finish0: int = p0.get("finish_tick", -1)
	var finish1: int = p1.get("finish_tick", -1)
	if finish0 != 4 or finish1 != 4:
		return {"ok": false}
	var standing: Dictionary = TraprushStanding.from_players(players, 3)
	if not standing.get("ok", false):
		return {"ok": false}
	var mvp_slot: int = standing.get("mvp_slot", -2)
	if mvp_slot != 0:
		return {"ok": false}
	if not realtime.allows_settlement():
		return {"ok": false}
	var built: Dictionary = TraprushMatchSettlement.try_build(realtime.session)
	if not built.get("ok", false):
		return {"ok": false}
	var settlement_hash: String = built.get("state_hash", "")
	if settlement_hash.is_empty():
		return {"ok": false}
	return {
		"ok": true,
		"finish0": finish0,
		"finish1": finish1,
		"mvp_slot": mvp_slot,
		"allows_settlement": true,
		"settlement_hash": settlement_hash,
	}


static func _run_replay_match() -> Dictionary:
	var first: MatchRealtime = _two_player_realtime()
	var second: MatchRealtime = _two_player_realtime()
	if first == null or second == null:
		return {"ok": false}
	first.add_player()
	first.add_player()
	second.add_player()
	second.add_player()
	for _step: int in range(FINISH_STEPS):
		var command: PackedByteArray = _move_cell()
		if not first.accept_command(0, command):
			return {"ok": false}
		if not first.accept_command(1, command):
			return {"ok": false}
		if not second.accept_command(0, command):
			return {"ok": false}
		if not second.accept_command(1, command):
			return {"ok": false}
		first.commit_tick()
		second.commit_tick()
		if first.snapshot_frame() != second.snapshot_frame():
			return {"ok": false}
		if first.session.hash_state() != second.session.hash_state():
			return {"ok": false}
	return {"ok": true}


static func _two_player_realtime() -> MatchRealtime:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	if world == null:
		return null
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return null
	var offsets: Array[Dictionary] = []
	for index: int in range(2):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		1,
		2,
		offsets,
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	if session == null:
		return null
	return MatchRealtime.create(session)


static func _move_cell() -> PackedByteArray:
	return MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
