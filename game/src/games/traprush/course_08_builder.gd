class_name TraprushCourse08Builder
extends RefCounted

## Official `course_08` benchmark parkour via the real EditCommand write path.
## Linear aerial yard. Not on MATCH_IDS.

const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const LayoutGd := preload("res://src/games/traprush/course_08_layout.gd")
const PlaceOpsGd := preload("res://src/games/traprush/course_08_builder_place.gd")

const MIN_ENTITIES: int = 650
const MAX_ENTITIES: int = 750


static func build_session() -> AuthoringSession:
	if not LayoutGd.geometry_ok():
		printerr("course_08 geometry_ok failed")
		return null
	var session: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.INTERNAL_DEV)
	if session == null:
		printerr("course_08 session create failed")
		return null
	if not PlaceOpsGd.place_checkpoints(session):
		printerr("course_08 checkpoints failed")
		return null
	if not PlaceOpsGd.place_finish(session):
		printerr("course_08 finish failed")
		return null
	if not PlaceOpsGd.place_portals(session):
		printerr("course_08 portals failed")
		return null
	var floor_ids: Array[int] = [LayoutGd.FLOOR_ID_START]
	if not PlaceOpsGd.place_floors(session, floor_ids):
		printerr("course_08 floors failed")
		return null
	var rail_ids: Array[int] = [LayoutGd.RAIL_ID_START]
	if not PlaceOpsGd.place_rails(session, rail_ids):
		printerr("course_08 rails failed")
		return null
	var gadget_ids: Array[int] = [LayoutGd.GADGET_ID_START]
	if not PlaceOpsGd.place_gadgets(session, gadget_ids):
		printerr("course_08 gadgets failed")
		return null
	return session


static func export_document() -> Dictionary:
	var session: AuthoringSession = build_session()
	if session == null:
		return {}
	return session.export_document()
