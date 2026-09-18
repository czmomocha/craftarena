class_name SharedSkyEnvironment
extends RefCounted

## TRAPRUSH 相机上的全景天空。只给 `Camera3D.environment`，从不挂
## `WorldEnvironment`：对局窗里 TRAPRUSH 的 SnapshotMap 与 BASTION 的
## BastionFieldMap 共用同一个 `World3D`（`own_world_3d = true`），挂世界级
## Environment 会把 BASTION 那台相机也染成同一片天。
##
## 环境光与反射**显式关掉**。天空一旦作为背景，Godot 默认把 ambient /
## reflected 源设成 Background，于是全景会参与 IBL。占位色块是 UNSHADED、
## 地块贴图挂在 emissive，都不受影响；角色 `animal-cat.glb` 走
## `baseColor + ORM + normal`，会被天空环境光改亮度。关掉之后照明仍只来自
## 已有的 `DirectionalLight3D`，与接线前一致。这是有意的选择，不是漏设。
##
## 贴图路径只从 `SharedSkyCatalog` 读。未知 id / 缺文件回退默认天空；默认
## 也缺就清掉 Environment，画面回到引擎清屏色，开局不因一张图失败。
##
## 从 AuthoringWorld / SimulationBundle / 课路径解析 `sky_id` 不在本文件：
## `shared/` 不依赖 `creator/` 与 `ugc/`。调用方自己扫实体或袋子，再把
## 解析出的 id 交给 `apply_to_camera`。

static func apply_to_camera(camera: Camera3D, sky_id: int) -> bool:
	if camera == null:
		return false
	var environment: Environment = make(sky_id)
	if environment == null:
		camera.environment = null
		return false
	camera.environment = environment
	return true


static func make(sky_id: int) -> Environment:
	var resolved: int = SharedSkyCatalog.resolve(sky_id)
	var texture: Texture2D = _load_texture(resolved)
	if texture == null and resolved != SharedSkyCatalog.DEFAULT_SKY_ID:
		texture = _load_texture(SharedSkyCatalog.DEFAULT_SKY_ID)
	if texture == null:
		return null
	var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	panorama.panorama = texture
	var sky: Sky = Sky.new()
	sky.sky_material = panorama
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	return environment


static func _load_texture(sky_id: int) -> Texture2D:
	var path: String = SharedSkyCatalog.texture_path(sky_id)
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
