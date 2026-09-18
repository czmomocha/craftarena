extends GutTest

## A2 对局壳天空：Camera3D.environment + IBL 关闭。
## 不断言贴图像素或清屏色。BASTION 相机不得被同一片天染上。

const MatchLobbyShell := preload("res://src/client/match_lobby_shell.gd")
const MatchLobbyStageBastionGd := preload("res://src/client/match_lobby_stage_bastion.gd")
const MatchLobbyStageSky := preload("res://src/client/match_lobby_stage_sky.gd")
const MatchSnapshotMap := preload("res://src/client/match_snapshot_map.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const SharedSkyCatalog := preload("res://src/shared/sky_catalog.gd")
const SharedSkyEnvironment := preload("res://src/shared/sky_environment.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

var _shell: MatchLobbyShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_make_uses_sky_background_and_disables_ibl() -> void:
	var environment: Environment = SharedSkyEnvironment.make(SharedSkyCatalog.DEFAULT_SKY_ID)
	assert_not_null(environment)
	assert_eq(environment.background_mode, Environment.BG_SKY)
	assert_eq(environment.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED)
	assert_eq(environment.reflected_light_source, Environment.REFLECTION_SOURCE_DISABLED)
	assert_eq(_panorama_path_of(environment), SharedSkyCatalog.texture_path(0))


func test_unknown_sky_id_falls_back_to_default_texture() -> void:
	var environment: Environment = SharedSkyEnvironment.make(SharedSkyCatalog.SKY_ID_MAX + 9)
	assert_not_null(environment)
	assert_eq(_panorama_path_of(environment), SharedSkyCatalog.texture_path(0))


func test_official_course_hangs_default_sky_on_snapshot_camera() -> void:
	_shell = _open_shell()
	var camera: Camera3D = _shell.map.camera_node()
	assert_not_null(camera)
	assert_not_null(camera.environment)
	assert_eq(camera.environment.background_mode, Environment.BG_SKY)
	assert_eq(camera.environment.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED)
	assert_eq(camera.environment.reflected_light_source, Environment.REFLECTION_SOURCE_DISABLED)
	assert_eq(
		_panorama_path_of(camera.environment),
		SharedSkyCatalog.texture_path(SharedSkyCatalog.DEFAULT_SKY_ID)
	)
	assert_eq(_count_world_environments(_shell.window), 0)


func test_bundle_sky_id_one_selects_the_other_catalog_entry() -> void:
	var map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(map)
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(90, {
		SharedComponentNames.ENVIRONMENT: {"sky_id": 1},
	})))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_true(MatchLobbyStageSky.apply_from_bundle(map, bundle))
	var camera: Camera3D = map.camera_node()
	assert_not_null(camera)
	assert_eq(_panorama_path_of(camera.environment), SharedSkyCatalog.texture_path(1))
	assert_eq(camera.environment.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED)


func test_empty_bundle_and_missing_path_still_use_default_sky() -> void:
	var map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(map)
	assert_true(MatchLobbyStageSky.apply_from_bundle(map, null))
	assert_eq(
		_panorama_path_of(map.camera_node().environment),
		SharedSkyCatalog.texture_path(0)
	)
	assert_true(MatchLobbyStageSky.apply_from_path(map, ""))
	assert_eq(
		_panorama_path_of(map.camera_node().environment),
		SharedSkyCatalog.texture_path(0)
	)
	assert_true(MatchLobbyStageSky.apply_from_path(map, OfficialTraprushCoursesGd.default_path()))
	assert_eq(
		_panorama_path_of(map.camera_node().environment),
		SharedSkyCatalog.texture_path(0)
	)


func test_bastion_camera_stays_clear_of_traprush_sky() -> void:
	_shell = _open_shell()
	var field: BastionFieldMap = MatchLobbyStageBastionGd.field_of(_shell)
	assert_not_null(field)
	field.ensure_rig()
	var trap_camera: Camera3D = _shell.map.camera_node()
	var bastion_camera: Camera3D = field.camera_node()
	assert_not_null(trap_camera)
	assert_not_null(trap_camera.environment)
	assert_not_null(bastion_camera)
	assert_null(bastion_camera.environment)
	assert_eq(_count_world_environments(_shell.window), 0)
	assert_true(_shell.window.own_world_3d)


func _open_shell() -> MatchLobbyShell:
	var shell: MatchLobbyShell = MatchLobbyShell.create()
	add_child(shell)
	assert_true(shell.open())
	assert_true(shell.is_window_visible())
	return shell


func _panorama_path_of(environment: Environment) -> String:
	if environment == null or environment.sky == null:
		return ""
	var material: PanoramaSkyMaterial = environment.sky.sky_material as PanoramaSkyMaterial
	if material == null or material.panorama == null:
		return ""
	return material.panorama.resource_path


func _count_world_environments(root: Node) -> int:
	if root == null:
		return 0
	var count: int = 0
	if root is WorldEnvironment:
		count += 1
	for child: Node in root.get_children():
		count += _count_world_environments(child)
	return count
