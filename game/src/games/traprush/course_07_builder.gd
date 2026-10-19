class_name TraprushCourse07Builder
extends RefCounted

## Official `course_07` via the real EditCommand write path.
## Same climb as `course_06`: standing y in {-6,-4,-2,0,2,4,6}, three two-way
## portals, three recovery lifts, no launch pads, bottom paved so a fall lands.
##
## `course_06` stacks every floor on one xz footprint. The match camera is locked
## at yaw 45° / pitch 45° (camera sits toward +X,+Y,+Z), so a wide roof toward
## the camera hides the floor you are standing on. Here each upper floor is a
## 2-cell band stepped toward -X,-Z (screen-up, away from the camera). The step
## is wide enough that a ray from the landing under a band clears the nearer
## bands. Bands are two `u=x+z` rows so a cardinal +X stays on solid. The bottom
## is the camera-near plaza plus a landing under each band. The trench between
## bands is open: paving it would put walkable floor in the 45° shadow.

const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const PlaceGd := preload("res://src/creator/authoring_editor_shell_place.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

const CELL: int = Fixed.SCALE
const HALF: int = CELL / 2
const BOTTOM: int = -6
const TOP: int = 6
const LAYER_COUNT: int = 7
const STEP_U: int = 20
const BAND: int = 2
const U_BASE: int = 0
const V_MIN: int = -24
const V_MAX: int = 24
const CHECKPOINT_ID: int = 1
const FINISH_ID: int = 2
const LIFT_IDS: Array[int] = [20, 21, 22]
const LIFT_LAYERS: Array[int] = [1, 3, 5]
const FLOOR_ID_START: int = 100
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-course-07"


static func floor_y(standing_y: int) -> int:
	return standing_y - 1


static func standing_y(layer: int) -> int:
	return BOTTOM + 2 * layer


static func u_far(layer: int) -> int:
	return U_BASE + (LAYER_COUNT - 1 - layer) * STEP_U


static func xz_of(u: int, v: int) -> Vector2i:
	return Vector2i((u + v) / 2, (u - v) / 2)


static func build_session() -> AuthoringSession:
	var session: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.INTERNAL_DEV)
	if session == null:
		return null
	var spawn: Vector2i = xz_of(u_far(0), 0)
	if not _place(session, PlaceGd.checkpoint_payload(
		CHECKPOINT_ID, 0, spawn.x * CELL, BOTTOM * CELL, spawn.y * CELL
	)):
		return null
	var finish: Vector2i = xz_of(u_far(LAYER_COUNT - 1), 0)
	if not _place(session, PlaceGd.zone_payload(
		FINISH_ID, finish.x * CELL, TOP * CELL, finish.y * CELL, HALF,
		TraprushTopologyCompiler.FINISH_ZONE_TAG
	)):
		return null
	if not _place_portals(session):
		return null
	if not _place_lifts(session):
		return null
	if not _place_floors(session):
		return null
	return session


static func export_document() -> Dictionary:
	var session: AuthoringSession = build_session()
	if session == null:
		return {}
	return session.export_document()


static func _place_portals(session: AuthoringSession) -> bool:
	## +X into the near row of a band, land on the far row of the band two
	## layers up, then +X again. Last hop lands on the top near row; -X is finish.
	var hops: Array[Dictionary] = [
		{"a": 10, "b": 11, "layer_a": 0, "layer_b": 2},
		{"a": 12, "b": 13, "layer_a": 2, "layer_b": 4},
		{"a": 14, "b": 15, "layer_a": 4, "layer_b": 6},
	]
	for hop_raw: Variant in hops:
		var hop: Dictionary = hop_raw
		var layer_a: int = hop["layer_a"]
		var layer_b: int = hop["layer_b"]
		var src: Vector2i = xz_of(u_far(layer_a) + 1, 1)
		## Middle hops land on the far row so the next step is +X onto that
		## band's portal. The last hop lands on the near row; -X is the finish
		## on the far row (same pattern as course_06).
		var dst_u: int = u_far(layer_b)
		var dst_v: int = 0
		if layer_b == LAYER_COUNT - 1:
			dst_u += 1
			dst_v = 1
		var dst: Vector2i = xz_of(dst_u, dst_v)
		var a: int = hop["a"]
		var b: int = hop["b"]
		if not _place(session, PlaceGd.portal_payload(
			a, b, src.x * CELL, standing_y(layer_a) * CELL, src.y * CELL
		)):
			return false
		if not _place(session, PlaceGd.portal_payload(
			b, a, dst.x * CELL, standing_y(layer_b) * CELL, dst.y * CELL
		)):
			return false
	return true


static func _place_lifts(session: AuthoringSession) -> bool:
	var lift_i: int = 0
	while lift_i < LIFT_IDS.size():
		var layer: int = LIFT_LAYERS[lift_i]
		var at: Vector2i = xz_of(u_far(layer), 0)
		if not _place(session, PlaceGd.lift_payload(
			LIFT_IDS[lift_i],
			at.x * CELL,
			floor_y(standing_y(layer)) * CELL,
			at.y * CELL,
			HALF,
			CELL
		)):
			return false
		lift_i += 1
	return true


static func _place_floors(session: AuthoringSession) -> bool:
	var next_id: Array[int] = [FLOOR_ID_START]
	if not _fill_bottom(session, next_id):
		return false
	var layer: int = 1
	while layer < LAYER_COUNT:
		if not _fill_band(session, layer, next_id):
			return false
		layer += 1
	return true


static func _fill_bottom(session: AuthoringSession, next_id: Array[int]) -> bool:
	var y: int = floor_y(BOTTOM)
	var u0: int = u_far(1) + BAND
	var u1: int = u_far(0) + BAND - 1
	var u: int = u0
	while u <= u1:
		if not _fill_u_row(session, next_id, u, y):
			return false
		u += 1
	return true


static func _fill_u_row(
	session: AuthoringSession, next_id: Array[int], u: int, y: int
) -> bool:
	var v: int = V_MIN
	while v <= V_MAX:
		if _same_parity(u, v):
			var at: Vector2i = xz_of(u, v)
			if not _place_floor(session, next_id, at.x, y, at.y):
				return false
		v += 1
	return true


static func _fill_band(session: AuthoringSession, layer: int, next_id: Array[int]) -> bool:
	var y: int = floor_y(standing_y(layer))
	var u0: int = u_far(layer)
	var u: int = u0
	while u < u0 + BAND:
		var v: int = V_MIN
		while v <= V_MAX:
			if _same_parity(u, v):
				var at: Vector2i = xz_of(u, v)
				if not _place_floor(session, next_id, at.x, floor_y(BOTTOM), at.y):
					return false
				if not _is_lift_cell(layer, at.x, at.y):
					if not _place_floor(session, next_id, at.x, y, at.y):
						return false
			v += 1
		u += 1
	return true


static func _is_lift_cell(layer: int, x: int, z: int) -> bool:
	var lift_i: int = 0
	while lift_i < LIFT_LAYERS.size():
		if LIFT_LAYERS[lift_i] == layer:
			var at: Vector2i = xz_of(u_far(layer), 0)
			return at.x == x and at.y == z
		lift_i += 1
	return false


static func _same_parity(u: int, v: int) -> bool:
	return (u & 1) == (v & 1)


static func _place_floor(
	session: AuthoringSession, next_id: Array[int], x: int, y: int, z: int
) -> bool:
	var entity_id: int = next_id[0]
	if not _place(session, PlaceGd.zone_payload(
		entity_id, x * CELL, y * CELL, z * CELL, HALF, TraprushTopologyCompiler.SOLID_ZONE_TAG
	)):
		return false
	next_id[0] = entity_id + 1
	return true


static func _place(session: AuthoringSession, payload: Dictionary) -> bool:
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
