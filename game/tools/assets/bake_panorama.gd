extends SceneTree
## Bakes one standalone equirectangular panorama PNG into a 2:1 sky texture.
##
##   "$GODOT4" --headless --path game \
##       --script res://tools/assets/bake_panorama.gd -- <src> <dest> [width] [height]
##
## Engine is located through GODOT4 (README section "命令"); never hard-code a
## path here. Not in CI — baking is a one-off pre-import step, same boundary as
## docs/runbooks/asset-bake.md §2.
##
## Why not `npx @gltf-transform/cli resize` like §2 of that runbook: it only
## rewrites textures *embedded in a GLB*. A standalone PNG gives it nothing to
## operate on. Image.resize keeps the new-dependency count at zero, so this
## stays clear of the CD-00 十八 dependency gate.
##
## `src` may sit outside the project (the sources live under `_source_refs/`,
## which .gitignore excludes), so pass it as an absolute OS path.
##
## IMPORTANT: `--script` exits 0 even when the script itself fails to parse
## (CD-53 "产品 UI 主题与场景静态校验" and docs/runbooks/ui-wiring.md §0.2).
## Callers must assert `RESULT: PASS` appears in stdout, not just check $?.

## PanoramaSkyMaterial wants 2:1 (Godot class reference). 1024×512 lossless is
## ~2 MB VRAM per sky. Human-decided 2026-09-17.
const DEFAULT_WIDTH: int = 1024
const DEFAULT_HEIGHT: int = 512


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() == 3:
		printerr("usage: --script res://tools/assets/bake_panorama.gd -- <src> <dest> [width] [height]")
		_finish(false)
		return

	var src: String = args[0]
	var dest: String = args[1]
	var out_w: int = DEFAULT_WIDTH
	var out_h: int = DEFAULT_HEIGHT
	if args.size() >= 4:
		out_w = args[2].to_int()
		out_h = args[3].to_int()
	if out_w <= 0 or out_h <= 0:
		printerr("FAILED: target size must be positive, got ", out_w, "x", out_h)
		_finish(false)
		return

	var image: Image = Image.load_from_file(src)
	if image == null or image.is_empty():
		printerr("FAILED: could not load source ", src)
		_finish(false)
		return

	var src_w: int = image.get_width()
	var src_h: int = image.get_height()
	print("source : ", src)
	print("         ", src_w, "x", src_h, ", ", _byte_size(src), " bytes")

	# Centre-crop to the destination aspect before scaling. Resizing straight to
	# 1024×512 from 1.79:1 would squash the horizon by ~11%; both panoramas put
	# their horizon near the vertical middle, so a centred trim is the safe
	# default. Override by passing a different target aspect if a source ever
	# disagrees, and record the value used in docs/runbooks/asset-bake.md.
	var region: Rect2i = _center_crop_region(src_w, src_h, out_w, out_h)
	if region.size == Vector2i(src_w, src_h):
		print("crop   : none (source already matches ", out_w, ":", out_h, ")")
	else:
		image = image.get_region(region)
		print(
			"crop   : ", region.size.x, "x", region.size.y,
			" at offset (", region.position.x, ", ", region.position.y, ")"
		)

	image.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)
	print("resize : ", out_w, "x", out_h, " (INTERPOLATE_LANCZOS)")

	var dest_dir: String = dest.get_base_dir()
	if not dest_dir.is_empty() and not DirAccess.dir_exists_absolute(dest_dir):
		var mk: int = DirAccess.make_dir_recursive_absolute(dest_dir)
		if mk != OK:
			printerr("FAILED: could not create ", dest_dir, " (error ", mk, ")")
			_finish(false)
			return

	var err: int = image.save_png(dest)
	if err != OK:
		printerr("FAILED: save_png ", dest, " (error ", err, ")")
		_finish(false)
		return

	# Read the file back rather than trusting the in-memory Image: the point of
	# this script is the bytes on disk, and save_png can succeed while writing
	# somewhere other than intended (res:// remaps).
	var written: Image = Image.load_from_file(dest)
	if written == null or written.is_empty():
		printerr("FAILED: wrote ", dest, " but cannot read it back")
		_finish(false)
		return

	var got: Vector2i = Vector2i(written.get_width(), written.get_height())
	print("output : ", dest)
	print("         ", got.x, "x", got.y, ", ", _byte_size(dest), " bytes")
	if got != Vector2i(out_w, out_h):
		printerr("FAILED: expected ", out_w, "x", out_h, " on disk, got ", got.x, "x", got.y)
		_finish(false)
		return

	_finish(true)


## Largest centred rect inside `src_w`×`src_h` whose aspect equals
## `out_w`:`out_h`. Integer cross-multiply, so no float comparison on equality.
static func _center_crop_region(src_w: int, src_h: int, out_w: int, out_h: int) -> Rect2i:
	var crop_w: int = src_w
	var crop_h: int = src_h
	if src_w * out_h > src_h * out_w:
		crop_w = mini(roundi(float(src_h) * float(out_w) / float(out_h)), src_w)
	elif src_w * out_h < src_h * out_w:
		crop_h = mini(roundi(float(src_w) * float(out_h) / float(out_w)), src_h)
	return Rect2i((src_w - crop_w) / 2, (src_h - crop_h) / 2, crop_w, crop_h)


static func _byte_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var size: int = f.get_length()
	f.close()
	return size


func _finish(ok: bool) -> void:
	if ok:
		print("RESULT: PASS")
		quit(0)
	else:
		printerr("RESULT: FAIL")
		quit(1)
