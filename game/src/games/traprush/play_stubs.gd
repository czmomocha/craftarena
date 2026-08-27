class_name TraprushPlayStubs
extends RefCounted

## 动作占位桩的单一配置源。
##
## 这些**不是产品数值**：跳跃高度、重力、爆破伤害与推击力度都还没拍板
## （[CD-63](Confirmed-docs/60-plan/63-open-decisions.md) §1）。它们只是让
## 对局能跑起来的开发期占位值。
##
## 存在的理由是变更成本，不是复用：同一组数字原先抄在对局进程、大厅 Solo 与
## Preview 壳三处，现在又要被 BotRunner 抄第四遍。数值拍板时四处必须同时改，
## 而漏改一处不会报错——只会让 bot 判定的「可完成」与真实对局不是同一件事。
## 冻结令（`.cursor/rules/course-correction-freeze.mdc` §3）因此要求新增消费方
## 改为从单一配置源注入。
##
## 分成两组是因为语义不同，不是因为有人抄错了：
## MATCH 组给随引擎 tick 连续推进的场景（对局进程、Solo、BotRunner）；
## PREVIEW 组给手动点 Advance tick 的编辑器 Preview，那里一次点击代表一大步，
## 每次落一整格，否则要点十六下才看得出在下落。
##
## 出界半宽不在这里复制，直接用 TraprushOutOfRangeReset.STUB_HALF。

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")

## 一格 hop：会与 course_01 出生点正上方的 two_way 盒闭区间相交并落地。
const JUMP_DY: int = Fixed.SCALE / 4
## 向下探测立足固体，与灰盒同向。
const SUPPORT_DY: int = -Fixed.SCALE
## 与大厅 play_move_step 同量。引擎约 60 physics tick/s，一格每 tick 会在约 8 帧内
## 触发出界复位，看起来像往上弹回出生点。
const FALL_DY: int = -Fixed.SCALE / 16
## Preview 手动 Advance tick：一次点击落一整格。
const PREVIEW_FALL_DY: int = -Fixed.SCALE

const USE_ITEM_DAMAGE: int = 1
## reach 只探 +Z 一格：要打箱必须先站到箱的 -Z 侧。不是产品爆破表。
const USE_ITEM_REACH_DX: int = 0
const USE_ITEM_REACH_DY: int = 0
const USE_ITEM_REACH_DZ: int = Fixed.SCALE

## 四分之一格推击步长与 1 tick 冷却，不是产品力度或冷却秒数。
const SHOVE_STEP: int = Fixed.SCALE / 4
const SHOVE_COOLDOWN_TICKS: int = 1

## 占位胶囊尺寸（八分之一格），不是产品角色比例——那要等 D4 的美术规格表。
## 改半径会连带改赛道布局、Shove 邻域、UseItem reach 与全部占用相交断言，
## 所以这里也只留一份。
const CAPSULE_RADIUS: int = Fixed.SCALE / 8
const CAPSULE_HEIGHT: int = Fixed.SCALE / 8


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
	session.enable_play_range(OutOfRangeReset.STUB_HALF)
