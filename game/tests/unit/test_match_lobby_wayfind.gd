extends GutTest

## 可玩性深化 轨 1 在对局壳上的接线：状态行 `next=`、玩法 HUD 导航行、
## 本席头顶箭头、传送/复位后的镜头滑行。占位表现只烟测（节点在不在、数量对不对），
## 强断言留给 `PlayWayfinder` / `CameraFollowTransition` 那两份纯逻辑。

const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

var _shell: MatchLobbyShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func _open_shell() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	assert_true(shell.open())
	return shell


func test_idle_lobby_shows_no_guide_at_all() -> void:
	_shell = _open_shell()
	assert_false(_shell.status_label_text().contains("next="))
	assert_eq(_shell.guide_label_text(), "")
	assert_eq(_shell.map.guide_count(), 0)


func test_solo_play_publishes_the_next_target_on_every_readout() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var line: String = _shell.status_label_text()
	assert_true(line.contains("next="), line)
	assert_true(line.contains("cp"), "首个目标是 order 与已验收数相等的那块垫")
	assert_ne(_shell.guide_label_text(), "", "玩法 HUD 也要有一行给玩家读")
	assert_eq(_shell.map.guide_count(), 1, "箭头只挂本席")
	assert_not_null(_shell.map.guide_node(0))


func test_guide_arrow_points_horizontally_and_sits_above_the_head() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var guide: MeshInstance3D = _shell.map.guide_node(0)
	assert_not_null(guide)
	if guide == null:
		return
	assert_almost_eq(guide.position.y, PlaceholderSpec.GUIDE_LIFT, 0.0001)
	var flat: Vector2 = Vector2(guide.position.x, guide.position.z)
	assert_almost_eq(flat.length(), PlaceholderSpec.GUIDE_FORWARD_M, 0.0001)


func test_leaving_play_drops_the_guide_and_the_token() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.map.guide_count(), 1)
	assert_true(_shell.try_stop_offline())
	assert_eq(_shell.map.guide_count(), 0)
	assert_false(_shell.status_label_text().contains("next="))
	assert_eq(_shell.guide_label_text(), "")


func test_camera_snaps_on_the_first_frame_and_glides_only_after_a_jump() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	# 入局第一帧直接就位——那不是跳变，是「还没有锚点」。
	assert_false(_shell.map.camera_teleport_active())
	var player: MeshInstance3D = _shell.map.player_node(0)
	assert_not_null(player)
	var camera: Camera3D = _shell.map.camera_node()
	assert_not_null(camera)
	if player == null or camera == null:
		return
	var expected: Vector3 = player.position + PlaceholderSpec.CAMERA_OFFSET
	assert_almost_eq(camera.position.x, expected.x, 0.0001)
	assert_almost_eq(camera.position.z, expected.z, 0.0001)
	# 常态移动一帧远小于跳变阈值，不得引入跟随延迟。
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_false(_shell.map.camera_teleport_active())
