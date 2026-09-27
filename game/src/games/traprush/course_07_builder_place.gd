class_name TraprushCourse07BuilderPlace
extends RefCounted

## Place helpers for course_07. Payloads stay on the editor place modules.

const LayoutGd := preload("res://src/games/traprush/course_07_layout.gd")
const PlaceGd := preload("res://src/creator/authoring_editor_shell_place.gd")
const PlaceMotionGd := preload("res://src/creator/authoring_editor_shell_place_motion.gd")
const PlaceTriggersGd := preload("res://src/creator/authoring_editor_shell_place_triggers.gd")
const PickupKindsGd := preload("res://src/ugc/traprush_pickup_kinds.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

const CELL: int = Fixed.SCALE
const HALF: int = CELL / 2
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-course-07"


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
	var next_id: int = LayoutGd.CHECKPOINT_ID_START
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		var standing: int = LayoutGd.standing_y(terrace)
		var cells: Array[Vector2i] = LayoutGd.checkpoint_cells(terrace)
		for cell: Vector2i in cells:
			if not place(session, PlaceGd.checkpoint_payload(
				next_id, next_id - LayoutGd.CHECKPOINT_ID_START,
				cell.x * CELL, standing * CELL, cell.y * CELL
			)):
				return false
			next_id += 1
		terrace += 1
	return true


static func place_finish(session: AuthoringSession) -> bool:
	var cell: Vector2i = LayoutGd.alcove_of(LayoutGd.TERRACE_NW)
	var standing: int = LayoutGd.standing_y(LayoutGd.TERRACE_NW)
	return place(session, PlaceGd.zone_payload(
		LayoutGd.FINISH_ID,
		cell.x * CELL,
		standing * CELL,
		cell.y * CELL,
		HALF,
		TraprushTopologyCompiler.FINISH_ZONE_TAG
	))


static func place_portals(session: AuthoringSession) -> bool:
	var sw_exit: Vector2i = LayoutGd.alcove_of(LayoutGd.TERRACE_SW)
	var se_land: Vector2i = LayoutGd.snake_of(LayoutGd.TERRACE_SE)[0]
	var se_exit: Vector2i = LayoutGd.alcove_of(LayoutGd.TERRACE_SE)
	var ne_land: Vector2i = LayoutGd.snake_of(LayoutGd.TERRACE_NE)[0]
	var ne_exit: Vector2i = LayoutGd.alcove_of(LayoutGd.TERRACE_NE)
	var nw_land: Vector2i = LayoutGd.snake_of(LayoutGd.TERRACE_NW)[0]
	if not _portal_pair(
		session, LayoutGd.PORTAL_SW, LayoutGd.PORTAL_SE_LAND,
		sw_exit, LayoutGd.standing_y(LayoutGd.TERRACE_SW),
		se_land, LayoutGd.standing_y(LayoutGd.TERRACE_SE)
	):
		return false
	if not _portal_pair(
		session, LayoutGd.PORTAL_SE_EXIT, LayoutGd.PORTAL_NE_LAND,
		se_exit, LayoutGd.standing_y(LayoutGd.TERRACE_SE),
		ne_land, LayoutGd.standing_y(LayoutGd.TERRACE_NE)
	):
		return false
	return _portal_pair(
		session, LayoutGd.PORTAL_NE_EXIT, LayoutGd.PORTAL_NW_LAND,
		ne_exit, LayoutGd.standing_y(LayoutGd.TERRACE_NE),
		nw_land, LayoutGd.standing_y(LayoutGd.TERRACE_NW)
	)


static func place_lifts(session: AuthoringSession) -> bool:
	if not _lift(session, LayoutGd.LIFT_SE, LayoutGd.TERRACE_SE):
		return false
	if not _lift(session, LayoutGd.LIFT_NE, LayoutGd.TERRACE_NE):
		return false
	return _lift(session, LayoutGd.LIFT_NW, LayoutGd.TERRACE_NW)


static func place_floors(session: AuthoringSession, next_id: Array[int]) -> bool:
	if not _fill_rect(session, next_id, -6, 6, LayoutGd.floor_y(-6), -6, 6):
		return false
	var terrace: int = 1
	while terrace < LayoutGd.TERRACE_COUNT:
		if not _fill_rect(
			session, next_id,
			LayoutGd.x_lo(terrace), LayoutGd.x_hi(terrace),
			LayoutGd.floor_y(LayoutGd.standing_y(terrace)),
			LayoutGd.z_lo(terrace), LayoutGd.z_hi(terrace)
		):
			return false
		terrace += 1
	return true


static func place_walls(session: AuthoringSession, next_id: Array[int]) -> bool:
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		var standing: int = LayoutGd.standing_y(terrace)
		var height: int = LayoutGd.wall_height(terrace)
		for cell: Vector2i in LayoutGd.wall_cells(terrace):
			var layer: int = 0
			while layer < height:
				var y: int = standing + layer
				if y > 7:
					break
				if not place(session, PlaceGd.zone_payload(
					next_id[0],
					cell.x * CELL,
					y * CELL,
					cell.y * CELL,
					HALF,
					TraprushTopologyCompiler.SOLID_ZONE_TAG
				)):
					return false
				next_id[0] = next_id[0] + 1
				layer += 1
		terrace += 1
	return true


static func place_gadgets(session: AuthoringSession, next_id: Array[int]) -> bool:
	if not _terrace_traps(session, next_id):
		return false
	if not place(session, PlaceTriggersGd.energy_wall_payload(
		LayoutGd.ENERGY_WALL_ID,
		LayoutGd.energy_wall_xz().x * CELL,
		LayoutGd.standing_y(LayoutGd.TERRACE_SE) * CELL,
		LayoutGd.energy_wall_xz().y * CELL,
		HALF
	)):
		return false
	if not place(session, PlaceGd.pickup_payload(
		LayoutGd.BOMB_ID,
		LayoutGd.bomb_xz().x * CELL,
		LayoutGd.standing_y(LayoutGd.TERRACE_SE) * CELL,
		LayoutGd.bomb_xz().y * CELL,
		PickupKindsGd.BOMB
	)):
		return false
	var chassis_floor: int = LayoutGd.floor_y(-6)
	if not place(session, PlaceMotionGd.pendulum_payload(
		next_id[0],
		LayoutGd.pendulum_xz().x * CELL,
		chassis_floor * CELL,
		LayoutGd.pendulum_xz().y * CELL,
		HALF,
		CELL
	)):
		return false
	next_id[0] = next_id[0] + 1
	if not place(session, PlaceGd.conveyor_payload(
		next_id[0],
		LayoutGd.conveyor_xz().x * CELL,
		chassis_floor * CELL,
		LayoutGd.conveyor_xz().y * CELL,
		HALF,
		0
	)):
		return false
	next_id[0] = next_id[0] + 1
	if not place(session, PlaceMotionGd.ice_payload(
		next_id[0],
		LayoutGd.ice_xz().x * CELL,
		chassis_floor * CELL,
		LayoutGd.ice_xz().y * CELL,
		HALF,
		0
	)):
		return false
	next_id[0] = next_id[0] + 1
	return place(session, PlaceTriggersGd.crusher_payload(
		next_id[0],
		LayoutGd.crusher_xz().x * CELL,
		chassis_floor * CELL,
		LayoutGd.crusher_xz().y * CELL,
		HALF,
		CELL
	))


static func geometry_ok() -> bool:
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		var snake: Array[Vector2i] = LayoutGd.snake_of(terrace)
		if snake.size() < 8:
			return false
		if not _chain_ok(snake):
			return false
		if not _adjacent(snake[snake.size() - 1], LayoutGd.alcove_of(terrace)):
			return false
		if LayoutGd.wr_move_count(terrace) < LayoutGd.MIN_TERRACE_MOVES:
			return false
		terrace += 1
	return true


static func _terrace_traps(session: AuthoringSession, next_id: Array[int]) -> bool:
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		var standing: int = LayoutGd.standing_y(terrace)
		var gadgets: Array[Vector2i] = LayoutGd.gadget_cells(terrace)
		if gadgets.size() < 2:
			return false
		var spike_cell: Vector2i = gadgets[0]
		if not place(session, PlaceTriggersGd.spike_payload(
			next_id[0],
			spike_cell.x * CELL,
			LayoutGd.floor_y(standing) * CELL,
			spike_cell.y * CELL,
			HALF
		)):
			return false
		next_id[0] = next_id[0] + 1
		var flame_cell: Vector2i = gadgets[1]
		if not place(session, PlaceTriggersGd.flame_payload(
			next_id[0],
			flame_cell.x * CELL,
			standing * CELL,
			flame_cell.y * CELL,
			HALF
		)):
			return false
		next_id[0] = next_id[0] + 1
		if gadgets.size() >= 3:
			var roller_cell: Vector2i = gadgets[2]
			if not place(session, PlaceTriggersGd.roller_payload(
				next_id[0],
				roller_cell.x * CELL,
				standing * CELL,
				roller_cell.y * CELL,
				HALF
			)):
				return false
			next_id[0] = next_id[0] + 1
		terrace += 1
	return true


static func _fill_rect(
	session: AuthoringSession, next_id: Array[int],
	x0: int, x1: int, y: int, z0: int, z1: int
) -> bool:
	var z: int = z0
	while z <= z1:
		var x: int = x0
		while x <= x1:
			if not LayoutGd.skip_floor(x, y, z):
				if not place(session, PlaceGd.zone_payload(
					next_id[0],
					x * CELL,
					y * CELL,
					z * CELL,
					HALF,
					TraprushTopologyCompiler.SOLID_ZONE_TAG
				)):
					return false
				next_id[0] = next_id[0] + 1
			x += 1
		z += 1
	return true


static func _portal_pair(
	session: AuthoringSession,
	a: int, b: int,
	a_cell: Vector2i, a_y: int,
	b_cell: Vector2i, b_y: int
) -> bool:
	if not place(session, PlaceGd.portal_payload(
		a, b, a_cell.x * CELL, a_y * CELL, a_cell.y * CELL
	)):
		return false
	return place(session, PlaceGd.portal_payload(
		b, a, b_cell.x * CELL, b_y * CELL, b_cell.y * CELL
	))


static func _lift(session: AuthoringSession, entity_id: int, terrace: int) -> bool:
	var xz: Vector2i = LayoutGd.lift_xz(terrace)
	var y: int = LayoutGd.floor_y(-6) * CELL
	var dest_y: int = LayoutGd.floor_y(LayoutGd.standing_y(terrace)) * CELL
	var x: int = xz.x * CELL
	var z: int = xz.y * CELL
	return place(session, {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": HALF,
						"hy": HALF,
						"hz": HALF,
					},
					"tags": [
						TraprushTopologyCompiler.SOLID_ZONE_TAG,
						TraprushTopologyCompiler.LIFT_ZONE_TAG,
					],
				},
				"mover": {
					"path": [
						{"x": x, "y": y, "z": z},
						{"x": x, "y": dest_y, "z": z},
					],
					"speed": Fixed.SCALE / 16,
					"loop": true,
				},
			},
		},
	})


static func _chain_ok(snake: Array[Vector2i]) -> bool:
	var i: int = 1
	while i < snake.size():
		if not _adjacent(snake[i - 1], snake[i]):
			return false
		i += 1
	return true


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1
