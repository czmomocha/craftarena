extends SceneTree
## Writes official `course_07` via TraprushCourse07Builder (EditCommand path).
##
##   "$GODOT4" --headless --path game \
##       --script res://tools/content/build_course_07.gd
##
## Engine is located through GODOT4 (README "命令"); never hard-code a path.
## Not in CI — regenerating the committed JSON is a one-off, same boundary as
## docs/runbooks/asset-bake.md. Callers must assert `RESULT: PASS` in stdout.

const BuilderGd := preload("res://src/games/traprush/course_07_builder.gd")
const LayoutGd := preload("res://src/games/traprush/course_07_layout.gd")
const ScriptsGd := preload("res://src/games/traprush/course_07_scripts.gd")
const DEST: String = "res://content/official/traprush/course_07.json"


func _init() -> void:
	var document: Dictionary = BuilderGd.export_document()
	if document.is_empty():
		printerr("course_07 builder returned an empty document")
		_finish(false)
		return
	var entities: Array = document.get("entities", [])
	if entities.size() < BuilderGd.MIN_ENTITIES or entities.size() > BuilderGd.MAX_ENTITIES:
		printerr("course_07 entity count %d is outside 500–850" % entities.size())
		_finish(false)
		return
	var moves: int = ScriptsGd.move_count()
	if moves < LayoutGd.MIN_TERRACE_MOVES * LayoutGd.TERRACE_COUNT:
		printerr("course_07 WR MOVE count %d is below 480" % moves)
		_finish(false)
		return
	var file: FileAccess = FileAccess.open(DEST, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % DEST)
		_finish(false)
		return
	file.store_string("%s\n" % JSON.stringify(document, "\t"))
	file.close()
	print("wrote %s entities=%d revision=%s moves=%d sw=%d se=%d ne=%d nw=%d" % [
		DEST,
		entities.size(),
		str(document.get("revision", 0)),
		moves,
		LayoutGd.wr_move_count(LayoutGd.TERRACE_SW),
		LayoutGd.wr_move_count(LayoutGd.TERRACE_SE),
		LayoutGd.wr_move_count(LayoutGd.TERRACE_NE),
		LayoutGd.wr_move_count(LayoutGd.TERRACE_NW),
	])
	print("RESULT: PASS")
	_finish(true)


func _finish(ok: bool) -> void:
	quit(0 if ok else 1)
