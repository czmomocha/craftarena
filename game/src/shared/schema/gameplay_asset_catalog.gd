class_name SharedGameplayAssetCatalog
extends RefCounted

## 平台内置 GameplayAsset 清单。契约见 [ADR-0006]，承诺的所有者是 CD-31 §5：
## 视觉与音效走 `latest` 自动更新；**权威碰撞、占地与挂点属不可变
## `GameplayAssetVersion`**。
##
## 为什么存在（ADR-0006 §1.3）：在此之前，创作者在 `zone.shape` 里声明的权威
## 碰撞会被 `TraprushTopologyCompiler` 静默丢弃，`TraprushTopologyLoader` 一律用
## `cell / 2` 当半长。字段通过了校验却不影响任何裁决，比不校验更坏。
##
## 三条边界，按 ADR-0006 §6 的拍板（Q1=B / Q2=A / Q3=A / Q4=A / Q5=A / Q6=A）：
##
## 1. **创作者不能自填尺寸**（Q5）。本目录是编译期白名单，`gameplay_asset`
##    组件只能引用这里的 `asset_id`，且 `gameplay_version` 必须等于当前版本。
##    理由不只是宪法第三条：`SimulationWorld._sweep_step_count` 用半径当扫掠
##    步长，半径越小采样次数越多且**当前没有上限**（宪法第十七条缺口）。允许
##    内容自填小半径等于把它变成 CPU 攻击面。
## 2. **权威几何写进 bundle，不是只留 id**（Q1）。本目录只在编译期被读；
##    已发布 bundle 自带 `assets` 袋，所以旧内容与旧回放不依赖"当时程序里那张
##    表长什么样"。改了本目录不会追溯改变已发布内容。
## 3. **改碰撞必须升版本**（CD-31 §5）。`has_version` 要求精确等于当前版本，
##    所以本目录一改几何、旧内容就**重编译失败**，必须走新内容版本，而不是
##    悄悄换掉裁决形状。`test_gameplay_asset_contract.gd` 用金标断言把
##    (asset_id, gameplay_version, 几何) 钉住，防止有人改几何忘了升版本。
##
## 占地（Q2）：一期由权威碰撞的 AABB 在格网上的投影派生，**不落字段**。等
## BASTION 的 `build_slot` 需要"占几格"时再独立，届时须先解冻 M6/M7。
## 挂点（Q3）：只留字段位，一期允许为空，仿真不消费。
## 视觉网格（Q4）：**不进本目录、也不进 bundle**。客户端按 `asset_id` 自行解析
## 当前 `latest`，所以改视觉不产生新内容版本。占位视觉仍在 `PlaceholderSpec`。
## 导航：一期不含（无导航网格、无寻路），解冻 BASTION 时重开。
##
## 本文件是**规格数据 + 校验**，不是仿真逻辑；`simulation/` 不引用它。

## 占满一格的通用占位盒。v1 内容迁移后全部引用它（ADR-0006 Q6）。
##
## 它的半长是 `cell / 2`，即**相对格**而不是绝对米数——这样任何 `cell` 下的
## v1 内容迁移后占用都逐字节不变。这也是纠偏冻结清单里 `cell / 2` 的唯一定义
## 点：此前散在 `TraprushTopologyLoader`，现在只在这里。
const LATTICE_CELL_ID: int = 1
const LATTICE_CELL_VERSION: int = 1

## 已知资产 id → 当前不可变版本。新增资产在这里登记；改已有资产的几何必须
## 同时把版本 +1（否则金标断言会失败）。
const CURRENT_VERSIONS: Dictionary[int, int] = {
	LATTICE_CELL_ID: LATTICE_CELL_VERSION,
}


static func has_asset(asset_id: int) -> bool:
	return CURRENT_VERSIONS.has(asset_id)


## 当前不可变版本；未知资产返回 0（0 不是合法版本）。
static func current_version(asset_id: int) -> int:
	if not CURRENT_VERSIONS.has(asset_id):
		return 0
	return CURRENT_VERSIONS[asset_id]


## 编译期唯一准入判断：id 已登记，且版本恰好是当前版本。
static func has_version(asset_id: int, gameplay_version: int) -> bool:
	if gameplay_version < 1:
		return false
	return current_version(asset_id) == gameplay_version


## 该资产在给定 `cell` 下的权威碰撞袋；不合法组合返回空字典。
static func try_collision(asset_id: int, gameplay_version: int, cell: int) -> Dictionary:
	if cell < 1:
		return {}
	if not has_version(asset_id, gameplay_version):
		return {}
	match asset_id:
		LATTICE_CELL_ID:
			var half: int = cell / 2
			return {
				"kind": SharedCollisionShapeKinds.BOX,
				"hx": half,
				"hy": half,
				"hz": half,
			}
		_:
			return {}


## 挂点表（Q3：一期全部为空，仿真不消费）。不合法组合返回空数组。
static func try_attach_points(asset_id: int, gameplay_version: int) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	if not has_version(asset_id, gameplay_version):
		return points
	return points


## 编译期写进 bundle `assets` 袋的那一条；不合法组合返回空字典。
static func try_entry(asset_id: int, gameplay_version: int, cell: int) -> Dictionary:
	var collision: Dictionary = try_collision(asset_id, gameplay_version, cell)
	if collision.is_empty():
		return {}
	var points: Array[Dictionary] = try_attach_points(asset_id, gameplay_version)
	var raw_points: Array = []
	for point: Dictionary in points:
		raw_points.append(point.duplicate(true))
	return {
		"asset_id": asset_id,
		"gameplay_version": gameplay_version,
		"collision": collision,
		"attach_points": raw_points,
	}


## `assets` 袋一条的形状校验。已发布 bundle 自带几何，所以这里**不查目录**：
## 旧内容引用的旧几何必须仍能解码，否则回放不可自证（ADR-0006 §1.4）。
static func entry_is_valid(entry: Dictionary) -> bool:
	if entry.size() != 4:
		return false
	if not _int_at_least(entry, "asset_id", 1):
		return false
	if not _int_at_least(entry, "gameplay_version", 1):
		return false
	if not entry.has("collision") or typeof(entry["collision"]) != TYPE_DICTIONARY:
		return false
	var collision: Dictionary = entry["collision"]
	if not SharedCollisionShapeKinds.shape_is_valid(collision):
		return false
	if not entry.has("attach_points") or typeof(entry["attach_points"]) != TYPE_ARRAY:
		return false
	var points: Array = entry["attach_points"]
	var seen: Dictionary[String, bool] = {}
	for item: Variant in points:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var point: Dictionary = item
		if point.size() != 4:
			return false
		if not point.has("name") or typeof(point["name"]) != TYPE_STRING:
			return false
		var point_name: String = point["name"]
		if point_name.is_empty():
			return false
		if seen.has(point_name):
			return false
		seen[point_name] = true
		if not _is_int_field(point, "dx"):
			return false
		if not _is_int_field(point, "dy"):
			return false
		if not _is_int_field(point, "dz"):
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
