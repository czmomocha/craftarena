class_name PlaceholderSpec
extends RefCounted

## D4 美术规格与占位表现值的单一配置源。
##
## 存在的理由是变更成本，不是复用。同一个 1 米盒、同一组相机/灯光偏移与十几个
## 色值原先抄在 8 套对局表现映射、Preview 映射与两条壳里；纠偏方案
## [§5.1 冻结令](docs/plans/course-correction-2026-08.md) 要求这些值改为
## 「从单一配置源注入，不再散落 const」，好让 D4 拍板后只改一处。漏改一处不会
## 报错——只会让 Preview 里看到的赛道和对局里看到的不是同一件事。
##
## 这里是**规格数据，不是仿真逻辑**：`simulation/` 不引用本文件，权威占用仍由
## `SimulationWorld` 的 Q48.16 胶囊与静态 AABB 决定，视觉盒从来不是碰撞盒。
## 放在 `shared/` 是因为 `client` 与 `creator` 两条壳要读同一份，而
## `creator` → `client` 方向今天没有依赖，不应为一份色板新建一条。
##
## D4 已拍板且已生效：1 格 = 1 表现米；角色高 0.125 格 / 半径 0.125 格；
## TRAPRUSH 危险色 = 洋红；相机斜 45°（C4 第 6 章接线）；UI 基准 1920×1080
## （C4 第 6 章接线，见 `UI_BASE_SIZE`）。
##
## D4 已拍板但仍未接线的**只剩字体**：思源黑体 / Noto Sans SC 子集化入包。
## 它不住在本文件——字体是新增第三方资产与许可证（宪法第十八条人类门禁），
## 且子集范围会决定公开未过滤昵称会不会变成豆腐块。本地化键已由 C4 第 12 章
## 落到 `UiCopy` + `content/locale/craft_arena.csv`；字体仍未入包。
##
## D4 那一行里**没被回答**的是「安全区」（表头是「UI 分辨率基准 + 安全区」，
## 人类只答了 1920×1080）。今天不阻塞：一期没有移动端导出，没有刘海与手势条
## 要避让。等 D7 的触控 UI 立项时必须回来补答，不得由 AI 自选。
##
## 权威碰撞与视觉网格的**分离**不在本文件：那要等 `GameplayAsset` 契约
## （纠偏方案 C4 第 2–4 章）。今天二者仍靠 1 格 = 1 米隐式对齐。
##
## `MOVE_STEP` 仍是表现占位步长，不是产品速度。`INTERP_STEP` 已由人类
## 2026-09-02 升为锁定值（E3：近端样本未证伪现桩，不改数字），见
## [CD-43 §4](Confirmed-docs/40-technical/43-networking-and-replay.md)。

# 格与米（D4：1 格 = 1 表现米，维持）

## 权威格边长（Q48.16）。Authoring 网格默认 cell 与之相同。
const CELL: int = Fixed.SCALE
## 一格对应的表现米数。视觉占位盒由它推导，不再各自写 1.0。
const METERS_PER_CELL: float = 1.0
## 每个有 transform 的实体画一个这么大的占位盒。不是碰撞盒。
const BOX_SIZE: Vector3 = Vector3(METERS_PER_CELL, METERS_PER_CELL, METERS_PER_CELL)

# 角色与出生（D4：高 0.125 格 / 半径 0.125 格，维持）

## 权威胶囊半径与高（Q48.16）。改这两个值会连带改赛道布局、Shove 邻域、
## UseItem reach、出界半宽与全部占用相交断言，所以只留这一份。
const CHARACTER_RADIUS: int = Fixed.SCALE / 8
const CHARACTER_HEIGHT: int = Fixed.SCALE / 8
## 胶囊底面相对中心的表现米数：柱高一半 + 半径。公式与
## `StaticAabb._segment_to_range_gap`（`y ± cylinder_height/2`）再加 `radius`
## 半球一致。角色视觉脚底对齐这个偏移，不要对齐 1 米占位盒底——盒比胶囊高，
## 重力把节点中心拉到固体顶面上方这么多之后，盒底会陷入顶面。
const CHARACTER_CAPSULE_BOTTOM_M: float = (
	float(CHARACTER_HEIGHT / 2 + CHARACTER_RADIUS) / float(CELL) * METERS_PER_CELL
)
## 出生偏移环的步长：slot i 向 -Z 退 i 格的一半。不是产品出生布局。
const SPAWN_STRIDE: int = Fixed.SCALE / 2

# 相机与灯光（D4：斜 45°）

## 跟随相机到目标的直线距离。D4 只给了角度，**没给距离**，所以这里是接线前
## 那个 Vector3(6, 8, 6) 的长度 √136，一位数字都没动。改距离要回去问人类。
const CAMERA_DISTANCE: float = 11.661903789690601
## D4 的「斜 45°」两个角都取 45：水平方位角 45°（等量偏 +X 与 +Z），俯角 45°。
## 接线前水平角已经是 45°，俯角却是 43.3°——差的那 1.7° 不是设计，是
## Vector3(6, 8, 6) 里 8 与 6√2 不相等的副产物。
const CAMERA_YAW_DEG: float = 45.0
const CAMERA_PITCH_DEG: float = 45.0
## sin(45°) = cos(45°) = 1/√2。const 表达式里不能调 `sqrt()`，所以写成字面量，
## 由 `test_placeholder_spec.gd` 反算角度来守。
const _SIN_45: float = 0.7071067811865476
## 俯角 45° ⇒ 竖直分量 = d/√2，水平半径也 = d/√2；水平方位角 45° ⇒
## x = z = 水平半径/√2 = d/2。三个分量因此都由 CAMERA_DISTANCE 推出。
const CAMERA_OFFSET: Vector3 = Vector3(
	CAMERA_DISTANCE / 2.0,
	CAMERA_DISTANCE * _SIN_45,
	CAMERA_DISTANCE / 2.0
)
## Godot `Camera3D.fov` 的默认值。**D4 没给 FOV**，所以维持默认；显式写在这里
## 是为了让下一个想改镜头的人必须改 spec，而不是在某个 map 里悄悄设一个数。
const CAMERA_FOV_DEG: float = 75.0
const LIGHT_ROTATION_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)

# UI（D4：分辨率基准 1920×1080）

## UI 的设计基准分辨率，不是窗口尺寸。落点是**主窗口**的 stretch
## （project.godot `display/window/stretch/mode=canvas_items`），由
## `test_project_contract.gd` 断言两处是同一个数。
##
## **嵌入子窗口不得自己设 `content_scale_*`。** `gui_embed_subwindows = true` 的
## 子窗口，`content_scale` 在渲染路径不生效、输入路径生效，于是画出来的按钮与
## 鼠标命中的按钮错开 `1/factor` 倍，右侧还会被切出可视区。两条壳各有一条回归
## 守卫钉住这件事。子窗口继承主窗口那一层缩放，不需要也不能再叠一层。
const UI_BASE_SIZE: Vector2i = Vector2i(1920, 1080)

# 色板（D4：TRAPRUSH 危险色 = 洋红；其余仍是占位色块，见 D8「不做描边」）

## 本席与远端玩家盒。
const OWN_ALBEDO: Color = Color(0.15, 0.85, 0.75)
const REMOTE_ALBEDO: Color = Color(0.2, 0.45, 0.95)
## 玩家盒的 -Z 朝向标记，让立方体上看得出偏航。
const FACE_ALBEDO: Color = Color(0.95, 0.92, 0.35)
## Preview 里的玩家标记。Preview 只有一个人，没有本席/远端之分，今天与远端同色。
const PREVIEW_PLAYER_ALBEDO: Color = REMOTE_ALBEDO

## 洋红周期机关（D4 危险色）、石色固定固体、橙色可破坏箱。
const HAZARD_ALBEDO: Color = Color(0.82, 0.18, 0.48)
const SOLID_ALBEDO: Color = Color(0.52, 0.48, 0.42)
const CRATE_ALBEDO: Color = Color(0.85, 0.4, 0.25)
## Preview 里没被上面任何一类认领的实体占位色。
const ENTITY_STUB_ALBEDO: Color = Color(0.85, 0.7, 0.25)

## 检查点垫三态：未到 / 已验收 / 当前目标。
const PAD_PENDING_ALBEDO: Color = Color(0.35, 0.9, 0.4)
const PAD_ACCEPTED_ALBEDO: Color = Color(0.16, 0.38, 0.22)
const PAD_CURRENT_ALBEDO: Color = Color(0.55, 1.0, 0.45)

## 终点三态：未开放 / 全垫完成后开放 / 冲线后。
const FINISH_PENDING_ALBEDO: Color = Color(0.95, 0.82, 0.2)
const FINISH_CURRENT_ALBEDO: Color = Color(1.0, 0.92, 0.35)
const FINISH_ACCEPTED_ALBEDO: Color = Color(0.42, 0.32, 0.08)

## 传送连线：双向 / 单向 / 悬空端。
const PORTAL_TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const PORTAL_ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)
const PORTAL_DANGLE_ALBEDO: Color = Color(0.9, 0.25, 0.35)

## 检查点顺序 gizmos。今天与未到的垫同色，是有意的；两者可以在 D4 之后分开，
## 所以留成两个名字而不是一个。
const CHECKPOINT_ALBEDO: Color = PAD_PENDING_ALBEDO
## 顺序重复的检查点，用一个不会与垫三态混淆的颜色喊出来。
const CHECKPOINT_DUP_ALBEDO: Color = Color(0.95, 0.3, 0.85)

## 名次 Label：已冲线 / 仍在跑；本席与远端的描边。
const STANDING_FINISHED_ALBEDO: Color = Color(1.0, 0.85, 0.2)
const STANDING_RUNNING_ALBEDO: Color = Color(0.85, 0.9, 1.0)
const STANDING_OWN_OUTLINE: Color = OWN_ALBEDO
const STANDING_REMOTE_OUTLINE: Color = Color(0.0, 0.0, 0.0)

## Preview 走路可达性问题 gizmos。
const REACH_ALBEDO: Color = Color(1.0, 0.82, 0.2)

## Editor 3D 放置引导（仅 AuthoringEditorShell 地板/光标/选中框；不是占用色、不进编译）。
const EDIT_GUIDE_FLOOR_FILL_ALBEDO: Color = Color(0.14, 0.16, 0.18, 0.92)
const EDIT_GUIDE_GRID_LINE_ALBEDO: Color = Color(0.38, 0.42, 0.48, 0.9)
const EDIT_GUIDE_CURSOR_ALBEDO: Color = Color(0.95, 0.85, 0.25, 0.45)
const EDIT_GUIDE_SELECT_ALBEDO: Color = Color(1.0, 1.0, 1.0, 0.35)

# 表现步长（占位桩，不是产品数值；锁定见文件头）

## 一次输入采样的水平位移量级。
const MOVE_STEP: int = Fixed.SCALE / 16
## 两帧快照之间每次推进的插值量。是表现桩，**不是**插值窗口长度。
const INTERP_STEP: int = Fixed.SCALE / 2
