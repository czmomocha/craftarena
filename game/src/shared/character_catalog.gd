class_name SharedCharacterCatalog
extends RefCounted

## 系统角色目录：语义 id → 视觉路径的唯一解析点。
##
## 三件必须先读的事：
##
## 1. **角色视觉不进 SimulationBundle / 协议帧**。依据是 ADR-0006 Q4 = A，
##    与 `visual_asset_catalog.gd` 文件头那句「视觉不进 SimulationBundle，
##    换一次模型不产生新内容版本、不改 ContentHash」是同一条。本机选哪一个
##    角色只改表现，不改权威胶囊、不改快照、不改回放；
## 2. **id 只增不减（append-only）**。已写入 `user://character_select.json`
##    的 id 必须永远能 `resolve`。要换掉一个角色，做法是改它那一行的路径，
##    不是把 id 拿掉——拿掉会让旧存档掉进默认角色，看起来像「我的选择丢了」；
## 3. **默认就是当前已接线的猫**。`DEFAULT_ID` 的路径必须等于
##    `SharedVisualAssetCatalog.CHARACTER_SCENE_PATH`，由测试钉住。没打开过
##    选择界面的玩家，画面一个三角面都不能变。
##
## 本刀登记的是仓库里**已经有许可证归档**的三份角色网格（猫 / 奔跑者 /
## 机器人）。Kenney Cube Pets 其余 23 只仍受 D-F9 未拍约束，本文件不加。
## 奔跑者与机器人是静态网格、没有 `AnimationPlayer`：`PlayAnimVisual` 会按
## 既有契约降级为静止，不是本目录的缺陷。
##
## 放 `shared/` 的理由与 `PlaceholderSpec` / `SharedSkyCatalog` 相同：
## 对局映射（`client/`）与 Preview 映射（`creator/`）必须读同一份。
## `simulation/` 不引用本文件，角色网格从来不是碰撞体。

const ID_CAT: String = "cat"
const ID_RUNNER: String = "runner"
const ID_ROBOT: String = "robot"
const DEFAULT_ID: String = ID_CAT

## 显示名键前缀。完整键是 `NAME_KEY_PREFIX + id`，加角色 = 追加 id 并在
## locale 表加一行，不必改本文件的键常量。
const NAME_KEY_PREFIX: String = "craft_arena.char.name_"

## id 就是下标。追加即新增，删除即让旧存档掉进默认——见文件头第 2 条。
const IDS: PackedStringArray = [ID_CAT, ID_RUNNER, ID_ROBOT]

const SCENE_PATHS: PackedStringArray = [
	"res://content/assets/characters/animal-cat.glb",
	"res://content/assets/characters/char_runner_base.glb",
	"res://content/assets/characters/robot_placeholder.glb",
]


static func is_known(id: String) -> bool:
	return IDS.find(id) >= 0


## 未知 / 空 id 回退默认。选择界面与存档加载都走这里，开局不因一份坏 JSON
## 而变成没有角色。
static func resolve(id: String) -> String:
	if is_known(id):
		return id
	return DEFAULT_ID


static func index_of(id: String) -> int:
	return IDS.find(resolve(id))


static func scene_path(id: String) -> String:
	var index: int = index_of(id)
	if index < 0 or index >= SCENE_PATHS.size():
		return SCENE_PATHS[0]
	return SCENE_PATHS[index]


static func name_key(id: String) -> String:
	return "%s%s" % [NAME_KEY_PREFIX, resolve(id)]


## 资产是否已经入库。写法照 `SharedVisualAssetCatalog.has_*`：目录与文件
## 是两条并行的活，测试允许「id 已锁、文件还没到」这个中间态。
static func has_scene(id: String) -> bool:
	var path: String = scene_path(id)
	if path.is_empty():
		return false
	return ResourceLoader.exists(path)


static func all_ids() -> PackedStringArray:
	return IDS
