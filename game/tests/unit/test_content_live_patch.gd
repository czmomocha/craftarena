extends GutTest

## M4b chapter 3: P0/P1 live patches fan out to running rooms, apply at
## the next safety boundary, reject P2/P3, record PatchHash sequence,
## and append a reverse patch on technical fault. latest can roll back
## to a signed older version without reusing numbers.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const ContentCatalogGd := preload("res://src/ugc/content_catalog.gd")
const ContentPatchGd := preload("res://src/ugc/content_patch.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const CrateGd := preload("res://src/games/traprush/destructible.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchPatchGd := preload("res://src/games/traprush/match_session_patch.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const PIPE_ID: String = "ugc_pipe_01"
const CRATE_ID: int = 40
const HAZARD_ID: int = 60


func test_p1_durability_applies_at_spawn_boundary_and_keeps_content_hash() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var published: Dictionary = _publish(catalog, bundle, 1)
	var published_ok: bool = published.get(ContentCatalogGd.KEY_OK, false)
	assert_true(published_ok)
	var room: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var room_ok: bool = room.get(ContentCatalogGd.KEY_OK, false)
	assert_true(room_ok)
	var session: TraprushMatchSessionGd = room[ContentCatalogGd.KEY_SESSION]
	var overlay: TraprushMatchPatchGd = _overlay(session)
	var before_hash: String = session.content_hash
	assert_eq(_crate_max(session, CRATE_ID), 1)
	var patched: Dictionary = _publish_patch(
		catalog, 1, 1, ContentPatchGd.BAG_DESTRUCTIBLES, CRATE_ID,
		ContentPatchGd.FIELD_DURABILITY, 2, "p1"
	)
	var patched_ok: bool = patched.get(ContentCatalogGd.KEY_OK, false)
	assert_true(patched_ok)
	assert_eq(overlay.pending_count(), 1)
	session.commit_tick()
	assert_eq(_crate_max(session, CRATE_ID), 2)
	assert_eq(session.content_hash, before_hash)
	assert_eq(overlay.patch_hashes().size(), 1)
	assert_eq(overlay.pending_count(), 0)


func test_p1_waits_for_real_pad_progress_not_spawn_overlap() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var published: Dictionary = _publish(catalog, bundle, 1)
	var published_ok: bool = published.get(ContentCatalogGd.KEY_OK, false)
	assert_true(published_ok)
	var room: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var room_ok: bool = room.get(ContentCatalogGd.KEY_OK, false)
	assert_true(room_ok)
	var session: TraprushMatchSessionGd = room[ContentCatalogGd.KEY_SESSION]
	var overlay: TraprushMatchPatchGd = _overlay(session)
	session.commit_tick()
	var patched: Dictionary = _publish_patch(
		catalog, 1, 1, ContentPatchGd.BAG_DESTRUCTIBLES, CRATE_ID,
		ContentPatchGd.FIELD_DURABILITY, 2, "p1"
	)
	var patched_ok: bool = patched.get(ContentCatalogGd.KEY_OK, false)
	assert_true(patched_ok)
	assert_eq(overlay.pending_count(), 1)
	session.commit_tick()
	assert_eq(_crate_max(session, CRATE_ID), 1)
	assert_eq(overlay.pending_count(), 1)
	overlay.note_pad_accepted()
	session.commit_tick()
	assert_eq(_crate_max(session, CRATE_ID), 2)
	assert_eq(overlay.pending_count(), 0)


func test_p2_ops_never_queue_and_p1_skips_rooms_on_another_base() -> void:
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
	var session_a: TraprushMatchSessionGd = room_a[ContentCatalogGd.KEY_SESSION]
	var forbidden: Dictionary = _publish_patch(
		catalog, 1, 1, "solids", 80, "x", 1, "p1"
	)
	var forbidden_ok: bool = forbidden.get(ContentCatalogGd.KEY_OK, false)
	var forbidden_reason: String = str(forbidden.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(forbidden_ok)
	assert_eq(forbidden_reason, ContentPatchGd.REASON_LEVEL_FORBIDDEN)
	assert_eq(_overlay(session_a).pending_count(), 0)
	var published_two: Dictionary = _publish(catalog, second, 2)
	var two_ok: bool = published_two.get(ContentCatalogGd.KEY_OK, false)
	assert_true(two_ok)
	var room_b: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var b_ok: bool = room_b.get(ContentCatalogGd.KEY_OK, false)
	assert_true(b_ok)
	var session_b: TraprushMatchSessionGd = room_b[ContentCatalogGd.KEY_SESSION]
	var overlay_b: TraprushMatchPatchGd = _overlay(session_b)
	var p1: Dictionary = _publish_patch(
		catalog, 2, 1, ContentPatchGd.BAG_HAZARDS, HAZARD_ID,
		ContentPatchGd.FIELD_COOLDOWN, 30, "p1"
	)
	var p1_ok: bool = p1.get(ContentCatalogGd.KEY_OK, false)
	assert_true(p1_ok)
	assert_eq(_overlay(session_a).pending_count(), 0)
	assert_eq(overlay_b.pending_count(), 1)
	session_b.commit_tick()
	assert_eq(_hazard_cooldown(session_b, HAZARD_ID), 30)
	assert_eq(_hazard_cooldown(session_a, HAZARD_ID), 1)


func test_technical_fault_appends_reverse_patch_and_restores_value() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var published: Dictionary = _publish(catalog, bundle, 1)
	var published_ok: bool = published.get(ContentCatalogGd.KEY_OK, false)
	assert_true(published_ok)
	var room: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var session: TraprushMatchSessionGd = room[ContentCatalogGd.KEY_SESSION]
	var patched: Dictionary = _publish_patch(
		catalog, 1, 1, ContentPatchGd.BAG_DESTRUCTIBLES, CRATE_ID,
		ContentPatchGd.FIELD_DURABILITY, 3, "p1"
	)
	var patched_ok: bool = patched.get(ContentCatalogGd.KEY_OK, false)
	assert_true(patched_ok)
	session.commit_tick()
	assert_eq(_crate_max(session, CRATE_ID), 3)
	var overlay: TraprushMatchPatchGd = _overlay(session)
	assert_true(overlay.note_fault(session, "tick_over_budget"))
	assert_eq(_crate_max(session, CRATE_ID), 1)
	assert_eq(overlay.patch_hashes().size(), 2)
	var hashes: PackedStringArray = overlay.patch_hashes()
	assert_eq(hashes.size(), 2)
	assert_false(session.content_hash.is_empty())


func test_latest_rollback_sends_new_rooms_to_old_version() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var first: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var second: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	var published_one: Dictionary = _publish(catalog, first, 1)
	var one_ok: bool = published_one.get(ContentCatalogGd.KEY_OK, false)
	assert_true(one_ok)
	var room_old: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var hash_old: String = str(room_old.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var published_two: Dictionary = _publish(catalog, second, 2)
	var two_ok: bool = published_two.get(ContentCatalogGd.KEY_OK, false)
	assert_true(two_ok)
	var rolled: Dictionary = catalog.rollback_latest(PIPE_ID, 1)
	var rolled_ok: bool = rolled.get(ContentCatalogGd.KEY_OK, false)
	assert_true(rolled_ok)
	var latest: Dictionary = catalog.latest(PIPE_ID)
	var latest_version: int = latest.get(ContentSignGd.KEY_VERSION, 0)
	assert_eq(latest_version, 1)
	var room_new: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var new_ok: bool = room_new.get(ContentCatalogGd.KEY_OK, false)
	assert_true(new_ok)
	var new_hash: String = str(room_new.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var new_version: int = room_new.get(ContentSignGd.KEY_VERSION, 0)
	assert_eq(new_hash, hash_old)
	assert_eq(new_version, 1)
	var replay: Dictionary = _publish(catalog, first, 2)
	var replay_ok: bool = replay.get(ContentCatalogGd.KEY_OK, false)
	var replay_reason: String = str(replay.get(ContentCatalogGd.KEY_REASON, ""))
	assert_false(replay_ok)
	assert_eq(replay_reason, ContentCatalogGd.REASON_VERSION_EXISTS)
	var third: Dictionary = _publish(catalog, second, 3)
	var third_ok: bool = third.get(ContentCatalogGd.KEY_OK, false)
	assert_true(third_ok)
	var after: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var after_version: int = after.get(ContentSignGd.KEY_VERSION, 0)
	assert_eq(after_version, 3)


func test_replay_applies_patch_hashes_in_order() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var published: Dictionary = _publish(catalog, bundle, 1)
	var published_ok: bool = published.get(ContentCatalogGd.KEY_OK, false)
	assert_true(published_ok)
	var patched: Dictionary = _publish_patch(
		catalog, 1, 1, ContentPatchGd.BAG_DESTRUCTIBLES, CRATE_ID,
		ContentPatchGd.FIELD_DURABILITY, 4, "p1"
	)
	var patched_ok: bool = patched.get(ContentCatalogGd.KEY_OK, false)
	assert_true(patched_ok)
	var first: Dictionary = catalog.try_create_match(
		PIPE_ID, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var session_a: TraprushMatchSessionGd = first[ContentCatalogGd.KEY_SESSION]
	assert_eq(_crate_max(session_a, CRATE_ID), 4)
	var hashes_a: PackedStringArray = _overlay(session_a).patch_hashes()
	var second: Dictionary = catalog.try_create_match(
		PIPE_ID, 2, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS, ContentSignGd.dev_key()
	)
	var session_b: TraprushMatchSessionGd = second[ContentCatalogGd.KEY_SESSION]
	assert_eq(_crate_max(session_b, CRATE_ID), 4)
	var hashes_b: PackedStringArray = _overlay(session_b).patch_hashes()
	assert_eq(hashes_a.size(), 1)
	assert_eq(hashes_b, hashes_a)


func _publish(catalog: ContentCatalogGd, bundle: SimulationBundleGd, version: int) -> Dictionary:
	var signed: Dictionary = ContentSignGd.sign(PIPE_ID, version, bundle, ContentSignGd.dev_key())
	return catalog.publish(_envelope_of_sign(signed), bundle, ContentSignGd.dev_key())


func _publish_patch(
	catalog: ContentCatalogGd,
	base_version: int,
	seq: int,
	bag: String,
	entity_id: int,
	field: String,
	value: int,
	level: String
) -> Dictionary:
	var ops: Array = [{
		"bag": bag,
		"entity_id": entity_id,
		"field": field,
		"value": value,
	}]
	var signed: Dictionary = ContentPatchGd.sign(
		PIPE_ID, base_version, seq, level, ops, ContentSignGd.dev_key()
	)
	var signed_ok: bool = signed.get(ContentPatchGd.KEY_OK, false)
	if not signed_ok:
		return signed
	return catalog.publish_patch(ContentPatchGd.envelope_of(signed), ops, ContentSignGd.dev_key())


func _compile(course_id: String) -> SimulationBundleGd:
	var path: String = OfficialTraprushCoursesGd.document_path(course_id)
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(path)
	assert_not_null(world, path)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle, path)
	return bundle


func _envelope_of_sign(signed: Dictionary) -> Dictionary:
	return {
		ContentSignGd.KEY_SCHEMA_VERSION: signed[ContentSignGd.KEY_SCHEMA_VERSION],
		ContentSignGd.KEY_CONTENT_ID: signed[ContentSignGd.KEY_CONTENT_ID],
		ContentSignGd.KEY_VERSION: signed[ContentSignGd.KEY_VERSION],
		ContentSignGd.KEY_CONTENT_HASH: signed[ContentSignGd.KEY_CONTENT_HASH],
		ContentSignGd.KEY_SIGNATURE: signed[ContentSignGd.KEY_SIGNATURE],
	}


func _overlay(session: TraprushMatchSessionGd) -> TraprushMatchPatchGd:
	var overlay: TraprushMatchPatchGd = session.live_patch as TraprushMatchPatchGd
	assert_not_null(overlay)
	return overlay


func _crate_max(session: TraprushMatchSessionGd, entity_id: int) -> int:
	if not session._crate_health.has(entity_id):
		return -1
	var crate_raw: Variant = session._crate_health[entity_id]
	if not (crate_raw is CrateGd):
		return -1
	var crate: CrateGd = crate_raw
	return crate.max_health()


func _hazard_cooldown(session: TraprushMatchSessionGd, entity_id: int) -> int:
	for item: Dictionary in session._hazard_cycle:
		var hazard_id: int = item.get("entity_id", -1)
		if hazard_id == entity_id:
			return item.get("cooldown_ticks", -1)
	return -1


func _offsets(count: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for index: int in range(count):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	return offsets
