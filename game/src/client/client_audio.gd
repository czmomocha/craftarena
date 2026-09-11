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
	return service


static func bind(next: AudioServiceGd) -> void:
	service = next
	if director == null:
		director = AudioMusicDirectorGd.new()
	director.bind(service)


static func shutdown() -> void:
	if director != null:
		director.stop()
	director = null
	if service != null:
		service.shutdown()
	service = null


static func post(cue_id: String) -> bool:
	if service == null:
		return false
	return service.post(cue_id)


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
