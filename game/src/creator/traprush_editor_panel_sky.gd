class_name TraprushEditorPanelSky
extends HBoxContainer

## World-level sky picker for TraprushEditorPanel. Writes place /
## set_component only. Not a selected-entity ParamRow field.

const ROW_NAME: String = "SkyRow"
const SKY_SELECT_NAME: String = "SkySelect"
const SKY_LABEL_NAME: String = "SkyLabel"


var panel: TraprushEditorPanel = null
var _select: OptionButton = null


static func attach(host_panel: TraprushEditorPanel) -> void:
	if host_panel == null:
		return
	attach_to(host_panel, host_panel)


static func attach_to(host_panel: TraprushEditorPanel, parent: Node) -> void:
	if host_panel == null or parent == null:
		return
	if host_panel.get_node_or_null(ROW_NAME) != null:
		return
	if parent.get_node_or_null(ROW_NAME) != null:
		return
	var row: TraprushEditorPanelSky = TraprushEditorPanelSky.new()
	parent.add_child(row)
	row.mount(host_panel)


static func sync_panel(host_panel: TraprushEditorPanel, world: AuthoringWorld) -> void:
	if host_panel == null:
		return
	var row: TraprushEditorPanelSky = host_panel.find_child(ROW_NAME, true, false) as TraprushEditorPanelSky
	if row != null:
		row.sync_from_world(world)


func mount(p_panel: TraprushEditorPanel) -> void:
	panel = p_panel
	if get_child_count() > 0:
		return
	name = ROW_NAME
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var caption: Label = Label.new()
	caption.name = SKY_LABEL_NAME
	caption.text = UiCopy.text(UiCopy.SKY)
	add_child(caption)
	_select = OptionButton.new()
	_select.name = SKY_SELECT_NAME
	_select.custom_minimum_size = Vector2(120, 0)
	_select.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_select.fit_to_longest_item = false
	_select.add_item(UiCopy.text(UiCopy.SKY_PASTEL_RIDGE), 0)
	_select.add_item(UiCopy.text(UiCopy.SKY_LOWPOLY_MESA), 1)
	_select.item_selected.connect(_on_item_selected)
	add_child(_select)


func sync_from_world(world: AuthoringWorld) -> void:
	if _select == null:
		return
	var sky_id: int = SharedSkyCatalog.DEFAULT_SKY_ID
	if AuthoringPreviewSky.environment_entity_id(world) != SharedIds.NULL_ID:
		sky_id = AuthoringPreviewSky.sky_id_from_world(world)
	if not SharedSkyCatalog.is_known(sky_id):
		sky_id = SharedSkyCatalog.DEFAULT_SKY_ID
	var index: int = _select.get_item_index(sky_id)
	if index < 0:
		return
	_select.set_block_signals(true)
	_select.select(index)
	_select.set_block_signals(false)


func _on_item_selected(index: int) -> void:
	if _select == null:
		return
	var sky_id: int = _select.get_item_id(index)
	if not _try_write(sky_id):
		if panel != null:
			sync_from_world(panel._world())


func _try_write(sky_id: int) -> bool:
	if panel == null or panel.host == null:
		return false
	var world: AuthoringWorld = panel._world()
	var existing_id: int = AuthoringPreviewSky.environment_entity_id(world)
	if existing_id != SharedIds.NULL_ID:
		return panel.host.try_set_sky(existing_id, sky_id)
	var entity_id: int = panel._peek_entity_id()
	if not panel.host.try_set_sky(entity_id, sky_id):
		return false
	if AuthoringPreviewSky.environment_entity_id(panel._world()) == entity_id:
		panel._commit_entity_id(entity_id)
	return true
