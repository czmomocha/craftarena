# CD-21 玩法一《机关狂奔》TRAPRUSH

> 文档 ID：CD-21
> 单一事实源：TRAPRUSH 的玩法定位、体验支柱、视角与操作、地图与传送、障碍与道具、单局流程与排序、可编辑范围、网络与仿真基线
> 加载建议：仅在改动 TRAPRUSH 相关内容时读取。改 BASTION 请读 [CD-22](22-bastion.md)
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第二、五条
> 相关：[CD-31 UGC 原则](../30-ugc/31-ugc-principles.md)、[CD-42 数据契约](../40-technical/42-contracts-and-rulevm.md)、[CD-43 网络与回放](../40-technical/43-networking-and-replay.md)、[CD-63 开发期决策清单](../60-plan/63-open-decisions.md)
> 派生自：初稿 v0.2 §8–§16

## 当前生效值

> 本节覆盖而非追加。覆盖链见 [CD-91 D.3 / D.8](../90-reference/91-decision-log.md)。

| 项 | 当前口径 |
|---|---|
| 一期最小道具 | **爆破球 + 冲刺**（纠偏 D5）。服务端裁决拾取 / 使用 / 命中；伪造命中被拒。其余候选未锁 |
| 机关伤害 / 击退 | C3 已接：固体半周期占用重叠才命中；击退后仍重叠则环境失败复位。不读 Authoring `damage` / `knockback` |
| 复活硬直 | **1.0 s**。不锁 Tick Hz。对局 / Solo 按占位 60 physics tick/s → 60 tick；Preview 仍 1 次 Advance |
| 重力 | 权威定点积分。对局 / Solo 跟 physics tick；Preview 只在 Advance 下落 |
| 出界 | 开发桩 ±8 格，不是产品场地 |
| 输入 | 壳消费 `PlayInput`。当前键：WASD / Space / F 推击 / Q 使用 / Shift 冲刺 / R 复位（上升沿，不是产品长按）。触控 UI 未做（D7） |
| Tick / 快照 / 插值 | **未锁**（[CD-43 §4](../40-technical/43-networking-and-replay.md)）。不得用 ICMP 锁定 |
| 官方课 | 4 张。04 = 垂直塔（电梯 + 弹射 + 压板，考验上下层）。第 5 张属 M5 C2。F 线示范课 `course_f_playable` **不计入**该计数。revision 12：危险捷径 +X 只挡能量墙（站其 −Z 侧 Q 打碎），周期机关在 −Z 侧廊；安全路 +Z。官方 01–03 侧廊已接深化段新机关，不挡既有捷径 / 安全路脚本 |
| 描边 | 不做（D8） |
| 传送带 | 可玩性深化已接：固体 + `zone.tags` 含 `conveyor` + `transform.yaw_bam`（四向）。**不新增组件**。占位步长是走路占位步长的两倍 ⇒ 逆行走不回去。示范课 revision 12 安全路外侧 z=+3 有三块；官方 `course_01` 侧廊 z=+6 有一块。数值仍属 [CD-63 §1.3](../60-plan/63-open-decisions.md) |
| 电梯 | 可玩性深化已接：竖直 `mover` + `zone.tags` 含 `lift`。**不另开袋、不新增组件**。路径必须纯 Y，否则编译拒绝。水平往返仍走已有 mover。占位速度 `SCALE/16` |
| 弹射垫 | 可玩性深化已接：固体 + `zone.tags` 含 `launch` + `transform.yaw_bam`（四向）。支撑**上升沿**弹一次：竖直 `LAUNCH_DY = JUMP_DY * 2`，水平送出一格。与 conveyor / mover 同实体则编译拒绝。数值仍属 [CD-63 §1.3](../60-plan/63-open-decisions.md) |
| 开关门 | 可玩性深化已接**踩区**：固体 + `zone.tags` 含 `switch` / `gate` + 已有 `interactable.link_group`。开合是当前占用的纯函数，不写 `state`、不进快照。走开同一拍关上。`InteractIntent` 仍未接线 |
| 开关传送 | 可玩性深化已接**踩区**：传送占用 + `zone.tags` 含 `portal_switch` + 已有 `interactable.link_group`。未列入可选 `portal_switches` 袋的门永远可传。关上时不落地。走开同一拍关上。`InteractIntent` 仍未接线 |
| 能量墙 | 可玩性深化已接：可破坏占用 + `zone.tags` 含 `energy_wall`。`SimulationBundle` 加可选 `energy_walls` 袋（省略 ≡ 空）。打碎走已有 UseItem。权威碰撞仍是一格盒 |
| 地刺 | 可玩性深化已接：固体 + `zone.tags` 含 `spike`。被支撑才环境失败（hazard）。可选 `spikes` 袋只带 `entity_id` |
| 喷火 | 可玩性深化已接：周期机关 + `zone.tags` 含 `flame`。永远非固体；半周期开时重叠才烫。可选 `flames` 袋只带 `entity_id` |
| 压板 | 可玩性深化已接：竖直 `mover` + `zone.tags` 含 `crusher`。重叠且不是乘客 ⇒ crush。可选 `crushers` 袋只带 `entity_id` |
| 滚柱 | 可玩性深化已接：周期机关 + `zone.tags` 含 `roller`。半周期固体挡路。可选 `rollers` 袋只带 `entity_id`。Place 用 cooldown 30 |
| 碎石 / 障碍核心 | 可玩性深化已接：可破坏占用 + `rubble` / `obstacle_core`。可选 `rubbles` / `obstacle_cores` 袋只带 `entity_id`。打碎走已有 UseItem |
| 摆锤 | 可玩性深化已接：水平 `mover` + `zone.tags` 含 `pendulum`。重叠且不是乘客 ⇒ crush。可选 `pendulums` 袋只带 `entity_id` |
| 冰面 | 可玩性深化已接：固体 + `zone.tags` 含 `ice` + `transform.yaw_bam`。支撑时按走路步长滑。可选 `ices` 袋带方向 |
| 道具栏 HUD | 可玩性深化已接：Solo / Preview 显示爆破球 / 冲刺持有数与失败次数。**不进快照帧**，线上读不到 |
| 碎裂反馈 | 可玩性深化已接：可破坏占用离开 live set 时喷占位碎片。纯表现，不进权威 |
| 楼层着色 | 可玩性深化已接：普通固体按楼层偏绿 / 品红。机关占位不染色 |
| 压板 / 摆锤预警 | 可玩性深化已接：gadget 按 tick 缩放。喷火 / 滚柱仍走半周期预警盒 |
| 失败原因读数 | 可玩性深化已接：服务端记 `hazard` / `out_of_range` / `crushed` 与发生 tick。**不进快照帧、不进 `hash_state`**，所以只有 Solo / Preview 读得到；线上要读须先做协议不兼容变更（宪法第十八条） |
| 寻路指示 | 可玩性深化已接：下一个目标 = `order == accepted_count` 的垫，全验收后是终点。方向按**屏幕**八向给（相机 D4 斜 45°），不按世界轴。纯表现读出 |
| HUD 计时 | F 线 FA：局时 = `tick/60`；过垫分段为客户端记忆，不进权威；冲线冻钟。结算表画已有 `rows[]` / `mvp_slot`，贴在窗口右上。字号从 `placeholder_spec` 读。Solo 本地 `try_build`，在线仍只 GET |
| 跳跃 / 重力 | **已接线**（可玩性深化覆盖 F 线 snappy）：`JUMP_DY = SCALE/4`，`FALL_DY = -SCALE/32`，约 8 拍到顶、峰值约 1.125 格。同层 hop 镜头冻高度。Preview Advance 与对局同一加速度 |

## 1. 玩法定位

**1～8 人轻 3D 道具避障竞速 + 玩家推挤对抗 + 立体传送关卡工坊。**

玩家在一张由多层区块、机关、可破坏障碍和传送节点组成的地图中竞速。路线不仅向前延伸，还可以通过传送门、电梯、弹射器和切换节点在上下层与左右区块之间移动。玩家依靠走位和道具规避危险，也可以摧毁部分障碍创造捷径。

原生端与 Web 规则一致，最多 8 人；Web 只能降低特效、阴影和资源精度，不能降低房间人数或改变玩法规则。在线单人房仍使用权威服务器。

## 2. 核心体验支柱

1. **移动清楚**：玩家始终知道当前目标方向和可走路径；
2. **路线有选择**：安全路线更慢，危险路线或破坏路线更快；
3. **障碍可读**：所有危险机关都有明显预警；
4. **道具有决策**：道具既能保命，也能开路；
5. **传送有空间感**：传送能连接上、下、左、右区块，但不能让检查点失序；
6. **失败惩罚轻**：死亡或坠落主要损失时间，不直接淘汰；
7. **玩家冲突非致命**：玩家有实体碰撞、阻挡和推挤，道具可造成短眩晕、减速或有限击退，但不直接扣血；
8. **硬卡口可成立但可破局**：系统不做自动相位或防堵，允许单人封住唯一通道；所有玩家拥有低强度、长冷却的基础推击。

## 3. 视角与操作

### 3.1 视角

- 斜 45°软跟随镜头：XZ 逐帧对齐；同层 hop 冻结跟随高度；换层落地或乘电梯（仍接地）才改 Y；
- 滚轮在默认距离上走近 / 拉远（8–20 m），中键拖移水平平移（≤4 m）；不改方位角与俯角；
- 移动按世界方向映射；
- 镜头自动朝当前导航目标调整；
- 传送 / 出界复位的跳变走短滑行；默认距离 / FOV 不改；
- 多层地图使用楼层颜色、方向箭头和轮廓高亮增强可读性；
- 不依赖自由旋转镜头才能判断路线。

### 3.2 基础操作

| 操作 | PC / Web 键鼠 | 移动端触屏 |
|---|---|---|
| 移动 | WASD | 虚拟摇杆 |
| 短跳 / 自动跨小台阶 | Space | 主动作键 |
| 基础推击 | 独立键（当前 F） | 推击键 |
| 使用道具 | 独立键（当前 Q） | 道具键 |
| 冲刺 | 独立键（当前 Shift） | 未做 |
| 重置到检查点 | R（产品表是长按；当前是上升沿桩） | 长按重置键 |

一期 PC/Web 不承诺手柄支持。玩法壳消费 `PlayInput`（方向向量 + 上升沿），键盘是适配器。从 Godot 编辑器 Tools 打开时编辑器 InputMap 没有玩法动作，回退到与 `project.godot` 同一套物理键（不往编辑器 InputMap 塞动作）。触控 UI / 虚拟摇杆仍未做（D7）。落点 `game/src/shared/play_input.gd`。

### 3.3 权威运动模型

采用直立式完整 XYZ kinematic 模型：角色可以移动和短跳，但始终直立，只允许水平朝向，不支持二段跳、攀爬、自由飞行、翻滚、墙面或天花板行走。

移动、扫掠、推挤和击退由定点 `SimulationCore` 按稳定顺序解算。Godot 物理只允许承担受控静态查询和表现，不决定竞速结果。

权威下落已接线：对局 / Solo 跟 physics tick，Preview 只在 Advance。默认 `fall_dy = 0`（2 人 Headless 冲线夹具不走路板）。形状见 [CD-32 §3](../30-ugc/32-editor-and-preview.md) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md)。口径见文首。

### 3.4 表现动画状态

一期角色网格没有 `skin`。纠偏 C4 产出 4 只锁**状态名与优先级**，让绑定动画有固定入口，而不是各壳自己猜「什么叫落地」。

| 状态 | 何时 | 不是 |
|---|---|---|
| `idle` | 接地、没水平输入 | 待机循环时长 |
| `run` | 接地且有水平输入；冲刺并进这里 | 产品跑速 |
| `jump` | `airborne` | 跳跃高度 / 重力秒数 |
| `land` | 上一拍 airborne、本拍不是 | 落地硬直 |
| `shove` | 本拍权威 shove 成功 | 产品力度 |
| `hit` | `stun_remaining > 0`（环境失败硬直） | 受击闪白 |
| `break` | 本拍权威 UseItem 打碎箱子 | 破坏特效 |
| `portal` | 传送门闩非空 | 镜头过渡 |

`airborne` = 接触探针（半格）未踩到固体，**或** `vy != 0`。优先级（高→低）：`hit` > `portal` > `land` > `jump` > `shove` > `break` > `run` > `idle`。单一状态。裁决落点 `game/src/shared/play_anim_state.gd`。

**视觉驱动已接线**（路线 A，人类 2026-09-05 拍板）：`game/src/shared/play_anim_visual.gd` 把裁决结果接到角色 `visual` 节点——`idle` / `run` / `hit` / `portal` 播 GLB 内置 clip，`jump` / `land` / `shove` / `break` 用程序化姿态偏移补，两张表恰好覆盖八态。角色资产同日换为 `animal-cat.glb`（Kenney Cube Pets，CC0，7 网格 / 0 skin / 684 面），因为此前的生成产物是静态网格、没有 `AnimationPlayer`。`hit` 用 `gesture-negative`、`portal` 用 `dance` 是**语义近似**，属路线 A 已接受的折衷。姿态角度与升降是占位数值，未定稿；不引入时间轴、clip 间无 blend，**动画时长与过渡仍属 [CD-63](../60-plan/63-open-decisions.md)**。缺 `AnimationPlayer` 或缺 clip 名一律降级为静止，不报错。

**角色贴合**（2026-09-07）：`fit_character_on_cell` 按资产 AABB 等比缩到 `CHARACTER_VISUAL_CELL_SPAN` 格宽、水平居中、脚底落在权威胶囊底面。此前角色是唯一没有贴合规则的资产类别。姿态叠加在贴合后的基准上（含 scale），两侧经 `character_base_transform` 同源读取，否则起跳会抹掉缩放。占格比例是表现占位值，所有者是 [CD-11 §8.2](../10-product/11-scope-and-platforms.md)。视觉不参与裁决，权威胶囊仍是 0.125 格。

**只在 Solo 与 Preview 接线**：v1 快照没有 `vy` / `stun_remaining` / 库存，在线远端算不出 `airborne` 与 `hit`。接它要改协议帧（宪法第十八条），因此在线席位保持静止是预期行为，不是遗漏（**贴合不受此限**，三条壳一致）。第三方资产条款归档见 `game/content/assets/ATTRIBUTION.md`；入库范围仍待人类拍板。

## 4. 地图传送与立体移动

### 4.1 地图结构

地图由可寻址区块组成：

```text
Track
├─ Segment A（中层）
├─ Segment B（上层）
├─ Segment C（下层）
├─ Segment D（左侧捷径）
└─ Segment E（右侧安全路）
```

每个区块通过普通通道或 `portal_link` 连接。传送目标可以位于：

- 同层前后区块；
- 左右平行路线；
- 上层平台；
- 下层地下区；
- 回环支路；
- 单向捷径。

### 4.2 传送规则

- 传送门必须成对或指向明确的单向出口；
- 每个出口具有稳定 ID、朝向和安全落点；
- 玩家必须经过有序检查点，传送不能跳过未完成的强制检查点；
- 传送由服务端确认，不做客户端权威预测；
- 出口被占用时等待确定性安全落点，不赋予自动相位穿透；出口外仍允许合法堵路；
- 传送链长度有上限，禁止无限循环；
- 编辑器实时显示传送连线、方向和可达性；
- 发布前验证所有必经路径至少存在一条完整通路。

UGC 权威碰撞形状约束见 [CD-42](../40-technical/42-contracts-and-rulevm.md)：只允许盒、球、胶囊和平台预制的少量复合体，视觉网格不参与碰撞裁决。

## 5. 障碍与道具

### 5.1 障碍分类

| 类别 | 示例 | 处理方式 |
|---|---|---|
| 固定不可破坏 | 墙、深坑、边界 | 绕行、跳跃或传送 |
| 周期机关 | 压板、摆锤、滚筒、喷火口 | 观察预警并择机通过 |
| 可破坏障碍 | 木箱、能量墙、碎石、障碍核心 | 普通攻击机制或道具削减耐久 |
| 触发型障碍 | 门、移动平台、开关链 | 交互、踩区或规则图触发 |

当前实现：`hazards` 袋按 `cooldown_ticks` 半周期切固体；`solids` 袋始终固体（编译进 `gates` 的门在占用打开时非固体）；官方三张课仍各有出生点 −Z 周期机关、−X 一格固体、正下一格立足固体。第十八批在侧廊接了深化段机关（01 冰 / 传送带 / 开关门，02 喷火 / 滚柱 / 地刺，03 弹射 / 电梯 / 压板 / 摆锤 / 开关传送），不挡既有捷径。编辑器 Place solid / hazard / crate / finish / mover / conveyor / lift / launch / switch / gate / energy wall / gated portal / spike / flame / crusher / roller / rubble / core 走已有 `place`。形状见 [CD-32 §3](../30-ugc/32-editor-and-preview.md) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md)。口径见文首。

「触发型障碍」这一行已交付移动平台、传送带、电梯、弹射垫、踩区开关门与开关传送：

- **移动平台**（`mover`）：位姿是 tick 的纯函数，载客跟随；
- **传送带**（可玩性深化）：一块固体 + `zone.tags` 的 `conveyor` 标签 + `transform.yaw_bam`。判据是**支撑**而非重叠（传送带是固体，胶囊只会站在它上面）；同时被多块支撑时只认 `entity_id` 最小的一块，否则合力取决于遍历顺序、回放会分叉。方向量化到四向：斜推会让「我会被带到哪一格」在定点网格上不可预读。
- **电梯**（可玩性深化）：竖直 `mover` + `zone.tags` 的 `lift`。不另开 bundle 袋。`lift` 无 `mover` 或路径含水平段 → 编译拒绝。水平往返仍走 Place mover。
- **弹射垫**（可玩性深化）：一块固体 + `zone.tags` 的 `launch` 标签 + `transform.yaw_bam`。支撑上升沿弹一次（竖直走已有 `apply_jump`，水平沿四向送出一格）；站着不连弹，走开再踩才再弹。与 conveyor / mover 同实体拒绝。
- **踩区开关门**（可玩性深化）：开关与门都是固体 + `switch` / `gate` 标签 + 已有 `interactable.link_group`。一组打开当且仅当有胶囊被该组开关支撑，或有胶囊与该组门盒相交（含当前非固体的门）。走开同一拍关上；关在身上按 crush 复位。与 conveyor / launch / mover 同实体拒绝。不新增组件。
- **能量墙**（可玩性深化）：可破坏占用 + `zone.tags` 的 `energy_wall`。几何和耐久在 `destructibles`，可选 `energy_walls` 袋只带 `entity_id`。打碎走已有 UseItemIntent，不改爆破半径。权威碰撞仍是一格盒；程序化半透板只是表现。与 solid / conveyor / launch / switch / gate / lift 同实体拒绝。
- **开关传送**（可玩性深化）：传送占用 + `zone.tags` 的 `portal_switch` + 已有 `interactable.link_group`。几何在 `portals`，可选 `portal_switches` 袋只带 `link_group`。未列入袋的传送门行为不变。关上时重叠也不落地。占用规则与开关门同一套：被该组开关支撑，或与该组**门**盒相交。传送门自己的占用**不会**把组打开——否则走进去永远能传。与 solid / conveyor / launch / switch / gate / energy_wall / lift 同实体拒绝；悬空带 tag 整份拒绝。
- **地刺**（可玩性深化）：固体 + `zone.tags` 的 `spike`。几何在 `solids`，可选 `spikes` 袋只带 `entity_id`。被该盒**支撑**才环境失败（hazard）。与 conveyor / launch / switch / gate / lift / crusher / flame 同实体拒绝。
- **喷火**（可玩性深化）：已有周期机关 + `zone.tags` 的 `flame`。几何在 `hazards`，可选 `flames` 袋只带 `entity_id`。盒子永远非固体（预测不当墙）；半周期「开」时重叠 ⇒ 环境失败。与滚柱的差别是挡路 vs 穿过去会被烫。与 solid / conveyor / launch / switch / gate / lift / spike / crusher / energy_wall 同实体拒绝。
- **压板**（可玩性深化）：竖直 `mover` + `zone.tags` 的 `crusher`。几何在 `solids`，竖直路径在 `movers`，可选 `crushers` 袋只带 `entity_id`。重叠且不是该盒乘客 ⇒ crush。路径必须纯 Y，否则编译拒绝。与 conveyor / launch / switch / gate / lift / spike / flame 同实体拒绝。
- **滚柱**（可玩性深化）：已有周期机关 + `zone.tags` 的 `roller`。几何在 `hazards`，可选 `rollers` 袋只带 `entity_id`。半周期固体挡路（与喷火相反）。与 flame 同实体拒绝。Place 用 cooldown 30。未打 tag 的旧 hazard 行为不变。
- **碎石 / 障碍核心**（可玩性深化）：可破坏占用 + `rubble` / `obstacle_core`。几何和耐久在 `destructibles`，可选袋只带 `entity_id`。打碎走已有 UseItem。与 energy_wall 同实体拒绝。权威仍是一格盒。
- **摆锤**（可玩性深化）：固体 + 水平 `mover` + `zone.tags` 的 `pendulum`。几何在 `solids`，路径在 `movers`，可选 `pendulums` 袋只带 `entity_id`。重叠且不是乘客 ⇒ crush。路径必须纯水平，否则编译拒绝。与压板（纯 Y）互斥。
- **冰面**（可玩性深化）：固体 + `zone.tags` 的 `ice` + `transform.yaw_bam`。几何在 `solids`，可选 `ices` 袋带方向。支撑时按走路步长滑（可逆走相消、可侧向走下）。与 conveyor / launch / mover 同实体拒绝。

**`InteractIntent` 仍未接线。** 命令帧新增 intent id、快照帧新增开合状态都是协议不兼容变更（宪法第十八条）。本刀开合不进快照；线上表现用快照位姿重算，可能与权威差一拍。锁存 / 延时关门未做。

### 5.2 障碍破坏

- 可破坏障碍具有服务端权威 `health`；
- 玩家普通撞击不能直接摧毁障碍；
- 必须使用爆破、钻头、冲击或地图机关；
- 障碍破坏后产生明确碎裂反馈，但碎片只做表现，不进入权威物理（可玩性深化：`MatchCrateBreak`，约 0.35 s）；Preview 开玩后耐久为 0 的箱子隐藏；
- 是否重生、重生时间和重生次数由白名单参数控制；
- 破坏不得导致地图彻底不可达；
- 重要竞速门只允许状态切换，不允许永久删除；
- 可破坏障碍存在于共享权威世界：一名玩家摧毁后，所有玩家都能利用打开的路线。

### 5.3 道具（一期最小集已锁）

纠偏 D5（2026-08-26）锁定一期最小集。**不是**完整道具表；其余候选与槽位规则仍见 [CD-63](../60-plan/63-open-decisions.md)。

| 道具 | 一期地位 | 作用 |
|---|---|---|
| 爆破球 | **已锁** | 对前方可破坏障碍造成伤害；服务端裁决拾取 / 使用 / 命中 |
| 冲刺 | **已锁** | 短距离加速，不穿墙；`SprintIntent` |
| 护盾 / 钻头 / 相位器 / 机关脉冲 | 仍是候选 | 未锁 |

约束：

- 道具可造成短眩晕、减速或有限击退，但不直接扣除玩家生命；
- 连续受控后提供短暂无控保护（**未接线**，仍属 CD-63）；
- 道具拾取、使用、冷却和命中由服务端裁决；
- 道具栏数量、替换与叠加规则**未锁定**；
- 所有玩家的基础推击独立于拾取道具；
- 小游戏端可以减少道具视觉效果，但规则不能变化。

## 6. 单局流程

| 阶段 | 时长规则 | 内容 |
|---|---|---|
| 内容握手 | 系统控制 | 校验基础内容哈希、补丁序列、规则版本和运行时版本 |
| 地图巡览 | 创作者白名单参数 | 展示主路线、终点或自定义目标、关键传送节点 |
| 竞速 | 创作者定义，不设内容级硬上限 | 移动、推挤、道具、避障、破坏、传送 |
| 终止判定 | 默认冲线，可组合 | 到达终点、掉出范围 N 次等白名单有界条件的与/或组合 |
| 结算 | 系统控制 | 展示本局名次、检查点、失败次数和道具使用 |

玩法内容不限制局时；基础设施侧的可续租会话与无活动回收规则见 [CD-44](../40-technical/44-deployment.md)。

环境失败后无限复活，返回最近检查点并承受固定复活硬直；不因生命次数淘汰。硬直秒数与出界桩见文首。

### 6.1 排序优先级

1. 已冲线玩家按服务端冲线 Tick；
2. 未冲线玩家按已完成检查点数量；
3. 检查点相同时按到下一强制检查点的合法路径距离；
4. 仍相同时按更早到达当前检查点者优先；
5. 离线试玩只显示本地结算，不上传。

v1 直播名次只用第 1、2 条 + 槽位稳定键。第 3、4 条走路可达仍待。写库与大厅 GET 见 [CD-13 §4](../10-product/13-account-and-session.md)。

默认结束规则是到达终点。创作者可以使用白名单事件、变量和有界计数组合自定义结束条件，但规则图必须至少存在一个可触发终止分支。机器人在验证预算内未触发结束时只标记"未验证可完成"，不阻止自动公开。

## 7. Edit 模式可编辑范围

创作者可以编辑：

- 起点、终点和检查点；
- 地形块、坡道、桥、上下层区块；
- 普通通道与传送连接；
- 周期机关和触发机关；
- 可破坏障碍及耐久；
- 道具刷新点；
- 机关参数和触发链；
- 人数上限（不得超过 8）；
- 默认终点或受限自定义结束规则；
- 可选玩法时长参数，不设平台内容级硬上限；
- 表现材质槽和环境主题。

一期白名单对象建议：

```text
地形：block_static / block_slope / bridge / floor_marker
流程：spawn_grid / finish_line / checkpoint_gate
移动：platform_mover / conveyor / lift / launch_pad
传送：portal_two_way / portal_one_way / portal_switch
机关：spike / crusher / roller / flame / gate / switch
障碍：crate / energy_wall / rubble / obstacle_core
道具：pickup_shield / pickup_dash / pickup_bomb / pickup_drill
```

编辑器必须提供网格吸附、楼层切换、传送/检查点可视化、可达性、预算、Undo/Redo、本地预览、从报错定位。数据落点见 [CD-32](../30-ugc/32-editor-and-preview.md)。走路可达仍待。

## 8. 网络与仿真基线

| 项目 | 已确认边界 |
|---|---|
| 传输 | 原生端与 Web 一期统一 WebSocket |
| 编码 | 版本化二进制命令与快照 Schema |
| 玩家数 | 原生端与 Web 均为 1～8 人 |
| 权威数值 | 定点整数；自定义 kinematic 胶囊、扫掠与稳定顺序解算 |
| 本地预测 | 自身移动、短跳，以及与远端外推胶囊的碰撞 |
| 服务端校正 | 返回权威位置和冲量，客户端平滑对账 |
| 不由客户端裁决 | 传送、破坏、道具效果、冲线、控制效果 |
| Tick/快照频率 | 开发期根据实测决定，本文不锁定 |
| 弱网门禁 | 不得用 ICMP 设自动「可玩性」门禁 |

客户端只能发送：

```text
MoveIntent
JumpIntent
ShoveIntent
UseItemIntent
SprintIntent
InteractIntent
ResetToCheckpointIntent
```

客户端不得发送最终位置、冲线结果、障碍死亡、道具命中和检查点完成断言。Move 超一格整条拒绝（防瞬移，不是产品速度）。Interact 仍未接线（开关门走踩区，不读 InteractIntent）。

网络故障正确性与手感一期只进行临时人工测试，不设固定频率或自动门禁。该选择**不代表**协议已经具备弱网鲁棒性。
