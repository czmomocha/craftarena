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
## TRAPRUSH 危险色 = 洋红。
##
## D4 已拍板但**尚未接线**：相机斜 45°（`CAMERA_OFFSET` 的水平角已是 45°，
## 俯角与距离没按 D4 重算，FOV D4 也没给）；UI 基准 1920×1080（大厅窗口仍
## 1600×900）。本刀只收敛引用点、不改数值，接线会改开发机可见行为，留 C4 后续章。
##
## 权威碰撞与视觉网格的**分离**不在本文件：那要等 `GameplayAsset` 契约
## （纠偏方案 C4 第 2–4 章）。今天二者仍靠 1 格 = 1 米隐式对齐。
##
## `MOVE_STEP` / `INTERP_STEP` 是表现占位桩，不是产品速度或插值窗口。锁定要等
## 24 小时 ICMP 或远端协议层样本，见 [CD-43 §4](Confirmed-docs/40-technical/43-networking-and-replay.md)
## 与 `docs/runbooks/server-deploy.md` §12 / §13。

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
## 出生偏移环的步长：slot i 向 -Z 退 i 格的一半。不是产品出生布局。
const SPAWN_STRIDE: int = Fixed.SCALE / 2

# 相机与灯光

## 大厅与 Preview 共用的跟随偏移。x = z 所以水平方位角已经是 D4 要的 45°，
## 但俯角约 43° 而不是 45°，距离与 FOV D4 也没给。按 D4 重算是后续章的事，
## 本刀只把这一份从两个文件收敛到一处。
const CAMERA_OFFSET: Vector3 = Vector3(6.0, 8.0, 6.0)
const LIGHT_ROTATION_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)

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

# 表现步长（占位桩，不是产品数值；锁定见文件头）

## 一次输入采样的水平位移量级。
const MOVE_STEP: int = Fixed.SCALE / 16
## 两帧快照之间每次推进的插值量。是表现桩，**不是**插值窗口长度。
const INTERP_STEP: int = Fixed.SCALE / 2
