extends GutTest

## M4b chapter 1: ContentHash + platform HMAC envelope.
## Hash is StateHasher canonical of SimulationBundle.to_dictionary().
## Official matches lock the hash and still load without a signature.
## Extra SimulationBundle keys stay rejected. No latest pointer.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const RFC4231_MAC: String = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"


func test_hmac_sha256_rfc4231_case_1() -> void:
	var key: PackedByteArray = PackedByteArray()
	key.resize(20)
	for index: int in range(20):
		key[index] = 0x0b
	var mac: PackedByteArray = ContentSignGd.hmac_sha256(key, "Hi There".to_utf8_buffer())
	assert_eq(mac.hex_encode(), RFC4231_MAC)


func test_official_course_hash_is_stable_and_distinct() -> void:
	var one: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var one_again: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var two: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	var first: Dictionary = ContentSignGd.hash_bundle(one)
	var repeat: Dictionary = ContentSignGd.hash_bundle(one_again)
	var other: Dictionary = ContentSignGd.hash_bundle(two)
	var first_ok: bool = first.get(ContentSignGd.KEY_OK, false)
	var repeat_ok: bool = repeat.get(ContentSignGd.KEY_OK, false)
	var other_ok: bool = other.get(ContentSignGd.KEY_OK, false)
	assert_true(first_ok)
	assert_true(repeat_ok)
	assert_true(other_ok)
	var first_hash: String = str(first.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var repeat_hash: String = str(repeat.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var other_hash: String = str(other.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	assert_true(ContentSignGd.hex_ok(first_hash))
	assert_eq(first_hash, repeat_hash)
	assert_ne(first_hash, other_hash)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(one.to_dictionary())
	assert_not_null(decoded)
	assert_eq(ContentSignGd.hash_hex(decoded), first_hash)


func test_sign_and_verify_official_course() -> void:
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var signed: Dictionary = ContentSignGd.sign(
		OfficialTraprushCoursesGd.COURSE_01, 1, bundle, ContentSignGd.dev_key()
	)
	var signed_ok: bool = signed.get(ContentSignGd.KEY_OK, false)
	assert_true(signed_ok)
	var schema: int = signed.get(ContentSignGd.KEY_SCHEMA_VERSION, 0)
	var content_id: String = str(signed.get(ContentSignGd.KEY_CONTENT_ID, ""))
	var version: int = signed.get(ContentSignGd.KEY_VERSION, 0)
	assert_eq(schema, ContentSignGd.SCHEMA_VERSION)
	assert_eq(content_id, OfficialTraprushCoursesGd.COURSE_01)
	assert_eq(version, 1)
	var envelope: Dictionary = _envelope_of(signed)
	var checked: Dictionary = ContentSignGd.verify(envelope, bundle, ContentSignGd.dev_key())
	var checked_ok: bool = checked.get(ContentSignGd.KEY_OK, false)
	assert_true(checked_ok)
	var checked_hash: String = str(checked.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	var signed_hash: String = str(signed.get(ContentSignGd.KEY_CONTENT_HASH, ""))
	assert_eq(checked_hash, signed_hash)


func test_tamper_and_wrong_key_fail_verify() -> void:
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var signed: Dictionary = ContentSignGd.sign("course_01", 1, bundle, ContentSignGd.dev_key())
	var envelope: Dictionary = _envelope_of(signed)
	var mutated: SimulationBundleGd = SimulationBundleGd.from_dictionary(bundle.to_dictionary())
	assert_not_null(mutated)
	mutated.source_revision = bundle.source_revision + 1
	var hash_miss: Dictionary = ContentSignGd.verify(envelope, mutated, ContentSignGd.dev_key())
	var hash_ok: bool = hash_miss.get(ContentSignGd.KEY_OK, false)
	var hash_reason: String = str(hash_miss.get(ContentSignGd.KEY_REASON, ""))
	assert_false(hash_ok)
	assert_eq(hash_reason, ContentSignGd.REASON_HASH_MISMATCH)
	var other_key: PackedByteArray = "craftarena-content-sign-other-k".to_utf8_buffer()
	var key_miss: Dictionary = ContentSignGd.verify(envelope, bundle, other_key)
	var key_ok: bool = key_miss.get(ContentSignGd.KEY_OK, false)
	var key_reason: String = str(key_miss.get(ContentSignGd.KEY_REASON, ""))
	assert_false(key_ok)
	assert_eq(key_reason, ContentSignGd.REASON_SIGNATURE_MISMATCH)
	var flipped: Dictionary = envelope.duplicate(true)
	flipped[ContentSignGd.KEY_SIGNATURE] = _flip_hex(str(envelope[ContentSignGd.KEY_SIGNATURE]))
	var sig_miss: Dictionary = ContentSignGd.verify(flipped, bundle, ContentSignGd.dev_key())
	var sig_ok: bool = sig_miss.get(ContentSignGd.KEY_OK, false)
	var sig_reason: String = str(sig_miss.get(ContentSignGd.KEY_REASON, ""))
	assert_false(sig_ok)
	assert_eq(sig_reason, ContentSignGd.REASON_SIGNATURE_MISMATCH)


func test_rejects_extra_keys_bad_id_and_short_key() -> void:
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var signed: Dictionary = ContentSignGd.sign("course_01", 1, bundle, ContentSignGd.dev_key())
	var extra: Dictionary = _envelope_of(signed)
	extra["latest"] = true
	var extra_fail: Dictionary = ContentSignGd.verify(extra, bundle, ContentSignGd.dev_key())
	var extra_ok: bool = extra_fail.get(ContentSignGd.KEY_OK, false)
	var extra_reason: String = str(extra_fail.get(ContentSignGd.KEY_REASON, ""))
	assert_false(extra_ok)
	assert_eq(extra_reason, ContentSignGd.REASON_ENVELOPE_KEYS)
	var bad_id: Dictionary = ContentSignGd.sign("course 01", 1, bundle, ContentSignGd.dev_key())
	var bad_id_ok: bool = bad_id.get(ContentSignGd.KEY_OK, false)
	var bad_id_reason: String = str(bad_id.get(ContentSignGd.KEY_REASON, ""))
	assert_false(bad_id_ok)
	assert_eq(bad_id_reason, ContentSignGd.REASON_ID_INVALID)
	var bad_ver: Dictionary = ContentSignGd.sign("course_01", 0, bundle, ContentSignGd.dev_key())
	var bad_ver_ok: bool = bad_ver.get(ContentSignGd.KEY_OK, false)
	var bad_ver_reason: String = str(bad_ver.get(ContentSignGd.KEY_REASON, ""))
	assert_false(bad_ver_ok)
	assert_eq(bad_ver_reason, ContentSignGd.REASON_VERSION_INVALID)
	var short_key: PackedByteArray = "tooshort".to_utf8_buffer()
	var bad_key: Dictionary = ContentSignGd.sign("course_01", 1, bundle, short_key)
	var bad_key_ok: bool = bad_key.get(ContentSignGd.KEY_OK, false)
	var bad_key_reason: String = str(bad_key.get(ContentSignGd.KEY_REASON, ""))
	assert_false(bad_key_ok)
	assert_eq(bad_key_reason, ContentSignGd.REASON_KEY_INVALID)
	assert_eq(ContentSignGd.hash_hex(null), "")


func test_match_locks_hash_without_requiring_signature() -> void:
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var expected: String = ContentSignGd.hash_hex(bundle)
	assert_true(ContentSignGd.hex_ok(expected))
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	assert_eq(session.content_hash, expected)
	assert_eq(session.player_count(), 1)


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
