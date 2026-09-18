class_name SharedSkyCatalog
extends RefCounted

## TRAPRUSH 天空目录：语义 `sky_id` → 贴图路径的唯一解析点。
##
## 三件必须先读的事：
##
## 1. **贴图路径不进 SimulationBundle**，只有语义 `sky_id` 进。依据是 ADR-0006
##    Q4 = A，与 `visual_asset_catalog.gd` 文件头那句「视觉不进 SimulationBundle，
##    换一次模型不产生新内容版本、不改 ContentHash」是同一条。所以以后换天空贴图、
##    改分辨率、改烘焙参数都**不会**让任何已发布内容失效，也不动 ContentHash；
## 2. **id 只增不减（append-only）**。编译期按本目录把关——
##    `TraprushTopologyCompiler` 认不出 `sky_id` 就整份拒绝发布——所以移除一个 id
##    会让引用它的旧内容**重编译失败**。要换掉一张天空，做法是改它那一行的路径，
##    不是把 id 拿掉；
## 3. `SKY_ID_MAX` 被 `tools/content-validator/src/gdscript_sync.ts` 镜像到 TS
##    （`sky_catalog.ts`），改它必须同步改那边，否则 `npm test` 会红。
##
## 三级门禁**有意不一致，不要合并**：
##
## | 环节 | 查本目录吗 | 未知 `sky_id` 的行为 |
## |---|---|---|
## | `SimulationBundle.from_dictionary`（解码；已发布内容也走这条） | 不查 | 接受任何 `>= 0` 的 int |
## | `TraprushTopologyCompiler.compile`（发布前编译） | 查 | 整份返回 `null` |
## | 客户端渲染 | 查 | 回退默认天空 |
##
## 解码不查目录的理由与 ADR-0006 §1.4 相同：已发布内容必须按它**发布时**的形状
## 裁决。天空是纯表现，认不出就回退，不该让一局开不起来。
##
## 放 `shared/` 的理由与 `PlaceholderSpec` / `SharedVisualAssetCatalog` 相同：
## 对局映射（`client/`）与 Preview 映射（`creator/`）必须读同一份，否则两边会
## 慢慢变成两片天。`simulation/` 不引用本文件，天空从不参与裁决。

## `environment` 组件缺席时按这一张渲染。
const DEFAULT_SKY_ID: int = 0
## 已登记的最大 id。加一张天空 = 往 `TEXTURE_PATHS` 追加一行并把这里 +1。
## 必须是字面量：`gdscript_sync.ts` 的 `parseIntConstant` 只认 `= <数字>`。
const SKY_ID_MAX: int = 1

## id 就是下标。追加即新增，删除即破坏旧内容——见文件头第 2 条。
## 两个 `.png` 由 M-Art 侧并行入库；缺图不是本目录的失败，见 `has_texture`。
const TEXTURE_PATHS: PackedStringArray = [
	"res://content/assets/sky/sky_pastel_ridge.png",
	"res://content/assets/sky/sky_lowpoly_mesa.png",
]

## 全景贴图预算的**代码侧唯一落点**。数值的所有者是 CD-11 §8.1「独立运行时贴图」
## 那一档，本常量只是它在代码里的那一份，冲突以 CD-11 为准。
##
## 它必须存在于某一处，是因为这一档**没有 CI 门禁**：`npm run asset-budget` 的
## `ASSET_EXTENSION` 就是 `.glb`，独立 `.png` 根本不在它的遍历里。替代保障是
## `PackageCheck._sky_textures_loadable` 与 GUT 断言，两者都从这里读。
##
## 高度不单列：全景必须是 2:1，比例由消费方按 `width == height * 2` 判，
## 多存一个会变成两个可以各自漂移的数字。
const MAX_TEXTURE_WIDTH: int = 1024


static func is_known(sky_id: int) -> bool:
	return sky_id >= 0 and sky_id < TEXTURE_PATHS.size()


## 未知 id 返回空串，让调用方回退默认天空：表现层从不因为缺一张图而拒绝开局
## （与 `SharedVisualAssetCatalog.try_instantiate` 的回退哲学一致）。
static func texture_path(sky_id: int) -> String:
	if not is_known(sky_id):
		return ""
	return TEXTURE_PATHS[sky_id]


## 贴图是否已经入库。写法照 `SharedVisualAssetCatalog.has_*`：资产入库与契约
## 是两条并行的活，测试允许「路径已锁、文件还没到」这个中间态。
static func has_texture(sky_id: int) -> bool:
	var path: String = texture_path(sky_id)
	if path.is_empty():
		return false
	return ResourceLoader.exists(path)


## 一张贴图是否满足 CD-11 §8.1 那一档。**纯函数，收 `Texture2D` 而不是路径**，
## 这样反例可以直接喂一张构造出来的 `ImageTexture`，不必往仓库里塞超预算的图、
## 也不必改这个文件再跑一遍引擎（改 `.gd` 做故障注入在 Windows 上会毁掉中文注释
## 的编码，2026-09-17 实测把 headless 进程挂死）。
##
## 判两件事：**2:1 比例**与**宽度上限**。比例是全景贴图的正确性前提——尺寸不对
## 的图照样能加载、能渲染，只是贴到球面上会歪，是典型的"存在但错"。
static func texture_meets_budget(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var width: int = texture.get_width()
	var height: int = texture.get_height()
	if height <= 0 or width != height * 2:
		return false
	return width <= MAX_TEXTURE_WIDTH


## 未知 id 回退默认天空。渲染路径永不拒绝开局（见文件头三级门禁表）。
static func resolve(sky_id: int) -> int:
	if is_known(sky_id):
		return sky_id
	return DEFAULT_SKY_ID


## 从一份组件袋读 `sky_id`。没有 `environment` 返回 -1，让调用方继续扫；
## 袋坏了或 id 未知则回退默认。本函数不引用 AuthoringWorld / SimulationBundle，
## 好让 `shared/` 不依赖 `creator/` 与 `ugc/`。
static func sky_id_from_components(components: Dictionary) -> int:
	if not components.has(SharedComponentNames.ENVIRONMENT):
		return -1
	return resolve(_sky_id_from_component(components[SharedComponentNames.ENVIRONMENT]))


## bundle 的 `environment` 袋：恰好一条用它的 `sky_id`，否则默认。
static func sky_id_from_bag(entries: Array) -> int:
	if entries.size() != 1:
		return DEFAULT_SKY_ID
	var raw: Variant = entries[0]
	if typeof(raw) != TYPE_DICTIONARY:
		return DEFAULT_SKY_ID
	var body: Dictionary = raw
	if typeof(body.get("sky_id", null)) != TYPE_INT:
		return DEFAULT_SKY_ID
	var sky_id: int = body["sky_id"]
	return resolve(sky_id)


static func _sky_id_from_component(raw: Variant) -> int:
	if typeof(raw) != TYPE_DICTIONARY:
		return DEFAULT_SKY_ID
	var body: Dictionary = raw
	if typeof(body.get("sky_id", null)) != TYPE_INT:
		return DEFAULT_SKY_ID
	var sky_id: int = body["sky_id"]
	return sky_id
