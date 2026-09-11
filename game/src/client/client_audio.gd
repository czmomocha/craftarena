class_name ClientAudio
extends RefCounted

## Presentation host for the audio module. Loads platform banks into the
## kernel. Cue ids here may use gameplay names; game/src/audio/** must not.

const AudioBankGd := preload("res://src/audio/audio_bank.gd")
const AudioBankLoaderGd := preload("res://src/audio/audio_bank_loader.gd")
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

static var service: AudioServiceGd = null


static func ensure(host: Node) -> AudioServiceGd:
	if service != null:
		return service
	service = AudioServiceGd.new()
	service.mount(host)
	var bank: AudioBankGd = AudioBankLoaderGd.load_directory()
	if bank != null:
		bank.apply_to(service)
	return service


static func bind(next: AudioServiceGd) -> void:
	service = next


static func shutdown() -> void:
	if service != null:
		service.shutdown()
	service = null


static func post(cue_id: String) -> bool:
	if service == null:
		return false
	return service.post(cue_id)


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
