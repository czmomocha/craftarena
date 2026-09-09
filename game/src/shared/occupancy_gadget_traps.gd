extends RefCounted

## Spike / flame / crusher procedural meshes. OccupancyGadget.attach dispatches
## here so occupancy_gadget.gd stays under E9.


static func fill_spike(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Base",
		OccupancyGadget._box(Vector3(0.9, 0.08, 0.9)),
		PlaceholderSpec.SPIKE_ALBEDO,
		Vector3(0.0, -0.42, 0.0)
	)
	var offsets: Array[Vector3] = [
		Vector3(-0.22, -0.12, -0.22),
		Vector3(0.22, -0.12, -0.22),
		Vector3(-0.22, -0.12, 0.22),
		Vector3(0.22, -0.12, 0.22),
		Vector3(0.0, -0.08, 0.0),
	]
	for pos: Vector3 in offsets:
		OccupancyGadget._mesh(
			gadget,
			"Spike",
			OccupancyGadget._box(Vector3(0.12, 0.55, 0.12)),
			PlaceholderSpec.SPIKE_MARK_ALBEDO,
			pos
		)


static func fill_flame(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Vent",
		OccupancyGadget._box(Vector3(0.7, 0.12, 0.7)),
		PlaceholderSpec.FLAME_ALBEDO,
		Vector3(0.0, -0.4, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Column",
		OccupancyGadget._box(Vector3(0.28, 0.7, 0.28)),
		PlaceholderSpec.FLAME_MARK_ALBEDO,
		Vector3(0.0, 0.05, 0.0),
		true
	)


static func fill_crusher(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Slab",
		OccupancyGadget._box(Vector3(0.92, 0.22, 0.92)),
		PlaceholderSpec.CRUSHER_ALBEDO,
		Vector3(0.0, 0.28, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Stem",
		OccupancyGadget._box(Vector3(0.16, 0.55, 0.16)),
		PlaceholderSpec.CRUSHER_MARK_ALBEDO,
		Vector3(0.0, -0.12, 0.0)
	)


static func fill_roller(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Log",
		OccupancyGadget._box(Vector3(0.92, 0.36, 0.36)),
		PlaceholderSpec.ROLLER_ALBEDO,
		Vector3(0.0, 0.0, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Band",
		OccupancyGadget._box(Vector3(0.18, 0.4, 0.4)),
		PlaceholderSpec.ROLLER_MARK_ALBEDO,
		Vector3(0.0, 0.0, 0.0)
	)


static func fill_rubble(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Pile",
		OccupancyGadget._box(Vector3(0.7, 0.28, 0.7)),
		PlaceholderSpec.RUBBLE_ALBEDO,
		Vector3(0.0, -0.28, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Chunk",
		OccupancyGadget._box(Vector3(0.32, 0.28, 0.32)),
		PlaceholderSpec.RUBBLE_MARK_ALBEDO,
		Vector3(0.16, 0.0, -0.12)
	)


static func fill_obstacle_core(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Shell",
		OccupancyGadget._box(Vector3(0.7, 0.7, 0.7)),
		PlaceholderSpec.OBSTACLE_CORE_ALBEDO,
		Vector3(0.0, 0.0, 0.0),
		true
	)
	OccupancyGadget._mesh(
		gadget,
		"Heart",
		OccupancyGadget._box(Vector3(0.28, 0.28, 0.28)),
		PlaceholderSpec.OBSTACLE_CORE_MARK_ALBEDO,
		Vector3(0.0, 0.0, 0.0)
	)


static func fill_pendulum(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Beam",
		OccupancyGadget._box(Vector3(0.92, 0.18, 0.28)),
		PlaceholderSpec.PENDULUM_ALBEDO,
		Vector3(0.0, 0.18, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Bob",
		OccupancyGadget._box(Vector3(0.32, 0.32, 0.32)),
		PlaceholderSpec.PENDULUM_MARK_ALBEDO,
		Vector3(0.28, -0.12, 0.0)
	)


static func fill_ice(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Sheet",
		OccupancyGadget._box(Vector3(0.92, 0.08, 0.92)),
		PlaceholderSpec.ICE_ALBEDO,
		Vector3(0.0, -0.4, 0.0),
		true
	)
	OccupancyGadget._mesh(
		gadget,
		"Arrow",
		OccupancyGadget._box(Vector3(0.18, 0.08, 0.55)),
		PlaceholderSpec.ICE_MARK_ALBEDO,
		Vector3(0.0, -0.32, -0.12)
	)
