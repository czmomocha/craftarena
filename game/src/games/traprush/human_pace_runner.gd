class_name TraprushHumanPaceRunner
extends RefCounted

## 真人节奏跑手：按 PlaceholderSpec.MOVE_STEP 每 tick 推一格的 1/16，测时长。
##
## 磁带格式（本文件锁定）：PackedByteArray，**每个 byte = 一个 tick 的一个意图**。
## 字节值与完赛探针 TraprushCourseCompletionProbe 相同：
##   0 move+x / 1 move-x / 2 move+z / 3 move-z / 8 jump / 9 use_item / 10 wait
## 解释不同：探针里一个 Move 码 = 走 1 格（dx/dz = SCALE）；这里一个 Move 码 =
## 本 tick 走 MOVE_STEP（SCALE/16）。对角码 4–7 整条拒绝，不拆成正交 tick。
##
## `expand_cells(action, n)` 把「走 n 格」展成 n * (SCALE / MOVE_STEP) 个相同
## Move 码。`expand_probe_actions` 把探针磁带（1 action / 格）展成人跑磁带：
## 四向 Move 各展 1 格，Jump / UseItem / Wait 仍是 1 tick。
##
## 每 tick 至多一个意图：Move / Jump / UseItem / Wait。Wait = 不发意图，只
## commit_tick。会话走 TraprushMatchSession + PlayStubs.apply_match，与对局同一套。
## 不进协议。数字是观测，不是产品门禁。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const OUTCOME_COMPLETABLE: String = "completable"
const OUTCOME_NOT_COMPLETABLE: String = "not_completable"
const OUTCOME_INVALID_COURSE: String = "invalid_course"

const REASON_TAPE_EXHAUSTED: String = "tape_exhausted"
const REASON_INTENT_REJECTED: String = "intent_rejected"
const REASON_DIAGONAL_REJECTED: String = "diagonal_rejected"
const REASON_BAD_TAPE: String = "bad_tape"
const REASON_COMPILE_FAILED: String = "compile_failed"
const REASON_SESSION_FAILED: String = "session_failed"
const REASON_NO_FINISH: String = "no_finish"
const REASON_BUDGET_EXHAUSTED: String = "budget_exhausted"

const ACTION_MOVE_POS_X: int = 0
const ACTION_MOVE_NEG_X: int = 1
const ACTION_MOVE_POS_Z: int = 2
const ACTION_MOVE_NEG_Z: int = 3
const ACTION_DIAGONAL_FIRST: int = 4
const ACTION_DIAGONAL_LAST: int = 7
const ACTION_JUMP: int = 8
const ACTION_USE_ITEM: int = 9
const ACTION_WAIT: int = 10

const _DIR_X: Array[int] = [1, -1, 0, 0]
const _DIR_Z: Array[int] = [0, 0, 1, -1]
const _MATCH_SEED: int = 1


static func ticks_per_cell() -> int:
	return Fixed.SCALE / PlaceholderSpec.MOVE_STEP


static func is_cardinal_move(action: int) -> bool:
	return action >= ACTION_MOVE_POS_X and action <= ACTION_MOVE_NEG_Z


static func is_diagonal(action: int) -> bool:
	return action >= ACTION_DIAGONAL_FIRST and action <= ACTION_DIAGONAL_LAST


static func is_human_action(action: int) -> bool:
	return is_cardinal_move(action) or action == ACTION_JUMP or action == ACTION_USE_ITEM or action == ACTION_WAIT


## 把「走 cell_count 格」展成每 tick 一个 MOVE_STEP 的四向码。非四向或 n<1 回空。
static func expand_cells(action: int, cell_count: int) -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	if not is_cardinal_move(action) or cell_count < 1:
		return packed
	var ticks: int = ticks_per_cell()
	var cell_i: int = 0
	while cell_i < cell_count:
		var tick_i: int = 0
		while tick_i < ticks:
			packed.append(action)
			tick_i += 1
		cell_i += 1
	return packed


## 探针磁带 → 人跑磁带。对角码或未知码整条拒绝。
static func expand_probe_actions(probe_actions: PackedByteArray) -> Dictionary:
	var tape: PackedByteArray = PackedByteArray()
	for action: int in probe_actions:
		if is_diagonal(action):
			return _tape_fail(REASON_DIAGONAL_REJECTED)
		if is_cardinal_move(action):
			var expanded: PackedByteArray = expand_cells(action, 1)
			for code: int in expanded:
				tape.append(code)
		elif action == ACTION_JUMP or action == ACTION_USE_ITEM or action == ACTION_WAIT:
			tape.append(action)
		else:
			return _tape_fail(REASON_BAD_TAPE)
	return {"ok": true, "reason": "", "tape": tape}


## `--tape=` 的人跑格式：逗号分隔的每 tick 意图码。对角 / 非人跑码整条拒绝。
static func parse_tick_codes(raw: String) -> Dictionary:
	var tape: PackedByteArray = PackedByteArray()
	var pieces: PackedStringArray = raw.split(",", true)
	if pieces.is_empty():
		return _tape_fail(REASON_BAD_TAPE)
	for piece: String in pieces:
		var token: String = piece.strip_edges()
		if token == "" or not token.is_valid_int():
			return _tape_fail(REASON_BAD_TAPE)
		var action: int = token.to_int()
		if is_diagonal(action):
			return _tape_fail(REASON_DIAGONAL_REJECTED)
		if not is_human_action(action):
			return _tape_fail(REASON_BAD_TAPE)
		tape.append(action)
	return {"ok": true, "reason": "", "tape": tape}


static func run_path(
	path: String,
	tape: PackedByteArray,
	max_ticks: int = 0
) -> Dictionary:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return _invalid(REASON_COMPILE_FAILED)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return _invalid(REASON_COMPILE_FAILED)
	return run_bundle(bundle, tape, max_ticks)


static func run_bundle(
	bundle: SimulationBundle,
	tape: PackedByteArray,
	max_ticks: int = 0
) -> Dictionary:
	if bundle == null:
		return _invalid(REASON_COMPILE_FAILED)
	var tape_check: Dictionary = _validate_tape(tape)
	var tape_ok: bool = tape_check.get("ok", false)
	if not tape_ok:
		return _unfinished(
			str(tape_check.get("reason", REASON_BAD_TAPE)),
			0,
			[],
			-1
		)
	if bundle.finish.is_empty():
		return _unfinished(REASON_NO_FINISH, 0, [], -1)
	var session: TraprushMatchSession = _fresh_session(bundle)
	if session == null:
		return _invalid(REASON_SESSION_FAILED)
	var checkpoint_ticks: Array = _accepted_ticks_so_far(session, [])
	if session.player_finish_tick(0) >= 0:
		return _finished(session, checkpoint_ticks)
	var played: int = 0
	for action: int in tape:
		if max_ticks > 0 and played >= max_ticks:
			return _unfinished_session(
				REASON_BUDGET_EXHAUSTED, session, checkpoint_ticks
			)
		if not _apply_tick(session, action):
			return _unfinished_session(
				REASON_INTENT_REJECTED, session, checkpoint_ticks
			)
		played += 1
		checkpoint_ticks = _accepted_ticks_so_far(session, checkpoint_ticks)
		if session.player_finish_tick(0) >= 0:
			return _finished(session, checkpoint_ticks)
	return _unfinished_session(REASON_TAPE_EXHAUSTED, session, checkpoint_ticks)


static func _apply_tick(session: TraprushMatchSession, action: int) -> bool:
	if action == ACTION_WAIT:
		session.commit_tick()
		return true
	var payload: Dictionary = _intent_payload(action)
	if payload.is_empty():
		return false
	if not session.apply_player_intent(0, payload):
		return false
	session.commit_tick()
	return true


static func _intent_payload(action: int) -> Dictionary:
	if action == ACTION_JUMP:
		return {"intent": PlayerIntentNames.JUMP}
	if action == ACTION_USE_ITEM:
		return {"intent": PlayerIntentNames.USE_ITEM}
	if not is_cardinal_move(action):
		return {}
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": _DIR_X[action] * PlaceholderSpec.MOVE_STEP,
		"dz": _DIR_Z[action] * PlaceholderSpec.MOVE_STEP,
	}


static func _fresh_session(bundle: SimulationBundle) -> TraprushMatchSession:
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		_MATCH_SEED,
		1,
		offsets,
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT,
	)
	if session == null:
		return null
	PlayStubs.apply_match(session)
	return session


static func _accepted_ticks_so_far(
	session: TraprushMatchSession, previous: Array
) -> Array:
	var ticks: Array = previous.duplicate()
	var accepted: int = session.player_accepted_count(0)
	var now_tick: int = session.tick_index()
	while ticks.size() < accepted:
		ticks.append(now_tick)
	return ticks


static func _validate_tape(tape: PackedByteArray) -> Dictionary:
	for action: int in tape:
		if is_diagonal(action):
			return {"ok": false, "reason": REASON_DIAGONAL_REJECTED}
		if not is_human_action(action):
			return {"ok": false, "reason": REASON_BAD_TAPE}
	return {"ok": true, "reason": ""}


static func _finished(session: TraprushMatchSession, checkpoint_ticks: Array) -> Dictionary:
	return _result_from_session(OUTCOME_COMPLETABLE, "", session, checkpoint_ticks)


static func _unfinished_session(
	reason: String,
	session: TraprushMatchSession,
	checkpoint_ticks: Array
) -> Dictionary:
	return _result_from_session(
		OUTCOME_NOT_COMPLETABLE, reason, session, checkpoint_ticks
	)


static func _unfinished(
	reason: String,
	total_ticks: int,
	checkpoint_ticks: Array,
	finish_tick: int
) -> Dictionary:
	return _result(
		OUTCOME_NOT_COMPLETABLE,
		reason,
		total_ticks,
		checkpoint_ticks,
		finish_tick,
		0,
		0,
		0
	)


static func _invalid(reason: String) -> Dictionary:
	return _result(OUTCOME_INVALID_COURSE, reason, 0, [], -1, 0, 0, 0)


static func _result_from_session(
	outcome: String,
	reason: String,
	session: TraprushMatchSession,
	checkpoint_ticks: Array
) -> Dictionary:
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	return _result(
		outcome,
		reason,
		session.tick_index(),
		checkpoint_ticks,
		session.player_finish_tick(0),
		pose_x,
		pose_y,
		pose_z
	)


static func _result(
	outcome: String,
	reason: String,
	total_ticks: int,
	checkpoint_ticks: Array,
	finish_tick: int,
	x: int,
	y: int,
	z: int
) -> Dictionary:
	return {
		"outcome": outcome,
		"reason": reason,
		"total_ticks": total_ticks,
		"checkpoint_ticks": checkpoint_ticks,
		"finish_tick": finish_tick,
		"x": x,
		"y": y,
		"z": z,
	}


static func _tape_fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "tape": PackedByteArray()}
