class_name MatchServerBoot
extends RefCounted

## Official `--course=` or signed `--content-envelope=` → TraprushMatchSession.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const SPAWN_STRIDE: int = PlaceholderSpec.SPAWN_STRIDE
const MATCH_SEED: int = 1


static func boot_session(config: Dictionary) -> TraprushMatchSession:
	if not config.get("ok", false):
		return null
	var players: int = config.get("players", 0)
	var bundle: SimulationBundle = _bundle_from_config(config)
	if bundle == null:
		return null
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		MATCH_SEED,
		players,
		_spawn_offsets(players),
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT
	)
	if session == null:
		return null
	PlayStubs.apply_match(session)
	return session


static func _bundle_from_config(config: Dictionary) -> SimulationBundle:
	var envelope_path: String = str(config.get("content_envelope", ""))
	if envelope_path != "":
		return _bundle_from_envelope(envelope_path)
	var course: String = str(config.get("course", ""))
	var world: AuthoringWorld = AuthoringDocument.load_from_path(course)
	if world == null:
		return null
	return TraprushTopologyCompiler.compile(world)


static func _bundle_from_envelope(path: String) -> SimulationBundle:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var raw: Dictionary = parsed
	var bundle_raw: Variant = raw.get("bundle", null)
	if typeof(bundle_raw) != TYPE_DICTIONARY:
		return null
	var bundle_dict: Dictionary = bundle_raw
	var bundle: SimulationBundle = SimulationBundle.from_dictionary(bundle_dict)
	if bundle == null:
		return null
	var envelope: Dictionary = {
		ContentSignGd.KEY_SCHEMA_VERSION: _as_int(raw.get(ContentSignGd.KEY_SCHEMA_VERSION, 0)),
		ContentSignGd.KEY_CONTENT_ID: str(raw.get(ContentSignGd.KEY_CONTENT_ID, "")),
		ContentSignGd.KEY_VERSION: _as_int(raw.get(ContentSignGd.KEY_VERSION, 0)),
		ContentSignGd.KEY_CONTENT_HASH: str(raw.get(ContentSignGd.KEY_CONTENT_HASH, "")),
		ContentSignGd.KEY_SIGNATURE: str(raw.get(ContentSignGd.KEY_SIGNATURE, "")),
	}
	var verified: Dictionary = ContentSignGd.verify(envelope, bundle, _sign_key())
	var ok: bool = verified.get(ContentSignGd.KEY_OK, false)
	if not ok:
		return null
	return bundle


static func _sign_key() -> PackedByteArray:
	var text: String = OS.get_environment("CONTENT_SIGN_KEY")
	if text.is_empty():
		return ContentSignGd.dev_key()
	return text.to_utf8_buffer()


static func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number != floor(number):
			return 0
		return int(number)
	return 0


static func _spawn_offsets(players: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for slot: int in range(players):
		offsets.append({"dx": 0, "dy": 0, "dz": -slot * SPAWN_STRIDE})
	return offsets
