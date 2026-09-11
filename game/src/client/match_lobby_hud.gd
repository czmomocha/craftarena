class_name MatchLobbyHud
extends RefCounted

## L4 presentation: lobby HUD status dictionary + the `join=` status line.
## Tokens (`join=` / `pads=` / `FPS`) stay untranslated (C4). FPS itself is
## FrameRateMeter, not this line.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const PlaySplitTrackerGd := preload("res://src/shared/play_split_tracker.gd")
const SettlementPanelGd := preload("res://src/shared/match_settlement_panel.gd")


static func floor_index_from_y(y: int) -> int:
	return y / Fixed.SCALE


static func own_player_int(players: Array, slot: int, key: String, reject_negative: bool) -> int:
	if slot < 0 or slot >= players.size():
		return -1
	var raw: Variant = players[slot]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	var value_raw: Variant = body.get(key, -1)
	if typeof(value_raw) != TYPE_INT:
		return -1
	var value: int = value_raw
	if reject_negative and value < 0:
		return -1
	return value


static func own_authority_y(players: Array, slot: int) -> int:
	if slot < 0 or slot >= players.size():
		return 0
	var raw: Variant = players[slot]
	if typeof(raw) != TYPE_DICTIONARY:
		return 0
	var body: Dictionary = raw
	var y_raw: Variant = body.get("y", 0)
	if typeof(y_raw) != TYPE_INT:
		return 0
	return y_raw


## 本席的权威 Q48.16 位姿。缺席 / 字段类型不对返回空字典——`own_player_int`
## 用 -1 当哨兵，而坐标本来就可以是 -1，不能共用那条路径。
static func own_authority_pose(players: Array, slot: int) -> Dictionary:
	if slot < 0 or slot >= players.size():
		return {}
	var raw: Variant = players[slot]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	var pose: Dictionary = {}
	for key: String in ["x", "y", "z"]:
		var value_raw: Variant = body.get(key, null)
		if typeof(value_raw) != TYPE_INT:
			return {}
		pose[key] = value_raw
	return pose


static func all_players_finished(players: Array) -> bool:
	if players.is_empty():
		return false
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		var tick_raw: Variant = body.get("finish_tick", -1)
		if typeof(tick_raw) != TYPE_INT:
			return false
		var finish_tick: int = tick_raw
		if finish_tick < 0:
			return false
	return true


static func tls_on(play_view: Dictionary, gateway_base: String) -> bool:
	var play_url: String = str(play_view.get("websocket_url", ""))
	if play_url != "":
		return MatchPlaySessionGd.uses_tls(play_url)
	return MatchPlaySessionGd.uses_tls(gateway_base)


static func build_view(
	join_view: Dictionary,
	play_view: Dictionary,
	offline_view: Dictionary,
	mapped: Dictionary,
	follow: MatchSnapshotFollowGd,
	follow_slot: int,
	selected_course_id: String,
	selected_seats: int,
	control_plane_base: String,
	gateway_base: String,
	server_error: String,
	window_visible: bool,
	offline_playing: bool,
	wayfind: Dictionary = {}
) -> Dictionary:
	var own_accepted_count: int = -1
	var own_finish_tick: int = -1
	var own_floor_index: int = 0
	var match_finished: bool = false
	var source: Dictionary = play_view
	if offline_playing:
		source = offline_view
	if follow != null and follow.has_snapshot:
		own_accepted_count = own_player_int(follow.players, follow_slot, "accepted_count", true)
		own_finish_tick = own_player_int(follow.players, follow_slot, "finish_tick", false)
		own_floor_index = floor_index_from_y(own_authority_y(follow.players, follow_slot))
		match_finished = all_players_finished(follow.players)
	return {
		"join_state": join_view.get("state", ""),
		"error": join_view.get("error", ""),
		"pending": join_view.get("pending", false),
		"position": join_view.get("position", 0),
		"estimated_wait_ms": join_view.get("estimated_wait_ms", 0),
		"room_code": join_view.get("room_code", ""),
		"ticket": join_view.get("ticket", ""),
		"course": join_view.get("course", ""),
		"course_id": selected_course_id,
		"content_id": join_view.get("content_id", ""),
		"seats": join_view.get("seats", 0),
		"selected_seats": selected_seats,
		"seat": join_view.get("seat", -1),
		"play_state": play_view.get("state", ""),
		"tls": tls_on(play_view, gateway_base),
		"rtt_ms": play_view.get("rtt_ms", -1),
		"rtt_n": play_view.get("rtt_n", 0),
		"rtt_p50_ms": play_view.get("rtt_p50_ms", -1),
		"rtt_p90_ms": play_view.get("rtt_p90_ms", -1),
		"rtt_p95_ms": play_view.get("rtt_p95_ms", -1),
		"rtt_lost": play_view.get("rtt_lost", 0),
		"server_host": ServerEndpointGd.host_port_of(control_plane_base),
		"control_plane_host": ServerEndpointGd.host_of(control_plane_base),
		"gateway_host": ServerEndpointGd.host_of(gateway_base),
		"server_error": server_error,
		"offline_state": offline_view.get("state", ""),
		"offline_banner": offline_view.get("banner", ""),
		"offline_error": offline_view.get("error", ""),
		"tick": source.get("tick", -1),
		"player_count": source.get("player_count", 0),
		"crate_count": source.get("crate_count", 0),
		"mapped_players": mapped.get("players", 0),
		"mapped_pads": mapped.get("pads", 0),
		"mapped_portals": mapped.get("portals", 0),
		"mapped_finish": mapped.get("finish", 0),
		"mapped_crates": mapped.get("crates", 0),
		"crate_total": mapped.get("crate_total", 0),
		"mapped_hazards": mapped.get("hazards", 0),
		"hazard_total": mapped.get("hazard_total", 0),
		"mapped_solids": mapped.get("solids", 0),
		"solid_total": mapped.get("solid_total", 0),
		"mapped_links": mapped.get("links", 0),
		"mapped_orders": mapped.get("orders", 0),
		"mapped_sequences": mapped.get("sequences", 0),
		"mapped_standings": mapped.get("standings", 0),
		"mvp_slot": mapped.get("mvp_slot", -1),
		"standing_line": mapped.get("standing_line", ""),
		"own_accepted_count": own_accepted_count,
		"own_finish_tick": own_finish_tick,
		"own_floor_index": own_floor_index,
		"match_finished": match_finished,
		"settlement_line": str(join_view.get("settlement_line", "")),
		"has_settlement": join_view.get("has_settlement", false),
		"settlement_rows": join_view.get("settlement_rows", []),
		"settlement_mvp_slot": join_view.get("settlement_mvp_slot", -1),
		"settlement_pad_total": join_view.get("settlement_pad_total", 0),
		"window_visible": window_visible,
		"setback_reason": offline_view.get("setback_reason", PlaySetback.NONE),
		"setback_tick": offline_view.get("setback_tick", -1),
		"stun_remaining": offline_view.get("stun_remaining", 0),
		"bomb_count": offline_view.get("bomb_count", -1),
		"dash_count": offline_view.get("dash_count", -1),
		"fails_count": offline_view.get("fails_count", -1),
		"wayfind": wayfind,
		"guide_token": PlayWayfinder.token(wayfind),
	}


static func format_line(view: Dictionary) -> String:
	var join_state: String = view.get("join_state", "")
	var play_state: String = view.get("play_state", "")
	var parts: PackedStringArray = PackedStringArray()
	parts.append("join=%s" % join_state)
	if view.get("pending", false):
		parts.append("pending=1")
	if join_state == MatchJoinSessionGd.STATE_WAITING:
		var position: int = view.get("position", 0)
		var wait_ms: int = view.get("estimated_wait_ms", 0)
		parts.append("pos=%d" % position)
		parts.append("wait_ms=%d" % wait_ms)
	var room_code: String = str(view.get("room_code", ""))
	if room_code != "":
		parts.append("room=%s" % room_code)
	var shown_content: String = str(view.get("content_id", ""))
	var shown_course: String = str(view.get("course", ""))
	if shown_course == "" and shown_content == "":
		shown_course = str(view.get("course_id", ""))
	if shown_course != "":
		parts.append("course_id=%s" % shown_course)
	if shown_content != "" and shown_course == "":
		parts.append("content=%s" % shown_content)
	var shown_seats: int = view.get("seats", 0)
	if shown_seats < 1:
		shown_seats = view.get("selected_seats", 0)
	if shown_seats >= 1:
		parts.append("seats=%d" % shown_seats)
	var own_seat: int = view.get("seat", -1)
	if own_seat >= 0 and (
		play_state == MatchPlaySessionGd.STATE_IN_MATCH
		or play_state == MatchPlaySessionGd.STATE_CONNECTING
	):
		parts.append("seat=%d" % own_seat)
	var error_text: String = str(view.get("error", ""))
	if error_text != "":
		parts.append("error=%s" % error_text)
	parts.append("play=%s" % play_state)
	var tls_flag: bool = view.get("tls", false)
	parts.append("tls=%s" % ("on" if tls_flag else "off"))
	var rtt_n: int = view.get("rtt_n", 0)
	if rtt_n > 0:
		var rtt_ms: int = view.get("rtt_ms", -1)
		parts.append("rtt=%d" % rtt_ms)
		parts.append("rtt_n=%d" % rtt_n)
	var server_host: String = str(view.get("server_host", ""))
	if server_host != "":
		parts.append("server=%s" % server_host)
	var gateway_host: String = str(view.get("gateway_host", ""))
	var control_plane_host: String = str(view.get("control_plane_host", ""))
	if gateway_host != "" and gateway_host != control_plane_host:
		parts.append("gw=%s" % gateway_host)
	var server_error: String = str(view.get("server_error", ""))
	if server_error != "":
		parts.append("server_error=%s" % server_error)
	var offline_state: String = str(view.get("offline_state", ""))
	if offline_state != "":
		parts.append("offline=%s" % offline_state)
	var offline_banner: String = str(view.get("offline_banner", ""))
	if offline_banner != "":
		parts.append(offline_banner)
	var offline_error: String = str(view.get("offline_error", ""))
	if offline_error != "":
		parts.append("offline_error=%s" % offline_error)
	var mapped_pads: int = view.get("mapped_pads", 0)
	var mapped_portals: int = view.get("mapped_portals", 0)
	var mapped_finish: int = view.get("mapped_finish", 0)
	if play_state == MatchPlaySessionGd.STATE_IN_MATCH or offline_state == MatchOfflineSessionGd.STATE_PLAYING:
		var tick: int = view.get("tick", -1)
		var player_count: int = view.get("player_count", 0)
		parts.append("tick=%d" % tick)
		parts.append("players=%d" % player_count)
		var mapped_players: int = view.get("mapped_players", 0)
		parts.append("mapped=%d" % mapped_players)
		var own_accepted_count: int = view.get("own_accepted_count", -1)
		var own_finish_tick: int = view.get("own_finish_tick", -1)
		var own_floor_index: int = view.get("own_floor_index", 0)
		var crate_alive: int = view.get("mapped_crates", 0)
		var crate_total: int = view.get("crate_total", 0)
		parts.append("pads=%d/%d" % [own_accepted_count, mapped_pads])
		parts.append("floor=%d" % own_floor_index)
		parts.append("finish=%d" % own_finish_tick)
		parts.append("crates=%d/%d" % [crate_alive, crate_total])
		var hazard_alive: int = view.get("mapped_hazards", 0)
		var hazard_total: int = view.get("hazard_total", 0)
		parts.append("hazards=%d/%d" % [hazard_alive, hazard_total])
		var solid_alive: int = view.get("mapped_solids", 0)
		var solid_total: int = view.get("solid_total", 0)
		parts.append("solids=%d/%d" % [solid_alive, solid_total])
		if view.get("match_finished", false):
			var result_line: String = str(view.get("standing_line", ""))
			if result_line != "":
				parts.append("result=%s" % result_line)
			var settled_line: String = str(view.get("settlement_line", ""))
			if settled_line != "":
				parts.append("settled=%s" % settled_line)
		var clock_tick: int = PlayClockGd.clock_tick(tick, own_finish_tick)
		parts.append("clock=%s" % PlayClockGd.format_clock(clock_tick))
		var split_line: String = str(view.get("split_line", ""))
		if split_line != "":
			parts.append("split=%s" % split_line)
		var guide_token: String = str(view.get("guide_token", ""))
		if guide_token != "":
			parts.append(guide_token)
		var setback_token: String = str(view.get("setback_token", ""))
		if setback_token != "":
			parts.append(setback_token)
	parts.append("course=%d/%d/%d" % [mapped_pads, mapped_portals, mapped_finish])
	var mapped_crates: int = view.get("mapped_crates", 0)
	parts.append("crates_mapped=%d" % mapped_crates)
	var mapped_hazards: int = view.get("mapped_hazards", 0)
	parts.append("hazards_mapped=%d" % mapped_hazards)
	var mapped_solids: int = view.get("mapped_solids", 0)
	parts.append("solids_mapped=%d" % mapped_solids)
	var mapped_links: int = view.get("mapped_links", 0)
	parts.append("links_mapped=%d" % mapped_links)
	var mapped_orders: int = view.get("mapped_orders", 0)
	var mapped_sequences: int = view.get("mapped_sequences", 0)
	parts.append("orders_mapped=%d/%d" % [mapped_orders, mapped_sequences])
	var standing_line: String = str(view.get("standing_line", ""))
	if standing_line != "":
		parts.append(standing_line)
	return " ".join(parts)


static func sync_play_progress(
	view: Dictionary,
	tracker: PlaySplitTrackerGd,
	local_board: Dictionary,
	is_offline_playing: bool,
	play_state: String
) -> void:
	var online: bool = play_state == MatchPlaySessionGd.STATE_IN_MATCH
	var playing: bool = is_offline_playing or online
	view["play_hud_active"] = playing
	var tick: int = PlayClockGd.dict_int(view, "tick", -1)
	var finish_tick: int = PlayClockGd.dict_int(view, "own_finish_tick", -1)
	var clock_tick: int = PlayClockGd.clock_tick(tick, finish_tick)
	view["clock_tick"] = clock_tick
	if tracker == null:
		view["split_line"] = ""
	elif playing:
		tracker.observe(PlayClockGd.dict_int(view, "own_accepted_count", -1), clock_tick)
		view["split_line"] = tracker.popup_line()
	else:
		tracker.reset()
		view["split_line"] = ""
	var wayfind_raw: Variant = view.get("wayfind", {})
	var wayfind: Dictionary = {}
	if typeof(wayfind_raw) == TYPE_DICTIONARY:
		wayfind = wayfind_raw
	view["guide_text"] = PlayWayfinder.guide_text(wayfind) if playing else ""
	_sync_setback(view, playing)
	var rows_raw: Variant = view.get("settlement_rows", [])
	var rows: Array = []
	if typeof(rows_raw) == TYPE_ARRAY:
		rows = rows_raw
	var join_board: Dictionary = SettlementPanelGd.board_from_join(
		PlayClockGd.dict_bool(view, "has_settlement", false),
		PlayClockGd.dict_int(view, "settlement_mvp_slot", -1),
		PlayClockGd.dict_int(view, "settlement_pad_total", 0),
		rows
	)
	if join_board.get("ok", false):
		view["settlement_board"] = join_board
	elif is_offline_playing:
		view["settlement_board"] = local_board
	else:
		view["settlement_board"] = {"ok": false}


## 环境失败读出。只在窗口期内显示，过了就自己消失——常驻的失败提示会变成
## 玩家学会忽略的一块 UI，那等于没写。
static func _sync_setback(view: Dictionary, playing: bool) -> void:
	view["setback_token"] = ""
	view["setback_text"] = ""
	if not playing:
		return
	var reason: String = str(view.get("setback_reason", PlaySetback.NONE))
	var setback_tick: int = PlayClockGd.dict_int(view, "setback_tick", -1)
	var tick: int = PlayClockGd.dict_int(view, "tick", -1)
	if not PlaySetback.is_visible(reason, setback_tick, tick):
		return
	var stun: int = PlayClockGd.dict_int(view, "stun_remaining", 0)
	view["setback_token"] = PlaySetback.token(reason, setback_tick, stun)
	view["setback_text"] = PlaySetback.text(
		reason, PlayClockGd.dict_int(view, "own_accepted_count", 0), stun
	)
