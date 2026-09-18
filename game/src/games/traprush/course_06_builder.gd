class_name TraprushCourse06Builder
extends RefCounted

## Official `course_06` via the real EditCommand write path.
## Standing y ∈ {-6,-4,-2,0,2,4,6}; floors sit one cell below (course_01).
## Layer gap is 2 cells. Bottom 13×13 is the catch-all.
##
## Launch pads cannot land a 4-cell hop onto a same-xz floor: peak ≈ 4.25 cells
## so the destination box sits in the ascent and is hit from below. The climb
## is therefore three two-way portals (scripted) plus three recovery lifts on
## the skipped floors. A* still cannot use this (two portal hops, jump < 1 cell).

const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const PlaceGd := preload("res://src/creator/authoring_editor_shell_place.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

const CELL: int = Fixed.SCALE
const HALF: int = CELL / 2
const BOTTOM: int = -6
const TOP: int = 6
const LIFT_X: int = 2
const LIFT_Z: int = 2
const CHECKPOINT_ID: int = 1
const FINISH_ID: int = 2
const PORTAL_IDS: Array[int] = [10, 11, 12, 13, 14, 15]
const LIFT_IDS: Array[int] = [20, 21, 22]
const FLOOR_ID_START: int = 100
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-course-06"


static func floor_y(standing_y: int) -> int:
	return standing_y - 1


static func build_session() -> AuthoringSession:
	var session: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.INTERNAL_DEV)
	if session == null:
		return null
	if not _place(session, PlaceGd.checkpoint_payload(CHECKPOINT_ID, 0, 0, BOTTOM * CELL, 0)):
		return null
	if not _place(session, PlaceGd.zone_payload(
		FINISH_ID, 0, TOP * CELL, 0, HALF, TraprushTopologyCompiler.FINISH_ZONE_TAG
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
	## three two-way hops: y=-6↔-2, -2↔+2, +2↔+6. Dest is one cell +X so the
	## next hop is a single walk, not a stack on the landing.
	var hops: Array[Dictionary] = [
		{"a": 10, "b": 11, "ax": 1, "ay": BOTTOM, "bx": 1, "by": -2},
		{"a": 12, "b": 13, "ax": 2, "ay": -2, "bx": 2, "by": 2},
		{"a": 14, "b": 15, "ax": 1, "ay": 2, "bx": 1, "by": TOP},
	]
	for hop_raw: Variant in hops:
		var hop: Dictionary = hop_raw
		var a: int = hop["a"]
		var b: int = hop["b"]
		var ax: int = hop["ax"]
		var ay: int = hop["ay"]
		var bx: int = hop["bx"]
		var by: int = hop["by"]
		if not _place(session, PlaceGd.portal_payload(a, b, ax * CELL, ay * CELL, 0)):
			return false
		if not _place(session, PlaceGd.portal_payload(b, a, bx * CELL, by * CELL, 0)):
			return false
	return true


static func _place_lifts(session: AuthoringSession) -> bool:
	var lift_starts: Array[int] = [-4, 0, 4]
	var lift_i: int = 0
	while lift_i < LIFT_IDS.size():
		var standing: int = lift_starts[lift_i]
		if not _place(session, PlaceGd.lift_payload(
			LIFT_IDS[lift_i],
			LIFT_X * CELL,
			floor_y(standing) * CELL,
			LIFT_Z * CELL,
			HALF,
			CELL
		)):
			return false
		lift_i += 1
	return true


static func _place_floors(session: AuthoringSession) -> bool:
	var next_id: Array[int] = [FLOOR_ID_START]
	var standing: int = BOTTOM
	while standing <= TOP:
		if not _fill_layer(session, standing, next_id):
			return false
		standing += 2
	return true


static func _fill_layer(session: AuthoringSession, standing: int, next_id: Array[int]) -> bool:
	var y: int = floor_y(standing)
	var extent: int = _extent_for(standing)
	var z: int = -extent
	while z <= extent:
		var x: int = -extent
		while x <= extent:
			if not _should_skip_floor(x, y, z):
				var entity_id: int = next_id[0]
				if not _place(session, PlaceGd.zone_payload(
					entity_id,
					x * CELL,
					y * CELL,
					z * CELL,
					HALF,
					TraprushTopologyCompiler.SOLID_ZONE_TAG
				)):
					return false
				next_id[0] = entity_id + 1
			x += 1
		z += 1
	return true


static func _extent_for(standing: int) -> int:
	if standing == BOTTOM:
		return 6
	if standing == -4 or standing == 0 or standing == 4:
		return 2
	return 3


static func _should_skip_floor(x: int, y: int, z: int) -> bool:
	if x == LIFT_X and z == LIFT_Z:
		if y == floor_y(-4) or y == floor_y(0) or y == floor_y(4):
			return true
		if y == floor_y(-2) or y == floor_y(2) or y == floor_y(TOP):
			return true
	return false


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
