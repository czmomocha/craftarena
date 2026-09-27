class_name TraprushCourse08BuilderPlace
extends RefCounted

## Place helpers for course_08. Payloads stay on the editor place modules.

const LayoutGd := preload("res://src/games/traprush/course_08_layout.gd")
const PlaceGd := preload("res://src/creator/authoring_editor_shell_place.gd")
const PlaceMotionGd := preload("res://src/creator/authoring_editor_shell_place_motion.gd")
const PlaceTriggersGd := preload("res://src/creator/authoring_editor_shell_place_triggers.gd")
const PickupKindsGd := preload("res://src/ugc/traprush_pickup_kinds.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

const CELL: int = Fixed.SCALE
const HALF: int = CELL / 2
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-course-08"


static func place(session: AuthoringSession, payload: Dictionary) -> bool:
	var command_id: int = session.world.revision + 1
	var command: SharedCommand = SharedCommand.create(
		command_id,
		ACTOR_ID,
		command_id,
		0,
		session.world.revision,
		CONTENT_VERSION,
		payload,
		TRACE_ID,
		SharedCommand.Kind.EDIT
	)
	if command == null:
		return false
	return session.try_apply(command)


static func place_checkpoints(session: AuthoringSession) -> bool:
	var order: int = 0
	while order < LayoutGd.CHECKPOINT_COUNT:
		var cell: Vector2i = LayoutGd.checkpoint_xz(order)
		var standing: int = LayoutGd.checkpoint_standing(order)
		if not place(session, PlaceGd.checkpoint_payload(
			LayoutGd.CHECKPOINT_ID_START + order,
			order,
			cell.x * CELL,
			standing * CELL,
			cell.y * CELL
		)):
			printerr("course_08 checkpoint %d failed at %s s=%d" % [order, str(cell), standing])
			return false
		order += 1
	return true


static func place_finish(session: AuthoringSession) -> bool:
	var cell: Vector2i = LayoutGd.FINISH_XZ
	if not place(session, PlaceGd.zone_payload(
		LayoutGd.FINISH_ID,
		cell.x * CELL,
		LayoutGd.finish_standing() * CELL,
		cell.y * CELL,
		HALF,
		TraprushTopologyCompiler.FINISH_ZONE_TAG
	)):
		printerr("course_08 finish failed")
		return false
	return true


static func place_portals(session: AuthoringSession) -> bool:
	var pairs: Array[PackedInt32Array] = LayoutGd.portal_pairs()
	var next_id: int = LayoutGd.PORTAL_ID_START
	for pair: PackedInt32Array in pairs:
		if pair.size() < 6:
			return false
		var a: int = next_id
		var b: int = next_id + 1
		next_id += 2
		if not place(session, PlaceGd.portal_payload(
			a, b, pair[0] * CELL, pair[1] * CELL, pair[2] * CELL
		)):
			printerr("course_08 portal %d failed" % a)
			return false
		if not place(session, PlaceGd.portal_payload(
			b, a, pair[3] * CELL, pair[4] * CELL, pair[5] * CELL
		)):
			printerr("course_08 portal %d failed" % b)
			return false
	return true


static func place_floors(session: AuthoringSession, next_id: Array[int]) -> bool:
	return _fill_spans(session, next_id, LayoutGd.floor_spans(), true)


static func place_rails(session: AuthoringSession, next_id: Array[int]) -> bool:
	return _fill_spans(session, next_id, LayoutGd.rail_spans(), false)


static func place_gadgets(session: AuthoringSession, next_id: Array[int]) -> bool:
	if not _place_launches(session, next_id):
		return false
	if not _place_conveyors(session, next_id):
		return false
	if not _place_crushers(session, next_id):
		return false
	if not _place_baskets(session, next_id):
		return false
	if not _place_pendulums(session, next_id):
		return false
	if not _place_flames(session, next_id):
		return false
	if not _place_spikes(session, next_id):
		return false
	if not _place_rollers(session, next_id):
		return false
	if not _place_pickups(session, next_id):
		return false
	if not place(session, PlaceTriggersGd.energy_wall_payload(
		next_id[0],
		LayoutGd.WALL_XZ.x * CELL,
		4 * CELL,
		LayoutGd.WALL_XZ.y * CELL,
		HALF
	)):
		printerr("course_08 energy wall failed")
		return false
	next_id[0] = next_id[0] + 1
	return true


static func _place_launches(session: AuthoringSession, next_id: Array[int]) -> bool:
	for cell: Vector2i in LayoutGd.launch_l1_cells():
		if not place(session, PlaceGd.launch_payload(
			next_id[0], cell.x * CELL, LayoutGd.floor_y(0) * CELL, cell.y * CELL,
			HALF, LayoutGd.YAW_NEG_Z
		)):
			printerr("course_08 L1 failed at %s" % str(cell))
			return false
		next_id[0] = next_id[0] + 1
	for cell: Vector2i in LayoutGd.launch_l2_cells():
		if not place(session, PlaceGd.launch_payload(
			next_id[0], cell.x * CELL, LayoutGd.floor_y(4) * CELL, cell.y * CELL,
			HALF, LayoutGd.YAW_NEG_Z
		)):
			printerr("course_08 L2 failed at %s" % str(cell))
			return false
		next_id[0] = next_id[0] + 1
	return true


static func _place_conveyors(session: AuthoringSession, next_id: Array[int]) -> bool:
	for z: int in LayoutGd.conveyor_zs():
		if not place(session, PlaceGd.conveyor_payload(
			next_id[0], 3 * CELL, LayoutGd.floor_y(2) * CELL, z * CELL,
			HALF, LayoutGd.YAW_NEG_Z
		)):
			printerr("course_08 conveyor failed z=%d" % z)
			return false
		next_id[0] = next_id[0] + 1
	return true


static func _place_crushers(session: AuthoringSession, next_id: Array[int]) -> bool:
	if not _crusher(session, next_id, LayoutGd.CRUSHER_A, 4, 2):
		return false
	return _crusher(session, next_id, LayoutGd.CRUSHER_B, 2, 4)


static func _crusher(
	session: AuthoringSession, next_id: Array[int], xz: Vector2i, y_from: int, y_to: int
) -> bool:
	var x: int = xz.x * CELL
	var z: int = xz.y * CELL
	var y: int = 2 * CELL
	var payload: Dictionary = PlaceTriggersGd.crusher_payload(
		next_id[0], x, y, z, HALF, CELL
	).duplicate(true)
	payload["record"]["components"]["mover"]["path"] = [
		{"x": x, "y": y_from * CELL, "z": z},
		{"x": x, "y": y_to * CELL, "z": z},
	]
	payload["record"]["components"]["mover"]["speed"] = LayoutGd.SPEED_CRUSHER
	if not place(session, payload):
		printerr("course_08 crusher failed at %s" % str(xz))
		return false
	next_id[0] = next_id[0] + 1
	return true


static func _place_baskets(session: AuthoringSession, next_id: Array[int]) -> bool:
	for bx: int in LayoutGd.basket_xs():
		var x: int = bx * CELL
		var y: int = LayoutGd.floor_y(2) * CELL
		var z: int = 10 * CELL
		var payload: Dictionary = PlaceGd.mover_payload(
			next_id[0], x, y, z, HALF, CELL
		).duplicate(true)
		payload["record"]["components"]["mover"]["path"] = [
			{"x": x, "y": y, "z": z},
			{"x": x, "y": y, "z": 5 * CELL},
		]
		payload["record"]["components"]["mover"]["speed"] = LayoutGd.SPEED_BASKET
		if not place(session, payload):
			printerr("course_08 basket failed x=%d" % bx)
			return false
		next_id[0] = next_id[0] + 1
	return true


static func _place_pendulums(session: AuthoringSession, next_id: Array[int]) -> bool:
	if not _pendulum(session, next_id, LayoutGd.PEND_S2_A, 0, 19, 33, 19, 35, LayoutGd.SPEED_PENDULUM_LANE):
		return false
	if not _pendulum(session, next_id, LayoutGd.PEND_S2_B, 0, 15, 35, 15, 33, LayoutGd.SPEED_PENDULUM_LANE):
		return false
	if not _pendulum(session, next_id, LayoutGd.PEND_S2_C, 0, 11, 33, 11, 35, LayoutGd.SPEED_PENDULUM_LANE):
		return false
	if not _pendulum(session, next_id, LayoutGd.PEND_S9_A, 6, -41, -29, -39, -29, LayoutGd.SPEED_PENDULUM_END):
		return false
	return _pendulum(session, next_id, LayoutGd.PEND_S9_B, 6, -39, -31, -41, -31, LayoutGd.SPEED_PENDULUM_END)


static func _pendulum(
	session: AuthoringSession, next_id: Array[int],
	origin: Vector2i, standing: int,
	x0: int, z0: int, x1: int, z1: int, speed: int
) -> bool:
	var x: int = origin.x * CELL
	var y: int = standing * CELL
	var z: int = origin.y * CELL
	var payload: Dictionary = PlaceMotionGd.pendulum_payload(
		next_id[0], x, y, z, HALF, CELL
	).duplicate(true)
	payload["record"]["components"]["mover"]["path"] = [
		{"x": x0 * CELL, "y": y, "z": z0 * CELL},
		{"x": x1 * CELL, "y": y, "z": z1 * CELL},
	]
	payload["record"]["components"]["mover"]["speed"] = speed
	if not place(session, payload):
		printerr("course_08 pendulum failed at %s" % str(origin))
		return false
	next_id[0] = next_id[0] + 1
	return true


static func _place_flames(session: AuthoringSession, next_id: Array[int]) -> bool:
	for fx: int in LayoutGd.flame_xs():
		for fz: int in LayoutGd.flame_zs():
			var payload: Dictionary = PlaceTriggersGd.flame_payload(
				next_id[0], fx * CELL, 4 * CELL, fz * CELL, HALF
			).duplicate(true)
			payload["record"]["components"]["hazard"]["cooldown_ticks"] = LayoutGd.FLAME_COOLDOWN
			if not place(session, payload):
				printerr("course_08 flame failed x=%d z=%d" % [fx, fz])
				return false
			next_id[0] = next_id[0] + 1
	return true


static func _place_spikes(session: AuthoringSession, next_id: Array[int]) -> bool:
	for cell: Vector2i in LayoutGd.spike_cells():
		if not place(session, PlaceTriggersGd.spike_payload(
			next_id[0],
			cell.x * CELL,
			LayoutGd.floor_y(6) * CELL,
			cell.y * CELL,
			HALF
		)):
			printerr("course_08 spike failed at %s" % str(cell))
			return false
		next_id[0] = next_id[0] + 1
	return true


static func _place_rollers(session: AuthoringSession, next_id: Array[int]) -> bool:
	for rx: int in LayoutGd.roller_xs():
		var payload: Dictionary = PlaceTriggersGd.roller_payload(
			next_id[0], rx * CELL, 6 * CELL, -26 * CELL, HALF
		).duplicate(true)
		payload["record"]["components"]["hazard"]["cooldown_ticks"] = LayoutGd.ROLLER_COOLDOWN
		if not place(session, payload):
			printerr("course_08 roller failed x=%d" % rx)
			return false
		next_id[0] = next_id[0] + 1
	return true


static func _place_pickups(session: AuthoringSession, next_id: Array[int]) -> bool:
	var dashes: Array[Vector3i] = [
		Vector3i(LayoutGd.DASH_S2.x, 0, LayoutGd.DASH_S2.y),
		Vector3i(LayoutGd.DASH_LAND_B.x, 2, LayoutGd.DASH_LAND_B.y),
		Vector3i(LayoutGd.DASH_S6.x, 4, LayoutGd.DASH_S6.y),
		Vector3i(LayoutGd.DASH_LAND_D.x, 6, LayoutGd.DASH_LAND_D.y),
	]
	for cell: Vector3i in dashes:
		if not place(session, PlaceGd.pickup_payload(
			next_id[0], cell.x * CELL, cell.y * CELL, cell.z * CELL, PickupKindsGd.DASH
		)):
			printerr("course_08 dash failed at %s" % str(cell))
			return false
		next_id[0] = next_id[0] + 1
	if not place(session, PlaceGd.pickup_payload(
		next_id[0],
		LayoutGd.BOMB_XZ.x * CELL,
		4 * CELL,
		LayoutGd.BOMB_XZ.y * CELL,
		PickupKindsGd.BOMB
	)):
		printerr("course_08 bomb failed")
		return false
	next_id[0] = next_id[0] + 1
	return true


static func _fill_spans(
	session: AuthoringSession, next_id: Array[int], spans: PackedInt32Array, skip_specials: bool
) -> bool:
	var i: int = 0
	while i + 4 < spans.size():
		var x0: int = spans[i]
		var x1: int = spans[i + 1]
		var y: int = spans[i + 2]
		var z0: int = spans[i + 3]
		var z1: int = spans[i + 4]
		var z: int = z0
		while z <= z1:
			var x: int = x0
			while x <= x1:
				if not skip_specials or not LayoutGd.skip_floor(x, y, z):
					if not place(session, PlaceGd.zone_payload(
						next_id[0],
						x * CELL,
						y * CELL,
						z * CELL,
						HALF,
						TraprushTopologyCompiler.SOLID_ZONE_TAG
					)):
						printerr("course_08 solid failed %d,%d,%d" % [x, y, z])
						return false
					next_id[0] = next_id[0] + 1
				x += 1
			z += 1
		i += 5
	return true
