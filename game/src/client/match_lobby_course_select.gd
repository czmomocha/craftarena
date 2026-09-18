extends OptionButton

## Lobby course picker. Official document ids, not a free-text LineEdit.
## TRAPRUSH lists match courses plus `course_f_playable`; BASTION pins
## `blueprint_01` and locks the control. Item text is the course id
## (UiCopy: course ids are not translated).

const ClientAudioGd := preload("res://src/client/client_audio.gd")
const OfficialBastionBlueprintsGd := preload("res://src/shared/official_bastion_blueprints.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")

const NODE_NAME: String = "CourseId"

var _on_picked: Callable = Callable()


func setup(on_picked: Callable) -> void:
	name = NODE_NAME
	focus_mode = Control.FOCUS_CLICK
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_picked = on_picked
	item_selected.connect(_on_item_selected)
	populate_traprush(OfficialTraprushCoursesGd.DEFAULT_ID)


func populate_traprush(selected_id: String) -> void:
	_fill(OfficialTraprushCoursesGd.all_document_ids(), selected_id, false)


func populate_bastion(selected_id: String) -> void:
	_fill(OfficialBastionBlueprintsGd.all_match_ids(), selected_id, true)


func selected_id(fallback: String) -> String:
	if selected < 0:
		return fallback
	if fallback != "" and _index_of(fallback) < 0:
		return fallback
	return get_item_text(selected)


func set_selected_id(course_id: String) -> void:
	var index: int = _index_of(course_id)
	set_block_signals(true)
	if index >= 0:
		select(index)
	set_block_signals(false)


func hits(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _fill(ids: PackedStringArray, selected_id: String, locked: bool) -> void:
	set_block_signals(true)
	clear()
	for id: String in ids:
		add_item(id)
	disabled = locked
	var index: int = _index_of(selected_id)
	if index >= 0:
		select(index)
	elif get_item_count() > 0:
		select(0)
	set_block_signals(false)


func _index_of(course_id: String) -> int:
	for i: int in get_item_count():
		if get_item_text(i) == course_id:
			return i
	return -1


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= get_item_count():
		return
	ClientAudioGd.post_ui_confirm()
	if _on_picked.is_valid():
		_on_picked.call(get_item_text(index))
