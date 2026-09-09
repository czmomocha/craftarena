class_name TraprushEditorPanelTraps
extends HBoxContainer

## Place spike / flame / crusher. Public place_next_* stays on the panel
## facade so traprush_editor_panel.gd stays under E9.

const PLACE_SPIKE_NAME: String = "PlaceSpike"
const PLACE_FLAME_NAME: String = "PlaceFlame"
const PLACE_CRUSHER_NAME: String = "PlaceCrusher"
const PLACE_ROLLER_NAME: String = "PlaceRoller"
const PLACE_RUBBLE_NAME: String = "PlaceRubble"
const PLACE_CORE_NAME: String = "PlaceObstacleCore"
const PLACE_PENDULUM_NAME: String = "PlacePendulum"
const PLACE_ICE_NAME: String = "PlaceIce"

var panel: TraprushEditorPanel = null
var _next_ice_yaw: int = 0


func mount(p_panel: TraprushEditorPanel) -> void:
	panel = p_panel
	if get_child_count() > 0:
		return
	name = "TrapRow"
	_add_button(PLACE_SPIKE_NAME, UiCopy.PLACE_SPIKE, place_next_spike)
	_add_button(PLACE_FLAME_NAME, UiCopy.PLACE_FLAME, place_next_flame)
	_add_button(PLACE_CRUSHER_NAME, UiCopy.PLACE_CRUSHER, place_next_crusher)
	_add_button(PLACE_ROLLER_NAME, UiCopy.PLACE_ROLLER, place_next_roller)
	_add_button(PLACE_RUBBLE_NAME, UiCopy.PLACE_RUBBLE, place_next_rubble)
	_add_button(PLACE_CORE_NAME, UiCopy.PLACE_OBSTACLE_CORE, place_next_obstacle_core)
	_add_button(PLACE_PENDULUM_NAME, UiCopy.PLACE_PENDULUM, place_next_pendulum)
	_add_button(PLACE_ICE_NAME, UiCopy.PLACE_ICE, place_next_ice)


func place_next_spike() -> bool:
	return _place_kind("spike")


func place_next_flame() -> bool:
	return _place_kind("flame")


func place_next_crusher() -> bool:
	return _place_kind("crusher")


func place_next_roller() -> bool:
	return _place_kind("roller")


func place_next_rubble() -> bool:
	return _place_kind("rubble")


func place_next_obstacle_core() -> bool:
	return _place_kind("obstacle_core")


func place_next_pendulum() -> bool:
	return _place_kind("pendulum")


func place_next_ice() -> bool:
	if panel == null:
		return false
	var yaw_bam: int = _next_ice_yaw
	if not panel._place_occupancy(func(entity_id: int) -> bool:
		return panel.host.try_place_ice(
			entity_id, panel.cursor.cell_x, panel.cursor.cell_y, panel.cursor.cell_z, yaw_bam
		)
	):
		return false
	_next_ice_yaw = (yaw_bam + Fixed.BAM_TURN / 4) % Fixed.BAM_TURN
	return true


func _place_kind(kind: String) -> bool:
	if panel == null:
		return false
	return panel._place_occupancy(func(entity_id: int) -> bool:
		return panel.host.try_place_named_trap(
			kind, entity_id, panel.cursor.cell_x, panel.cursor.cell_y, panel.cursor.cell_z
		)
	)


func _add_button(node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	add_child(button)
