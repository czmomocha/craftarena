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
## 引用它，官方赛道的路面地板也是。把视觉按 `asset_id` 接上去，等于让地板、
## 检查点垫和箱子共用同一个模型——那不是"资产有了视觉"，是"内容还没有区分
## 资产"。等内容能区分资产后另开一章，届时本文件加的是一张 `asset_id → 视觉`
## 表，不需要改调用方。
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

## 模型自己的脚底在原点，而占位盒是以权威位置为**中心**的 1 米立方体。下沉半个
## 盒高，模型才和它替换掉的那个盒子站在同一个平面上，不会浮空半米。
const CHARACTER_FOOT_LIFT: Vector3 = Vector3(0.0, -PlaceholderSpec.METERS_PER_CELL / 2.0, 0.0)

## 座位色薄膜的不透明度。模型自带灰白外壳，本席 / 远端如果只靠模型就分不出来，
## 而分色是 M3 已交付的可读性，不能因为换了视觉就退回去。半透明而不是纯色，
## 是为了让机器人自己的细节还看得见。
const SEAT_TINT_ALPHA: float = 0.42


static func has_character() -> bool:
	return ResourceLoader.exists(CHARACTER_SCENE_PATH)


static func try_instantiate_character() -> Node3D:
	return try_instantiate(CHARACTER_SCENE_PATH)


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


static func _apply_overlay(node: Node, overlay: StandardMaterial3D) -> int:
	var count: int = 0
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.material_overlay = overlay
		count += 1
	for child: Node in node.get_children():
		count += _apply_overlay(child, overlay)
	return count
