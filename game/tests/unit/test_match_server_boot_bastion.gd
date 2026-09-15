extends GutTest

## M6 E3：MatchServerBoot 按玩法分派。省略 `--gameplay` 仍是 TRAPRUSH。
## `--gameplay=bastion` 编译官方蓝图进 BastionMatchSession，席位锁 2。
## 内容信封仍是 TRAPRUSH-only。本刀没有画面。

const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const MatchServer := preload("res://src/server/match_server.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const BLUEPRINT_01_PATH: String = "res://content/official/bastion/blueprint_01.json"
const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"


func test_omitted_gameplay_stays_traprush() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1", "port": "42000", "course": COURSE_01_PATH, "players": "2",
	})
	var ok: bool = config.get("ok", false)
	var gameplay: String = str(config.get("gameplay", ""))
	assert_true(ok)
	assert_eq(gameplay, MatchGameplayGd.TRAPRUSH)
	var session: RefCounted = MatchServer.boot_session(config)
	assert_true(session is TraprushMatchSession)


func test_bastion_boot_requires_two_seats_and_a_blueprint_path() -> void:
	var ok_config: Dictionary = MatchServer._boot_config({
		"match-id": "m1",
		"port": "42000",
		"course": BLUEPRINT_01_PATH,
		"players": "2",
		"gameplay": MatchGameplayGd.BASTION,
	})
	var ok: bool = ok_config.get("ok", false)
	var gameplay: String = str(ok_config.get("gameplay", ""))
	assert_true(ok)
	assert_eq(gameplay, MatchGameplayGd.BASTION)
	assert_false(_boot_ok({
		"match-id": "m1",
		"port": "42000",
		"course": BLUEPRINT_01_PATH,
		"players": "4",
		"gameplay": MatchGameplayGd.BASTION,
	}))
	assert_false(_boot_ok({
		"match-id": "m1",
		"port": "42000",
		"content-envelope": COURSE_01_PATH,
		"players": "2",
		"gameplay": MatchGameplayGd.BASTION,
	}))
	assert_false(_boot_ok({
		"match-id": "m1",
		"port": "42000",
		"players": "2",
		"gameplay": MatchGameplayGd.BASTION,
	}))


func test_boot_official_blueprint_01_starts_setup() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1",
		"port": "42000",
		"course": BLUEPRINT_01_PATH,
		"players": "2",
		"gameplay": MatchGameplayGd.BASTION,
	})
	var session: RefCounted = MatchServer.boot_session(config)
	assert_true(session is BastionMatchSession)
	var bastion: BastionMatchSession = session as BastionMatchSession
	assert_eq(bastion.player_count(), MatchGameplayGd.BASTION_SEATS)
	assert_eq(bastion.phase, BastionMatchSession.PHASE_SETUP)
	assert_eq(MatchGameplayGd.team_id_for_seat(0), MatchGameplayGd.TEAM_A)
	assert_eq(MatchGameplayGd.team_id_for_seat(1), MatchGameplayGd.TEAM_B)
	assert_eq(MatchGameplayGd.seat_for_team_id(MatchGameplayGd.TEAM_A), 0)
	assert_eq(MatchGameplayGd.seat_for_team_id(MatchGameplayGd.TEAM_B), 1)


func test_boot_graybox_blueprint_also_starts() -> void:
	var config: Dictionary = MatchServer._boot_config({
		"match-id": "m1",
		"port": "42000",
		"course": GRAYBOX_PATH,
		"players": "2",
		"gameplay": MatchGameplayGd.BASTION,
	})
	var ok: bool = config.get("ok", false)
	assert_true(ok)
	var session: RefCounted = MatchServer.boot_session(config)
	assert_true(session is BastionMatchSession)


func _boot_ok(options: Dictionary) -> bool:
	var config: Dictionary = MatchServer._boot_config(options)
	var ok: bool = config.get("ok", false)
	return ok
