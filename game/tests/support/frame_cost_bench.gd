extends SceneTree

## 离线 Solo 每帧 CPU 成本的可复跑微基准。**观察工具，不是门禁。**
##
## CD-53 §1.1 明确不建自动性能回归门禁，所以这里不断言任何毫秒数，只打印。
## 它存在的理由是「改前改后要有同一把尺子」——C4 第 6/7/8 章那几个
## 「12.76 → 0.44 ms」的数字当时是临时量的，没留下能再跑一遍的东西。
##
## 跑法：
##   & $env:GODOT4_CONSOLE --headless --path game -s res://tests/support/frame_cost_bench.gd
##   $env:FRAME_COST_FRAMES=600  # 可选，默认 300
##
## **诚实边界（读数字前必须先读这段）**：
##
## 1. headless 没有真实渲染。节点增删在这里只付 CPU 侧的场景树与 RenderingServer
##    记账，不付 GPU 上传、着色器与 draw call 提交。所以本表**低估**真实窗口下
##    「每帧 free 再 new 一个 Label3D / MeshInstance3D」的代价——真机收益只会比
##    这里大，不会更小。
## 2. 这是 Windows 开发机 debug 解释器的数字，不是产品性能指标，也没在导出包或
##    Linux 上量过。
## 3. 真机 FPS 由人类按 docs/runbooks/dev-window-check.md 本刀走查确认。
##    本文件不能替代那一步（宪法第二十四条）。

const MatchLobbyShell := preload("res://src/client/match_lobby_shell.gd")
const PlaceholderSpec := preload("res://src/shared/placeholder_spec.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const Fixed := preload("res://src/shared/fixed/fixed.gd")
const TraprushGravity := preload("res://src/games/traprush/gravity.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")

const DEFAULT_FRAMES: int = 300
const FRAME_DELTA: float = 1.0 / 60.0


func _initialize() -> void:
	var frames: int = _frame_count()
	var shell: MatchLobbyShell = MatchLobbyShell.create()
	root.add_child(shell)
	if not shell.open():
		printerr("frame_cost_bench: shell.open() failed")
		quit(1)
		return
	if not shell.try_solo():
		printerr("frame_cost_bench: try_solo() failed")
		quit(1)
		return

	# 预热：第一帧要建玩家节点、解析视觉资产、生成字体图集，混进均值会读出一个
	# 假的「每帧很贵」。
	for _warm: int in range(10):
		_frame(shell)

	_trace_over_time(shell, frames)

	var rows: Array[Dictionary] = []
	rows.append(_measure("whole frame (physics + render)", frames, func() -> void:
		_frame(shell)
	))
	rows.append(_measure("  offline.try_advance", frames, func() -> void:
		shell.offline.try_advance()
	))
	rows.append(_measure("    session.commit_tick", frames, func() -> void:
		shell.offline.session.commit_tick()
	))
	rows.append(_measure("      apply_player_falls", frames, func() -> void:
		shell.offline.session.apply_player_falls()
	))
	rows.append(_measure("        Gravity.integrate", frames, func() -> void:
		var session: TraprushMatchSession = shell.offline.session
		TraprushGravity.integrate(session._world, session.player_capsule_id(0), session.fall_dy)
	))
	rows.append(_measure("        _resolve_player_hazards", frames, func() -> void:
		var session: TraprushMatchSession = shell.offline.session
		session._resolve_player_hazards(session._players[0])
	))
	rows.append(_measure("        _reset_player_if_out_of_range", frames, func() -> void:
		var session: TraprushMatchSession = shell.offline.session
		session._reset_player_if_out_of_range(session._players[0])
	))
	rows.append(_measure("      advance_sim_tick", frames, func() -> void:
		shell.offline.session.advance_sim_tick()
	))
	rows.append(_measure("    _publish (encode+decode)", frames, func() -> void:
		shell.offline._publish()
	))
	rows.append(_measure("  _apply_snapshot_map", frames, func() -> void:
		shell._apply_snapshot_map()
	))
	rows.append(_measure("  _refresh_status", frames, func() -> void:
		shell._refresh_status()
	))
	rows.append(_measure("    standings.apply_players", frames, func() -> void:
		shell.standings.apply_players(shell.offline.follow.players, shell.course.pad_count())
	))
	rows.append(_measure("    crates.apply_follow", frames, func() -> void:
		shell.crates.apply_follow(shell.offline.follow)
	))
	rows.append(_measure("    hazards.apply_follow", frames, func() -> void:
		shell.hazards.apply_follow(shell.offline.follow)
	))
	rows.append(_measure("    map.apply_players", frames, func() -> void:
		shell.map.apply_players(shell.offline.follow.players, shell.offline.follow.crates)
	))

	_probe_collision_math(shell, frames)

	print("frame_cost_bench: %d frames, headless, %s" % [frames, _engine_line()])
	print("%10s  %s" % ["ms/call", "section"])
	for row: Dictionary in rows:
		var ms: float = row["ms"]
		var label: String = row["label"]
		print("%10.3f  %s" % [ms, label])
	var whole: float = rows[0]["ms"]
	print(
		"frame budget at 60 FPS is 16.667 ms; the whole frame uses %.1f%% of it"
		% [whole / 16.667 * 100.0]
	)
	shell.queue_free()
	quit(0)


## 每帧成本是常数还是在长？竖直扫掠的步数正比于 |vy|，所以一旦玩家没落到固体上，
## vy 每 tick 累加、扫掠每 tick 变长，成本会**线性发散**。均值读不出这件事，必须分段看。
func _trace_over_time(shell: MatchLobbyShell, frames: int) -> void:
	var bucket: int = maxi(frames / 6, 1)
	print("%8s  %10s  %12s  %12s  %s" % ["tick", "ms/frame", "y", "vy", "sweep steps"])
	for _block: int in range(6):
		var started: int = Time.get_ticks_usec()
		for _i: int in range(bucket):
			_frame(shell)
		var elapsed: int = Time.get_ticks_usec() - started
		var session: TraprushMatchSession = shell.offline.session
		var capsule: int = session.player_capsule_id(0)
		var world: SimulationWorld = session._world
		var pose: Dictionary = world.get_pose(capsule)
		var vy: int = world.get_vy(capsule)
		print("%8d  %10.3f  %12d  %12d  %d" % [
			session.tick_index(),
			float(elapsed) / float(bucket) / 1000.0,
			pose.get("y", 0),
			vy,
			absi(vy) / PlaceholderSpec.CHARACTER_RADIUS,
		])


## 一次 `is_pose_blocked` 要对每个静态盒跑一遍 `overlaps_capsule`，而后者做 4 次
## `Fixed.try_mul`。把盒数与单次定点乘法的代价打出来，才能判断该修哪一层。
func _probe_collision_math(shell: MatchLobbyShell, frames: int) -> void:
	var session: TraprushMatchSession = shell.offline.session
	var world: SimulationWorld = session._world
	var capsule: int = session.player_capsule_id(0)
	var pose: Dictionary = world.get_pose(capsule)
	var px: int = pose.get("x", 0)
	var py: int = pose.get("y", 0)
	var pz: int = pose.get("z", 0)

	var blocked: Dictionary = _measure("is_pose_blocked", frames, func() -> void:
		world.is_pose_blocked(capsule, px, py, pz)
	)
	var boxes: Dictionary = _measure("solid box scan", frames, func() -> void:
		world.overlapping_solid_static_boxes_at(capsule, px, py, pz)
	)
	var mul: Dictionary = _measure("try_mul x1000", frames, func() -> void:
		for _i: int in range(1000):
			Fixed.try_mul(12345678, 87654321)
	)
	var add: Dictionary = _measure("try_add x1000", frames, func() -> void:
		for _i: int in range(1000):
			Fixed.try_add(12345678, 87654321)
	)

	var blocked_ms: float = blocked["ms"]
	var boxes_ms: float = boxes["ms"]
	var mul_ms: float = mul["ms"]
	var add_ms: float = add["ms"]
	print("collision math probe")
	print("  static boxes            %d" % [world._boxes.size()])
	print("  entities                %d" % [world._x.size()])
	print("  is_pose_blocked         %.3f ms" % [blocked_ms])
	print("  solid box scan          %.3f ms" % [boxes_ms])
	print("  Fixed.try_mul           %.4f ms each" % [mul_ms / 1000.0])
	print("  Fixed.try_add           %.4f ms each" % [add_ms / 1000.0])


## 一「帧」= 一次固定步长权威推进 + 一次渲染帧表现。60 FPS 下两者一比一，
## 这也是本表想代表的工况；帧率更高时 `_physics_process` 不会跟着变多。
func _frame(shell: MatchLobbyShell) -> void:
	shell._physics_process(FRAME_DELTA)
	shell._process(FRAME_DELTA)


func _measure(label: String, frames: int, body: Callable) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	for _i: int in range(frames):
		body.call()
	var elapsed: int = Time.get_ticks_usec() - started
	return {
		"label": label,
		"ms": float(elapsed) / float(frames) / 1000.0,
	}


func _frame_count() -> int:
	var raw: String = OS.get_environment("FRAME_COST_FRAMES")
	if raw.is_valid_int():
		var parsed: int = raw.to_int()
		if parsed > 0:
			return parsed
	return DEFAULT_FRAMES


func _engine_line() -> String:
	var info: Dictionary = Engine.get_version_info()
	return "Godot %s" % [info.get("string", "?")]
