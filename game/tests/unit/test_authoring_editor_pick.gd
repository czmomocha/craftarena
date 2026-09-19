extends GutTest

## Editor 3D pick: layout / Label must not swallow clicks; ray range follows
## the Camera3D far plane instead of a magic 256 m cap.

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewMapConvert := preload("res://src/creator/authoring_preview_map_convert.gd")
const AuthoringEditorShellPointerCamera := preload(
	"res://src/creator/authoring_editor_shell_pointer_camera.gd"
)
const AuthoringEditorTransformGizmo := preload(
	"res://src/creator/authoring_editor_transform_gizmo.gd"
)
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWindowLayout := preload("res://src/creator/authoring_window_layout.gd")

const HALF: Vector3 = Vector3(0.5, 0.5, 0.5)
const EPS: float = 0.0001
const OLD_RAY_CAP: float = 256.0

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	AuthoringWindowLayout.reset_split()
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_layout_and_label_do_not_count_as_interactive_gui() -> void:
	assert_false(AuthoringEditorShellPointerCamera.hits_interactive_control(null))
	var box: VBoxContainer = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	assert_false(AuthoringEditorShellPointerCamera.hits_interactive_control(box))
	assert_false(AuthoringEditorShellPointerCamera.hits_interactive_control(row))
	assert_false(AuthoringEditorShellPointerCamera.hits_interactive_control(caption))
	box.free()
	row.free()
	caption.free()


func test_spin_is_editable_button_is_not() -> void:
	var spin: SpinBox = SpinBox.new()
	var button: Button = Button.new()
	assert_true(AuthoringEditorShellPointerCamera.hits_editable_control(spin))
	assert_false(AuthoringEditorShellPointerCamera.hits_editable_control(button))
	spin.free()
	button.free()


func test_buttons_spins_and_lists_count_as_interactive_gui() -> void:
	var button: Button = Button.new()
	var spin: SpinBox = SpinBox.new()
	var option: OptionButton = OptionButton.new()
	var list: ItemList = ItemList.new()
	assert_true(AuthoringEditorShellPointerCamera.hits_interactive_control(button))
	assert_true(AuthoringEditorShellPointerCamera.hits_interactive_control(spin))
	assert_true(AuthoringEditorShellPointerCamera.hits_interactive_control(option))
	assert_true(AuthoringEditorShellPointerCamera.hits_interactive_control(list))
	button.free()
	spin.free()
	option.free()
	list.free()


func test_spinbox_inner_line_edit_counts_as_interactive_gui() -> void:
	var spin: SpinBox = SpinBox.new()
	add_child_autofree(spin)
	var edit: LineEdit = spin.get_line_edit()
	assert_not_null(edit)
	assert_true(AuthoringEditorShellPointerCamera.hits_interactive_control(edit))


func test_chrome_layout_ignores_mouse_buttons_still_stop() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	var root: Control = _shell.window.get_node_or_null("VBoxContainer") as Control
	assert_not_null(root)
	assert_eq(root.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(_shell.chrome.status)
	assert_eq(_shell.chrome.status.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var flow: Control = _shell.tools.find_child("PlaceFlow", true, false) as Control
	assert_not_null(flow)
	assert_eq(flow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var undo: Button = _shell.window.find_child("Undo", true, false) as Button
	assert_not_null(undo)
	assert_eq(undo.mouse_filter, Control.MOUSE_FILTER_STOP)
	var cell_x: SpinBox = _shell.tools.find_child("CellX", true, false) as SpinBox
	assert_not_null(cell_x)
	assert_eq(cell_x.mouse_filter, Control.MOUSE_FILTER_STOP)
	var sky: OptionButton = _shell.tools.find_child("SkySelect", true, false) as OptionButton
	assert_not_null(sky)
	assert_eq(sky.mouse_filter, Control.MOUSE_FILTER_STOP)
	var issues: ItemList = _shell.window.find_child("IssueList", true, false) as ItemList
	assert_not_null(issues)
	assert_eq(issues.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_ray_picks_placeholder_at_y8() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.try_move_entity(1, 0, 8, 0))
	var placed: MeshInstance3D = _shell.map.placeholder_node(1)
	assert_not_null(placed)
	assert_almost_eq(placed.position.y, 8.0, EPS)
	var hit: Dictionary = AuthoringPreviewMapConvert.try_entity_from_ray(
		_shell.map,
		Vector3(0.0, 16.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		HALF
	)
	assert_eq(_dict_bool(hit, "ok", false), true)
	assert_eq(_dict_int(hit, "id", 0), 1)


func test_ray_from_default_edit_camera_picks_high_placeholder() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.try_move_entity(1, 0, 8, 0))
	var camera: Camera3D = _shell.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	var placed: MeshInstance3D = _shell.map.placeholder_node(1)
	assert_not_null(placed)
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = (placed.position - origin).normalized()
	var hit: Dictionary = AuthoringPreviewMapConvert.try_entity_from_ray(
		_shell.map, origin, direction, HALF
	)
	assert_eq(_dict_bool(hit, "ok", false), true)
	assert_eq(_dict_int(hit, "id", 0), 1)


func test_ray_picks_beyond_old_256_t() -> void:
	var map: Node3D = Node3D.new()
	add_child_autofree(map)
	var camera: Camera3D = Camera3D.new()
	camera.name = AuthoringPreviewMap.CAMERA_NAME
	map.add_child(camera)
	assert_gt(camera.far, OLD_RAY_CAP)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "entity_1"
	mesh.position = Vector3.ZERO
	map.add_child(mesh)
	var origin: Vector3 = Vector3(0.0, OLD_RAY_CAP + 44.0, 0.0)
	var hit: Dictionary = AuthoringPreviewMapConvert.try_entity_from_ray(
		map, origin, Vector3(0.0, -1.0, 0.0), HALF
	)
	assert_eq(_dict_bool(hit, "ok", false), true)
	assert_eq(_dict_int(hit, "id", 0), 1)


func test_old_256_cap_misses_far_box_camera_far_hits() -> void:
	var aabb: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var origin: Vector3 = Vector3(0.0, OLD_RAY_CAP + 44.0, 0.0)
	var down: Vector3 = Vector3(0.0, -1.0, 0.0)
	var clipped: float = AuthoringPreviewMapConvert.ray_aabb_t(origin, down, aabb, OLD_RAY_CAP)
	assert_lt(clipped, 0.0)
	var camera: Camera3D = Camera3D.new()
	var open_t: float = AuthoringPreviewMapConvert.ray_aabb_t(origin, down, aabb, camera.far)
	assert_gt(open_t, OLD_RAY_CAP)
	camera.free()


func test_pick_range_reads_camera_far() -> void:
	var map: Node3D = Node3D.new()
	add_child_autofree(map)
	var camera: Camera3D = Camera3D.new()
	map.add_child(camera)
	assert_almost_eq(AuthoringPreviewMapConvert.pick_range(map), camera.far, EPS)
	assert_gt(camera.far, OLD_RAY_CAP)


func test_gizmo_picks_axis_beyond_old_256_t() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_solid())
	assert_eq(_shell.chrome.selected_id, 1)
	var axis: String = AuthoringEditorTransformGizmo.try_pick_axis(
		_shell.map,
		Vector3(OLD_RAY_CAP + 44.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0)
	)
	assert_eq(axis, AuthoringEditorTransformGizmo.AXIS_X)


func _dict_bool(bag: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = bag.get(key, fallback)
	if typeof(raw) != TYPE_BOOL:
		return fallback
	var flag: bool = raw
	return flag


func _dict_int(bag: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = bag.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value
