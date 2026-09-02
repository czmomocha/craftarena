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
## 能接的是**袋类型**，因为那是玩法语义而不是资产身份。一期接线：
##
## | 袋 / 组件 | 视觉 | 贴合 |
## |---|---|---|
## | `solids` | 地块 | `fit_tile_on_cell`（顶面对齐占位盒顶面） |
## | `pads` | 检查点垫 + 检查点门 | 垫走地块贴合；门走 `fit_prop_on_cell`（脚底对齐盒底） |
## | `finish` | 终点门 | 脚底对齐 |
## | `destructibles` | 箱子 | 脚底对齐 + 橙色 overlay |
## | `hazards` | 滚柱 | 脚底对齐 + 洋红 overlay |
## | `portals` | 仍是占位盒 | 传送门专用模型还没生成 |
##
## 箱与滚柱**保留 D4 危险色薄膜**（人类 2026-09-02 拍板）：换真模型不能把
## "会打你的"画成和地板一个色。薄膜走 `material_overlay`，不改共享 Mesh。
## 等内容能区分资产后再按 `asset_id` 解析，届时本文件加的是一张表，不改调用方。
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

## 检查点垫：薄台面，走地块贴合（顶面对齐），避免再出现扁板悬空。
const CHECKPOINT_PAD_SCENE_PATH: String = "res://content/assets/checkpoints/checkpoint_pad.glb"

## 检查点门：站立拱门，挂在同一块垫占用上，走脚底对齐。设计稿 1.6×2.0×0.4 m，
## 生成网格更矮——本刀不靠拉伸"修"，缺陷留在真机清单里。
const CHECKPOINT_GATE_SCENE_PATH: String = "res://content/assets/checkpoints/checkpoint_gate.glb"

## 终点门：站立拱门。设计稿 3 m 宽，水平缩进一格后仍可能比角色高，同样不拉伸。
const FINISH_GATE_SCENE_PATH: String = "res://content/assets/finish/finish_gate.glb"

## 可破坏箱。橙色 overlay 是 D4 可读性，不是模型自带色。
const CRATE_SCENE_PATH: String = "res://content/assets/crates/crate.glb"

## 周期滚柱。洋红 overlay 同上。生成网格可能略超一格，不压扁。
const HAZARD_ROLLER_SCENE_PATH: String = "res://content/assets/hazards/hazard_roller.glb"

## 模型自己的脚底在原点，权威胶囊原点在中心。下沉「柱高一半 + 半径」，脚底才
## 落在胶囊底面（重力落地后就是固体顶面）。数值从 PlaceholderSpec 注入，不另写。
## 不要沉到 1 米占位盒底：盒比胶囊高，重力把节点跟着胶囊沉下去之后，盒底
## 会陷入实心方块（C3 重力 + C4 实心块之后才看得见）。
const CHARACTER_FOOT_LIFT: Vector3 = Vector3(0.0, -PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M, 0.0)

const InstantiateGd := preload("res://src/shared/visual_asset_catalog_instantiate.gd")
const FitGd := preload("res://src/shared/visual_asset_catalog_fit.gd")

## 座位色薄膜的不透明度。模型自带灰白外壳，本席 / 远端如果只靠模型就分不出来，
## 而分色是 M3 已交付的可读性，不能因为换了视觉就退回去。半透明而不是纯色，
## 是为了让机器人自己的细节还看得见。数值与 Fit 协作者同源。
const SEAT_TINT_ALPHA: float = FitGd.SEAT_TINT_ALPHA


## 清空模板缓存。给测试用，也给"在编辑器里重新导入了 `.glb`"这种开发期情况。
static func clear_template_cache() -> void:
	InstantiateGd.clear_template_cache()


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
	return try_instantiate_fitted_tile_from(TERRAIN_TILE_SCENE_PATH)


static func try_instantiate_fitted_tile_from(path: String) -> Node3D:
	var visual: Node3D = try_instantiate(path)
	if visual == null:
		return null
	if not fit_tile_on_cell(visual):
		visual.free()
		return null
	return visual


## 站立物：水平缩进一格，脚底落到占位盒底面。失败返回 `null`。
static func try_instantiate_fitted_prop(path: String) -> Node3D:
	var visual: Node3D = try_instantiate(path)
	if visual == null:
		return null
	if not fit_prop_on_cell(visual):
		visual.free()
		return null
	return visual


## 一块检查点占用上的垫 + 门。两者都失败才返回 `null`；只做成一个也算接上。
static func try_instantiate_checkpoint(pad_path: String, gate_path: String) -> Node3D:
	var pad: Node3D = try_instantiate_fitted_tile_from(pad_path)
	var gate: Node3D = try_instantiate_fitted_prop(gate_path)
	if pad == null and gate == null:
		return null
	var root: Node3D = Node3D.new()
	if pad != null:
		pad.name = "pad"
		root.add_child(pad)
	if gate != null:
		gate.name = "gate"
		root.add_child(gate)
	return root


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
## 多网格或带 skin 的资产**回退到 instantiate**。实现在 Instantiate / Fit 协作者上。
static func try_instantiate(path: String) -> Node3D:
	return InstantiateGd.try_instantiate(path)


static func tint(root: Node, color: Color) -> int:
	return FitGd.tint(root, color)


static func seat_tint(color: Color) -> StandardMaterial3D:
	return FitGd.seat_tint(color)


static func fit_tile_on_cell(visual: Node3D) -> bool:
	return FitGd.fit_tile_on_cell(visual)


static func fit_prop_on_cell(visual: Node3D) -> bool:
	return FitGd.fit_prop_on_cell(visual)


static func local_bounds(root: Node3D) -> AABB:
	return FitGd.local_bounds(root)
