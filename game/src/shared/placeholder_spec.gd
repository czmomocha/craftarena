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
## 角色视觉的**水平占格比例**：贴合时按资产自身 AABB 等比缩放，让水平最长边
## 落到 `METERS_PER_CELL * 本值`。
##
## 它存在的理由是角色此前**根本没有贴合规则**——地块走 `fit_tile_on_cell`、
## 门 / 箱 / 滚柱走 `fit_prop_on_cell`，只有角色是把资产原始尺寸直接摆上去。
## 前两个角色资产水平最长边 0.75 m / 0.74 m，本来就小于一格，所以看不出来；
## 换成 Cube Pets 的猫（水平最长 1.806 m，尾巴与四足伸展）之后一眼可见。
##
## **为什么不是 1.0**：门 / 箱那类静物占满整格是对的，角色不是——权威胶囊直径
## 只有 0.25 格，视觉占满一格会让角色在 1 格宽的路面上显得贴边、并与相邻格
## 的物件穿插。0.7 是人类 2026-09-07 提出「动物有点大」后给的**占位值，未定稿**：
## 它不是产品比例，改它只动这一行。D4 没有问过这一项。
##
## 缩放按 AABB 算而不是写死系数，理由与地块那条相同：Cube Pets 24 只动物尺寸
## 各异（长颈鹿高、螃蟹扁），写死系数等于每换一只都要重算一次。
const CHARACTER_VISUAL_CELL_SPAN: float = 0.7
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
## 滚轮调距：默认距离仍是 CAMERA_DISTANCE（D4 未答，不许改默认）。只允许在
## 斜 45° 上走近/拉远，不改方位角与俯角。
const CAMERA_DISTANCE_MIN: float = 8.0
const CAMERA_DISTANCE_MAX: float = 20.0
const CAMERA_ZOOM_STEP: float = 1.25
## 中键拖移的水平平移上限（米）。不是自由旋转。
const CAMERA_PAN_LIMIT: float = 4.0
const CAMERA_PAN_SENS: float = 0.012
const LIGHT_ROTATION_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)

## 跟随锚点一帧内位移超过这么多米，就判为**跳变**（传送 / 复位），由
## `CameraFollowTransition` 摊成一段滑行而不是瞬移换机位。一帧里最大的一次
## 合法位移是冲刺 1 格 = 1 米，所以 2.5 留了足够余量，不会被普通移动误触。
const CAMERA_TELEPORT_SNAP_M: float = 2.5
## 跳变滑行时长（秒）。短到不夺走操作权，长到能看清「我从哪去了哪」。
## 占位值，D4 没有问过镜头过渡；改它只动这一行。
const CAMERA_TELEPORT_GLIDE_S: float = 0.35


static func clamp_camera_distance(distance: float) -> float:
	if distance < CAMERA_DISTANCE_MIN:
		return CAMERA_DISTANCE_MIN
	if distance > CAMERA_DISTANCE_MAX:
		return CAMERA_DISTANCE_MAX
	return distance


static func camera_offset_for_distance(distance: float) -> Vector3:
	var d: float = clamp_camera_distance(distance)
	return Vector3(d / 2.0, d * _SIN_45, d / 2.0)

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
## 玩法 HUD / 世界标签字号。不是产品字体（入包仍推迟）；只把挡视线的字缩小。
const HUD_CLOCK_FONT_SIZE: int = 28
const HUD_SPLIT_FONT_SIZE: int = 16
const HUD_STATUS_FONT_SIZE: int = 13
const LABEL3D_FONT_SIZE: int = 28
const LABEL3D_PIXEL_SIZE: float = 0.008
const LABEL3D_OUTLINE_SIZE: int = 6
const LABEL3D_STANDING_LIFT: float = 0.95
const LABEL3D_ANIM_LIFT: float = 1.2
const LABEL3D_ANIM_FONT_SIZE: int = 20
const LABEL3D_ANIM_PIXEL_SIZE: float = 0.006

# 色板（D4：TRAPRUSH 危险色 = 洋红；其余仍是占位色块，见 D8「不做描边」）

## 本席与远端玩家盒。
const OWN_ALBEDO: Color = Color(0.15, 0.85, 0.75)
const REMOTE_ALBEDO: Color = Color(0.2, 0.45, 0.95)
## 玩家盒的 -Z 朝向标记，让立方体上看得出偏航。
const FACE_ALBEDO: Color = Color(0.95, 0.92, 0.35)
## Preview 里的玩家标记。Preview 只有一个人，没有本席/远端之分，今天与远端同色。
const PREVIEW_PLAYER_ALBEDO: Color = REMOTE_ALBEDO

## 表现预警提前量（D-F7 桩）。0.25 s @ 60 Hz。不进权威、不进快照。
const HAZARD_WARN_TICKS: int = 15
## 打碎碎裂反馈时长。纯表现，不进权威。
const BREAK_FX_SECONDS: float = 0.35
const BREAK_FX_SIZE: Vector3 = Vector3(0.22, 0.18, 0.22)
## 楼层着色：上层偏绿、下层偏品红。不是产品材质。
const FLOOR_TINT: float = 0.35

## 洋红周期机关（D4 危险色）、石色固定固体、橙色可破坏箱。
const HAZARD_ALBEDO: Color = Color(0.82, 0.18, 0.48)
const SOLID_ALBEDO: Color = Color(0.52, 0.48, 0.42)
const CRATE_ALBEDO: Color = Color(0.85, 0.4, 0.25)
## 踩区开关（青绿踏板）与门（紫墙）。不是产品材质，只为和石色固体分开。
const SWITCH_ALBEDO: Color = Color(0.28, 0.78, 0.48)
const GATE_ALBEDO: Color = Color(0.58, 0.32, 0.82)
## 传送带 / 弹射垫 / 电梯 / 能量墙的程序化占位色。不是产品材质。
const CONVEYOR_ALBEDO: Color = Color(0.82, 0.62, 0.18)
const CONVEYOR_MARK_ALBEDO: Color = Color(0.98, 0.88, 0.32)
const LAUNCH_ALBEDO: Color = Color(0.92, 0.48, 0.16)
const LAUNCH_MARK_ALBEDO: Color = Color(1.0, 0.82, 0.28)
const LIFT_ALBEDO: Color = Color(0.42, 0.52, 0.62)
const LIFT_MARK_ALBEDO: Color = Color(0.72, 0.82, 0.9)
const ENERGY_WALL_ALBEDO: Color = Color(0.13, 0.75, 0.95, 0.55)
const SPIKE_ALBEDO: Color = Color(0.62, 0.18, 0.22)
const SPIKE_MARK_ALBEDO: Color = Color(0.92, 0.42, 0.38)
const FLAME_ALBEDO: Color = Color(0.42, 0.16, 0.12)
const FLAME_MARK_ALBEDO: Color = Color(1.0, 0.48, 0.12, 0.7)
const CRUSHER_ALBEDO: Color = Color(0.38, 0.34, 0.4)
const CRUSHER_MARK_ALBEDO: Color = Color(0.72, 0.28, 0.32)
const ROLLER_ALBEDO: Color = Color(0.55, 0.42, 0.28)
const ROLLER_MARK_ALBEDO: Color = Color(0.82, 0.62, 0.32)
const RUBBLE_ALBEDO: Color = Color(0.48, 0.4, 0.34)
const RUBBLE_MARK_ALBEDO: Color = Color(0.7, 0.58, 0.42)
const OBSTACLE_CORE_ALBEDO: Color = Color(0.72, 0.22, 0.55, 0.55)
const OBSTACLE_CORE_MARK_ALBEDO: Color = Color(0.95, 0.45, 0.78)
const PENDULUM_ALBEDO: Color = Color(0.42, 0.28, 0.22)
const PENDULUM_MARK_ALBEDO: Color = Color(0.72, 0.38, 0.22)
const ICE_ALBEDO: Color = Color(0.55, 0.82, 0.95, 0.7)
const ICE_MARK_ALBEDO: Color = Color(0.82, 0.94, 1.0)
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

## 拾取物与出生点标记（F 线 FC）。不是产品道具表色。
const PICKUP_BOMB_ALBEDO: Color = Color(0.92, 0.42, 0.18)
const PICKUP_DASH_ALBEDO: Color = Color(0.25, 0.78, 0.92)
const SPAWN_MARKER_ALBEDO: Color = Color(0.95, 0.92, 0.35)

## 传送连线：双向 / 单向 / 悬空端。
const PORTAL_TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const PORTAL_ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)
const PORTAL_DANGLE_ALBEDO: Color = Color(0.9, 0.25, 0.35)

## 检查点顺序 gizmos。今天与未到的垫同色，是有意的；两者可以在 D4 之后分开，
## 所以留成两个名字而不是一个。
const CHECKPOINT_ALBEDO: Color = PAD_PENDING_ALBEDO
## 顺序重复的检查点，用一个不会与垫三态混淆的颜色喊出来。
const CHECKPOINT_DUP_ALBEDO: Color = Color(0.95, 0.3, 0.85)

## 本席头顶的世界导航箭头（可玩性深化，轨 1）：指向下一个检查点 / 终点。
## 三色按楼层差分：同层 / 需要上楼 / 需要下楼。方向本身已经由朝向给出，颜色
## 只回答「在这一层找还是换一层找」——那正是多层课里最容易丢的信息。
const GUIDE_SAME_ALBEDO: Color = Color(0.98, 0.86, 0.3)
const GUIDE_UP_ALBEDO: Color = Color(0.45, 0.95, 0.55)
const GUIDE_DOWN_ALBEDO: Color = Color(0.95, 0.5, 0.85)
const GUIDE_SIZE: Vector3 = Vector3(0.1, 0.1, 0.45)
const GUIDE_LIFT: float = 0.72
const GUIDE_FORWARD_M: float = 0.5

## 名次 Label：已冲线 / 仍在跑；本席与远端的描边。
const STANDING_FINISHED_ALBEDO: Color = Color(1.0, 0.85, 0.2)
const STANDING_RUNNING_ALBEDO: Color = Color(0.85, 0.9, 1.0)
const STANDING_OWN_OUTLINE: Color = OWN_ALBEDO
const STANDING_REMOTE_OUTLINE: Color = Color(0.0, 0.0, 0.0)

## 课内动效（可玩性深化 轨 2）。全部由权威 tick 推出，不读墙钟；相位按
## entity_id 错开。占位表现值，D4 没有问过动效节奏；改它们只动这三行。
## 传送门旋翼转一整圈的 tick 数（60 tick/s 桩 ⇒ 2 秒一圈）。
const FX_PORTAL_SPIN_TICKS: int = 120
## 当前目标垫 / 已开放终点的呼吸周期与幅度。
const FX_PULSE_TICKS: int = 48
const FX_PULSE_AMPLITUDE: float = 0.12
## 未开的开关传送：旋翼停、亮度压到这个系数。占位表现值。
const FX_PORTAL_LOCKED_MODULATE: float = 0.4

## Preview 走路可达性问题 gizmos。
const REACH_ALBEDO: Color = Color(1.0, 0.82, 0.2)

## Editor 3D 放置引导（仅 AuthoringEditorShell 地板/光标/选中框；不是占用色、不进编译）。
## 填色 alpha 必须明显小于 1：切到其它楼层时平面挡在相机和已放实体之间，
## 不走 TRANSPARENCY_ALPHA + 低 alpha 时下层实体会看起来像被删掉。
const EDIT_GUIDE_FLOOR_FILL_ALBEDO: Color = Color(0.14, 0.16, 0.18, 0.2)
const EDIT_GUIDE_GRID_LINE_ALBEDO: Color = Color(0.38, 0.42, 0.48, 0.9)
const EDIT_GUIDE_CURSOR_ALBEDO: Color = Color(0.95, 0.85, 0.25, 0.45)
const EDIT_GUIDE_SELECT_ALBEDO: Color = Color(1.0, 1.0, 1.0, 0.35)


static func floor_albedo(y: int, cell: int) -> Color:
	if cell < 1:
		return SOLID_ALBEDO
	var floor_index: int = y / cell
	if floor_index > 0:
		return SOLID_ALBEDO.lerp(GUIDE_UP_ALBEDO, FLOOR_TINT)
	if floor_index < 0:
		return SOLID_ALBEDO.lerp(GUIDE_DOWN_ALBEDO, FLOOR_TINT)
	return SOLID_ALBEDO

# 表现步长（占位桩，不是产品数值；锁定见文件头）

## 一次输入采样的水平位移量级。
const MOVE_STEP: int = Fixed.SCALE / 16
## 两帧快照之间每次推进的插值量。是表现桩，**不是**插值窗口长度。
const INTERP_STEP: int = Fixed.SCALE / 2
