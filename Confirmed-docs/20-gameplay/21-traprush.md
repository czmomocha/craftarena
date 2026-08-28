# CD-21 玩法一《机关狂奔》TRAPRUSH

> 文档 ID：CD-21
> 单一事实源：TRAPRUSH 的玩法定位、体验支柱、视角与操作、地图与传送、障碍与道具、单局流程与排序、可编辑范围、网络与仿真基线
> 加载建议：仅在改动 TRAPRUSH 相关内容时读取。改 BASTION 请读 [CD-22](22-bastion.md)
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第二、五条
> 相关：[CD-31 UGC 原则](../30-ugc/31-ugc-principles.md)、[CD-42 数据契约](../40-technical/42-contracts-and-rulevm.md)、[CD-43 网络与回放](../40-technical/43-networking-and-replay.md)、[CD-63 开发期决策清单](../60-plan/63-open-decisions.md)
> 派生自：初稿 v0.2 §8–§16

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

- 斜 45°软跟随镜头；
- 移动按世界方向映射；
- 镜头自动朝当前导航目标调整；
- 镜头只在区块切换或传送时自动调整并做短过渡；
- 多层地图使用楼层颜色、方向箭头和轮廓高亮增强可读性；
- 不依赖自由旋转镜头才能判断路线。

### 3.2 基础操作

| 操作 | PC / Web 键鼠 | 移动端触屏 |
|---|---|---|
| 移动 | WASD | 虚拟摇杆 |
| 短跳 / 自动跨小台阶 | Space | 主动作键 |
| 基础推击 | 鼠标键 / 独立键 | 推击键 |
| 使用道具 | E / 鼠标键 | 道具键 |
| 交互 | F | 交互键 |
| 重置到检查点 | 长按 R | 长按重置键 |

一期 PC/Web 不承诺手柄支持。

### 3.3 权威运动模型

采用直立式完整 XYZ kinematic 模型：角色可以移动和短跳，但始终直立，只允许水平朝向，不支持二段跳、攀爬、自由飞行、翻滚、墙面或天花板行走。

移动、扫掠、推挤和击退由定点 `SimulationCore` 按稳定顺序解算。Godot 物理只允许承担受控静态查询和表现，不决定竞速结果。

实现落点（2026-08-26）：权威下落。`TraprushMatchSession.fall_dy` 默认 0（2 人 Headless 冲线夹具不走路板，不能默认下落）。对局进程 / Solo 占位 `-Fixed.SCALE / 16`（与大厅 `play_move_step` 同量；引擎 ~60 tick/s 时一格每 tick 会在约 8 帧内触发出界复位）。Preview 壳占位 `-Fixed.SCALE`（手动 Advance tick）。经已有 `try_move_y_until_blocked` 直到固体，不是产品重力加速度。会话 `commit_tick` 先下落再 `world.tick`（与灰盒相同）。`MatchRealtime.commit_tick` 把下落与 `world.tick` 拆开，中间按到达顺序应用排队意图，避免同一拍 Jump 被立刻落下。Preview 只在 `try_advance_play` 下落，意图不推进 tick。纯下落不续租。不铺官方沿路地板。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

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

实现落点（2026-08-26）：周期机关编进 v1 拓扑。`SimulationBundle` 必含 `hazards` 数组（可空）。袋为 `entity_id` / `x` / `y` / `z` / `cooldown_ticks`（已有 `hazard` 组件字段，当半周期，不发明 `period`，不编 `damage` / `knockback`）。`TraprushTopologyCompiler` 把带 `hazard`+`transform` 的实体编进去；缺 transform、或与检查点/传送/终点/可破坏同实体则整份拒绝。加载为固体静态盒（tick 0 落在固体半周期）。`TraprushHazardCycle` 在对局 `commit_tick` 与 Preview `try_advance_play` 于 `world.tick()` 之后按 `((tick_index / cooldown_ticks) % 2) == 0` 切换固体（`cooldown_ticks < 1` 始终固体）。意图不推进 tick，故不切换。切回固体不挤出、不伤害。官方三张赛道各 1 个机关。Preview 壳 **Advance tick** 调用已有 `try_advance_play`。大厅与 Preview 表现映射见下一段。不锁产品秒数、预警动画、伤害/击退。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

实现落点（2026-08-26）：周期机关表现映射。`MatchHazardMap` 把编译袋 `hazards` 画成 1 米占位盒（洋红 `HAZARD_ALBEDO`）；显隐跟同一 `is_solid(快照 tick, cooldown_ticks)`，不改协议。固体半周期计入本席 overlay 的 `live_solid_boxes`（半长 `cell/2`，与箱子相同）。`AuthoringPreviewMap` 对 `hazard` 实体用同一色；开玩后非固体隐藏。HUD 写 `hazards=n/m`（固体数 / 编译袋总数）。官方赛道各 1 个。不锁预警动画、产品秒数。落点见 [CD-12 §1](../10-product/12-product-structure.md#1-入口结构)、[CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览) 与 [CD-43 §2](../40-technical/43-networking-and-replay.md#2-传输)。

实现落点（2026-08-26）：固定固体占用。`SimulationBundle` 必含 `solids` 数组（可空）。袋为 `entity_id` / `x` / `y` / `z`。`TraprushTopologyCompiler` 把 `zone.tags` 含 `solid` 且有 `transform` 的实体编进去（`SOLID_ZONE_TAG`，与 `finish` 同一套 `zone.tags`，不新增 Component Schema 字段）；缺 transform、或与检查点/传送/终点/可破坏/机关同实体、或同一实体同时带 `finish`+`solid` 则整份拒绝。加载为始终固体静态盒，不随 tick 切换。大厅 `MatchSolidMap` 画石色 1 米占位（`SOLID_ALBEDO`），永远显示；计入本席 overlay 的 `live_solid_boxes`（半长 `cell/2`）。Preview 对 `zone.tags` 含 `solid` 的占位同一色。HUD 写 `solids=n/m`（编译袋数，永不切换故 n=m）。官方三张赛道各 1 个 solid（出生点 −X）。Jump 接地位移用合成固体袋单测，官方赛道起点格仍无立足固体、不改 Preview `play_support_dy` 默认 0。不锁编辑器 Place finish、重力/下落。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)、[CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点) 与 [CD-43 §2](../40-technical/43-networking-and-replay.md#2-传输)。

实现落点（2026-08-26）：编辑器占用摆放。`TraprushEditorPanel` 用已有 EDIT `place` 摆固定固体（`zone.tags` 含 `solid`）、周期机关（已有 `hazard`，`cooldown_ticks=1` 开发桩）与可破坏箱（已有 `destructible`，耐久 1 开发桩）。不新增 `op`，不新增 Component Schema 字段。Editor / Preview 占位盒分石色 / 洋红 / 橙色。不锁产品秒数、预警动画、伤害/击退、重力/下落。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)。

实现落点（2026-08-26）：官方赛道占用。三张官方 TRAPRUSH 赛道各含 1 个始终固体（entity 70，出生点 −X 一格，`zone.tags` 含 `solid`）与 1 个周期机关（entity 60，出生点 −Z 两格，已有 `hazard`，`cooldown_ticks=1` 开发桩；两格避开双人 Shove 邻域落点）。不挡 +X 必经检查点路，不改检查点/传送/终点/箱子布局。不锁产品秒数、预警动画、伤害/击退、重力/下落。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)。

实现落点（2026-08-26）：官方赛道立足固体与 Jump。三张官方课各加 entity 80：出生点正下一格（`y = -cell`）的始终固体，不挡 +X 必经路，不改检查点/传送/终点/箱子/−X 固体/−Z 机关。对局 / Solo / Preview 壳 `support_dy = -Fixed.SCALE`（与灰盒相同，向下探测）；`jump_dy` 为 `Fixed.SCALE / 4` 占位桩（一格 hop 会与 `course_01` 出生点正上方 `two_way` 盒闭区间相交并落地）。出生点 Jump 接地 hop。在线 overlay `play_jump_dy` 仍为 0（不叠假跳跃）。不锁产品跳跃高度、预警动画。权威下落见 [§3.3](#33-权威运动模型)。落点见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)。

### 5.2 障碍破坏

- 可破坏障碍具有服务端权威 `health`；
- 玩家普通撞击不能直接摧毁障碍；
- 必须使用爆破、钻头、冲击或地图机关；
- 障碍破坏后产生明确碎裂反馈，但碎片只做表现，不进入权威物理；
- 是否重生、重生时间和重生次数由白名单参数控制；
- 破坏不得导致地图彻底不可达；
- 重要竞速门只允许状态切换，不允许永久删除；
- 可破坏障碍存在于共享权威世界：一名玩家摧毁后，所有玩家都能利用打开的路线。

### 5.3 道具（首批原型候选）

以下**不是**已锁定的正式道具表。正式清单与数值见 [CD-63](../60-plan/63-open-decisions.md)。

| 道具 | 作用 | 主要用途 |
|---|---|---|
| 护盾 | 抵消一次机关伤害或击退 | 稳定通过高危段 |
| 冲刺 | 短距离加速，不穿墙 | 抢时间 |
| 爆破球 | 对前方可破坏障碍造成高伤害 | 开路 |
| 钻头 | 短时间持续破坏接触障碍 | 连续清障 |
| 相位器 | 短时间穿过指定相位门 | 路线选择 |
| 机关脉冲 | 暂停附近周期机关一个短周期 | 控制时机 |

约束：

- 道具可造成短眩晕、减速或有限击退，但不直接扣除玩家生命；
- 连续受控后提供短暂无控保护；
- 道具拾取、使用、冷却和命中由服务端裁决；
- 道具栏数量、替换与叠加规则**未锁定**，列入 [CD-63](../60-plan/63-open-decisions.md)；
- 所有玩家的基础推击独立于拾取道具；
- 生成点和刷新间隔受内容预算限制；
- 刷新点固定可见，每局由服务端种子从该点白名单中确定道具轮换和时间；
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

环境失败后无限复活，返回最近检查点并承受固定复活硬直；不因生命次数淘汰。

实现落点（2026-08-28）：复活硬直 **1.0 s**（纠偏 D5）。对局进程 / Solo / BotRunner 从 `TraprushPlayStubs` 注入：`RESPAWN_STUN_MS = 1000`，按 `PHYSICS_TICKS_PER_SECOND_PLACEHOLDER = 60`（当前引擎 physics，**不是** [CD-43 §4](../40-technical/43-networking-and-replay.md#4-未锁定项) 产品 Tick）换成 60 个会话 tick。出界与踩实心机关复位后写入 `stun_remaining`，每 `advance_sim_tick` 减 1；硬直中拒绝 Move / Jump / UseItem / Shove / Sprint，允许 ResetToCheckpoint。Preview 手动 Advance 不是墙钟，仍用 `PREVIEW_RESPAWN_STUN_TICKS = 1`。快照帧不含 stun 字段（不改协议）；线上靠权威拒意图 + 新快照硬贴。不锁 Tick Hz。

实现落点（2026-08-26）：出界复位。`TraprushOutOfRangeReset` 在调用方 AABB（闭区间：边界上算出界为假）外把胶囊写回已有 `CheckpointSpawn.pose_for`（尚无进度则回起点）。对局 `TraprushMatchSession` 与 Preview `AuthoringPreview` 共用该模块；会话默认 `range_enabled=false`，对局进程 / Solo / Preview 壳打开开发桩半宽 `STUB_HALF = 8 * Fixed.SCALE`（±8 格），不是产品场地。先复位再占用扫描，避免踩到范围外的垫再弹回该垫。进度不回退。不计数掉出次数 N，不接重力/下落。该句中「不写复活硬直」被上文 2026-08-28 硬直落点覆盖。空区间（min > max）拒绝。灰盒磁带路径不改委托。

### 6.1 排序优先级

1. 已冲线玩家按服务端冲线 Tick；
2. 未冲线玩家按已完成检查点数量；
3. 检查点相同时按到下一强制检查点的合法路径距离；
4. 仍相同时按更早到达当前检查点者优先；
5. 离线试玩只显示本地结算，不上传。

实现落点（2026-08-25）：`TraprushStanding` 用最新快照的 `finish_tick` / `accepted_count` 做直播名次板（第 1、2 条 + 槽位次序作为稳定键）。第 3、4 条（合法路径距离、到达当前检查点时间）v1 快照没有字段，走路可达仍待，本刀不锁。第 5 条：大厅离线单人试玩只显示本地直播名次，HUD 持续「离线试玩，成绩不上传」，不上传、不结算写。全部配置玩家冲线后，`TraprushMatchSettlement` 用同一套第 1、2 条排序生成写库 payload；控制面 `POST /match-sessions/:matchId/settlement` 写一次（MatchHost 活场心跳即可写，停止前再 POST）。大厅只读 GET 面板。名次板仍是表现。落点见 [CD-13 §3](../10-product/13-account-and-session.md#3-离线单人模式)、[CD-13 §4](../10-product/13-account-and-session.md#4-单局排名)、[CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点) 与 [CD-43 §2](../40-technical/43-networking-and-replay.md#2-传输)。

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

编辑器必须提供：

- 网格吸附与楼层切换；
- 传送连接可视化；
- 检查点顺序可视化；
- 可达性检测；
- 障碍预算和动态实体预算；
- Undo/Redo；
- 一键本地预览；
- 一键启动 1 个 Headless + 2～4 个客户端；
- 从报错直接定位到对象或规则节点。

吸附格、楼层查询、传送连线分类、发布前通路/循环、Preview Patch、共同 AuthoringDocument、Preview 窗口宿主、3D 占位映射、传送连线可视化、检查点顺序可视化、可达性叠加、内部开发编辑外壳、编辑窗口 3D 映射、TRAPRUSH 工具面板（检查点 / 传送门 / Place solid / Place hazard / Place crate / Place finish / 删除 / 楼层）、验证器详情（从报错定位）、三张官方赛道 JSON 与内部开发 EditorPlugin 与本地草稿恢复与 Preview 试玩与 Preview 试玩 MoveIntent 与 Preview 试玩检查点占用验收与 Preview 试玩传送占用落地与 Preview 试玩冲线占用与 Preview 试玩重置到检查点与 Preview 试玩 UseItemIntent 可破坏占用与 Preview 试玩 JumpIntent 接地跳跃与 Preview 试玩权威下落的数据落点见 [CD-32 §2](../30-ugc/32-editor-and-preview.md#2-草稿持久化与协同) 与 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)。对局进程多人仿真循环（无网络）落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。走路可达仍待。通用编辑器框架与预览行为见 [CD-32](../30-ugc/32-editor-and-preview.md)。

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
| 弱网门禁 | 香港真实样本形成前不设自动"可玩性"门禁 |

客户端只能发送：

```text
MoveIntent
JumpIntent
ShoveIntent
UseItemIntent
InteractIntent
ResetToCheckpointIntent
```

客户端不得发送最终位置、冲线结果、障碍死亡、道具命中和检查点完成断言。

实现落点（2026-08-26）：对局会话 `MOVE_STEP_MAX = Fixed.SCALE`。Move 任一轴绝对值超过该上限则整条拒绝，不裁剪成合法位移。这堵住「一条命令走出许多格」的位置伪造；不是产品速度，也不改大厅 `play_move_step`。Preview 试玩仍走 `IntentStepper`，不经此门。

实现落点（2026-08-26）：对局基础推击。命令 `intent_id=5` 为 `ShoveIntent`，保留字段仍须为零，无线上目标 id。`TraprushMatchSession` 在 `SHOVE_REACH_MAX = Fixed.SCALE` 的 XZ/Y 邻域内选最近其它胶囊（切比雪夫，平手再曼哈顿，再低席位），沿 XZ 远离施术者用调用方 `shove_step` 经已有 `TraprushShoveApply` 推开；冷却为调用方 `shove_cooldown_ticks`。`shove_step` 超过 `SHOVE_STEP_MAX` 或为负则整条拒绝。对局进程占位桩 `shove_step = SCALE/4`、冷却 1 tick，不是产品力度。大厅 **F** 上升沿编码；Solo 只有一枚胶囊，无目标。推击不进本席 overlay。Interact 仍不接线。Preview 仍拒绝 Shove。

实现落点（2026-08-26）：出界复位见 [§6](#6-胜负与排名)。对局 Move/Jump/Reset 步进后、传送早退、Shove 推中目标后、以及 `commit_tick` 在 `world.tick()` 之后、占用扫描之前，调用同一模块。Preview 试玩同样先复位再占用。

实现落点（2026-08-26）：周期机关见 [§5.1](#51-障碍分类)。对局 `advance_sim_tick` 在 `world.tick()` 之后经 `TraprushHazardCycle` 切换固体，再做出界复位与占用扫描；lease 比较仍在 tick 前。意图不推进 tick。官方赛道各 1 个机关。

实现落点（2026-08-26）：权威下落见 [§3.3](#33-权威运动模型)。`MatchRealtime.commit_tick` 先 `apply_player_falls`，再应用排队意图，再 `advance_sim_tick`。Solo `_process` 先 `try_advance` 再采样空格。Preview 意图不下落。

实现落点（2026-08-25）：在线大厅本席 `MatchLocalPredict` 只叠加已有 Move/Jump 的 Q48.16 位移到最新权威位姿；本席不插值。更新的快照 tick 硬贴权威（不是平滑对账）。传送、重置、道具、冲线不预测。预测位姿若与最新活箱或最新远端胶囊或最新固体周期机关重叠，本帧不叠 overlay（权威胶囊/箱/机关几何，不是 1 米表现盒）；远端不外推。垫 / 门 / 终点不是固体。在线 `play_jump_dy` 仍为 0（不叠假跳跃 overlay）；对局进程 `jump_dy` 已是 Preview 占位桩，`support_dy = -Fixed.SCALE`。官方赛道出生点正下一格有立足固体，权威 Jump 接地 hop。在线 `play_jump_dy` 仍为 0（不叠假跳跃 overlay）。对局进程 UseItem 伤害/触达与 Preview 对齐，官方 `course_01` 出生点可打碎 +Z 箱。大厅 SnapshotCamera 跟随本席表现位姿（线上预测 overlay / Solo 本地权威），偏移与 Preview 相同；远端不拉镜头。大厅 WASD 把 8 向离散水平 `yaw_bam` 写入已有 Move 命令（W=0 为世界 -Z；省略哨兵仍是 -1，0 是合法朝前）；线上 overlay 立即改本席朝向，Solo 走本地权威；立方体玩家盒加 local -Z 面向标记。不发明 atan2，不锁产品转向速度，不改 Preview WASD。大厅 `follow_slot` 把本席玩家盒涂成 `OWN_ALBEDO`（青），远端仍 `REMOTE_ALBEDO`；名次标本席前缀 `*`。不是产品皮肤或槽位色盘。大厅用本席 `accepted_count` 给检查点垫分色（已验收 / 当前目标 / 未到）；未开玩保持原垫色。大厅用本席 `finish_tick` 给终点分色（未到金 / 垫齐后当前目标 / 已冲线暗金）；HUD 写 `pads=n/m`、`floor=n`（本席权威 `y / Fixed.SCALE` 向零）、`finish=n`、`crates=n/m`（活着的箱 / 编译袋总数）与 `hazards=n/m`（固体机关 / 编译袋总数），快照全员 `finish_tick>=0` 时加 `result=`。线上全员冲线后大厅 GET 控制面结算记录，200 后 HUD 加 `settled=`；Solo 不 GET。R 上升沿把已有 ResetToCheckpointIntent 接到可见复位（传送后回到最近已验收垫，进度不回退）。不是走路可达、合法路径距离或结算写库。客户端不 POST。落点见 [CD-43 §2](../40-technical/43-networking-and-replay.md#2-传输) 与 [CD-12 §1](../10-product/12-product-structure.md#1-入口结构)。

实现落点（2026-08-26）：开发机运行窗与空格。大厅/Preview 动作按钮 `FOCUS_NONE`，空格走已有 `jump`，不点 Solo play / Play。项目运行窗默认 1600×900 最大化，Traprush/Preview 窗默认 1280×720 最大化。不是产品镜头/FOV。落点见 [CD-12 §1](../10-product/12-product-structure.md#1-入口结构) 与 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)。

网络故障正确性与手感一期只进行临时人工测试，不设固定频率或自动门禁。该选择**不代表**协议已经具备弱网鲁棒性；真实香港样本形成后再定义目标。若可靠传输队头阻塞被实测证明影响 TRAPRUSH，再评估原生 ENet 或 WebRTC，不能提前维护两套传输。
