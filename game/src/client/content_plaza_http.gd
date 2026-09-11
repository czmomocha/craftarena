class_name ContentPlazaHttp
extends RefCounted

## GET /content/plaza and GET /content/:id/latest decode (CD-12 / CD-33).
## Plaza items have no bundle; Solo fetches latest and compiles locally.

const HttpGd := preload("res://src/client/control_plane_http.gd")
const PlazaGd := preload("res://src/ugc/content_plaza.gd")
const BundleGd := preload("res://src/ugc/simulation_bundle.gd")

const KEY_TAB: String = "tab"
const KEY_ITEMS: String = "items"
const KEY_BUNDLE: String = "bundle"


static func list_path(tab: String) -> String:
	var next: String = tab if PlazaGd.is_tab(tab) else PlazaGd.TAB_NEWEST
	return "/content/plaza?tab=%s" % next


static func latest_path(content_id: String) -> String:
	return "/content/%s/latest" % content_id


static func version_path(content_id: String, version: int) -> String:
	return "/content/%s/versions/%d" % [content_id, version]


static func fetch_list(
	base: String,
	tab: String,
	transport: Callable = Callable()
) -> Dictionary:
	var exchanged: Dictionary = HttpGd.get_json(
		base, list_path(tab), PackedStringArray(), transport
	)
	return _body_or_error(exchanged)


static func fetch_latest(
	base: String,
	content_id: String,
	transport: Callable = Callable()
) -> Dictionary:
	var exchanged: Dictionary = HttpGd.get_json(
		base, latest_path(content_id), PackedStringArray(), transport
	)
	return _body_or_error(exchanged)


static func fetch_version(
	base: String,
	content_id: String,
	version: int,
	transport: Callable = Callable()
) -> Dictionary:
	var exchanged: Dictionary = HttpGd.get_json(
		base, version_path(content_id, version), PackedStringArray(), transport
	)
	return _body_or_error(exchanged)


static func read_list(raw: Dictionary) -> Dictionary:
	if raw.has("error"):
		return _fail(str(raw.get("error", PlazaGd.REASON_TAB_INVALID)))
	var tab: String = str(raw.get(KEY_TAB, PlazaGd.TAB_NEWEST))
	if not PlazaGd.is_tab(tab):
		return _fail(PlazaGd.REASON_TAB_INVALID)
	var items_raw: Variant = raw.get(KEY_ITEMS, [])
	if typeof(items_raw) != TYPE_ARRAY:
		return _fail(PlazaGd.REASON_TAB_INVALID)
	var items: Array = []
	for entry: Variant in items_raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		var content_id: String = str(item.get("content_id", ""))
		if content_id == "":
			continue
		items.append(item)
	return {
		PlazaGd.KEY_OK: true,
		PlazaGd.KEY_REASON: "",
		KEY_TAB: tab,
		KEY_ITEMS: items,
	}


static func read_latest_bundle(raw: Dictionary) -> SimulationBundle:
	if raw.has("error"):
		return null
	var bundle_raw: Variant = raw.get(KEY_BUNDLE, {})
	if typeof(bundle_raw) != TYPE_DICTIONARY:
		return null
	var bundle: Dictionary = bundle_raw
	return BundleGd.from_dictionary(bundle)


static func _body_or_error(exchanged: Dictionary) -> Dictionary:
	var body_raw: Variant = exchanged.get(HttpGd.KEY_BODY, {})
	if typeof(body_raw) != TYPE_DICTIONARY:
		return {"error": str(exchanged.get(HttpGd.KEY_REASON, HttpGd.REASON_RESPONSE))}
	var body: Dictionary = body_raw
	if not _flag(exchanged) and not body.has("error"):
		return {"error": str(exchanged.get(HttpGd.KEY_REASON, HttpGd.REASON_TRANSPORT))}
	return body


static func _fail(reason: String) -> Dictionary:
	return {PlazaGd.KEY_OK: false, PlazaGd.KEY_REASON: reason}


static func _flag(raw: Dictionary) -> bool:
	var flag: Variant = raw.get(HttpGd.KEY_OK, false)
	return typeof(flag) == TYPE_BOOL and flag
