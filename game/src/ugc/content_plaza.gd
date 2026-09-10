class_name ContentPlaza
extends RefCounted

## Public listing for signed content (CD-12 / CD-31 / CD-33).
## Names come from a word bank; tags from occupancy bags. No free text.

const BundleGd := preload("res://src/ugc/simulation_bundle.gd")

const TAB_NEWEST: String = "newest"
const TAB_RATING: String = "rating"
const TAB_PLAYS: String = "plays"
const TAB_VERIFIED: String = "verified"
const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_ITEMS: String = "items"
const KEY_TAB: String = "tab"
const REASON_TAB_INVALID: String = "tab_invalid"
const REASON_MISSING: String = "content_not_found"
const REASON_PLAY_EXISTS: String = "play_exists"
const REASON_RATING_EXISTS: String = "rating_exists"
const REASON_TAGS_INVALID: String = "tags_invalid"
const REASON_STARS_INVALID: String = "stars_invalid"
const REASON_RATER_INVALID: String = "rater_invalid"
const REASON_MATCH_INVALID: String = "match_id_invalid"

const ADJECTIVES: PackedStringArray = [
	"swift", "iron", "quiet", "bold", "brisk", "calm", "dark", "fair",
	"keen", "lean", "pale", "rare", "stark", "true", "vivid", "warm",
]
const NOUNS: PackedStringArray = [
	"lane", "gate", "spire", "arch", "brook", "cliff", "forge", "grove",
	"hearth", "ridge", "run", "span", "trail", "vault", "well", "yard",
]
const TAG_IDS: PackedStringArray = [
	"portal", "crate", "hazard", "pickup", "mover", "conveyor", "launch",
	"switch", "gate", "energy_wall", "portal_switch", "spike", "flame",
	"crusher", "roller", "rubble", "core", "pendulum", "ice",
]
const TAG_BAGS: PackedStringArray = [
	"portals", "destructibles", "hazards", "pickups", "movers", "conveyors",
	"launches", "switches", "gates", "energy_walls", "portal_switches",
	"spikes", "flames", "crushers", "rollers", "rubbles", "obstacle_cores",
	"pendulums", "ices",
]

var _rows: Dictionary = {}
var _plays: Dictionary = {}
var _ratings: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()


static func display_name(content_id: String) -> String:
	var hash_value: int = fnv1a32(content_id)
	var adjective: String = ADJECTIVES[hash_value % ADJECTIVES.size()]
	var noun: String = NOUNS[int(hash_value / ADJECTIVES.size()) % NOUNS.size()]
	return "%s_%s" % [adjective, noun]


static func tags_from_bundle(bundle: BundleGd) -> PackedStringArray:
	if bundle == null:
		return PackedStringArray()
	return tags_from_dictionary(bundle.to_dictionary())


static func tags_from_dictionary(data: Dictionary) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	for index: int in TAG_IDS.size():
		var bag_raw: Variant = data.get(TAG_BAGS[index], [])
		if typeof(bag_raw) != TYPE_ARRAY:
			continue
		var bag: Array = bag_raw
		if bag.is_empty():
			continue
		tags.append(TAG_IDS[index])
	return tags


static func fnv1a32(text: String) -> int:
	var hash_value: int = 2166136261
	for index: int in text.length():
		hash_value = (hash_value ^ text.unicode_at(index)) & 0xFFFFFFFF
		hash_value = (hash_value * 16777619) & 0xFFFFFFFF
	return hash_value


static func is_tab(tab: String) -> bool:
	return tab == TAB_NEWEST or tab == TAB_RATING or tab == TAB_PLAYS or tab == TAB_VERIFIED


func index_listing(
	content_id: String,
	version: int,
	content_hash: String,
	bundle: BundleGd,
	listed_at: String
) -> Dictionary:
	var tags: PackedStringArray = tags_from_bundle(bundle)
	if _rows.has(content_id):
		var existing: Dictionary = _rows[content_id]
		existing["version"] = version
		existing["content_hash"] = content_hash
		existing["tags"] = tags
		existing["listed_at"] = listed_at
		_rows[content_id] = existing
		return _ok_item(existing)
	var row: Dictionary = {
		"content_id": content_id,
		"version": version,
		"content_hash": content_hash,
		"display_name": display_name(content_id),
		"tags": tags,
		"play_count": 0,
		"rating_sum": 0,
		"rating_count": 0,
		"verified": false,
		"listed_at": listed_at,
	}
	_rows[content_id] = row
	_order.append(content_id)
	return _ok_item(row)


func sync_latest(content_id: String, version: int, content_hash: String, bundle: BundleGd) -> Dictionary:
	if not _rows.has(content_id):
		return _fail(REASON_MISSING)
	var row: Dictionary = _rows[content_id]
	row["version"] = version
	row["content_hash"] = content_hash
	row["tags"] = tags_from_bundle(bundle)
	_rows[content_id] = row
	return _ok_item(row)


func list_tab(tab: String) -> Dictionary:
	if not is_tab(tab):
		return _fail(REASON_TAB_INVALID)
	var items: Array[Dictionary] = []
	for content_id: String in _order:
		var row: Dictionary = _rows[content_id]
		var verified_raw: Variant = row.get("verified", false)
		if tab == TAB_VERIFIED and verified_raw != true:
			continue
		items.append(row.duplicate(true))
	items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _before(tab, left, right))
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_TAB: tab,
		KEY_ITEMS: items,
	}


func record_play(content_id: String, match_id: String) -> Dictionary:
	if not _id_ok(match_id):
		return _fail(REASON_MATCH_INVALID)
	if not _rows.has(content_id):
		return _fail(REASON_MISSING)
	var key: String = "%s\n%s" % [content_id, match_id]
	if _plays.has(key):
		return _fail(REASON_PLAY_EXISTS)
	_plays[key] = true
	var row: Dictionary = _rows[content_id]
	row["play_count"] = _as_int(row.get("play_count", 0)) + 1
	row["verified"] = true
	_rows[content_id] = row
	return _ok_item(row)


func rate(content_id: String, rater: String, stars: int, tags: PackedStringArray) -> Dictionary:
	if not _id_ok(rater):
		return _fail(REASON_RATER_INVALID)
	if stars < 1 or stars > 5:
		return _fail(REASON_STARS_INVALID)
	if not _tags_ok(tags):
		return _fail(REASON_TAGS_INVALID)
	if not _rows.has(content_id):
		return _fail(REASON_MISSING)
	var key: String = "%s\n%s" % [content_id, rater]
	if _ratings.has(key):
		return _fail(REASON_RATING_EXISTS)
	_ratings[key] = true
	var row: Dictionary = _rows[content_id]
	row["rating_sum"] = _as_int(row.get("rating_sum", 0)) + stars
	row["rating_count"] = _as_int(row.get("rating_count", 0)) + 1
	_rows[content_id] = row
	return _ok_item(row)


func _before(tab: String, left: Dictionary, right: Dictionary) -> bool:
	if tab == TAB_PLAYS:
		var play_left: int = _as_int(left.get("play_count", 0))
		var play_right: int = _as_int(right.get("play_count", 0))
		if play_left != play_right:
			return play_left > play_right
	elif tab == TAB_RATING:
		var count_left: int = _as_int(left.get("rating_count", 0))
		var count_right: int = _as_int(right.get("rating_count", 0))
		if (count_left == 0) != (count_right == 0):
			return count_left > 0
		if count_left > 0 and count_right > 0:
			var avg_left: int = _as_int(left.get("rating_sum", 0)) * 1000 / count_left
			var avg_right: int = _as_int(right.get("rating_sum", 0)) * 1000 / count_right
			if avg_left != avg_right:
				return avg_left > avg_right
			if count_left != count_right:
				return count_left > count_right
	var listed_left: String = str(left.get("listed_at", ""))
	var listed_right: String = str(right.get("listed_at", ""))
	if listed_left != listed_right:
		return listed_left > listed_right
	return str(left.get("content_id", "")) < str(right.get("content_id", ""))


func _as_int(raw: Variant, fallback: int = 0) -> int:
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value


func _tags_ok(tags: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for tag: String in tags:
		if not TAG_IDS.has(tag) or seen.has(tag):
			return false
		seen[tag] = true
	return true


func _id_ok(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	var regex: RegEx = RegEx.new()
	regex.compile("^[A-Za-z0-9._-]+$")
	return regex.search(value) != null


func _ok_item(row: Dictionary) -> Dictionary:
	var copy: Dictionary = row.duplicate(true)
	copy[KEY_OK] = true
	copy[KEY_REASON] = ""
	return copy


func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
