class_name BastionMatchSessionWire
extends RefCounted

## 离线会话 → BASTION 快照帧。拆出来是因为 L0 编解码不许引用 L3 会话
## （CD-41 §4），而 E1 的裁剪又必须对着真实 pending 证明，不能只拿手写字典。
##
## 本文件把**权威**状态（含对方 pending）交给编码器。藏住对方布局是
## `BastionFrameCodec.encode_snapshot` 在 phase=SETUP 时按观察者裁剪障碍袋，
## 不是这里先把字典滤一遍——否则编码器忘了裁，测试仍会绿。

const CodecGd := preload("res://src/shared/protocol/bastion_frame_codec.gd")


static func encode_snapshot(session: BastionMatchSession, viewer_team_id: int) -> PackedByteArray:
	if session == null:
		return PackedByteArray()
	var viewer: int = viewer_team_id
	if session.phase != BastionMatchSession.PHASE_SETUP:
		viewer = 0
	return CodecGd.encode_snapshot(
		session.tick,
		session.phase,
		session.wave_index(),
		session.result,
		snapshot_teams(session),
		viewer
	)


static func snapshot_teams(session: BastionMatchSession) -> Array[Dictionary]:
	var teams: Array[Dictionary] = []
	if session == null:
		return teams
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = session._team(team_id)
		if team.is_empty():
			continue
		teams.append({
			"team_id": team_id,
			"core_health": session.core_health(team_id),
			"gold": session.gold(team_id),
			"leaked": session.leaked(team_id),
			"kills": session.kills(team_id),
			"locked": 1 if session.team_setup_locked(team_id) else 0,
			"towers": _towers(team),
			"units": session.unit_states(team_id),
			"obstacles": session.setup_authority_obstacles(team_id),
		})
	return teams


static func _towers(team: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var towers: Array = team["towers"]
	for item: Variant in towers:
		var tower: Dictionary = item
		out.append({
			"slot_id": tower["slot_id"],
			"prototype_id": tower["prototype_id"],
			"level": tower["level"],
			"target_priority": tower["target_priority"],
			"cooldown_left": tower["cooldown_left"],
		})
	return out
