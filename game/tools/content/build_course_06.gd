extends SceneTree
## Writes official `course_06` via TraprushCourse06Builder (EditCommand path).
##
##   "$GODOT4" --headless --path game \
##       --script res://tools/content/build_course_06.gd
##
## Engine is located through GODOT4 (README "命令"); never hard-code a path.
## Not in CI — regenerating the committed JSON is a one-off, same boundary as
## docs/runbooks/asset-bake.md. Callers must assert `RESULT: PASS` in stdout.

const BuilderGd := preload("res://src/games/traprush/course_06_builder.gd")
const DEST: String = "res://content/official/traprush/course_06.json"


func _init() -> void:
	var document: Dictionary = BuilderGd.export_document()
	if document.is_empty():
		printerr("course_06 builder returned an empty document")
		_finish(false)
		return
	var entities: Array = document.get("entities", [])
	if entities.size() < 350 or entities.size() > 400:
		printerr("course_06 entity count %d is outside 350–400" % entities.size())
		_finish(false)
		return
	var file: FileAccess = FileAccess.open(DEST, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % DEST)
		_finish(false)
		return
	file.store_string("%s\n" % JSON.stringify(document, "\t"))
	file.close()
	print("wrote %s entities=%d revision=%s" % [
		DEST,
		entities.size(),
		str(document.get("revision", 0)),
	])
	print("RESULT: PASS")
	_finish(true)


func _finish(ok: bool) -> void:
	quit(0 if ok else 1)
