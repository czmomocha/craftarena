extends GutTest

## M4b chapter 2: publish writes a version then latest; new rooms
## resolve latest; a room opened on v1 keeps the v1 hash after v2.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const ContentCatalogGd := preload("res://src/ugc/content_catalog.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const PIPE_ID: String = "ugc_pipe_01"


func test_publish_v1_then_v2_new_room_uses_latest() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var first: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var second: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	var published_one: Dictionary = _publish(catalog, first, 1)
	var one_ok: bool = published_one.get(ContentCatalogGd.KEY_OK, false)
	assert_true(one_ok)
	var room_a: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var a_ok: bool = room_a.get(ContentCatalogGd.KEY_OK, false)
	assert_true(a_ok)
	var published_two: Dictionary = _publish(catalog, second, 2)
	var two_ok: bool = published_two.get(ContentCatalogGd.KEY_OK, false)
	assert_true(two_ok)
	var room_b: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var b_ok: bool = room_b.get(ContentCatalogGd.KEY_OK, false)
	assert_true(b_ok)
	var hash_a: String = str(room_a.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var hash_b: String = str(room_b.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	assert_eq(hash_a, ContentSignGd.hash_hex(first))
	assert_eq(hash_b, ContentSignGd.hash_hex(second))
	assert_ne(hash_a, hash_b)
	var version_a: int = room_a.get(ContentSignGd.KEY_VERSION, 0)
	var version_b: int = room_b.get(ContentSignGd.KEY_VERSION, 0)
	assert_eq(version_a, 1)
	assert_eq(version_b, 2)
	var latest: Dictionary = catalog.latest(PIPE_ID)
	var latest_ok: bool = latest.get(ContentCatalogGd.KEY_OK, false)
	var latest_version: int = latest.get(ContentSignGd.KEY_VERSION, 0)
	assert_true(latest_ok)
	assert_eq(latest_version, 2)
	var old: Dictionary = catalog.get_version(PIPE_ID, 1)
	var old_ok: bool = old.get(ContentCatalogGd.KEY_OK, false)
	var old_hash: String = str(old.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	assert_true(old_ok)
	assert_eq(old_hash, hash_a)


func test_version_must_start_at_one_and_increment() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var first: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var skip: Dictionary = _publish(catalog, first, 2)
	var skip_ok: bool = skip.get(ContentCatalogGd.KEY_OK, false)
	var skip_reason: String = str(skip.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(skip_ok)
	assert_eq(skip_reason, ContentCatalogGd.REASON_VERSION_NOT_NEXT)
	var missing: Dictionary = catalog.latest(PIPE_ID)
	var missing_ok: bool = missing.get(ContentCatalogGd.KEY_OK, false)
	var missing_reason: String = str(missing.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(missing_ok)
	assert_eq(missing_reason, ContentCatalogGd.REASON_LATEST_MISSING)
	var first_pub: Dictionary = _publish(catalog, first, 1)
	var first_ok: bool = first_pub.get(ContentCatalogGd.KEY_OK, false)
	assert_true(first_ok)
	var again: Dictionary = _publish(catalog, first, 1)
	var again_ok: bool = again.get(ContentCatalogGd.KEY_OK, false)
	var again_reason: String = str(again.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(again_ok)
	assert_eq(again_reason, ContentCatalogGd.REASON_VERSION_EXISTS)
	var still: Dictionary = catalog.latest(PIPE_ID)
	var still_ok: bool = still.get(ContentCatalogGd.KEY_OK, false)
	var still_version: int = still.get(ContentSignGd.KEY_VERSION, 0)
	assert_true(still_ok)
	assert_eq(still_version, 1)


func test_bad_signature_does_not_move_latest() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var first: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var signed: Dictionary = ContentSignGd.sign(PIPE_ID, 1, first, ContentSignGd.dev_key())
	var envelope: Dictionary = _envelope_of(signed)
	envelope[ContentSignGd.KEY_SIGNATURE] = _flip_hex(str(envelope[ContentSignGd.KEY_SIGNATURE]))
	var failed: Dictionary = catalog.publish(envelope, first, ContentSignGd.dev_key())
	var failed_ok: bool = failed.get(ContentCatalogGd.KEY_OK, false)
	var failed_reason: String = str(failed.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(failed_ok)
	assert_eq(failed_reason, ContentSignGd.REASON_SIGNATURE_MISMATCH)
	var missing: Dictionary = catalog.latest(PIPE_ID)
	var missing_ok: bool = missing.get(ContentCatalogGd.KEY_OK, false)
	assert_false(missing_ok)
	var no_room: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var no_room_ok: bool = no_room.get(ContentCatalogGd.KEY_OK, false)
	var no_room_reason: String = str(no_room.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(no_room_ok)
	assert_eq(no_room_reason, ContentCatalogGd.REASON_LATEST_MISSING)


func _publish(catalog: ContentCatalogGd, bundle: SimulationBundleGd, version: int) -> Dictionary:
	var signed: Dictionary = ContentSignGd.sign(PIPE_ID, version, bundle, ContentSignGd.dev_key())
	return catalog.publish(_envelope_of(signed), bundle, ContentSignGd.dev_key())


func _compile(course_id: String) -> SimulationBundleGd:
	var path: String = OfficialTraprushCoursesGd.document_path(course_id)
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(path)
	assert_not_null(world, path)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle, path)
	return bundle


func _envelope_of(signed: Dictionary) -> Dictionary:
	return {
		ContentSignGd.KEY_SCHEMA_VERSION: signed[ContentSignGd.KEY_SCHEMA_VERSION],
		ContentSignGd.KEY_CONTENT_ID: signed[ContentSignGd.KEY_CONTENT_ID],
		ContentSignGd.KEY_VERSION: signed[ContentSignGd.KEY_VERSION],
		ContentSignGd.KEY_CONTENT_HASH: signed[ContentSignGd.KEY_CONTENT_HASH],
		ContentSignGd.KEY_SIGNATURE: signed[ContentSignGd.KEY_SIGNATURE],
	}


func _flip_hex(text: String) -> String:
	if text.is_empty():
		return "0"
	var first: String = text.substr(0, 1)
	if first == "0":
		return "1" + text.substr(1)
	return "0" + text.substr(1)


func _offsets(count: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for index: int in range(count):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	return offsets
