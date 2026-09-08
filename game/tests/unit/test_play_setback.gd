extends GutTest

## 可玩性深化 轨 1：失败惩罚可读。
## 原因由服务端在 `TraprushMatchScan` 判定（本文件后半段），读出格式是纯函数
## （前半段）。线上 v1 快照不带原因——那是协议变更，属人类门禁，本刀不做。

const PlaySetbackGd := preload("res://src/shared/play_setback.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const HAZARD_ID: int = 50


# ---- 读出格式 ----

func test_only_the_three_environment_reasons_are_known() -> void:
	assert_true(PlaySetbackGd.contains(PlaySetbackGd.HAZARD))
	assert_true(PlaySetbackGd.contains(PlaySetbackGd.OUT_OF_RANGE))
	assert_true(PlaySetbackGd.contains(PlaySetbackGd.CRUSHED))
	assert_false(PlaySetbackGd.contains(PlaySetbackGd.NONE))
	assert_false(PlaySetbackGd.contains("manual"), "自己按 R 不是失败惩罚")


func test_visibility_window_opens_at_the_setback_and_closes_on_its_own() -> void:
	assert_true(PlaySetbackGd.is_visible(PlaySetbackGd.HAZARD, 100, 100))
	assert_true(PlaySetbackGd.is_visible(PlaySetbackGd.HAZARD, 100, 100 + PlaySetbackGd.SHOW_TICKS - 1))
	assert_false(PlaySetbackGd.is_visible(PlaySetbackGd.HAZARD, 100, 100 + PlaySetbackGd.SHOW_TICKS))
	assert_false(PlaySetbackGd.is_visible(PlaySetbackGd.HAZARD, 100, 99), "不显示未来的失败")
	assert_false(PlaySetbackGd.is_visible(PlaySetbackGd.HAZARD, -1, 0), "本局还没失败过")
	assert_false(PlaySetbackGd.is_visible(PlaySetbackGd.NONE, 10, 10))


func test_token_is_ascii_and_empty_without_a_reason() -> void:
	assert_eq(PlaySetbackGd.token(PlaySetbackGd.OUT_OF_RANGE, 240, 42), "setback=out_of_range@240 stun=42")
	assert_eq(PlaySetbackGd.token(PlaySetbackGd.NONE, 240, 42), "")


func test_text_names_the_cause_the_respawn_and_the_stun() -> void:
	var line: String = PlaySetbackGd.text(
		PlaySetbackGd.HAZARD, 2, 42, UiCopy.FALLBACK_LOCALE
	)
	assert_true(line.contains("trap"), line)
	assert_true(line.contains("checkpoint 1"), "已验收 2 块垫 ⇒ 落点是 order 1 那块")
	assert_true(line.contains("0.7"), line)


func test_text_says_start_before_the_first_checkpoint_and_drops_a_zero_stun() -> void:
	var line: String = PlaySetbackGd.text(
		PlaySetbackGd.OUT_OF_RANGE, 0, 0, UiCopy.FALLBACK_LOCALE
	)
	assert_true(line.contains("start"), line)
	assert_false(line.contains("stunned"), "硬直已经走完就别再占一行")
	assert_eq(PlaySetbackGd.text(PlaySetbackGd.NONE, 0, 0, UiCopy.FALLBACK_LOCALE), "")


func test_short_seconds_round_up_so_the_countdown_never_shows_zero_early() -> void:
	assert_eq(PlayClockGd.format_seconds(60), "1.0")
	assert_eq(PlayClockGd.format_seconds(42), "0.7")
	assert_eq(PlayClockGd.format_seconds(1), "0.1")
	assert_eq(PlayClockGd.format_seconds(0), "0.0")
	assert_eq(PlayClockGd.format_seconds(-5), "0.0")


# ---- 权威判定 ----

func test_hazard_crush_records_the_hazard_reason_and_tick() -> void:
	var session: TraprushMatchSessionGd = _hazard_session()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.NONE)
	assert_eq(session.player_setback_tick(0), -1)
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.HAZARD)
	assert_eq(session.player_setback_tick(0), session.tick_index())


func test_out_of_range_reset_records_the_out_of_range_reason() -> void:
	var session: TraprushMatchSessionGd = _hazard_session()
	session.enable_play_range(CELL / 8)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.OUT_OF_RANGE)


func test_setback_reason_stays_out_of_the_state_hash() -> void:
	# 原因是既有事件（位姿 + stun，两者已入 hash）的读出别名。把它入 hash 只会
	# 让已录制的回放哈希失效，不增加检测力。两局同样跑法必须仍然同哈希。
	var left: TraprushMatchSessionGd = _hazard_session()
	var right: TraprushMatchSessionGd = _hazard_session()
	left.commit_tick()
	right.commit_tick()
	assert_true(left.apply_player_intent(0, _move(CELL, 0)))
	assert_true(right.apply_player_intent(0, _move(CELL, 0)))
	left.commit_tick()
	right.commit_tick()
	assert_eq(left.player_setback_reason(0), PlaySetbackGd.HAZARD)
	assert_eq(left.hash_state(), right.hash_state())


func _hazard_session() -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	assert_true(world.put(SharedComponentRecordGd.create(HAZARD_ID, {
		"transform": {"x": CELL, "y": 0, "z": 0, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})))
	var bundle: SimulationBundle = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	return session


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}
