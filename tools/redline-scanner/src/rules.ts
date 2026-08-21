/**
 * High-signal Godot 3 identifiers from the official 3 → 4 rename table:
 * https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html
 *
 * This is an initial slice, not an exhaustive catalog. Names that still exist
 * in Godot 4 (Viewport) or are common English words (Listener) are omitted.
 */
export const GODOT3_IDENTIFIERS: readonly string[] = [
	"AnimatedSprite",
	"ARVRAnchor",
	"ARVRCamera",
	"ARVRController",
	"ARVRInterface",
	"ARVROrigin",
	"ARVRPositionalTracker",
	"ARVRServer",
	"BoxShape",
	"CapsuleShape",
	"CubeMesh",
	"EditorSpatialGizmo",
	"EditorSpatialGizmoPlugin",
	"GIProbe",
	"GIProbeData",
	"GradientTexture",
	"KinematicBody",
	"KinematicBody2D",
	"Light2D",
	"LineShape2D",
	"Navigation2DServer",
	"NavigationMeshInstance",
	"NavigationPolygonInstance",
	"Physics2DServer",
	"PoolByteArray",
	"PoolColorArray",
	"PoolIntArray",
	"PoolRealArray",
	"PoolStringArray",
	"PoolVector2Array",
	"PoolVector3Array",
	"Position2D",
	"Position3D",
	"ShortCut",
	"Spatial",
	"SpatialGizmo",
	"SpatialMaterial",
	"StreamTexture",
	"TextureProgress",
	"VideoPlayer",
	"ViewportContainer",
	"VisibilityEnabler",
	"VisibilityNotifier",
	"VisibilityNotifier2D",
	"VisibilityNotifier3D",
	"VisualServer",
	"YSort",
];

export const SCENE_TREE_IDENTIFIERS: readonly string[] = [
	"Node",
	"Node2D",
	"Node3D",
	"NodePath",
	"SceneTree",
	"get_tree",
	"_process",
];

export const RULE_ID = {
	simulationNoSceneTree: "simulation-no-scene-tree",
	simulationNoFloat: "simulation-no-float",
	coreNoGdextension: "core-no-gdextension",
	noGodot3Api: "no-godot3-api",
	noDotnet: "no-dotnet",
} as const;

export type RuleId = (typeof RULE_ID)[keyof typeof RULE_ID];

export const CORE_SRC_DIRS = ["shared", "simulation", "ugc", "server", "creator"] as const;
