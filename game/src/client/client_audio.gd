class_name ClientAudio
extends RefCounted

## Presentation host for the audio module. Loads platform banks into the
## kernel and maps product states to theme cue ids. Cue ids here may use
## gameplay names; game/src/audio/** must not.

const AudioBankGd := preload("res://src/audio/audio_bank.gd")
const AudioBankLoaderGd := preload("res://src/audio/audio_bank_loader.gd")
const AudioMusicDirectorGd := preload("res://src/audio/audio_music_director.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")
const MatchPlayAudioGd := preload("res://src/client/match_play_audio.gd")
const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")

const DIR: String = "res://content/audio/f_line_temp/"
const CUE_STEP: String = CatalogGd.STEP
const CUE_JUMP: String = CatalogGd.JUMP
const CUE_LAND: String = CatalogGd.LAND
const CUE_PICKUP: String = CatalogGd.PICKUP
const CUE_CRATE: String = CatalogGd.CRATE
const CUE_HAZARD_WARN: String = CatalogGd.HAZARD_WARN
const CUE_PORTAL: String = CatalogGd.PORTAL
const CUE_FINISH: String = CatalogGd.FINISH
const STATE_LOBBY: String = "lobby"
const STATE_PLAY: String = "play"
const STATE_RESULT: String = "result"
const STATE_EDIT: String = "edit"

static var service: AudioServiceGd = null
static var director: AudioMusicDirectorGd = null
static var play_audio: MatchPlayAudioGd = null


static func ensure(host: Node) -> AudioServiceGd:
	if service != null:
		return service
	service = AudioServiceGd.new()
	service.mount(host)
	var bank: AudioBankGd = AudioBankLoaderGd.load_directory()
	if bank != null:
		bank.apply_to(service)
	director = AudioMusicDirectorGd.new()
	director.bind(service)
	director.request(CatalogGd.THEME_IDLE)
	play_audio = MatchPlayAudioGd.new()
	return service


static func bind(next: AudioServiceGd) -> void:
	service = next
	if director == null:
		director = AudioMusicDirectorGd.new()
	director.bind(service)
	if play_audio == null:
		play_audio = MatchPlayAudioGd.new()


static func shutdown() -> void:
	if play_audio != null and service != null:
		play_audio.reset(service)
	play_audio = null
	if director != null:
		director.stop()
	director = null
	if service != null:
		service.shutdown()
	service = null


static func post(cue_id: String, ctx: Dictionary = {}) -> bool:
	if service == null:
		return false
	return service.post(cue_id, ctx)


static func post_event(event: String, ctx: Dictionary = {}) -> bool:
	return post(RouterGd.cue(event), ctx)


static func clear_play() -> void:
	if play_audio != null:
		play_audio.reset(service)


static func pump_session(
	session: TraprushMatchSession,
	slot: int,
	map: Node3D,
	ear: Node3D,
	intent: String = "",
	kinds: Dictionary = {}
) -> void:
	if play_audio == null or service == null or session == null:
		return
	var sample: Dictionary = play_audio.observe.sample_session(session, slot, intent, kinds)
	var events: PackedStringArray = play_audio.observe.collect(sample)
	var loops: Array[Dictionary] = play_audio.observe.loops_session(session)
	var origin: Vector3 = MatchPlayAudioGd.pose_meters(session.player_pose(slot))
	play_audio.pump(service, events, loops, map, ear, origin)


static func request_state(state: String) -> bool:
	if director == null:
		return false
	var cue_id: String = _cue_for_state(state)
	if cue_id == "":
		return false
	return director.request(cue_id)


static func advance_music() -> void:
	if director != null:
		director.advance()


static func muted() -> bool:
	if service == null:
		return DisplayServer.get_name() == "headless"
	return service.settings.muted or service.backend.is_silent()


static func has_slot(slot: String) -> bool:
	if not CatalogGd.has_id(slot):
		return false
	if service != null:
		var bank_path: String = service.stream_path(slot)
		if bank_path != "":
			return FileAccess.file_exists(bank_path)
	return FileAccess.file_exists(path_for(slot))


static func path_for(slot: String) -> String:
	if not CatalogGd.has_id(slot):
		return ""
	return "%s%s.wav" % [DIR, slot]


static func all_slots() -> PackedStringArray:
	return CatalogGd.all_ids()


static func _cue_for_state(state: String) -> String:
	match state:
		STATE_LOBBY:
			return CatalogGd.THEME_IDLE
		STATE_PLAY:
			return CatalogGd.THEME_RUN
		STATE_RESULT:
			return CatalogGd.THEME_END
		STATE_EDIT:
			return CatalogGd.THEME_EDIT
		_:
			return ""
