class_name AuthoringValidatorPanel
extends VBoxContainer

## Read-only publish-check details on AuthoringEditorShell (CD-32 §1.1 / CD-21).
## Lists existing AuthoringReachability codes. Not a write gate.
## Focus frames the editor map camera on a transform entity. Never settlement.
##
## `details` 对应 CD-32 的 `allows_validator_details`（仅 `internal_dev`）。
## 关掉时**仍然照常求值**，只是收起问题码清单与 Focus，留一行摘要：Web 轻量的
## 创作者读不懂 `unreachable_checkpoint` 这种码，但必须知道「这张课现在能不能
## 发」。把整块面板藏掉才是真的少了一条信息。

const LIST_NAME: String = "IssueList"
const FOCUS_NAME: String = "FocusIssue"
const SUMMARY_NAME: String = "Summary"

var map: AuthoringPreviewMap = null
var details: bool = true
var _summary: Label = null
var _list: ItemList = null
var _issues: Array[Dictionary] = []
var _reach_ok: bool = true


func mount(p_map: AuthoringPreviewMap, p_details: bool = true) -> void:
	map = p_map
	details = p_details
	if get_child_count() > 0:
		return
	_summary = Label.new()
	_summary.name = SUMMARY_NAME
	add_child(_summary)
	if not details:
		_sync_summary()
		return
	_list = ItemList.new()
	_list.name = LIST_NAME
	_list.custom_minimum_size = Vector2(0, 72)
	add_child(_list)
	var focus: Button = Button.new()
	focus.name = FOCUS_NAME
	focus.text = UiCopy.text(UiCopy.FOCUS_ISSUE)
	focus.pressed.connect(focus_selected)
	add_child(focus)


func refresh(world: AuthoringWorld) -> void:
	var result: Dictionary = AuthoringReachability.evaluate(world)
	var ok_raw: Variant = result.get("ok", false)
	_reach_ok = typeof(ok_raw) == TYPE_BOOL and ok_raw
	_issues.clear()
	var issues_raw: Variant = result.get("issues", [])
	if typeof(issues_raw) == TYPE_ARRAY:
		var issues: Array = issues_raw
		for item: Variant in issues:
			if typeof(item) == TYPE_DICTIONARY:
				_issues.append(item)
	_rebuild_list()
	_sync_summary()


func summary_text() -> String:
	if _summary == null or not is_instance_valid(_summary):
		return ""
	return _summary.text


func reach_ok() -> bool:
	return _reach_ok


func issue_count() -> int:
	return _issues.size()


func issue_code_at(index: int) -> String:
	if index < 0 or index >= _issues.size():
		return ""
	return str(_issues[index].get("code", ""))


func has_code(code: String) -> bool:
	for issue: Dictionary in _issues:
		if str(issue.get("code", "")) == code:
			return true
	return false


func focus_selected() -> bool:
	if _list == null or _issues.is_empty():
		return false
	var index: int = 0
	var selected: PackedInt32Array = _list.get_selected_items()
	if not selected.is_empty():
		index = selected[0]
	return _focus_issue_at(index)


func focus_code(code: String) -> bool:
	var index: int = 0
	while index < _issues.size():
		if str(_issues[index].get("code", "")) == code:
			if _list != null and index < _list.item_count:
				_list.select(index)
			return _focus_issue_at(index)
		index += 1
	return false


func _focus_issue_at(index: int) -> bool:
	if map == null or index < 0 or index >= _issues.size():
		return false
	var ids_raw: Variant = _issues[index].get("entity_ids", [])
	if typeof(ids_raw) != TYPE_ARRAY:
		return false
	for id_raw: Variant in ids_raw:
		if typeof(id_raw) != TYPE_INT:
			continue
		var entity_id: int = id_raw
		if map.focus_entity(entity_id):
			return true
	return false


func _sync_summary() -> void:
	if _summary == null or not is_instance_valid(_summary):
		return
	if _reach_ok and _issues.is_empty():
		_summary.text = UiCopy.text(UiCopy.VALIDATOR_OK)
		_summary.remove_theme_color_override("font_color")
		return
	_summary.text = UiCopy.text(UiCopy.VALIDATOR_ISSUES) % _issues.size()
	_summary.add_theme_color_override("font_color", PlaceholderSpec.HAZARD_ALBEDO)


func _rebuild_list() -> void:
	if _list == null:
		return
	_list.clear()
	for issue: Dictionary in _issues:
		var code: String = str(issue.get("code", ""))
		var ids_raw: Variant = issue.get("entity_ids", [])
		var suffix: String = ""
		if typeof(ids_raw) == TYPE_ARRAY:
			var ids: Array = ids_raw
			if not ids.is_empty():
				suffix = " #" + ",".join(_ids_as_strings(ids_raw))
		_list.add_item(code + suffix)
	if _list.item_count > 0:
		_list.select(0)


func _ids_as_strings(ids_raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(ids_raw) != TYPE_ARRAY:
		return out
	var ids: Array = ids_raw
	for id_raw: Variant in ids:
		out.append(str(id_raw))
	return out
