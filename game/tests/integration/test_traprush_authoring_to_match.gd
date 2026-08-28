extends GutTest

## CD-53 §2.3 里已经落地、且确实跨层的集成路径。
##
## 这一层原先空着：AuthoringWorld 编译、Preview 安全 Tick、Headless 双人、
## 离线不写库，各自的断言都堆在 `tests/unit/`。本章把它们按层放回
## `integration/`，让目录名不再撒谎。
##
## 仍未实现、因此本章不假装覆盖的 §2.3 项：内容下载与哈希校验、
## P2/P3 只影响新房、回滚后新房恢复旧版本（均属 M4，冻结令不得开工）。
## 断线重连的 HTTP 补票在后端单测；这里只验对局进程内「断开丢排队、
## 同槽再占、进度还在」——那是服务端权威会话侧，不是网关补票。
##
## 进程内 MatchRealtime，不是多 OS 进程、不是真 socket。真多客户端
## 仍是人工网络清单（CD-53 §2.5 / CD-91 D.8）。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchOfflineSession := preload("res://src/client/match_offline_session.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchHeadlessAcceptance := preload("res://src/games/traprush/match_headless_acceptance.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const FINISH_STEPS: int = 5


func test_authoring_document_compiles_into_a_two_player_headless_finish() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 3)
	assert_eq(bundle.finish.size(), 1)
	var result: Dictionary = TraprushMatchHeadlessAcceptance.try_run()
	var ok: bool = result.get("ok", false)
	var finish0: int = result.get("finish0", -1)
	var finish1: int = result.get("finish1", -1)
	var mvp_slot: int = result.get("mvp_slot", -2)
	var replay_match: bool = result.get("replay_match", false)
	var allows_settlement: bool = result.get("allows_settlement", false)
	var allows_online_writes: bool = result.get("allows_online_writes", true)
	assert_true(ok)
	assert_eq(finish0, 4)
	assert_eq(finish1, 4)
	assert_eq(mvp_slot, 0)
	assert_true(replay_match)
	assert_true(allows_settlement)
	assert_false(allows_online_writes)


func test_preview_compiles_advances_and_refuses_patches_until_stop() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.is_safe_point())
	# 真实角色尺寸。半径决定竖直扫掠的取样密度，写 1 会把这条跑成十几分钟，
	# 见 docs/audits/2026-08-28-ci-gate-timeout.md。
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	assert_true(preview.is_playing())
	assert_false(preview.is_safe_point())
	assert_eq(preview.play_world.tick_index, 0)
	assert_true(preview.try_advance_play())
	assert_eq(preview.play_world.tick_index, 1)
	var patch: SharedCommand = _place_portal_edit(preview.world.revision)
	assert_false(preview.try_apply_patch(Levels.P2, patch))
	assert_false(preview.world.has_entity(50))
	assert_true(preview.try_stop_play())
	assert_true(preview.is_safe_point())
	assert_true(preview.try_apply_patch(Levels.P2, _place_portal_edit(preview.world.revision)))
	assert_true(preview.world.has_entity(50))
	assert_false(preview.allows_online_writes())
	assert_false(preview.allows_settlement())


func test_offline_finish_does_not_allow_online_writes() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01_PATH))
	for _index: int in range(FINISH_STEPS):
		assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	assert_eq(offline.session.player_finish_tick(0), 0)
	assert_eq(offline.session.player_accepted_count(0), 3)
	assert_false(offline.allows_settlement())
	assert_false(offline.allows_online_writes())
	var banner: String = str(offline.status_view().get("banner", ""))
	assert_eq(banner, MatchOfflineSession.BANNER)


func test_disconnect_keeps_authority_and_drops_queued_command() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	assert_eq(realtime.add_player(), 0)
	assert_true(realtime.accept_command(0, _move_cell()))
	realtime.commit_tick()
	var after_move: Dictionary = realtime.session.player_pose(0)
	var after_x: int = after_move.get("x", -1)
	var accepted_before: int = realtime.session.player_accepted_count(0)
	assert_eq(after_x, CELL)
	assert_true(realtime.accept_command(0, _move_cell()))
	assert_eq(realtime.pending_count(), 1)
	assert_true(realtime.remove_player(0))
	assert_eq(realtime.pending_count(), 0)
	assert_false(realtime.is_occupied(0))
	assert_true(realtime.occupy_slot(0))
	realtime.commit_tick()
	var after_rejoin: Dictionary = realtime.session.player_pose(0)
	var rejoin_x: int = after_rejoin.get("x", -1)
	assert_eq(rejoin_x, CELL)
	assert_eq(realtime.session.player_accepted_count(0), accepted_before)
	assert_false(realtime.allows_online_writes())


func _two_player_realtime() -> MatchRealtime:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
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
	assert_not_null(session)
	return MatchRealtime.create(session)


func _move_cell() -> PackedByteArray:
	return MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)


func _place_portal_edit(expected_revision: int) -> SharedCommand:
	return SharedCommand.create(
		1,
		2,
		1,
		0,
		expected_revision,
		"content-v1",
		{
			"op": "place",
			"record": {
				"schema_version": 1,
				"entity_id": 50,
				"components": {
					"transform": {"x": CELL, "y": 0, "z": 0, "yaw_bam": 0},
					"portal": {"target_id": 51, "yaw_bam": 0, "cooldown_ticks": 0},
				},
			},
		},
		"trace-integration-preview",
		SharedCommand.Kind.EDIT
	)
