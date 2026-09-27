class_name TraprushCourse07Builder
extends RefCounted

## Official `course_07` Terrace Circuit via the real EditCommand write path.
## Four staggered terraces, comb foldbacks, one-way WR through two-way portals.

const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const LayoutGd := preload("res://src/games/traprush/course_07_layout.gd")
const PlaceOpsGd := preload("res://src/games/traprush/course_07_builder_place.gd")

const MIN_ENTITIES: int = 500
const MAX_ENTITIES: int = 850


static func build_session() -> AuthoringSession:
	if not PlaceOpsGd.geometry_ok():
		printerr("course_07 geometry_ok failed")
		var terrace: int = 0
		while terrace < LayoutGd.TERRACE_COUNT:
			var snake: Array[Vector2i] = LayoutGd.snake_of(terrace)
			printerr("terrace %d snake=%d last=%s alcove=%s adj=%s moves=%d" % [
				terrace,
				snake.size(),
				str(snake[snake.size() - 1]) if snake.size() > 0 else "empty",
				str(LayoutGd.alcove_of(terrace)),
				str(PlaceOpsGd._adjacent(snake[snake.size() - 1], LayoutGd.alcove_of(terrace))) if snake.size() > 0 else "n/a",
				LayoutGd.wr_move_count(terrace),
			])
			if snake.size() >= 2:
				var i: int = 1
				while i < snake.size():
					if not PlaceOpsGd._adjacent(snake[i - 1], snake[i]):
						printerr("  break at %d %s -> %s" % [i, str(snake[i - 1]), str(snake[i])])
						break
					i += 1
			terrace += 1
		return null
	var session: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.INTERNAL_DEV)
	if session == null:
		printerr("course_07 session create failed")
		return null
	if not PlaceOpsGd.place_checkpoints(session):
		printerr("course_07 checkpoints failed")
		return null
	if not PlaceOpsGd.place_finish(session):
		printerr("course_07 finish failed")
		return null
	if not PlaceOpsGd.place_portals(session):
		printerr("course_07 portals failed")
		return null
	if not PlaceOpsGd.place_lifts(session):
		printerr("course_07 lifts failed")
		return null
	var floor_ids: Array[int] = [LayoutGd.FLOOR_ID_START]
	if not PlaceOpsGd.place_floors(session, floor_ids):
		printerr("course_07 floors failed")
		return null
	var wall_ids: Array[int] = [LayoutGd.WALL_ID_START]
	if not PlaceOpsGd.place_walls(session, wall_ids):
		printerr("course_07 walls failed")
		return null
	var gadget_ids: Array[int] = [LayoutGd.GADGET_ID_START]
	if not PlaceOpsGd.place_gadgets(session, gadget_ids):
		printerr("course_07 gadgets failed")
		return null
	return session


static func export_document() -> Dictionary:
	var session: AuthoringSession = build_session()
	if session == null:
		return {}
	return session.export_document()
