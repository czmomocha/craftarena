class_name TraprushEditorPanelCursor
extends HBoxContainer

## Cell cursor for TraprushEditorPanel. SpinBoxes are the write path;
## clicking the Editor 3D view only updates X/Z on the current floor.
## Not a new EDIT op.

signal cell_changed

const CELL_X_NAME: String = "CellX"
const CELL_Y_NAME: String = "CellY"
const CELL_Z_NAME: String = "CellZ"
const CELL_MIN: int = -64
const CELL_MAX: int = 64

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")

var cell_x: int = 0
var cell_y: int = 0
var cell_z: int = 0
var _syncing: bool = false
var spin_x: SpinBox = null
var spin_y: SpinBox = null
var spin_z: SpinBox = null


func mount() -> void:
	if get_child_count() > 0:
		return
	name = "CursorRow"
	spin_x = _add_spin(CELL_X_NAME, "X")
	spin_y = _add_spin(CELL_Y_NAME, "Y")
	spin_z = _add_spin(CELL_Z_NAME, "Z")
	_push_spins()


func set_cell(x: int, y: int, z: int) -> void:
	cell_x = x
	cell_y = y
	cell_z = z
	_push_spins()


func bump_x() -> void:
	set_cell(cell_x + 1, cell_y, cell_z)


func try_pick_from_ray(origin: Vector3, direction: Vector3) -> bool:
	var picked: Dictionary = ConvertGd.try_cell_xz_from_ray(
		origin,
		direction,
		float(cell_y)
	)
	var ok_raw: Variant = picked.get("ok", false)
	if typeof(ok_raw) != TYPE_BOOL or not ok_raw:
		return false
	var x_raw: Variant = picked.get("x", 0)
	var z_raw: Variant = picked.get("z", 0)
	if typeof(x_raw) != TYPE_INT or typeof(z_raw) != TYPE_INT:
		return false
	var next_x: int = x_raw
	var next_z: int = z_raw
	set_cell(next_x, cell_y, next_z)
	return true


func _add_spin(node_name: String, caption: String) -> SpinBox:
	var label: Label = Label.new()
	label.text = caption
	add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.name = node_name
	spin.min_value = float(CELL_MIN)
	spin.max_value = float(CELL_MAX)
	spin.step = 1.0
	spin.rounded = true
	spin.value_changed.connect(_on_spin_changed)
	add_child(spin)
	return spin


func _on_spin_changed(_value: float) -> void:
	if _syncing:
		return
	cell_x = _spin_int(spin_x)
	cell_y = _spin_int(spin_y)
	cell_z = _spin_int(spin_z)
	cell_changed.emit()


func _spin_int(spin: SpinBox) -> int:
	if spin == null:
		return 0
	return int(spin.value)


func _push_spins() -> void:
	_syncing = true
	if spin_x != null:
		spin_x.value = float(cell_x)
	if spin_y != null:
		spin_y.value = float(cell_y)
	if spin_z != null:
		spin_z.value = float(cell_z)
	_syncing = false
