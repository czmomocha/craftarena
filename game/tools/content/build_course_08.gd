extends SceneTree
## Writes official `course_08` via TraprushCourse08Builder (EditCommand path).
##
##   "$GODOT4" --headless --path game \
##       --script res://tools/content/build_course_08.gd
##
## Engine is located through GODOT4 (README "命令"); never hard-code a path.
## Not in CI — regenerating the committed JSON is a one-off, same boundary as
## docs/runbooks/asset-bake.md. Callers must assert `RESULT: PASS` in stdout.

const BuilderGd := preload("res://src/games/traprush/course_08_builder.gd")
const ScriptsGd := preload("res://src/games/traprush/course_08_scripts.gd")
const DEST: String = "res://content/official/traprush/course_08.json"


func _init() -> void:
	var document: Dictionary = BuilderGd.export_document()
	if document.is_empty():
		printerr("course_08 builder returned an empty document")
		_finish(false)
		return
	var entities: Array = document.get("entities", [])
	if entities.size() < BuilderGd.MIN_ENTITIES or entities.size() > BuilderGd.MAX_ENTITIES:
		printerr("course_08 entity count %d is outside %d–%d" % [
			entities.size(), BuilderGd.MIN_ENTITIES, BuilderGd.MAX_ENTITIES
		])
		_finish(false)
		return
	var file: FileAccess = FileAccess.open(DEST, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % DEST)
		_finish(false)
		return
	file.store_string("%s\n" % JSON.stringify(document, "\t"))
	file.close()
	print("wrote %s entities=%d revision=%s moves=%d" % [
		DEST,
		entities.size(),
		str(document.get("revision", 0)),
		ScriptsGd.move_count(),
	])
	print("RESULT: PASS")
	_finish(true)


func _finish(ok: bool) -> void:
	quit(0 if ok else 1)
