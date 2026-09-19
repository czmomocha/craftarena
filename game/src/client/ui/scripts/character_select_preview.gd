class_name CharacterSelectPreview
extends RefCounted

## 3D standee inside the character-select SubViewport. Presentation only.
## Missing assets leave the viewport empty; the screen still works.

const VIEWPORT_PATH: String = "Layout/Main/HBox/PreviewColumn/PreviewFrame/View"
const WORLD_NAME: StringName = &"PreviewWorld"
const LIGHT_NAME: StringName = &"PreviewLight"
const CAMERA_NAME: StringName = &"PreviewCamera"
const VISUAL_NAME: StringName = &"PreviewVisual"
const YAW_SPEED: float = 0.6

var _world: Node3D = null
var _visual: Node3D = null
var _shown_id: String = ""


func mount(host: Control) -> void:
	if _world != null:
		return
	var viewport: SubViewport = host.get_node_or_null(VIEWPORT_PATH) as SubViewport
	if viewport == null:
		return
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world = Node3D.new()
	_world.name = String(WORLD_NAME)
	viewport.add_child(_world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = String(LIGHT_NAME)
	light.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	_world.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.name = String(CAMERA_NAME)
	camera.position = Vector3(0.0, 0.85, 1.7)
	camera.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
	_world.add_child(camera)
	camera.current = true


func show_id(id: String) -> void:
	var resolved: String = SharedCharacterCatalog.resolve(id)
	if resolved == _shown_id and _visual != null:
		return
	_clear_visual()
	if _world == null:
		return
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(
		SharedCharacterCatalog.scene_path(resolved)
	)
	if visual == null:
		_shown_id = ""
		return
	visual.name = String(VISUAL_NAME)
	SharedVisualAssetCatalog.fit_character_on_cell(visual)
	_world.add_child(visual)
	_visual = visual
	_shown_id = resolved


func advance(delta: float) -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	_visual.rotate_y(YAW_SPEED * delta)


func clear() -> void:
	_clear_visual()
	_shown_id = ""
	_world = null


func _clear_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		var parent: Node = _visual.get_parent()
		if parent != null:
			parent.remove_child(_visual)
		_visual.free()
	_visual = null
