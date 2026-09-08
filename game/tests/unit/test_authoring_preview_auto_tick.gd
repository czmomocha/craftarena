extends GutTest

## 可玩性深化 轨 3：Preview 连续试玩。此前只有「Advance tick」一颗按钮，
## 走一段路要点几百下——对拿到链接的外人那不是试玩。

const AuthoringPreviewShellGd := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringPreviewHostKindsGd := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringSessionGd := preload("res://src/creator/authoring_session.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const PLAY_RADIUS: int = PlaceholderSpec.CHARACTER_RADIUS

var _shell: AuthoringPreviewShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func _open_on_course_01() -> AuthoringPreviewShellGd:
	var world: AuthoringWorld = AuthoringDocumentGd.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var session: AuthoringSessionGd = AuthoringSessionGd.create(AuthoringSurfaceNamesGd.WEB_LIGHT)
	assert_not_null(session)
	assert_true(session.import_document(AuthoringDocumentGd.encode(world)))
	var shell: AuthoringPreviewShellGd = AuthoringPreviewShellGd.create(
		AuthoringPreviewHostKindsGd.WINDOW
	)
	add_child(shell)
	assert_true(shell.open_from(session))
	return shell


func test_auto_tick_is_on_by_default() -> void:
	_shell = _open_on_course_01()
	assert_true(_shell.play_auto_tick, "默认连续跑；单步是调试用的，不是常态")
	var toggle: CheckButton = _shell.chrome.auto_tick_button()
	assert_not_null(toggle)
	if toggle != null:
		assert_true(toggle.button_pressed)


func _play_tick() -> int:
	if _shell.preview == null or _shell.preview.play_world == null:
		return -1
	return _shell.preview.play_world.tick_index


func test_auto_tick_advances_the_simulation_without_clicking_advance() -> void:
	_shell = _open_on_course_01()
	assert_true(_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var before: int = _play_tick()
	_shell._physics_process(1.0 / 60.0)
	_shell._physics_process(1.0 / 60.0)
	assert_eq(_play_tick(), before + 2)


func test_turning_auto_tick_off_freezes_the_simulation() -> void:
	_shell = _open_on_course_01()
	assert_true(_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_shell.set_auto_tick(false)
	var before: int = _play_tick()
	_shell._physics_process(1.0 / 60.0)
	assert_eq(_play_tick(), before)
	assert_true(_shell.try_advance_play(), "单步仍然可用")
	assert_eq(_play_tick(), before + 1)


func test_stun_matches_the_clock_the_creator_is_actually_watching() -> void:
	# 单步时 1 拍就过，否则一次机关命中要多点 60 下；连续跑时必须是 D5 那 1.0 s，
	# 不然「改完立刻试」试到的惩罚不是玩家会遇到的那一个。
	_shell = _open_on_course_01()
	assert_eq(_shell.play_respawn_stun_ticks, TraprushPlayStubsGd.RESPAWN_STUN_TICKS)
	_shell.set_auto_tick(false)
	assert_eq(_shell.play_respawn_stun_ticks, TraprushPlayStubsGd.PREVIEW_RESPAWN_STUN_TICKS)
	_shell.set_auto_tick(true)
	assert_eq(_shell.play_respawn_stun_ticks, TraprushPlayStubsGd.RESPAWN_STUN_TICKS)


func test_auto_tick_stays_off_while_not_playing_or_hidden() -> void:
	_shell = _open_on_course_01()
	_shell._physics_process(1.0 / 60.0)
	assert_false(_shell.preview.is_playing(), "没点开始就不该自己跑")
	assert_true(_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_shell.hide_window()
	var before: int = _play_tick()
	_shell._physics_process(1.0 / 60.0)
	assert_eq(_play_tick(), before, "窗口收起来就停，别在后台空转")
