class_name PlaySetback
extends RefCounted

## 环境失败的原因名与可读读出（可玩性深化，轨 1：失败惩罚可读）。
##
## 存在的理由：一期的失败惩罚是「弹回最近检查点 + 1.0 s 硬直」（CD-21 §6，
## D5 拍板）。此前玩家看到的只有画面突然换到别处、按键有一秒不响应——**没有任何
## 一处告诉他发生了什么**，于是硬直读起来像卡顿，复位读起来像 bug。本文件给
## 那一秒配一句话：为什么被打回、打回到哪、还剩多久。
##
## 原因由**服务端**在 `TraprushMatchScan` 判定，不是客户端猜的。但它**不进
## v1 快照帧**：那是协议不兼容变更，属宪法第十八条人类门禁，本刀不做。因此
## 线上对局今天读不到 `setback=`，只有 Solo / Preview 能读（两者直接持有会话）。
## 这是诚实边界，不是遗漏——不要在客户端用位姿跳变去「推断」原因来补这个洞。
##
## 纯读出：不写裁决、不进 hash_state（理由见 `match_session_bootstrap.gd`）。

const NONE: String = ""
## 周期机关在固体半周期与胶囊重叠：击退并弹回。
const HAZARD: String = "hazard"
## 掉出开发期 ±8 格出界桩（`OutOfRangeReset.STUB_HALF`），不是产品边界。
const OUT_OF_RANGE: String = "out_of_range"
## 移动平台把胶囊顶进固体里，无处可去：弹回。
const CRUSHED: String = "crushed"

const ALL: PackedStringArray = [HAZARD, OUT_OF_RANGE, CRUSHED]

## 失败提示在屏上停留多久（tick）。比 1.0 s 硬直略长，好让硬直结束那一刻
## 玩家还能把话读完。占位表现值，不是产品数值。
const SHOW_TICKS: int = 90

const _TEXT_KEYS: Dictionary[String, String] = {
	HAZARD: UiCopy.SETBACK_HAZARD,
	OUT_OF_RANGE: UiCopy.SETBACK_OUT_OF_RANGE,
	CRUSHED: UiCopy.SETBACK_CRUSHED,
}


static func contains(reason: String) -> bool:
	return ALL.has(reason)


## 这一帧该不该显示。`setback_tick < 0` 表示本局还没失败过。
static func is_visible(reason: String, setback_tick: int, tick: int) -> bool:
	if not contains(reason) or setback_tick < 0 or tick < setback_tick:
		return false
	return tick - setback_tick < SHOW_TICKS


## 开发期状态行 token。不翻译，与 `join=` / `pads=` 同一类契约读出。
static func token(reason: String, setback_tick: int, stun_remaining: int) -> String:
	if not contains(reason):
		return ""
	return "setback=%s@%d stun=%d" % [reason, setback_tick, maxi(stun_remaining, 0)]


## 玩家可读的一行：为什么、打回到哪、还剩多久。
## `accepted_count` 是服务端已验收的垫数，也就是复位落点那块垫的 order + 1。
static func text(
	reason: String,
	accepted_count: int,
	stun_remaining: int,
	locale: String = ""
) -> String:
	if not contains(reason):
		return ""
	var key: String = _TEXT_KEYS[reason]
	var where: String = UiCopy.text(UiCopy.SETBACK_RESPAWN_START, locale)
	if accepted_count > 0:
		where = UiCopy.text(UiCopy.SETBACK_RESPAWN_CHECKPOINT, locale) % (accepted_count - 1)
	var parts: PackedStringArray = PackedStringArray()
	parts.append(UiCopy.text(key, locale))
	parts.append(where)
	if stun_remaining > 0:
		parts.append(UiCopy.text(UiCopy.SETBACK_STUN, locale) % PlayClock.format_seconds(stun_remaining))
	return "  ".join(parts)
