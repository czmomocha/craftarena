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
##
## 单网格资产的实例化走**共享 Mesh**，不走 `PackedScene.instantiate()`
## （见 `try_instantiate`）。共享的是 `Mesh` 资源，所以**不要改它的 surface
## material**；per-instance 的颜色一律用 `material_overlay` / `material_override`。

## 角色占位视觉。TRELLIS / 混元 3D 类生成产物，按 CD-51 §5.1 烘焙到预算内后入库。
## 这是**占位美术**：比例、朝向轴与配色都没有经过美术定稿，只用来把
## DCC → GLB → LFS → 导入 → 表现层这条链路跑通。
##
## 换过一次模型（2026-09-01）：`robot_placeholder.glb`（0.74 × 1.03 × 0.61 m）
## 换成同批混元 3D 生成的 `char_runner_base.glb`（0.7492 × 1.1340 × 0.4174 m）。
## 旧文件**留着不删**，它是这条链路上第一个跑通的样本，也是共享 Mesh 快路径
## 第一个真实用例；而且两者都不被任何测试写死尺寸，留着不产生维护成本。
## 换它不产生新内容版本、不改 ContentHash、不动任何权威碰撞 —— 这正是
## ADR-0006 Q4 = A（视觉不进 bundle、客户端按 `latest` 解析）要的效果。
const CHARACTER_SCENE_PATH: String = "res://content/assets/characters/char_runner_base.glb"

## 地块占位视觉，画在**始终固体**占用上（官方赛道的路面、立足面与上层楼板都在
## `solids` 袋里）。周期机关与可破坏箱**不用**它：洋红危险色与橙色箱是 D4 已定
## 的可读性，把它们也铺成地板会让"能踩"和"会打你"看起来一样。
##
## 换过一次（2026-09-01）：`floor_tile.glb`（扁板 1.842 × 0.338 × 1.843 m）
## 换成 `block_static.glb`（正方块 0.768 × 0.769 × 0.768 m）。
##
## **换它的理由是一个实测出来的缺陷，不是审美**：贴合规则让缩放后的**顶面**落在
## 占位盒顶面，而缩放是等比、系数由水平最长边推出（`fit_tile_on_cell`）。扁板的
## 厚宽比只有 0.18，贴合后就是一片 0.184 格厚的板**悬在格子顶部**，底下 0.816 格
## 是空的。占位盒本体已经 `layers = 0` 退出渲染，所以那片板就是玩家看到的全部——
## 平路上不明显，官方赛道的落差处（台阶侧立面）一看就是悬空的纸。
## 正方块的厚宽比是 1.001，贴合后厚度 0.999 格、悬空 0.000 格，整格填满。
##
## 注意这个修复**没有改贴合规则**：顶面仍然对齐占位盒顶面（那是"踩得到的那个
## 平面"，ADR-0006 Q4 = A 要求视觉不读裁决数据，所以对齐占位盒而非权威 AABB）。
## 变的是资产自己的比例，规则一个字没动——这也正是它当初不写死 0.5427 的原因。
##
## 旧文件**留着不删**，理由与角色那条一致：它是这条链路上第一个跑通的样本，
## 且没有被任何测试写死尺寸。真机上如果正方块不如扁板好看，回退就是改回这一行。
const TERRAIN_TILE_SCENE_PATH: String = "res://content/assets/terrain/block_static.glb"

## 模型自己的脚底在原点，而占位盒是以权威位置为**中心**的 1 米立方体。下沉半个
## 盒高，模型才和它替换掉的那个盒子站在同一个平面上，不会浮空半米。
const CHARACTER_FOOT_LIFT: Vector3 = Vector3(0.0, -PlaceholderSpec.METERS_PER_CELL / 2.0, 0.0)

## 座位色薄膜的不透明度。模型自带灰白外壳，本席 / 远端如果只靠模型就分不出来，
## 而分色是 M3 已交付的可读性，不能因为换了视觉就退回去。半透明而不是纯色，
## 是为了让机器人自己的细节还看得见。
const SEAT_TINT_ALPHA: float = 0.42

## 贴合计算的下限。零尺寸或退化 AABB 算不出缩放，直接放弃贴合而不是除以 0。
const _MIN_EXTENT: float = 0.0001

## 扁平化模板缓存：资产路径 → `{ "mesh": Mesh, "transform": Transform3D }`，
## 或空字典表示"这个资产不能扁平化，走 instantiate"。见 `_template_for`。
static var _templates: Dictionary = {}


## 清空模板缓存。给测试用，也给"在编辑器里重新导入了 `.glb`"这种开发期情况：
## 缓存握着的是旧 `Mesh` 资源引用，重新导入产生的是新资源，缓存不会自己失效。
## 运行时资产不变，所以生产路径不需要调它。
static func clear_template_cache() -> void:
	_templates = {}


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
##
## 单网格资产走**共享 Mesh** 快路径，不走 `PackedScene.instantiate()`。这不是
## 微优化：开发机实测实例化 36 个地砖 **55.9 ms**，而把同一份 `Mesh` 挂到 36 个
## 新 `MeshInstance3D` 上是 **0.099 ms**（564×）。那 55.9 ms 此前直接落在两个
## 可感知的地方——挂课程时 `MatchSolidMap.apply_bundle` 一次 64.6 ms，以及
## Preview 每帧 `AuthoringPreviewMap.rebuild` 74.3 ms（同一份世界不带 `.glb`
## 只要 7.6 ms）。
##
## 多网格或带 skin 的资产**回退到 instantiate**，因为共享一份 `Mesh` 表达不了
## 多个 surface 各自的层级与蒙皮。今天两个资产都是单网格无 skin，但下一个未必。
static func try_instantiate(path: String) -> Node3D:
	if path.is_empty():
		return null
	var template: Dictionary = _template_for(path)
	if not template.is_empty():
		return _spawn_from_template(template)
	return _instantiate_scene(path)


## 原始路径：整棵子树照搬。多网格 / 带 skin 的资产只能走这条。
static func _instantiate_scene(path: String) -> Node3D:
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


## 按模板造一个"根 Node3D + 一个子 MeshInstance3D"的两层结构。
##
## **故意复刻原有层级，而不是直接返回那个 MeshInstance3D。** 调用方与
## `local_bounds` / `tint` 都假设"根是容器、网格在子节点"：`_bounds` 对根节点
## 跳过自身 transform（`is_root`），若把带非 identity transform 的网格当根返回，
## AABB 就会算漏那一层，`fit_tile_on_cell` 随之贴错。多一个 Node3D 是纳秒级
## 代价，换掉一整类"今天恰好对"的隐患。
static func _spawn_from_template(template: Dictionary) -> Node3D:
	var mesh: Mesh = template["mesh"]
	var local: Transform3D = template["transform"]
	var root: Node3D = Node3D.new()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = local
	root.add_child(instance)
	return root


## 惰性求值一次，之后常驻。空字典 = 已经判过、不能扁平化，不会每次重试。
static func _template_for(path: String) -> Dictionary:
	if _templates.has(path):
		return _templates[path]
	var built: Dictionary = _build_template(path)
	_templates[path] = built
	return built


## 只有"恰好一个 MeshInstance3D、有网格、无 skin、无 skeleton 绑定"的资产能扁平化。
##
## 共享的是 `Mesh` 资源本身，所以**谁都不能改它的 surface material**——那会串到
## 所有实例上。座位色走 `material_overlay`（`MeshInstance3D` 自己的属性，不碰
## `Mesh`），固体不染色，所以今天成立；以后要给单个实例改材质，用
## `material_override` / `material_overlay`，不要动 `mesh`。
static func _build_template(path: String) -> Dictionary:
	var probe: Node3D = _instantiate_scene(path)
	if probe == null:
		return {}
	var found: Array[Dictionary] = []
	_collect_meshes(probe, Transform3D.IDENTITY, true, found)
	var template: Dictionary = {}
	if found.size() == 1:
		var only: Dictionary = found[0]
		template = {
			"mesh": only["mesh"],
			"transform": only["transform"],
		}
	probe.free()
	return template


## 收集子树里每个带网格的 MeshInstance3D 及其相对根的累积 transform。
## 带 skin 或 skeleton 的直接让整个资产判为不可扁平化（返回一个哨兵项，
## 使 size() != 1），因为蒙皮网格离开原层级就不再是同一个东西。
static func _collect_meshes(
	node: Node,
	accumulated: Transform3D,
	is_root: bool,
	into: Array[Dictionary]
) -> void:
	var here: Transform3D = accumulated
	var spatial: Node3D = node as Node3D
	if spatial != null and not is_root:
		here = accumulated * spatial.transform
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null and instance.mesh != null:
		if instance.skin != null or instance.skeleton != NodePath(""):
			# 两个哨兵项，保证 size() != 1 ⇒ 回退 instantiate
			into.append({})
			into.append({})
			return
		into.append({
			"mesh": instance.mesh,
			"transform": here,
		})
	for child: Node in node.get_children():
		_collect_meshes(child, here, false, into)


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
