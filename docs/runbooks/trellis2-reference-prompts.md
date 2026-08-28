# TRELLIS 2 参考图提示词手册

> 文档类型：实现级作业手册（`docs/runbooks/`）
> 状态：**草案，待人类确认**。本文件不修改任何 `Confirmed-docs/`，不拍板任何数值
> 上位约束：[CD-00 宪法](../Confirmed-docs/00-constitution/CONSTITUTION.md)（尤其第一、十七、十八、十九条）
> 关联批次：纠偏 C4（资产契约与美术规格），见 [course-correction-2026-08.md §C4](../plans/course-correction-2026-08.md)
> 事实源：`game/src/shared/placeholder_spec.gd`（色板与尺度）、[CD-11 §8](../Confirmed-docs/10-product/11-scope-and-platforms.md)（美术风格）、[CD-21 §7](../Confirmed-docs/20-gameplay/21-traprush.md)（TRAPRUSH 白名单）、[CD-22 §5](../Confirmed-docs/20-gameplay/22-bastion.md)（BASTION 候选）

---

## 1. 这份文档做什么

把「文生图 → TRELLIS 2（`trellis2_model_generation`）→ GLB → Godot 导入」这条链路的**第一步**标准化，输出可直接粘贴的提示词。

范围边界：

- 只管**参考图提示词**与出图约束；
- 不定义 `GameplayAsset` 契约（C4 第 2 章）、不定义导入规范与性能预算（C4 第 3 章）、不做动画（C4 第 4 章）；
- BASTION 部分在 [M6/M7 冻结](../plans/course-correction-2026-08.md) 范围内，只作**预研素材**，不得据此开工。

### 1.1 为什么是「模块化组件」而不是「整张地图」

TRELLIS 2 的输入是**单个物体**（Objaverse 类分布），不是场景。给一张「赛道全景」会得到一坨糊掉的地形。

因此：

| 层 | 由谁产生 |
|---|---|
| 单件资产（地块、机关、门、箱、角色、塔、兵） | TRELLIS 2 逐个生成 |
| 赛道 / 战场 | 编辑器按网格吸附摆放，由 `AuthoringDocument` + 拓扑编译器组装 |
| 地面引导箭头、危险区条纹等平面信息 | 程序化贴图或 shader，不进模型 |

---

## 2. 硬约束（出图前必读）

| # | 约束 | 来源 | 提示词体现 |
|---|---|---|---|
| 1 | 统一风格化低多边形、清晰纯色分区 | CD-11 §8 | G-PREFIX |
| 2 | **纠偏期不做描边**，可读性靠色块 + 明度分区 | D8 | G-NEGATIVE 禁 outline |
| 3 | 渲染共同基线是 Compatibility / WebGL 2，核心可读性不得依赖 Forward+ 专属效果 | CD-11 §7、宪法第七条 | 材质只用 albedo，不依赖高光/PBR |
| 4 | 目标 12+，青少年级，不出现血腥、武器、真实暴力 | CD-11 §8 | G-NEGATIVE |
| 5 | 无文字、无 logo、无第三方 IP | 法律 + UGC 边界 | G-NEGATIVE |
| 6 | 1 格 = 1 表现米；glTF 单位即米，Godot 与 glTF 均为 Y-up / -Z 前 | D4、Godot 4 | 尺寸表 + 原点约定 |
| 7 | 视觉网格**不是**碰撞体；权威碰撞只由盒/球/胶囊/平台预制表达 | 宪法第五条、CD-21 §4.2 | 造型不得出现影响通行的悬挑 |
| 8 | 生成式模型的输出物授权与商用边界**未评估** | 宪法第十八条 | 见 §9 |

---

## 3. 三段拼装规则

每条提示词 = **前缀 + 主体 + 后缀**。一个资产出多张图时，主体不变，只换视角片段。

```text
[ G-PREFIX ] + [ SUBJECT ] + [ VIEW_x ] + [ G-SUFFIX ]
```

- `G-PREFIX` / `G-SUFFIX` / `VIEW_x` 见 §4，全项目只有一份；
- `SUBJECT` 见 §6–§8 的表格，每个资产一段英文名词短语（已含造型、配色、材质分区）；
- 同一资产的四个视角必须**复制同一个 SUBJECT 字符串**，只改 `VIEW_x`；
- 同一资产的多视角应尽量复用同一 seed 与同一出图参数，否则造型会漂移。

### 3.1 完整示例（照抄这个格式）

`traprush_crate` 的 A 视角：

```text
stylized low-poly 3D game asset, chunky faceted forms, clean flat color blocking, matte diffuse surfaces, soft rounded bevels, readable silhouette, no outline, no ink lines, no cel shading, toy-like diorama proportions, workshop machine-shop theme, painted steel and plywood, yellow-and-black hazard bands, single object, a destructible supply crate, cube 1x1x1 meters, warm orange painted panels #D96640 with darker orange corner frames and a lighter orange top face, black metal corner brackets and rivets, shallow crack lines suggesting damage, standing squarely on its base, view: three-quarter front view from slightly above, camera about 35 degrees above horizontal, matching a 45-degree isometric-style game camera, plain neutral light gray seamless studio background (#C8C8C8), soft even three-point lighting, gentle contact shadow, no cast shadow across background, centered in frame, fills 80% of frame, sharp focus, high detail texture map, no text, no labels, no watermark, no logo, no brand, no human characters, no weapons
```

---

## 4. 全局片段（全项目唯一一份）

### 4.1 G-PREFIX（风格）

```text
stylized low-poly 3D game asset, chunky faceted forms, clean flat color blocking, matte diffuse surfaces, soft rounded bevels, readable silhouette, no outline, no ink lines, no cel shading, toy-like diorama proportions, {THEME}, single object,
```

`{THEME}` 取值（**主题与 BASTION 色板均未拍板，以下为建议，需人类确认**）：

| 玩法 | 建议主题串 |
|---|---|
| TRAPRUSH | `workshop machine-shop theme, painted steel and plywood, yellow-and-black hazard bands` |
| BASTION | `stone-and-brass siege-works theme, cut masonry with brass fittings` |

### 4.2 视角片段 `VIEW_x`

| 视图 | 文件后缀 | 片段 |
|---|---|---|
| A 主视图 | `_a_three_quarter` | `view: three-quarter front view from slightly above, camera about 35 degrees above horizontal, matching a 45-degree isometric-style game camera,` |
| B 正视图 | `_b_front` | `view: straight-on front elevation, camera level with the object's vertical center,` |
| C 侧视图 | `_c_side` | `view: straight-on right-side elevation, camera level with the object's vertical center,` |
| D 顶视图 | `_d_top` | `view: top-down orthographic-style view looking straight down at the object,` |

视图集：地形 / 结构 / 门 / 塔 / 角色用 **A B C D**；小件道具、单位、障碍用 **A B C**（省一半出图量，TRELLIS 2 对这些够用）。

### 4.3 G-SUFFIX（构图与背景）

```text
plain neutral light gray seamless studio background (#C8C8C8), soft even three-point lighting, gentle contact shadow, no cast shadow across background, centered in frame, fills 80% of frame, sharp focus, high detail texture map, no text, no labels, no watermark, no logo, no brand, no human characters, no weapons
```

说明：TRELLIS 2 是**图像条件生成**，背景会被当作物体环境的一部分。纯中性灰 + 无跨背景投影，能显著降低「背景被烤成一块面片」的概率。

### 4.4 G-NEGATIVE（负向，全资产共用）

```text
outline, ink line, toon shading, cel shading, airbrush gradient, photorealistic, baked grunge, rust, decals, text, letters, numbers, logo, watermark, brand marks, third-party IP characters, cut off, cropped, multiple objects in one image, scattered props, floating disconnected parts, harsh specular highlights, strong cast shadow on background, reflective floor, mirror, glass ambiguity, motion blur, depth of field, blurry, low resolution
```

### 4.5 出图参数（起点，非门禁）

| 项 | 值 |
|---|---|
| 分辨率 | 1024×1024（角色与塔用 1536×1536） |
| 宽高比 | 1:1（物体的外接立方体接近正方时） |
| 同资产多视角 | 固定 seed、固定 sampler、只换 `VIEW_x` 片段 |
| 批次 | 每资产一次出 3–4 张，不要逐张单独抽 |

> 面数与贴图预算**尚未拍板**（C4 第 3 章），§10 的数值是起点建议，不是 [CD-53](../Confirmed-docs/50-engineering/53-testing-and-ci.md) §1.1 意义上的门禁。

---

## 5. 色板与尺度

### 5.1 色板

来源：`game/src/shared/placeholder_spec.gd`。**除「危险 = 洋红」外，其余仍是占位色**（D4 只拍板了这一条），随时可能改，[§5.1 冻结令](../plans/course-correction-2026-08.md) 仍生效——本表只供提示词参考，不得反向写回代码。

| 语义 | 常量 | HEX | 状态 |
|---|---|---|---|
| 本席玩家 | `OWN_ALBEDO` | `#26D9BF` | 占位 |
| 远端玩家 | `REMOTE_ALBEDO` | `#2173F2` | 占位 |
| 玩家朝向标记 | `FACE_ALBEDO` | `#F2EB59` | 占位 |
| 周期机关（危险） | `HAZARD_ALBEDO` | `#D12E7A` | **D4 已拍板** |
| 固定固体 / 地形 | `SOLID_ALBEDO` | `#857A6B` | 占位 |
| 可破坏箱 | `CRATE_ALBEDO` | `#D96640` | 占位 |
| 未认领实体 | `ENTITY_STUB_ALBEDO` | `#D9B340` | 占位 |
| 检查点：未到 | `PAD_PENDING_ALBEDO` | `#59E666` | 占位 |
| 检查点：已验收 | `PAD_ACCEPTED_ALBEDO` | `#296138` | 占位 |
| 检查点：当前目标 | `PAD_CURRENT_ALBEDO` | `#8CFF73` | 占位 |
| 终点：未开放 | `FINISH_PENDING_ALBEDO` | `#F2D133` | 占位 |
| 终点：已开放 | `FINISH_CURRENT_ALBEDO` | `#FFEB59` | 占位 |
| 终点：冲线后 | `FINISH_ACCEPTED_ALBEDO` | `#6B5214` | 占位 |
| 传送：双向 | `PORTAL_TWO_WAY_ALBEDO` | `#21BFF2` | 占位 |
| 传送：单向 | `PORTAL_ONE_WAY_ALBEDO` | `#F28C26` | 占位 |
| 传送：悬空端 | `PORTAL_DANGLE_ALBEDO` | `#E64059` | 占位 |
| 检查点重复 | `CHECKPOINT_DUP_ALBEDO` | `#F24DD9` | 占位 |
| 可达性 gizmo | `REACH_ALBEDO` | `#FFD133` | 占位 |

BASTION 色板：**D4 空白，未拍板**（[§4 空白表](../plans/course-correction-2026-08.md)）。§8 中出现的 BASTION 颜色一律标注「候选」，人类未确认前不得使用。

### 5.2 尺度与原点

| 项 | 值 | 状态 |
|---|---|---|
| 1 格 | 1.0 m | D4 已拍板 |
| 权威胶囊 半径 / 高 | 0.125 格 / 0.125 格 | D4 维持（**占位**，见 §9 风险 2） |
| 视觉占位盒 | 1.0 × 1.0 × 1.0 m | 占位 |
| 玩家视觉高度 | **未定义** | 本手册按 0.9 m 构图，待 C4 拍板 |
| 相机 | 斜 45°，俯角与距离未算 | D4 已拍板角度，接线留后续章 |

原点约定（写进 DCC 交付要求，TRELLIS 2 不保证，需在 Blender 里校正）：

| 类别 | 原点 | 朝向 |
|---|---|---|
| 地块 / 结构 / 塔 / 障碍 | **底面中心** | 正面朝 **-Z** |
| 门框 / 拱门 | 底面中心（跨两侧立柱之间） | 通行方向沿 **Z**，正面朝 **-Z** |
| 角色 / 单位 | **脚底中心** | 正面朝 **-Z** |
| 道具 / 小件 | 几何中心 | 正面朝 **-Z** |

与前向一致：Godot 4 与 glTF 都是 Y-up / -Z 前，项目内玩家盒也用 local -Z 做朝向标记，无需翻转。

---

## 6. TRAPRUSH 资产提示词

`{THEME}` = `workshop machine-shop theme, painted steel and plywood, yellow-and-black hazard bands`

### 6.1 地形与结构（视图集 A B C D）

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_block_static` | 1.0×1.0×1.0 | `#857A6B` | `a solid terrain block cube, stone-grey top face #857A6B with a lighter grey beveled rim, darker grey sides, thin pale stripe along the top edge, flat closed bottom` |
| `traprush_block_slope` | 1.0×0.5×1.0 | `#857A6B` | `a wedge-shaped ramp block rising from 0 to 0.5 meters over one meter, stone-grey sloped face #857A6B with a lighter grey top edge, dark grey side triangles, flat closed bottom` |
| `traprush_bridge` | 1.0×0.25×1.0 | `#857A6B` | `a narrow bridge deck one meter square and 0.25 meters thick, grey deck #857A6B with dark grey underside ribs and low kerb strips along both long edges, no railings` |
| `traprush_platform_mover` | 1.6×0.35×1.6 | `#857A6B` | `a moving platform slab 1.6 meters square and 0.35 meters thick, grey deck #857A6B with yellow-and-black chevron strips on the side faces, four dark metal corner shoes, no visible rails or motors` |
| `traprush_conveyor` | 1.0×0.3×2.0 | `#857A6B` | `a conveyor belt module one meter wide and two meters long, grey frame #857A6B, dark rubber belt with raised chevron treads pointing along the length, cylindrical rollers visible at both ends, yellow side guards` |
| `traprush_lift` | 1.5×0.3×1.5 | `#857A6B` | `a lift platform 1.5 meters square with a 0.3 meter thick deck, grey deck #857A6B with yellow-and-black edge band, four short dark steel guide posts at the corners, scissor mechanism hinted but not extended` |
| `traprush_launch_pad` | 1.2×0.4×1.2 | `#857A6B` | `a launch pad 1.2 meters square and 0.4 meters tall, grey base #857A6B with a recessed circular launching plate on top, four thick coil springs around the plate, yellow-and-black hazard band on the base sides` |

> `floor_marker`（地面引导箭头）**不生成模型**：它是平面信息，走程序化贴图或 shader，见 §1.1。

### 6.2 流程物件（视图集 A B C D）

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_spawn_grid` | 2.0×0.2×2.0 | `#857A6B` | `a starting platform two meters square and 0.2 meters thick, grey deck #857A6B, four recessed square foot slots arranged in a row, dark metal border frame, no numbers or letters` |
| `traprush_checkpoint_pad` | 1.0×0.12×1.0 | `#59E666` | `a checkpoint pad one meter square and 0.12 meters thick, muted green deck #59E666 with a darker green recessed inner square #296138 and a bright green glowing rim channel #8CFF73, dark grey undershell` |
| `traprush_checkpoint_gate` | 1.6×2.0×0.4 | `#59E666` | `a checkpoint gate frame 1.6 meters wide and 2 meters tall, two dark grey posts with a green crossbeam #59E666, a bright green light strip #8CFF73 along the inner edge of the crossbeam, open passage between the posts` |
| `traprush_finish_gate` | 3.0×2.4×0.6 | `#F2D133` | `a finish line arch three meters wide and 2.4 meters tall, two chunky dark grey pillars with a golden crossbeam #F2D133, a pale gold light strip #FFEB59 under the beam, a row of small pennant flags along the top, open passage beneath` |

### 6.3 传送（视图集 A B C D）

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_portal_two_way` | 1.4×2.0×0.4 | `#21BFF2` | `a two-way teleport gate, rectangular portal frame 1.4 meters wide and 2 meters tall, dark grey posts with a cyan glowing ring #21BFF2 around the opening, two identical arrow notches on both faces pointing through the frame, empty opening` |
| `traprush_portal_one_way` | 1.4×2.0×0.4 | `#F28C26` | `a one-way teleport gate, rectangular portal frame 1.4 meters wide and 2 meters tall, dark grey posts with an orange glowing ring #F28C26 around the opening, deep arrow grooves on the front face all pointing in one direction, a solid back plate on the reverse face, empty opening` |
| `traprush_portal_switch` | 0.8×1.2×0.8 | `#21BFF2` | `a portal switch node, hexagonal dark grey pedestal 0.8 meters wide and 1.2 meters tall with a rotating cyan ring #21BFF2 around its upper half and a large chunky push button on top, no text` |

> 传送门内的能量面片**不生成模型**：面片用半透明面 + shader，见 §10.3。

### 6.4 机关（视图集 A B C D）

危险件统一使用洋红 `#D12E7A`（D4 已拍板），并要求「静态即可看出危险」——对应 [CD-21 §2.3](../Confirmed-docs/20-gameplay/21-traprush.md)「障碍可读、明显预警」。周期机关只做**一个姿态**（激活/危险态），收回态靠缩放或动画。

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_hazard_spike` | 1.0×0.6×1.0 | `#D12E7A` | `a floor spike hazard, dark grey base plate one meter square with a row of five chunky magenta spikes #D12E7A fully extended upward 0.6 meters, yellow-and-black hazard chevrons painted on the base rim` |
| `traprush_hazard_crusher` | 1.2×1.8×1.2 | `#D12E7A` | `a crushing press hazard, dark grey frame with two vertical guide rails and a heavy magenta block #D12E7A hanging at the top 1.8 meters high, chunky teeth along the bottom of the block, yellow-and-black hazard bands on the rails` |
| `traprush_hazard_roller` | 1.6×0.9×0.9 | `#D12E7A` | `a rolling drum hazard, magenta cylinder #D12E7A 1.6 meters long and 0.9 meters in diameter lying horizontally, raised grey ridge bands around the circumference, dark grey axle caps at both ends, yellow-and-black hazard rings near the caps` |
| `traprush_hazard_flame` | 0.8×0.7×0.8 | `#D12E7A` | `a flame vent hazard, squat dark grey nozzle housing 0.8 meters square and 0.7 meters tall with a magenta inner ring #D12E7A around the round upward opening, a protective metal cage over the opening, yellow-and-black hazard band on the base, no fire, no flames` |
| `traprush_gate` | 1.2×2.0×0.3 | `#857A6B` | `a sliding gate, dark grey frame 1.2 meters wide and 2 meters tall with a grey panel #857A6B lowered to block the opening, horizontal ridge lines on the panel, yellow-and-black chevron band across the lower third, guide slots in the frame` |
| `traprush_switch` | 0.5×0.9×0.5 | `#21BFF2` | `an interactable lever switch, dark grey base block 0.5 meters square and 0.4 meters tall with a short chunky lever arm tilted forward and a cyan ball handle #21BFF2 on top, total height 0.9 meters, no text` |

### 6.5 障碍（视图集 A B C）

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_crate` | 1.0×1.0×1.0 | `#D96640` | `a destructible supply crate, cube one meter, warm orange painted panels #D96640 with a lighter orange top face and darker orange corner frames, black metal corner brackets and rivets, shallow crack lines suggesting damage` |
| `traprush_rubble` | 1.0×0.6×1.0 | `#857A6B` | `a pile of broken rubble one meter square and 0.6 meters tall, grey concrete chunks #857A6B with lighter broken faces, a few dark steel rebar stubs poking out, no dust, no debris scattered outside the footprint` |
| `traprush_obstacle_core` | 0.8×0.8×0.8 | `#D12E7A` | `an obstacle core, dark grey faceted shell 0.8 meters cube with four vertical slits, a glowing magenta crystal core #D12E7A visible through the slits, small brass fitting ring at the base` |
| `traprush_energy_wall` | 1.0×2.0×0.15 | `#21BFF2` | `an energy wall panel, thin dark grey emitter frame one meter wide and two meters tall holding a flat translucent cyan panel #21BFF2 with a subtle hexagonal grid pattern, solid metal posts on both sides`（**透明件，见 §10.3**） |

### 6.6 道具（视图集 A B C）

只有 **爆破球 + 冲刺** 是 D5 拍板的 C3 最小集；其余候选见 [CD-21 §5.3](../Confirmed-docs/20-gameplay/21-traprush.md)，**未锁定**，本表不列。

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `traprush_pickup_bomb` | Ø 0.4 | `#857A6B` | `a cartoon blast bomb pickup, dark charcoal sphere 0.4 meters in diameter with a lighter grey highlight cap, a short thick fuse on top with a bright orange spark tip, a warm orange equatorial stripe around the middle, clean toy proportions, no fire` |
| `traprush_pickup_dash` | 0.4×0.4×0.4 | `#26D9BF` | `a dash pickup, a chunky teal energy module #26D9BF shaped like a rounded chevron pointing forward, dark grey base collar, a lighter cyan glowing arrow notch on the front face, no text` |

### 6.7 角色（视图集 A B C D）

| 资产 ID | 尺寸 (m) | 主色 | SUBJECT |
|---|---|---|---|
| `char_runner_base` | 高 0.9 | 中性 | `a stylized low-poly runner character, 0.9 meters tall, chunky toy proportions with a big rounded head, short stubby limbs and mitten hands, neutral light grey bodysuit with dark grey gloves, boots and belt so the body color can be swapped by material, a small amber visor band across the face, standing in a relaxed ready stance, arms slightly out, no weapons, no text, no logo` |

玩家配色策略（与 `PlaceholderSpec` 一致）：**一套模型 + 两个 albedo 实例**——本席 `#26D9BF`、远端 `#2173F2`。不要为每个席位单独生成模型，也不要把席位色烘进贴图。

---

## 7. BASTION 资产提示词（预研，冻结期内不得开工）

`{THEME}` = `stone-and-brass siege-works theme, cut masonry with brass fittings`

**颜色全部是候选**：D4 的 BASTION 色板是空白，未拍板。下表用「冷蓝（己方/秩序） vs 暖橙（敌方/威胁）」的候选对比，人类确认前不得用于生产资产。

候选色：塔基石灰 `#8A8577`、己方蓝 `#4C7BD9`、敌方橙 `#D97A3C`、控制冰蓝 `#7FD4E8`、增益金 `#E8C56A`、核心紫 `#8E6BC8`。

### 7.1 场地与结构（视图集 A B C D）

| 资产 ID | 尺寸 (m) | SUBJECT |
|---|---|---|
| `bastion_core` | 2.0×2.4×2.0 | `a team core structure, stepped stone tower 2 meters square and 2.4 meters tall, pale grey masonry #8A8577 with brass bands, a floating faceted violet crystal #8E6BC8 in a brass cradle on top, four short buttresses at the base` |
| `bastion_lane_floor` | 1.0×0.12×1.0 | `a lane path tile one meter square and 0.12 meters thick, pale grey stone deck #8A8577 with darker recessed grout lines and slightly raised beveled edges, flat closed bottom` |
| `bastion_build_slot` | 1.0×0.15×1.0 | `a build slot pad one meter square and 0.15 meters thick, dark grey recessed square basin with brass corner brackets #E8C56A at the four corners and a thin brass inner ring, empty` |

### 7.2 炮塔（视图集 A B C D）

全部为 [CD-22 §5.1](../Confirmed-docs/20-gameplay/22-bastion.md) **原型候选，非锁定清单**。

| 资产 ID | 尺寸 (m) | SUBJECT |
|---|---|---|
| `bastion_tower_arrow` | 0.9×1.1×0.9 | `an arrow turret, squat pale grey stone base 0.9 meters square and 0.6 meters tall with a rotating wooden crossbow mount on top, a short blue-painted shield #4C7BD9 on the front, total height 1.1 meters` |
| `bastion_tower_cannon` | 1.0×1.0×1.0 | `a cannon turret, chunky grey stone base with a fat brass-barreled mortar angled upward, an orange powder keg #D97A3C strapped to the side, total height 1.0 meter` |
| `bastion_tower_sniper` | 0.8×1.4×0.8 | `a sniper turret, narrow stone pillar 1.4 meters tall with a long slim brass-barreled rifle on a swivel mount, a blue scope accent #4C7BD9, thin stabilizer legs at the base` |
| `bastion_tower_frost` | 0.9×1.2×0.9 | `a frost turret, grey stone base with a faceted ice-blue crystal #7FD4E8 floating above a brass ring, a ring of small frost shards around the base, total height 1.2 meters` |
| `bastion_tower_tesla` | 0.9×1.3×0.9 | `a tesla turret, grey stone base with a brass coil column and a spherical blue electrode #4C7BD9 on top, three small orbiting spark prongs around the sphere, total height 1.3 meters` |
| `bastion_tower_amplifier` | 0.9×1.0×0.9 | `an amplifier turret, wide grey stone drum with a golden brass horn #E8C56A pointing outward on a swivel, a glowing gold ring around the drum, total height 1.0 meter` |

### 7.3 进攻单位（视图集 A B C）

[CD-22 §5.2](../Confirmed-docs/20-gameplay/22-bastion.md)：单位表**未锁定**。

| 资产 ID | 高 (m) | SUBJECT |
|---|---|---|
| `bastion_unit_runner` | 0.6 | `a small fast ground unit, 0.6 meters tall, low-slung faceted orange beetle-like body #D97A3C with four stubby legs and a pointed head, no weapons, no rider` |
| `bastion_unit_heavy` | 0.9 | `a bulky armored ground unit, 0.9 meters tall, wide blocky dark grey body with orange plating #D97A3C on the shoulders and a low domed back, four thick legs` |
| `bastion_unit_swarm` | 0.35 | `a tiny swarm ground unit, 0.35 meters tall, a cluster of three small faceted orange shells #D97A3C with short legs, designed to appear in groups` |
| `bastion_unit_shield` | 0.8 | `a shielded ground unit, 0.8 meters tall, blocky grey body carrying a large blue hexagonal energy shield plate #4C7BD9 on its front, stubby legs` |
| `bastion_unit_support` | 0.7 | `a support ground unit, 0.7 meters tall, slim grey body with a golden brass emitter dish #E8C56A on its back and a small glowing ring at the base` |
| `bastion_unit_boss` | 1.6 | `a boss ground unit, 1.6 meters tall, massive faceted dark grey body with thick orange armor plates #D97A3C, a violet core crystal #8E6BC8 set into the chest, four heavy pillar legs, no weapons, no face` |

### 7.4 互设障碍（视图集 A B C）

[CD-22 §4.2](../Confirmed-docs/20-gameplay/22-bastion.md)：障碍表**未锁定**。

| 资产 ID | 尺寸 (m) | SUBJECT |
|---|---|---|
| `bastion_obstacle_barricade` | 0.9×0.7×0.6 | `a wooden barricade obstacle, chunky dark timber fence section 0.9 meters wide and 0.7 meters tall with orange painted cross braces #D97A3C and stone foot blocks` |
| `bastion_obstacle_slow_field` | 1.0×0.1×1.0 | `a slowing ground field tile, flat one meter square plate with a raised ice-blue hexagonal grid #7FD4E8 and a recessed dark grey border` |
| `bastion_obstacle_shield_pillar` | 0.4×1.2×0.4 | `a shield pillar obstacle, slender grey stone column 1.2 meters tall topped with a floating blue hexagonal energy plate #4C7BD9 and a brass collar` |
| `bastion_obstacle_divert_gate` | 1.2×0.9×0.4 | `a divert gate obstacle, low stone arch 1.2 meters wide and 0.9 meters tall with a one-way orange chevron slab #D97A3C mounted above the opening, open passage beneath` |
| `bastion_obstacle_jammer_base` | 0.7×0.6×0.7 | `a jammer pedestal obstacle, squat dark grey hexagonal base 0.7 meters wide with a violet emitter node #8E6BC8 and three short brass antenna prongs` |
| `bastion_obstacle_fog_zone` | 1.0×1.2×1.0 | `a fog zone marker, low grey stone brazier one meter wide with a pale translucent grey-white vapor column rising 1.2 meters, solid faceted shell, no fire`（**透明件，见 §10.3**） |

---

## 8. 文件与命名

参考图与 GLB 建议落盘在**仓库外**的本地工作目录，避免把大二进制推进 Git；GLB 入库时走 Git LFS（C4 第 1 章验收要求「第一个 `.glb` 入库且 LFS 正常」）。

```text
<workdir>/                        # 不入库
├─ ref/                           # 参考图
│  └─ traprush_crate/
│     ├─ traprush_crate__a_three_quarter.png
│     ├─ traprush_crate__b_front.png
│     ├─ traprush_crate__c_side.png
│     └─ prompt.txt               # 该资产实际使用的完整提示词与 seed
└─ glb/
   └─ traprush_crate.glb
```

- 资产 ID 用 `snake_case`，与 [CD-21 §7 / CD-22 §5](../Confirmed-docs/20-gameplay/21-traprush.md) 的白名单对象名对齐；
- 视图后缀固定为 `__a_three_quarter` / `__b_front` / `__c_side` / `__d_top`；
- 每个资产目录存一份 `prompt.txt`，记录**实际完整字符串 + seed + 出图工具版本**。没有这份记录，三个视角漂移后无法复现。

---

## 9. 未决事项与风险

按宪法第五条，下列事项**没有默认答案**，AI 不得自选：

| # | 事项 | 阻塞什么 | 建议 |
|---|---|---|---|
| 1 | BASTION 色板（D4 空白） | §7 全部提示词 | M6/M7 解冻前补答即可 |
| 2 | 玩家**视觉**高度 | 角色构图与相机距离 | 权威胶囊是 0.125 格（约 12.5 cm）而视觉占位是 1 m 盒，二者**必须分离**（C4 第 2 章）。本手册按 0.9 m 构图，最终以资产契约为准 |
| 3 | 玩法主题（工坊车间 / 砖石黄铜） | `{THEME}` 串 | 与色板一起拍板 |
| 4 | 面数 / 贴图 / draw call 预算 | §10 的导出参数 | 归入 C4 第 3 章性能预算表 |
| 5 | 是否重新引入描边 | 风格前缀 | D8 已决定纠偏期不做，美术定型后专项评估 |
| 6 | **生成式模型输出物的授权与商用边界** | 是否可以把这些 GLB 发布 | 宪法第十八条：新依赖与许可证属人类门禁。**未评估前不得把这些资产当作可发布内容** |
| 7 | 参考图工具的许可与数据条款 | 出图 | 同上 |

---

## 10. TRELLIS 2 侧参数与导入要点

### 10.1 运行环境事实（来自上游 README，非本项目决策）

- 仅 Linux；需 ≥ 24 GB 显存的 NVIDIA GPU（上游在 A100 / H100 验证）；
- 输出：`512³`（约 3 s）/ `1024³`（约 17 s）/ `1536³`（约 60 s）；
- 可导出带 PBR（base color / roughness / metallic / opacity）的 GLB。

### 10.2 导出参数起点（待 C4 第 3 章拍板）

| 规模 | `decimation_target` | `texture_size` |
|---|---|---|
| 小件（道具、箱、单位） | 1,500 – 3,000 | 512 |
| 中件（地形块、机关、门、塔） | 3,000 – 6,000 | 1024 |
| 角色 / 首领 | 8,000 – 12,000 | 1024 |

网格简化后必须回看：TRELLIS 2 的简化会削掉「低多边形硬边」，与 §4.1 的风格前缀冲突，必要时降低 `decimation_target` 或改在 Blender 里手工重拓扑。

### 10.3 三个必踩的坑

1. **GLB 默认 OPAQUE**：上游导出保留 alpha 通道但不启用透明。`energy_wall`、`fog_zone`、传送门能量面必须手工把贴图 alpha 接到 opacity，或直接改用 Godot 内的半透明面片 + shader；
2. **PBR 与 Compatibility 基线**：宪法第七条要求核心可读性不依赖 Forward+。导入后统一转 `StandardMaterial3D`，`metallic = 0`、`roughness = 1`，风格完全靠 albedo 分区与明度差实现（与 D8「不描边」一致）；
3. **参考图里的高光会被烤进贴图**：G-SUFFIX 已禁强高光；若生成结果仍有明显高光块，说明提示词被工具改写，需人工剔除后重出。

### 10.4 每张参考图的自检（出图后立刻做）

- [ ] 单一物体，未被裁切，未贴边；
- [ ] 背景是纯中性灰，无跨背景长投影；
- [ ] 无文字、数字、logo、水印、可辨识 IP；
- [ ] 无强高光、无反射地面；
- [ ] 同资产各视角间：造型一致、配色一致、比例一致；
- [ ] 造型没有影响通行的悬挑（宪法第五条：视觉网格不是碰撞体，但视觉误导会毁掉可读性）。

### 10.5 每个 GLB 的入库自检

- [ ] 单位 = 米，1 格 = 1 m；
- [ ] 原点位置符合 §5.2，正面朝 -Z，Y-up；
- [ ] 面数在 §10.2 区间内；
- [ ] 材质已收敛为 albedo 为主，`metallic = 0`、`roughness = 1`；
- [ ] 透明件已按 §10.3 处理；
- [ ] 视觉网格**未**被当作碰撞体引用（碰撞由 `GameplayAssetVersion` 的白名单形状表达）；
- [ ] 已入 Git LFS，导入检查通过。

---

## 11. 维护规则

1. 改动本文件前先确认所有者文档是否已变更：`placeholder_spec.gd` 改色值 → 同步 §5.1；CD-21 / CD-22 白名单变更 → 同步 §6 / §7；
2. §9 中的任何一条被人类拍板后，**从本文件删除**并写入对应的所有者文档，不得在本文件里追加「已于某日拍板」的历史层；
3. 新增资产类别必须先在 `Confirmed-docs/` 的白名单里存在对应条目，否则先走范围评审（宪法第一条）。
