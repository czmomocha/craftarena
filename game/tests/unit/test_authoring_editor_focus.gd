extends GutTest

## Editor GUI caret vs 3D pick: SpinBox LineEdit must drop focus when the
## editor chrome releases, when the Window is marked inactive, and when
## Preview is activated. Pointer ignores 3D while inactive. Matches the
## lobby LineEdit contract without depending on OS Window.has_focus().

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringEditorShellPointer := preload("res://src/creator/authoring_editor_shell_pointer.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWindowLayout := preload("res://src/creator/authoring_window_layout.gd")
const TraprushEditorPanelCursor := preload("res://src/creator/traprush_editor_panel_cursor.gd")

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	AuthoringWindowLayout.reset_split()
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_release_focus_clears_cell_spin_line_edit() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	assert_true(edit.has_focus())
	_shell.chrome.release_focus()
	assert_false(edit.has_focus())


func test_note_window_focus_false_releases_gui_and_blocks_pointer() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	assert_true(_shell.chrome.is_editor_active())
	_shell.chrome.selected_id = 7
	_shell.chrome.note_window_focus(false)
	assert_false(_shell.chrome.is_editor_active())
	assert_false(edit.has_focus())
	AuthoringEditorShellPointer.handle(_shell.chrome, _left_click(Vector2(400, 500)))
	assert_eq(_shell.chrome.selected_id, 7)


func test_focus_exited_releases_gui() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	assert_true(edit.has_focus())
	_shell.window.focus_exited.emit()
	assert_false(edit.has_focus())
	assert_false(_shell.chrome.is_editor_active())


func test_click_off_interactive_releases_gui_and_clears_selection() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	_shell.chrome.selected_id = 7
	var miss: Label = Label.new()
	_shell.chrome.handle_window_input(_left_click(Vector2(400, 500)), miss)
	miss.free()
	assert_false(edit.has_focus())
	assert_true(_shell.chrome.is_editor_active())
	assert_eq(_shell.chrome.selected_id, 0)


func test_click_on_spin_keeps_gui_and_does_not_pick() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	_shell.chrome.selected_id = 7
	_shell.chrome.handle_window_input(_left_click(edit.get_global_rect().get_center()), edit)
	assert_true(edit.has_focus())
	assert_eq(_shell.chrome.selected_id, 7)


func test_click_on_button_releases_gui_and_does_not_pick() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	_shell.chrome.selected_id = 7
	var undo: Button = _shell.window.find_child("Undo", true, false) as Button
	assert_not_null(undo)
	_shell.chrome.handle_window_input(_left_click(undo.get_global_rect().get_center()), undo)
	assert_false(edit.has_focus())
	assert_true(_shell.chrome.is_editor_active())
	assert_eq(_shell.chrome.selected_id, 7)


func test_open_preview_releases_editor_spin() -> void:
	var edit: LineEdit = _open_cell_edit()
	edit.grab_focus()
	assert_true(edit.has_focus())
	assert_true(_shell.open_preview())
	assert_false(edit.has_focus())
	assert_false(_shell.chrome.is_editor_active())


func test_pointer_handle_when_active_clears_selection_on_empty_click() -> void:
	_open_cell_edit()
	_shell.chrome.selected_id = 7
	assert_true(_shell.chrome.is_editor_active())
	AuthoringEditorShellPointer.handle(_shell.chrome, _left_click(Vector2(400, 500)))
	assert_eq(_shell.chrome.selected_id, 0)


func test_preview_click_handler_releases_editor_spin() -> void:
	var edit: LineEdit = _open_cell_edit()
	assert_true(_shell.open_preview())
	edit.grab_focus()
	assert_true(edit.has_focus())
	_shell.preview.chrome.handle_window_input(_left_click(Vector2(80, 400)))
	assert_false(edit.has_focus())
	assert_false(_shell.chrome.is_editor_active())


func test_preview_focus_entered_releases_editor_spin() -> void:
	var edit: LineEdit = _open_cell_edit()
	assert_true(_shell.open_preview())
	edit.grab_focus()
	assert_true(edit.has_focus())
	_shell.preview.window.focus_entered.emit()
	assert_false(edit.has_focus())
	assert_false(_shell.chrome.is_editor_active())


func _open_cell_edit() -> LineEdit:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	var spin: SpinBox = _shell.tools.find_child(TraprushEditorPanelCursor.CELL_X_NAME, true, false) as SpinBox
	assert_not_null(spin)
	var edit: LineEdit = spin.get_line_edit()
	assert_not_null(edit)
	return edit


func _left_click(point: Vector2) -> InputEventMouseButton:
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	return mouse
