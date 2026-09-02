class_name SharedVisualAssetInstantiate
extends RefCounted

## Shared-mesh instantiate path for SharedVisualAssetCatalog.
## Public try_instantiate stays on the catalog facade so this file stays under E9.

## 扁平化模板缓存：资产路径 → `{ "mesh": Mesh, "transform": Transform3D }`，
## 或空字典表示"这个资产不能扁平化，走 instantiate"。见 `_template_for`。
static var _templates: Dictionary = {}


static func clear_template_cache() -> void:
	_templates = {}


static func try_instantiate(path: String) -> Node3D:
	if path.is_empty():
		return null
	var template: Dictionary = _template_for(path)
	if not template.is_empty():
		return _spawn_from_template(template)
	return _instantiate_scene(path)


static func instantiate_scene(path: String) -> Node3D:
	return _instantiate_scene(path)


static func _instantiate_scene(path: String) -> Node3D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource == null:
		return null
	var packed: PackedScene = resource as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		return null
	var node: Node3D = instance as Node3D
	if node == null:
		instance.free()
		return null
	return node


static func _spawn_from_template(template: Dictionary) -> Node3D:
	var mesh: Mesh = template["mesh"]
	var local: Transform3D = template["transform"]
	var root: Node3D = Node3D.new()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = local
	root.add_child(instance)
	return root


static func _template_for(path: String) -> Dictionary:
	if _templates.has(path):
		return _templates[path]
	var built: Dictionary = _build_template(path)
	_templates[path] = built
	return built


static func _build_template(path: String) -> Dictionary:
	var probe: Node3D = _instantiate_scene(path)
	if probe == null:
		return {}
	var found: Array[Dictionary] = []
	_collect_meshes(probe, Transform3D.IDENTITY, true, found)
	var template: Dictionary = {}
	if found.size() == 1:
		var only: Dictionary = found[0]
		template = {
			"mesh": only["mesh"],
			"transform": only["transform"],
		}
	probe.free()
	return template


static func _collect_meshes(
	node: Node,
	accumulated: Transform3D,
	is_root: bool,
	into: Array[Dictionary]
) -> void:
	var here: Transform3D = accumulated
	var spatial: Node3D = node as Node3D
	if spatial != null and not is_root:
		here = accumulated * spatial.transform
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null and instance.mesh != null:
		if instance.skin != null or instance.skeleton != NodePath(""):
			into.append({})
			into.append({})
			return
		into.append({
			"mesh": instance.mesh,
			"transform": here,
		})
	for child: Node in node.get_children():
		_collect_meshes(child, here, false, into)
