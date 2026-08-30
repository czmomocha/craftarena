class_name SharedVisualAssetCatalog
extends RefCounted

## 视觉资产解析。ADR-0006 Q4 = A：**视觉不进 SimulationBundle**，客户端自己按
## 当前 `latest` 解析，所以换一次模型不产生新内容版本、不改 ContentHash。
##
## 与 `SharedGameplayAssetCatalog` 的分工是这一章的全部意义：
##
## | | 权威碰撞 / 占地 / 挂点 | 视觉网格 |
## |---|---|---|
## | 所有者 | `SharedGameplayAssetCatalog` + 已发布 bundle 的 `assets` 袋 | 本文件 |
## | 版本 | 不可变 `GameplayAssetVersion`，改了旧内容重编译失败 | `latest`，改了不影响任何已发布内容 |
## | 谁消费 | 编译期与加载期，进裁决与回放 | 只有表现层 |
##
## 在此之前二者是同一个 1 米占位盒，所以 ADR-0006 §7 只能声明"结构已分离、
## 数值仍相等"。本文件让它**数值上**也分开：角色视觉是一个 0.74 × 1.03 × 0.61 m
## 的网格，权威胶囊仍是 `PlaceholderSpec.CHARACTER_RADIUS / HEIGHT`（0.125 格），
## 占位盒仍是 1 米。三者互不相等且可独立改动。
##
## **本文件不解析 GameplayAsset 的 `asset_id`**，这是有意的，不是遗漏：一期唯一
## 内置资产是"占满一格"，7 类袋（垫 / 门 / 终点 / 箱 / 机关 / 固体 / 拾取）全都
## 引用它。按 `asset_id` 取视觉等于让终点、检查点垫和箱子共用同一个模型——那不是
## "资产有了视觉"，是"内容还没有区分资产"。
##
## 能接的是**袋类型**，因为那是玩法语义而不是资产身份：`solids` 袋就是"踩得到的
## 固体"，所以它铺地块；`hazards`（洋红）与 `destructibles`（橙）**不铺**，D4 已把
## 危险色定成可读性的一部分，把会打你的东西画成地板是反向的。等内容能区分资产后
## 再按 `asset_id` 解析，届时本文件加的是一张表，不需要改调用方。
##
## 放 `shared/` 的理由与 `PlaceholderSpec` 相同：`client` 的对局映射与 `creator`
## 的 Preview 映射必须读同一份，否则两边慢慢变成两套角色。`simulation/` 不引用
## 本文件，视觉网格从来不是碰撞体。
##
## 资产入库规范（格式、目录、预算、烘焙）的所有者是 [CD-51 §5.1]。

## 角色占位视觉。TRELLIS / 混元 3D 类生成产物，按 CD-51 §5.1 烘焙到预算内后入库。
## 这是**占位美术**：比例、朝向轴与配色都没有经过美术定稿，只用来把
## DCC → GLB → LFS → 导入 → 表现层这条链路跑通。
const CHARACTER_SCENE_PATH: String = "res://content/assets/characters/robot_placeholder.glb"

## 地块占位视觉，画在**始终固体**占用上（官方赛道的路面、立足面与上层楼板都在
## `solids` 袋里）。周期机关与可破坏箱**不用**它：洋红危险色与橙色箱是 D4 已定
## 的可读性，把它们也铺成地板会让"能踩"和"会打你"看起来一样。
const TERRAIN_TILE_SCENE_PATH: String = "res://content/assets/terrain/floor_tile.glb"

## 模型自己的脚底在原点，而占位盒是以权威位置为**中心**的 1 米立方体。下沉半个
## 盒高，模型才和它替换掉的那个盒子站在同一个平面上，不会浮空半米。
const CHARACTER_FOOT_LIFT: Vector3 = Vector3(0.0, -PlaceholderSpec.METERS_PER_CELL / 2.0, 0.0)

## 座位色薄膜的不透明度。模型自带灰白外壳，本席 / 远端如果只靠模型就分不出来，
## 而分色是 M3 已交付的可读性，不能因为换了视觉就退回去。半透明而不是纯色，
## 是为了让机器人自己的细节还看得见。
const SEAT_TINT_ALPHA: float = 0.42

## 贴合计算的下限。零尺寸或退化 AABB 算不出缩放，直接放弃贴合而不是除以 0。
const _MIN_EXTENT: float = 0.0001


static func has_character() -> bool:
	return ResourceLoader.exists(CHARACTER_SCENE_PATH)


static func try_instantiate_character() -> Node3D:
	return try_instantiate(CHARACTER_SCENE_PATH)


static func has_terrain_tile() -> bool:
	return ResourceLoader.exists(TERRAIN_TILE_SCENE_PATH)


static func try_instantiate_terrain_tile() -> Node3D:
	return try_instantiate(TERRAIN_TILE_SCENE_PATH)


## 实例化并按 `fit_tile_on_cell` 贴合，失败返回 `null`，让调用方回退占位盒。
static func try_instantiate_fitted_tile() -> Node3D:
	var visual: Node3D = try_instantiate_terrain_tile()
	if visual == null:
		return null
	if not fit_tile_on_cell(visual):
		visual.free()
		return null
	return visual


## 解析失败一律返回 `null`，让调用方回退到占位盒。缺资产、导入产物没生成、
## 导入成了别的类型都算失败：表现层宁可显示一个盒子，也不该因为美术没到位
## 就整个大厅不出人。
static func try_instantiate(path: String) -> Node3D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource == null:
		return null
	var packed: PackedScene = resource as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		return null
	var node: Node3D = instance as Node3D
	if node == null:
		instance.free()
		return null
	return node


## 给整棵子树套一层座位色薄膜，返回套上的实例数。`material_overlay` 不改模型
## 自己的材质，所以同一份导入资源可以同时给多个席位用不同颜色。
static func tint(root: Node, color: Color) -> int:
	if root == null:
		return 0
	var overlay: StandardMaterial3D = seat_tint(color)
	return _apply_overlay(root, overlay)


static func seat_tint(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, SEAT_TINT_ALPHA)
	return material


## 把地块视觉贴到一个格子上：**等比**缩到水平最长边恰好一格，水平居中，
## 并让缩放后的**顶面**落在占位盒顶面（也就是玩家踩得到的那个平面）。
##
## 缩放系数从模型自己的 AABB 算，**不写死**。理由是变更成本：这块地砖实测
## 1.84 m 见方，约两格；下一块可能是 1.0 或 3.7。写死一个 0.5427 只会让换资产
## 时出现"看起来对了一半"的重叠，而重叠在铺成一条路之后才看得出来。
##
## 为什么等比而不是只压水平：只缩 x/z 会把 0.34 m 的板厚留在原尺寸，砖面比例
## 被压扁；等比保住模型自己的厚薄关系。
##
## 为什么对齐**占位盒**而不是权威 AABB：视觉不该读裁决数据（ADR-0006 Q4 = A，
## 视觉不进 bundle）。权威半长的真正来源是已发布 bundle 的 `assets` 袋，那是
## 加载期的事；表现层只需要"看起来站在格子上"。今天两者数值相同（唯一内置资产
## 就是占满一格），但耦合方向必须保持单向。
##
## 与角色的差别是有意的：角色**不缩放**（1.03 m 已经接近一格，放大到一格宽会
## 变成 1.39 m 高的巨人），只把脚底沉到盒底，见 `CHARACTER_FOOT_LIFT`。所以这里
## 没有做成一个"通用贴合"函数——两条规则的锚点和缩放语义都不同，硬合成一个
## 抽象只会让下一个人猜错默认行为。
static func fit_tile_on_cell(visual: Node3D) -> bool:
	if visual == null:
		return false
	var bounds: AABB = local_bounds(visual)
	var widest: float = maxf(bounds.size.x, bounds.size.z)
	if widest < _MIN_EXTENT:
		return false
	var factor: float = PlaceholderSpec.METERS_PER_CELL / widest
	visual.scale = Vector3(factor, factor, factor)
	var scaled: AABB = AABB(bounds.position * factor, bounds.size * factor)
	var top: float = scaled.position.y + scaled.size.y
	var centre_x: float = scaled.position.x + scaled.size.x / 2.0
	var centre_z: float = scaled.position.z + scaled.size.z / 2.0
	visual.position = Vector3(
		-centre_x,
		PlaceholderSpec.METERS_PER_CELL / 2.0 - top,
		-centre_z
	)
	return true


## 整棵子树在 `root` 局部空间里的 AABB。逐级累乘子节点 transform，因为导入的
## GLB 未必是"根下一个单位变换的 Mesh"——今天这两个资产是，下一个未必是。
## 没有任何网格时返回零 AABB，调用方据 `_MIN_EXTENT` 判为贴合失败。
static func local_bounds(root: Node3D) -> AABB:
	if root == null:
		return AABB()
	return _bounds(root, Transform3D.IDENTITY, true)


static func _bounds(node: Node, accumulated: Transform3D, is_root: bool) -> AABB:
	var here: Transform3D = accumulated
	var spatial: Node3D = node as Node3D
	if spatial != null and not is_root:
		here = accumulated * spatial.transform
	var result: AABB = AABB()
	var seen: bool = false
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null and instance.mesh != null:
		result = here * instance.get_aabb()
		seen = true
	for child: Node in node.get_children():
		var child_bounds: AABB = _bounds(child, here, false)
		if child_bounds.size == Vector3.ZERO:
			continue
		if not seen:
			result = child_bounds
			seen = true
			continue
		result = result.merge(child_bounds)
	return result


static func _apply_overlay(node: Node, overlay: StandardMaterial3D) -> int:
	var count: int = 0
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.material_overlay = overlay
		count += 1
	for child: Node in node.get_children():
		count += _apply_overlay(child, overlay)
	return count
