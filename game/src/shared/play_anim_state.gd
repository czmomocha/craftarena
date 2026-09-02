class_name PlayAnimState
extends RefCounted

## C4 表现动画状态契约。纠偏方案产出 4：先锁状态名，不播 clip、不入库
## AnimationPlayer、不改协议。
##
## 状态集是纠偏原文那七个，外加 idle（站着也得有名字）：
## idle / run / jump / land / shove / hit / break / portal
##
## 调用方塞事实，本文件只做优先级裁决。大厅 Solo 与 Preview 读局部权威。
## v1 快照没有 vy / stun / 库存，所以**在线远端不接线**——那不是遗漏，
## 是改协议（宪法第十八条）。
##
## `airborne` 必须由调用方合成：接触探针未踩到固体 **或** `vy != 0`。
## 接触探针是半格（`CONTACT_DY`），不要复用 Jump 的 1 格 `support_dy`，
## 也不要用一个量子：占用盒在格心，出生在格平面，脚底到盒顶有半格空隙，
## 一个量子探不到立足面；1 格探针又会把官方 1/4 格 hop 整段判成接地，
## 弧顶 `vy` 过 0 时落地会在空中误触发。
##
## 时长不锁（[CD-63] 仍延期「动画」的秒数）。land / shove / break 只在本拍
## 事实为真时出现一次；hit 跟 stun_remaining；jump 跟 airborne。
## sprint 并进 run，不单开状态。
##
## 放 `shared/` 的理由与 PlayInput 相同：大厅与 Preview 必须读同一份优先级。
## `simulation/` 不引用本文件。

const IDLE: String = "idle"
const RUN: String = "run"
const JUMP: String = "jump"
const LAND: String = "land"
const SHOVE: String = "shove"
const HIT: String = "hit"
const BREAK: String = "break"
const PORTAL: String = "portal"

## 接触探针。占用半长来自 PlaceholderSpec.CELL，不是再散落一份 cell/2。
## 不是产品落地容差。
const CONTACT_DY: int = -PlaceholderSpec.CELL / 2

const NAMES: PackedStringArray = [
	IDLE,
	RUN,
	JUMP,
	LAND,
	SHOVE,
	HIT,
	BREAK,
	PORTAL,
]

## 开局当成已落地，避免出生第一拍被误判成落地。
var _was_airborne: bool = false


static func contains(state: String) -> bool:
	return NAMES.has(state)


static func is_airborne(vy: int, contact_supported: bool) -> bool:
	return vy != 0 or not contact_supported


static func empty_facts() -> Dictionary:
	return {
		"airborne": false,
		"moving": false,
		"stunned": false,
		"latched": false,
		"shove": false,
		"broke": false,
	}


static func facts(
	airborne: bool,
	moving: bool,
	stunned: bool,
	latched: bool,
	shove: bool,
	broke: bool
) -> Dictionary:
	return {
		"airborne": airborne,
		"moving": moving,
		"stunned": stunned,
		"latched": latched,
		"shove": shove,
		"broke": broke,
	}


func reset() -> void:
	_was_airborne = false


func resolve(source: Dictionary) -> String:
	var airborne: bool = _flag(source, "airborne", false)
	var moving: bool = _flag(source, "moving", false)
	var stunned: bool = _flag(source, "stunned", false)
	var latched: bool = _flag(source, "latched", false)
	var shove: bool = _flag(source, "shove", false)
	var broke: bool = _flag(source, "broke", false)
	var landed: bool = not airborne and _was_airborne
	_was_airborne = airborne
	if stunned:
		return HIT
	if latched:
		return PORTAL
	if landed:
		return LAND
	if airborne:
		return JUMP
	if shove:
		return SHOVE
	if broke:
		return BREAK
	if moving:
		return RUN
	return IDLE


static func _flag(source: Dictionary, key: String, fallback: bool) -> bool:
	if not source.has(key) or typeof(source[key]) != TYPE_BOOL:
		return fallback
	var flag: bool = source[key]
	return flag
