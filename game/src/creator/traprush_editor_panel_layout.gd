class_name TraprushEditorPanelLayout
extends RefCounted

## Compact TRAPRUSH tool strip. Existing EDIT ops only.

const FLOW_NAME: String = "PlaceFlow"
const META_NAME: String = "MetaRow"
const CONVEYOR_DIR_NAME: String = "ConveyorDir"


static func mount(panel: TraprushEditorPanel) -> void:
	if panel == null:
		return
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = FLOW_NAME
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	panel.add_child(flow)
	_add_button(flow, TraprushEditorPanel.PLACE_CHECKPOINT_NAME, UiCopy.PLACE_CHECKPOINT, panel.place_next_checkpoint)
	_add_button(flow, TraprushEditorPanel.PLACE_PORTAL_NAME, UiCopy.PLACE_PORTAL, panel.place_next_portal)
	_add_button(flow, TraprushEditorPanel.PLACE_SOLID_NAME, UiCopy.PLACE_SOLID, panel.place_next_solid)
	_add_button(flow, TraprushEditorPanel.PLACE_HAZARD_NAME, UiCopy.PLACE_HAZARD, panel.place_next_hazard)
	_add_button(flow, TraprushEditorPanel.PLACE_CRATE_NAME, UiCopy.PLACE_CRATE, panel.place_next_crate)
	_add_button(flow, TraprushEditorPanel.PLACE_FINISH_NAME, UiCopy.PLACE_FINISH, panel.place_next_finish)
	_add_button(flow, TraprushEditorPanel.PLACE_MOVER_NAME, UiCopy.PLACE_MOVER, panel.place_next_mover)
	_add_button(flow, TraprushEditorPanel.PLACE_CONVEYOR_NAME, UiCopy.PLACE_CONVEYOR, panel.place_next_conveyor)
	_add_dir_button(flow, panel)
	_add_button(flow, TraprushEditorPanel.PLACE_LIFT_NAME, UiCopy.PLACE_LIFT, panel.place_next_lift)
	_add_button(flow, TraprushEditorPanel.PLACE_LAUNCH_NAME, UiCopy.PLACE_LAUNCH, panel.place_next_launch)
	_add_button(flow, TraprushEditorPanel.PLACE_SWITCH_NAME, UiCopy.PLACE_SWITCH, panel.place_next_switch)
	_add_button(flow, TraprushEditorPanel.PLACE_GATE_NAME, UiCopy.PLACE_GATE, panel.place_next_gate)
	_add_button(flow, TraprushEditorPanel.PLACE_ENERGY_WALL_NAME, UiCopy.PLACE_ENERGY_WALL, panel.place_next_energy_wall)
	_add_button(flow, TraprushEditorPanel.PLACE_GATED_PORTAL_NAME, UiCopy.PLACE_GATED_PORTAL, panel.place_next_gated_portal)
	_add_button(flow, TraprushEditorPanel.PLACE_BOMB_NAME, UiCopy.PLACE_BOMB, panel.place_next_bomb)
	_add_button(flow, TraprushEditorPanel.PLACE_DASH_NAME, UiCopy.PLACE_DASH, panel.place_next_dash)
	_add_button(flow, TraprushEditorPanel.REMOVE_LAST_NAME, UiCopy.REMOVE_LAST, panel.remove_last)
	if panel.traps != null:
		panel.traps.panel = panel
		panel.traps.mount_into(flow)
	var meta: HBoxContainer = HBoxContainer.new()
	meta.name = META_NAME
	meta.add_theme_constant_override("separation", 6)
	panel.add_child(meta)
	_add_button(meta, TraprushEditorPanel.FLOOR_UP_NAME, UiCopy.FLOOR_UP, panel.floor_up)
	_add_button(meta, TraprushEditorPanel.FLOOR_DOWN_NAME, UiCopy.FLOOR_DOWN, panel.floor_down)
	TraprushEditorPanelSky.attach_to(panel, meta)


static func sync_conveyor_dir(panel: TraprushEditorPanel) -> void:
	if panel == null:
		return
	var button: Button = panel.find_child(CONVEYOR_DIR_NAME, true, false) as Button
	if button == null:
		return
	if panel.conveyor_vertical:
		button.text = UiCopy.text(UiCopy.CONVEYOR_AXIS_Z)
	else:
		button.text = UiCopy.text(UiCopy.CONVEYOR_AXIS_X)


static func _add_dir_button(row: Container, panel: TraprushEditorPanel) -> void:
	var button: Button = Button.new()
	button.name = CONVEYOR_DIR_NAME
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44, 0)
	button.pressed.connect(panel.toggle_conveyor_axis)
	row.add_child(button)
	sync_conveyor_dir(panel)


static func _add_button(row: Container, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(handler)
	row.add_child(button)
