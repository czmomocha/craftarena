class_name SharedComponentRecord
extends RefCounted

## 一份实体上的 Component Schema v1 组件袋。字段名单的所有者是 CD-42 §1.2。
## 只做类型、白名单和稳定 ID 校验；不发明槽位语义、默认血量或复制策略表。

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var entity_id: int = SharedIds.NULL_ID
var components: Dictionary = {}


static func create(entity_id: int, components: Dictionary) -> SharedComponentRecord:
	if not SharedIds.is_valid(entity_id):
		return null
	if not _components_are_valid(components):
		return null
	var record: SharedComponentRecord = SharedComponentRecord.new()
	record.schema_version = SCHEMA_VERSION
	record.entity_id = entity_id
	record.components = components.duplicate(true)
	return record


static func from_dictionary(data: Dictionary) -> SharedComponentRecord:
	if data.size() != 3:
		return null
	if not data.has("schema_version") or typeof(data["schema_version"]) != TYPE_INT:
		return null
	var version: int = data["schema_version"]
	if version != SCHEMA_VERSION:
		return null
	if not data.has("entity_id") or typeof(data["entity_id"]) != TYPE_INT:
		return null
	var parsed_id: int = data["entity_id"]
	if not data.has("components") or typeof(data["components"]) != TYPE_DICTIONARY:
		return null
	var parsed_components: Dictionary = data["components"]
	return create(parsed_id, parsed_components)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"entity_id": entity_id,
		"components": components.duplicate(true),
	}


func feed_hasher(hasher: StateHasher) -> void:
	hasher.write_s64(schema_version)
	hasher.write_s64(entity_id)
	if not hasher.write_canonical(components):
		push_error("SharedComponentRecord components must remain canonical after create()")


static func _components_are_valid(components: Dictionary) -> bool:
	if not CanonicalPayload.is_allowed(components):
		return false
	var keys: Array = components.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return false
		var component_name: String = key
		if not SharedComponentNames.contains(component_name):
			return false
		var raw: Variant = components[key]
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		if not _named_component_is_valid(component_name, body):
			return false
	return true


static func _named_component_is_valid(component_name: String, body: Dictionary) -> bool:
	match component_name:
		SharedComponentNames.TRANSFORM:
			return _transform_is_valid(body)
		SharedComponentNames.VELOCITY:
			return _velocity_is_valid(body)
		SharedComponentNames.HEALTH:
			return _health_is_valid(body)
		SharedComponentNames.TEAM:
			return _team_is_valid(body)
		SharedComponentNames.SCORE:
			return _score_is_valid(body)
		SharedComponentNames.ZONE:
			return _zone_is_valid(body)
		SharedComponentNames.SPAWNER:
			return _spawner_is_valid(body)
		SharedComponentNames.HAZARD:
			return _hazard_is_valid(body)
		SharedComponentNames.MOVER:
			return _mover_is_valid(body)
		SharedComponentNames.INTERACTABLE:
			return _interactable_is_valid(body)
		SharedComponentNames.CHECKPOINT:
			return _checkpoint_is_valid(body)
		SharedComponentNames.PORTAL:
			return _portal_is_valid(body)
		SharedComponentNames.DESTRUCTIBLE:
			return _destructible_is_valid(body)
		SharedComponentNames.INVENTORY:
			return _inventory_is_valid(body)
		SharedComponentNames.PATH_AGENT:
			return _path_agent_is_valid(body)
		SharedComponentNames.BUILD_SLOT:
			return _build_slot_is_valid(body)
		SharedComponentNames.TOWER:
			return _tower_is_valid(body)
		SharedComponentNames.REPLICATION:
			return _replication_is_valid(body)
		SharedComponentNames.GAMEPLAY_ASSET:
			return _gameplay_asset_is_valid(body)
		_:
			return false


static func _transform_is_valid(body: Dictionary) -> bool:
	return _exactly(body, PackedStringArray(["x", "y", "z", "yaw_bam"])) and _all_ints(body)


static func _velocity_is_valid(body: Dictionary) -> bool:
	return _exactly(body, PackedStringArray(["vx", "vy", "vz"])) and _all_ints(body)


static func _health_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["current", "maximum", "invuln_ticks"])):
		return false
	return _int_at_least(body, "current", 0) and _int_at_least(body, "maximum", 1) and _int_at_least(body, "invuln_ticks", 0)


static func _team_is_valid(body: Dictionary) -> bool:
	return _exactly(body, PackedStringArray(["team_id"])) and _int_at_least(body, "team_id", 0)


static func _score_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["tallies"])):
		return false
	var raw: Variant = body["tallies"]
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var tallies: Dictionary = raw
	var keys: Array = tallies.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return false
		var name: String = key
		if name.is_empty():
			return false
		if typeof(tallies[key]) != TYPE_INT:
			return false
	return true


static func _zone_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["shape", "tags"])):
		return false
	var shape_raw: Variant = body["shape"]
	if typeof(shape_raw) != TYPE_DICTIONARY:
		return false
	var shape: Dictionary = shape_raw
	if not _shape_is_valid(shape):
		return false
	return _string_array(body["tags"])


static func _spawner_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["prototype_id", "interval_ticks", "max_alive"])):
		return false
	return (
		_int_at_least(body, "prototype_id", 1)
		and _int_at_least(body, "interval_ticks", 0)
		and _int_at_least(body, "max_alive", 0)
	)


static func _hazard_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["damage", "knockback", "cooldown_ticks"])):
		return false
	return (
		_int_at_least(body, "damage", 0)
		and _is_int_field(body, "knockback")
		and _int_at_least(body, "cooldown_ticks", 0)
	)


static func _mover_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["path", "speed", "loop"])):
		return false
	if not _xyz_array(body["path"]):
		return false
	if not _is_int_field(body, "speed"):
		return false
	return typeof(body["loop"]) == TYPE_BOOL


static func _interactable_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["state", "link_group"])):
		return false
	return _int_at_least(body, "state", 0) and _int_at_least(body, "link_group", 0)


static func _checkpoint_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["order", "respawn_dx", "respawn_dy", "respawn_dz"])):
		return false
	return (
		_int_at_least(body, "order", 0)
		and _is_int_field(body, "respawn_dx")
		and _is_int_field(body, "respawn_dy")
		and _is_int_field(body, "respawn_dz")
	)


static func _portal_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["target_id", "yaw_bam", "cooldown_ticks"])):
		return false
	return (
		_int_at_least(body, "target_id", 1)
		and _is_int_field(body, "yaw_bam")
		and _int_at_least(body, "cooldown_ticks", 0)
	)


static func _destructible_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["durability", "regen_policy_id"])):
		return false
	return _int_at_least(body, "durability", 0) and _int_at_least(body, "regen_policy_id", 0)


static func _inventory_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["item_state"])):
		return false
	return CanonicalPayload.is_allowed(body["item_state"])


static func _path_agent_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["waypoints", "speed", "bounty"])):
		return false
	if not _xyz_array(body["waypoints"]):
		return false
	return _is_int_field(body, "speed") and _int_at_least(body, "bounty", 0)


static func _build_slot_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["whitelist", "occupant_id"])):
		return false
	if not _id_array(body["whitelist"]):
		return false
	return _int_at_least(body, "occupant_id", 0)


static func _tower_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["level", "attack_range", "cooldown_ticks", "target_priority"])):
		return false
	if not _int_at_least(body, "level", 1):
		return false
	if not _is_int_field(body, "attack_range"):
		return false
	if not _int_at_least(body, "cooldown_ticks", 0):
		return false
	var priority_raw: Variant = body["target_priority"]
	if typeof(priority_raw) != TYPE_STRING:
		return false
	var priority: String = priority_raw
	return SharedTowerTargetPriorities.contains(priority)


static func _replication_is_valid(body: Dictionary) -> bool:
	return _exactly(body, PackedStringArray(["policy_id"])) and _int_at_least(body, "policy_id", 0)


## 引用平台内置资产的不可变玩法版本。只校验形状与下界；`asset_id` 是否登记、
## 版本是否是当前版本由编译期的 `SharedGameplayAssetCatalog` 把关（ADR-0006 Q5），
## 因为 AuthoringWorld 允许存在草稿态的引用，而编译才是发布门禁。
static func _gameplay_asset_is_valid(body: Dictionary) -> bool:
	if not _exactly(body, PackedStringArray(["asset_id", "gameplay_version"])):
		return false
	return _int_at_least(body, "asset_id", 1) and _int_at_least(body, "gameplay_version", 1)


## 形状校验的实现在 `SharedCollisionShapeKinds`：`zone.shape` 与资产表的权威碰撞
## 必须用同一份 kind→字段对应关系（ADR-0006）。
static func _shape_is_valid(shape: Dictionary) -> bool:
	return SharedCollisionShapeKinds.shape_is_valid(shape)


static func _exactly(source: Dictionary, keys: PackedStringArray) -> bool:
	if source.size() != keys.size():
		return false
	for key: String in keys:
		if not source.has(key):
			return false
	return true


static func _all_ints(source: Dictionary) -> bool:
	var keys: Array = source.keys()
	for key: Variant in keys:
		if typeof(source[key]) != TYPE_INT:
			return false
	return true


static func _is_int_field(source: Dictionary, key: String) -> bool:
	if not source.has(key):
		return false
	return typeof(source[key]) == TYPE_INT


static func _int_at_least(source: Dictionary, key: String, minimum: int) -> bool:
	if not _is_int_field(source, key):
		return false
	var number: int = source[key]
	return number >= minimum


static func _xyz_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var point: Dictionary = item
		if not _exactly(point, PackedStringArray(["x", "y", "z"])):
			return false
		if not _all_ints(point):
			return false
	return true


static func _id_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	for item: Variant in items:
		if typeof(item) != TYPE_INT:
			return false
		var number: int = item
		if number < 1:
			return false
	return true


static func _string_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	for item: Variant in items:
		if typeof(item) != TYPE_STRING:
			return false
		var text: String = item
		if text.is_empty():
			return false
	return true
