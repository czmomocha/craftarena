extends GutTest

## TraprushEditorPanel 天空下拉：place / set_component，不新增 EDIT op。
## PreviewCamera 的 IBL 关闭是契约，不是贴图/清屏色断言。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewSky := preload("res://src/creator/authoring_preview_sky.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const SharedComponentNames := preload("res://src/shared/schema/component_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushEditorPanelSky := preload("res://src/creator/traprush_editor_panel_sky.gd")

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_open_editor_camera_uses_sky_without_ibl() -> void:
	_open_shell()
	var camera: Camera3D = _shell.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	assert_not_null(camera.environment)
	assert_eq(camera.environment.background_mode, Environment.BG_SKY)
	assert_eq(camera.environment.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED)
	assert_eq(camera.environment.reflected_light_source, Environment.REFLECTION_SOURCE_DISABLED)


func test_empty_world_defaults_to_sky_zero_then_places_once() -> void:
	_open_shell()
	var select: OptionButton = _sky_select()
	assert_not_null(select)
	assert_eq(select.get_selected_id(), 0)
	assert_eq(_environment_count(_shell.session.world), 0)
	_emit_sky(1)
	assert_eq(_shell.session.world.revision, 1)
	assert_eq(_environment_count(_shell.session.world), 1)
	var entity_id: int = AuthoringPreviewSky.environment_entity_id(_shell.session.world)
	assert_true(SharedIds.is_valid(entity_id))
	var record: SharedComponentRecord = _shell.session.world.get_record(entity_id)
	assert_not_null(record)
	assert_true(record.components.has(SharedComponentNames.ENVIRONMENT))
	assert_false(record.components.has(SharedComponentNames.TRANSFORM))
	var bag_raw: Variant = record.components[SharedComponentNames.ENVIRONMENT]
	assert_eq(typeof(bag_raw), TYPE_DICTIONARY)
	var bag: Dictionary = bag_raw
	var placed_sky: int = bag.get("sky_id", -1)
	assert_eq(placed_sky, 1)
	_emit_sky(1)
	assert_eq(_shell.session.world.revision, 1)
	assert_eq(_environment_count(_shell.session.world), 1)


func test_undo_after_sky_place_drops_entity_or_sky_zero() -> void:
	_open_shell()
	_emit_sky(1)
	assert_eq(_environment_count(_shell.session.world), 1)
	assert_true(_shell.undo())
	var remaining: int = _environment_count(_shell.session.world)
	var sky_id: int = AuthoringPreviewSky.sky_id_from_world(_shell.session.world)
	assert_true(remaining == 0 or sky_id == 0)


func test_connected_preview_follows_sky_dropdown() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	assert_eq(AuthoringPreviewSky.sky_id_from_world(_shell.preview.preview.world), 0)
	_emit_sky(1)
	assert_eq(AuthoringPreviewSky.sky_id_from_world(_shell.session.world), 1)
	assert_eq(AuthoringPreviewSky.sky_id_from_world(_shell.preview.preview.world), 1)
	assert_true(_shell.preview_follows)


func test_set_component_keeps_other_bags_and_skips_same_id() -> void:
	_open_shell()
	assert_true(_shell.try_edit({
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": 4,
			"components": {
				SharedComponentNames.ENVIRONMENT: {"sky_id": 0},
				SharedComponentNames.REPLICATION: {"policy_id": 2},
			},
		},
	}))
	_shell.tools.adopt_world(_shell.session.world)
	_emit_sky(1)
	var record: SharedComponentRecord = _shell.session.world.get_record(4)
	assert_not_null(record)
	assert_eq(_environment_count(_shell.session.world), 1)
	var env_raw: Variant = record.components.get(SharedComponentNames.ENVIRONMENT, {})
	assert_eq(typeof(env_raw), TYPE_DICTIONARY)
	var env: Dictionary = env_raw
	var replaced_sky: int = env.get("sky_id", -1)
	assert_eq(replaced_sky, 1)
	assert_true(record.components.has(SharedComponentNames.REPLICATION))
	var rev: int = _shell.session.world.revision
	_emit_sky(1)
	assert_eq(_shell.session.world.revision, rev)


func _open_shell() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())


func _sky_select() -> OptionButton:
	if _shell == null or _shell.tools == null:
		return null
	return _shell.tools.find_child(TraprushEditorPanelSky.SKY_SELECT_NAME, true, false) as OptionButton


func _emit_sky(sky_id: int) -> void:
	var select: OptionButton = _sky_select()
	assert_not_null(select)
	var index: int = select.get_item_index(sky_id)
	assert_gte(index, 0)
	select.select(index)
	select.item_selected.emit(index)


func _environment_count(world: AuthoringWorld) -> int:
	if world == null:
		return 0
	var count: int = 0
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record != null and record.components.has(SharedComponentNames.ENVIRONMENT):
			count += 1
	return count
