class_name PlayAnimVisual
extends RefCounted

## C4 表现动画状态 → 视觉驱动（路线 A，人类 2026-09-05 拍板）。
##
## `PlayAnimState` 锁的是状态名与优先级，本文件把裁决结果接到角色的
## `visual` 节点上：**有 clip 的状态播 clip，没有的用程序化姿态补**。
##
## 两张表合起来必须恰好覆盖契约八态（idle / run / jump / land / shove /
## hit / break / portal），这是测试钉住的关系，不是碰巧。
##
## - clip 态：`AnimationPlayer.play(clip)`，同时把 visual 的 transform
##   归零回基准（上一状态可能是姿态态，偏移不能残留）。
## - 姿态态：停 clip，在基准 transform 上叠加一个占位姿态偏移。
##   **数值未定稿**：CD-63 仍延期动画秒数，这里先给"事实驱动的持续
##   姿态"——land 在本拍事实为真时出现一拍，jump 跟 airborne，
##   与 `PlayAnimState` 的裁决节奏一致，不引入时间轴。
##
## Kenney Cube Pets（CC0）没有骨骼（skins=0），动画是部件级节点变换，
## 驱动的是 GLB 内部子节点；姿态偏移写在 visual 根节点上，两者不冲突。
##
## 基准 transform 由 `SharedVisualAssetCatalog.character_base_transform(visual)`
## 提供，**不是**由常量重建。角色贴合（`fit_character_on_cell`）会等比缩放
## 并把结果记进 visual 的 meta，基准因此含 scale；若这里还用
## `Transform3D(Basis(), CHARACTER_FOOT_LIFT)` 重建，姿态态一写 transform 就把
## 缩放抹掉——表现是角色一跳就突然变大。attach 与本文件读同一个入口，这对
## 关系由测试钉住（"apply clip 态回到基准" + "姿态保留缩放"）。
## 未贴合的 visual（裸 Node3D）仍回落到不缩放的老基准。
##
## 放 `shared/` 的理由与 `PlayAnimState` 相同：对局（MatchSnapshotMap）
## 与 Preview（AuthoringPreviewMap）必须读同一份映射，否则两边状态
## 语义漂移。`simulation/` 不引用本文件，视觉从来不是裁决输入。
##
## 安全降级：visual 缺 AnimationPlayer、clip 缺名都不报错——宁可摆个
## 静止模型，也不让大厅出不了人（与 SharedVisualAssetCatalog 的
## 回退哲学一致）。

## 契约状态 → GLB 内置 clip 名（Kenney Cube Pets 动画集）。
## hit 用 gesture-negative（摇头晃脑）、portal 用 dance（进传送门的
## 手舞足蹈），语义近似是路线 A 已接受的折衷。
const CLIP_BY_STATE: Dictionary[String, String] = {
	PlayAnimState.IDLE: "idle",
	PlayAnimState.RUN: "run",
	PlayAnimState.HIT: "gesture-negative",
	PlayAnimState.PORTAL: "dance",
}

## 契约状态 → 程序化姿态。pitch_deg 绕 X 轴（负 = 前倾），lift 沿 Y
## 叠加（负 = 下压）。占位数值，未定稿；换数值不改结构。
const POSE_PITCH_DEG: Dictionary[String, float] = {
	PlayAnimState.JUMP: -20.0,
	PlayAnimState.LAND: 10.0,
	PlayAnimState.SHOVE: -30.0,
	PlayAnimState.BREAK: 25.0,
}

const POSE_LIFT: Dictionary[String, float] = {
	PlayAnimState.JUMP: 0.0,
	PlayAnimState.LAND: -0.12,
	PlayAnimState.SHOVE: 0.0,
	PlayAnimState.BREAK: 0.0,
}


static func covers(state: String) -> bool:
	return CLIP_BY_STATE.has(state) or POSE_PITCH_DEG.has(state)


## 把契约状态接到 visual 上。返回是否有视觉产出：
## false = 状态未知或节点为空；true = clip 或姿态已应用（含降级）。
static func apply(visual: Node3D, state: String) -> bool:
	if visual == null or not covers(state):
		return false
	var player: AnimationPlayer = _animation_player(visual)
	if CLIP_BY_STATE.has(state):
		return _apply_clip(visual, player, CLIP_BY_STATE[state])
	return _apply_pose(visual, player, state)


static func _apply_clip(
	visual: Node3D, player: AnimationPlayer, clip: String
) -> bool:
	_reset_to_base(visual)
	if player == null:
		return true
	if player.has_animation(clip):
		player.play(clip)
	else:
		player.stop()
	return true


static func _apply_pose(
	visual: Node3D, player: AnimationPlayer, state: String
) -> bool:
	if player != null:
		player.stop()
	var base: Transform3D = _base_transform(visual)
	var pitch_deg: float = POSE_PITCH_DEG.get(state, 0.0)
	var lift: float = POSE_LIFT.get(state, 0.0)
	var pitched: Basis = base.basis.rotated(
		Vector3.RIGHT, deg_to_rad(pitch_deg)
	)
	visual.transform = Transform3D(
		pitched,
		base.origin + Vector3(0.0, lift, 0.0)
	)
	return true


static func _reset_to_base(visual: Node3D) -> void:
	visual.transform = _base_transform(visual)


## `Basis.rotated` 是 `rotation * self`，所以基准里的缩放在俯仰之后仍然保留。
static func _base_transform(visual: Node3D) -> Transform3D:
	return SharedVisualAssetCatalog.character_base_transform(visual)


static func _animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found: AnimationPlayer = _animation_player(child)
		if found != null:
			return found
	return null
