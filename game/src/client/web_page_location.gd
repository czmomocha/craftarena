class_name WebPageLocation
extends RefCounted

## Live browser location. Headless / desktop GUT never calls into
## JavaScriptBridge; `ServerEndpoint.from_os` takes an injected Dictionary
## with the same keys so the query and `/play/` host rules stay testable.


static func read() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	# Official templates ship JavaScriptBridge. Prefer get_interface over eval:
	# eval can be compiled out; location is a host object.
	var location: JavaScriptObject = JavaScriptBridge.get_interface("location")
	if location == null:
		return {}
	return {
		"search": _js_prop(location, "search"),
		"pathname": _js_prop(location, "pathname"),
		"hostname": _js_prop(location, "hostname"),
	}


static func _js_prop(object: JavaScriptObject, key: String) -> String:
	var value: Variant = object.get(key)
	if typeof(value) != TYPE_STRING:
		return ""
	return str(value)
