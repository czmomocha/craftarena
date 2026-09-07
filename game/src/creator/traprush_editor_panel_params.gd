class_name TraprushEditorPanelParams
extends VBoxContainer

## Selected-entity fields. Writes set_component only (F-line FF).

const COOLDOWN_NAME: String = "CooldownTicks"
const DURABILITY_NAME: String = "Durability"
const ORDER_NAME: String = "CheckpointOrder"
const RESPAWN_DX_NAME: String = "RespawnDx"
const RESPAWN_DY_NAME: String = "RespawnDy"
const RESPAWN_DZ_NAME: String = "RespawnDz"
const ASSET_ID_NAME: String = "AssetId"

var host: AuthoringEditorShell = null
var _syncing: bool = false


func mount(p_host: AuthoringEditorShell) -> void:
	host = p_host
	if get_child_count() > 0:
		return
	name = "ParamRow"
	_add_spin(COOLDOWN_NAME, 0, 600)
	_add_spin(DURABILITY_NAME, 0, 99)
	_add_spin(ORDER_NAME, 0, 64)
	_add_spin(RESPAWN_DX_NAME, -8, 8)
	_add_spin(RESPAWN_DY_NAME, -8, 8)
	_add_spin(RESPAWN_DZ_NAME, -8, 8)
	_add_spin(ASSET_ID_NAME, 1, 32)


func sync_selection() -> void:
	if host == null or host.chrome == null or host.session == null:
		return
	var entity_id: int = host.chrome.selected_id
	if entity_id < 1 or host.session.world == null:
		return
	var record: SharedComponentRecord = host.session.world.get_record(entity_id)
	if record == null:
		return
	_syncing = true
	_fill_hazard(record)
	_fill_crate(record)
	_fill_checkpoint(record)
	_fill_asset(record)
	_syncing = false


func _fill_hazard(record: SharedComponentRecord) -> void:
	if not record.components.has(SharedComponentNames.HAZARD):
		return
	var raw: Variant = record.components[SharedComponentNames.HAZARD]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var bag: Dictionary = raw
	_set_spin(COOLDOWN_NAME, PlayClock.dict_int(bag, "cooldown_ticks", 1))


func _fill_crate(record: SharedComponentRecord) -> void:
	if not record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return
	var raw: Variant = record.components[SharedComponentNames.DESTRUCTIBLE]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var bag: Dictionary = raw
	_set_spin(DURABILITY_NAME, PlayClock.dict_int(bag, "durability", 1))


func _fill_checkpoint(record: SharedComponentRecord) -> void:
	if not record.components.has(SharedComponentNames.CHECKPOINT):
		return
	var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var bag: Dictionary = raw
	_set_spin(ORDER_NAME, PlayClock.dict_int(bag, "order", 0))
	_set_spin(RESPAWN_DX_NAME, PlayClock.dict_int(bag, "respawn_dx", 0) / _cell())
	_set_spin(RESPAWN_DY_NAME, PlayClock.dict_int(bag, "respawn_dy", 0) / _cell())
	_set_spin(RESPAWN_DZ_NAME, PlayClock.dict_int(bag, "respawn_dz", 0) / _cell())


func _fill_asset(record: SharedComponentRecord) -> void:
	if not record.components.has(SharedComponentNames.GAMEPLAY_ASSET):
		_set_spin(ASSET_ID_NAME, SharedGameplayAssetCatalog.LATTICE_CELL_ID)
		return
	var raw: Variant = record.components[SharedComponentNames.GAMEPLAY_ASSET]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var bag: Dictionary = raw
	_set_spin(ASSET_ID_NAME, PlayClock.dict_int(bag, "asset_id", 1))


func _on_changed(_value: float) -> void:
	if _syncing or host == null or host.chrome == null:
		return
	var entity_id: int = host.chrome.selected_id
	if entity_id < 1 or host.session == null or host.session.world == null:
		return
	var record: SharedComponentRecord = host.session.world.get_record(entity_id)
	if record == null:
		return
	var next: Dictionary = record.to_dictionary()
	var components_raw: Variant = next.get("components", {})
	if typeof(components_raw) != TYPE_DICTIONARY:
		return
	var components: Dictionary = components_raw
	_write_hazard(components)
	_write_crate(components)
	_write_checkpoint(components)
	_write_asset(components)
	next["components"] = components
	host.try_edit({"op": "set_component", "record": next})


func _write_hazard(components: Dictionary) -> void:
	if not components.has(SharedComponentNames.HAZARD):
		return
	var raw: Variant = components[SharedComponentNames.HAZARD]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var typed: Dictionary = raw
	var bag: Dictionary = typed.duplicate(true)
	bag["cooldown_ticks"] = _spin_int(COOLDOWN_NAME)
	components[SharedComponentNames.HAZARD] = bag


func _write_crate(components: Dictionary) -> void:
	if not components.has(SharedComponentNames.DESTRUCTIBLE):
		return
	var raw: Variant = components[SharedComponentNames.DESTRUCTIBLE]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var typed: Dictionary = raw
	var bag: Dictionary = typed.duplicate(true)
	bag["durability"] = _spin_int(DURABILITY_NAME)
	components[SharedComponentNames.DESTRUCTIBLE] = bag


func _write_checkpoint(components: Dictionary) -> void:
	if not components.has(SharedComponentNames.CHECKPOINT):
		return
	var raw: Variant = components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var typed: Dictionary = raw
	var bag: Dictionary = typed.duplicate(true)
	var cell: int = _cell()
	bag["order"] = _spin_int(ORDER_NAME)
	bag["respawn_dx"] = _spin_int(RESPAWN_DX_NAME) * cell
	bag["respawn_dy"] = _spin_int(RESPAWN_DY_NAME) * cell
	bag["respawn_dz"] = _spin_int(RESPAWN_DZ_NAME) * cell
	components[SharedComponentNames.CHECKPOINT] = bag


func _write_asset(components: Dictionary) -> void:
	var asset_id: int = _spin_int(ASSET_ID_NAME)
	if not SharedGameplayAssetCatalog.has_asset(asset_id):
		return
	var version: int = SharedGameplayAssetCatalog.current_version(asset_id)
	components[SharedComponentNames.GAMEPLAY_ASSET] = {
		"asset_id": asset_id,
		"gameplay_version": version,
	}


func _add_spin(node_name: String, min_v: int, max_v: int) -> void:
	var spin: SpinBox = SpinBox.new()
	spin.name = node_name
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value_changed.connect(_on_changed)
	add_child(spin)


func _set_spin(node_name: String, value: int) -> void:
	var spin: SpinBox = get_node_or_null(node_name) as SpinBox
	if spin != null:
		spin.value = value


func _spin_int(node_name: String) -> int:
	var spin: SpinBox = get_node_or_null(node_name) as SpinBox
	if spin == null:
		return 0
	return int(spin.value)


func _cell() -> int:
	if host == null or host.session == null or host.session.world == null:
		return 1
	if host.session.world.grid == null or host.session.world.grid.cell < 1:
		return 1
	return host.session.world.grid.cell
