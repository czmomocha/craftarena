class_name WebPageLocation
extends RefCounted

## Live browser location. Headless / desktop GUT never calls into
## JavaScriptBridge; `ServerEndpoint.from_os` takes an injected Dictionary
## with the same keys so the query and `/play/` host rules stay testable.


static func read() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	return {
		"search": _js_string("window.location.search"),
		"pathname": _js_string("window.location.pathname"),
		"hostname": _js_string("window.location.hostname"),
	}


static func _js_string(expression: String) -> String:
	var value: Variant = JavaScriptBridge.eval(expression)
	if typeof(value) != TYPE_STRING:
		return ""
	return str(value)
