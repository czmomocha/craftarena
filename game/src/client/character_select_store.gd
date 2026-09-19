class_name CharacterSelectStore
extends RefCounted

## 本机角色选择。缺文件 / 坏 JSON / 未知 id 一律回退目录默认。
## 永不写入 SimulationWorld / hash_state / 协议帧。

const PATH: String = "user://character_select.json"
const KEY_ID: String = "id"

var path: String = PATH
var selected_id: String = SharedCharacterCatalog.DEFAULT_ID


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	selected_id = SharedCharacterCatalog.DEFAULT_ID


func load_or_default() -> void:
	reset_defaults()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		reset_defaults()
		return
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		reset_defaults()
		return
	var data: Dictionary = parsed
	var raw: Variant = data.get(KEY_ID, "")
	if typeof(raw) != TYPE_STRING:
		reset_defaults()
		return
	selected_id = SharedCharacterCatalog.resolve(str(raw))


func save() -> bool:
	selected_id = SharedCharacterCatalog.resolve(selected_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({KEY_ID: selected_id}))
	return true


func select(id: String) -> String:
	selected_id = SharedCharacterCatalog.resolve(id)
	save()
	return selected_id


func scene_path() -> String:
	return SharedCharacterCatalog.scene_path(selected_id)


func display_name() -> String:
	return UiCopy.text(SharedCharacterCatalog.name_key(selected_id))
