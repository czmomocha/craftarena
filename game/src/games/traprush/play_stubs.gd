class_name TraprushPlayStubs
extends RefCounted

## 动作数值的单一配置源。
##
## 跳跃 / 重力已由 F 线 FD 接到产品桩（D-F2 / D-F3）：`JUMP_DY = SCALE*5/4`，
## `FALL_DY = -JUMP_DY`。爆破伤害与推击力度仍未拍板（[CD-63](Confirmed-docs/60-plan/63-open-decisions.md) §1）。
## 例外：`RESPAWN_STUN_MS` 已由纠偏 D5 定为 1.0 s；
## 换算用的 `PHYSICS_TICKS_PER_SECOND_PLACEHOLDER` 仍是当前引擎 physics，不是
## [CD-43](Confirmed-docs/40-technical/43-networking-and-replay.md) 产品 Tick。
##
## 存在的理由是变更成本，不是复用：同一组数字原先抄在对局进程、大厅 Solo 与
## Preview 壳三处，现在又要被 BotRunner 抄第四遍。数值拍板时四处必须同时改，
## 而漏改一处不会报错——只会让 bot 判定的「可完成」与真实对局不是同一件事。
## 冻结令（`.cursor/rules/course-correction-freeze.mdc` §3）因此要求新增消费方
## 改为从单一配置源注入。
##
## 分成两组是因为语义不同，不是因为有人抄错了：
## MATCH 组给随引擎 tick 连续推进的场景（对局进程、Solo、BotRunner）；
## PREVIEW 组的下落加速度与对局同一 `FALL_DY`（F 线 FD；不再用 `-SCALE` 特判）。
##
## 出界半宽不在这里复制，直接用 TraprushOutOfRangeReset.STUB_HALF。

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")

## 一格 hop 的竖直冲量。D-F2：SCALE*5/4，下一拍到顶，峰值 1.25 格。
## apply_jump 把本拍位移和 vy 都写成这个值，后续各拍由重力加速度拉回。
const JUMP_DY: int = Fixed.SCALE * 5 / 4
## 向下探测立足固体，与灰盒同向。
const SUPPORT_DY: int = -Fixed.SCALE
## D-F2 / D-F3：与跳跃冲量等量反向。下一拍到顶，峰值 1.25 格。
const FALL_DY: int = -JUMP_DY
## Preview Advance 与对局同一加速度，不再用 -SCALE 特判。
const PREVIEW_FALL_DY: int = FALL_DY

const USE_ITEM_DAMAGE: int = 1
## reach 只探 +Z 一格：要打箱必须先站到箱的 -Z 侧。不是产品爆破表。
const USE_ITEM_REACH_DX: int = 0
const USE_ITEM_REACH_DY: int = 0
const USE_ITEM_REACH_DZ: int = Fixed.SCALE

## 四分之一格推击步长与 1 tick 冷却，不是产品力度或冷却秒数。
const SHOVE_STEP: int = Fixed.SCALE / 4
const SHOVE_COOLDOWN_TICKS: int = 1
## 一格冲刺步长与 1 tick 道具冷却，不是产品冲刺距离或冷却秒数。
const SPRINT_STEP: int = Fixed.SCALE
const ITEM_COOLDOWN_TICKS: int = 1
## 机关击退四分之一格。不是 Authoring hazard.knockback / damage 字段。
const HAZARD_KNOCKBACK_STEP: int = Fixed.SCALE / 4
## D5：一期环境失败硬直 1.0 s（人类 2026-08-28）。不锁 Tick Hz。
## 对局 / Solo / BotRunner 用当前引擎 physics 占位 Hz 换成 tick；改 Hz 只改
## PHYSICS_TICKS_PER_SECOND_PLACEHOLDER，不是 CD-43 产品 Tick。
const RESPAWN_STUN_MS: int = 1000
const PHYSICS_TICKS_PER_SECOND_PLACEHOLDER: int = 60
const RESPAWN_STUN_TICKS: int = (RESPAWN_STUN_MS * PHYSICS_TICKS_PER_SECOND_PLACEHOLDER + 999) / 1000
## Preview 手动 Advance，不是墙钟。硬直一次点击即可过，避免点 60 下。
const PREVIEW_RESPAWN_STUN_TICKS: int = 1


## 墙钟毫秒 → 会话 tick。向上取整，避免把 1.0 s 缩短。非正数当 0。
static func ticks_from_ms(duration_ms: int) -> int:
	if duration_ms <= 0:
		return 0
	return (duration_ms * PHYSICS_TICKS_PER_SECOND_PLACEHOLDER + 999) / 1000

## 角色比例是 D4 的美术规格项，不是本文件的动作占位桩，所以数值住在
## PlaceholderSpec。这里只保留对局侧的名字，避免调用方两处引用。
const CAPSULE_RADIUS: int = PlaceholderSpec.CHARACTER_RADIUS
const CAPSULE_HEIGHT: int = PlaceholderSpec.CHARACTER_HEIGHT


## 套用 MATCH 组并打开开发桩出界 AABB。对局进程、BotRunner 与任何直接持有
## TraprushMatchSession 的调用方都走这里；只持有 `play_*` 字段的外壳
## （Solo、Preview）按分层自己读上面的常量。
static func apply_match(session: TraprushMatchSession) -> void:
	if session == null:
		return
	session.jump_dy = JUMP_DY
	session.support_dy = SUPPORT_DY
	session.fall_dy = FALL_DY
	session.use_item_damage = USE_ITEM_DAMAGE
	session.use_item_reach_dx = USE_ITEM_REACH_DX
	session.use_item_reach_dy = USE_ITEM_REACH_DY
	session.use_item_reach_dz = USE_ITEM_REACH_DZ
	session.shove_step = SHOVE_STEP
	session.shove_cooldown_ticks = SHOVE_COOLDOWN_TICKS
	session.sprint_step = SPRINT_STEP
	session.item_cooldown_ticks = ITEM_COOLDOWN_TICKS
	session.hazard_knockback_step = HAZARD_KNOCKBACK_STEP
	session.respawn_stun_ticks = RESPAWN_STUN_TICKS
	session.enable_play_range(OutOfRangeReset.STUB_HALF)
