# CD-42 数据契约、Rule VM 与命令模型

> 文档 ID：CD-42
> 单一事实源：Component Schema v1、定点数与碰撞形状约束、Rule VM v1 节点与 gas、命令分类与字段、服务端命令处理管线
> 加载建议：改动组件、Schema、规则节点、命令字段或服务端校验顺序时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第三、四、五、十七、十八条
> 相关：[CD-41 架构](41-architecture.md)、[CD-43 网络与回放](43-networking-and-replay.md)、[CD-31 UGC 原则](../30-ugc/31-ugc-principles.md)
> 派生自：初稿 v0.2 §34–§36

## 1. Component Schema v1

首版共享组件：

| 组件 | 关键字段 | 用途 |
|---|---|---|
| `transform` | 定点 XYZ 位置、水平朝向 | 两玩法 |
| `velocity` | 定点速度 | TRAPRUSH |
| `health` | 当前值、最大值、无敌 Tick | 障碍、单位、核心 |
| `team` | TeamId | 所有权 |
| `score` | 单局统计 | 结算 |
| `zone` | 形状、标签过滤 | 触发与查询 |
| `spawner` | 原型、间隔、上限 | 道具和兵线 |
| `hazard` | 伤害、击退、冷却 | TRAPRUSH |
| `mover` | 路径、速度、循环 | 平台与机关 |
| `interactable` | 状态、链接组 | 开关和门 |
| `checkpoint` | 顺序、复活偏移 | TRAPRUSH |
| `portal` | 目标 ID、方向、冷却 | TRAPRUSH |
| `destructible` | 耐久、重生策略 | TRAPRUSH |
| `inventory` | 道具状态；槽位语义待定 | TRAPRUSH |
| `path_agent` | waypoint、速度、赏金 | BASTION |
| `build_slot` | 白名单、占用者 | BASTION |
| `tower` | 等级、射程、冷却、目标策略 | BASTION |
| `replication` | 复制策略 | 两玩法 |

字段的英文标识符、JSON 形状与校验落点见 [§1.2](#12-字段标识符v1)。槽位语义、具体数值和复制策略表仍见 [CD-63](../60-plan/63-open-decisions.md)，不得从本表自行补全。

### 1.1 数值与碰撞约束

- 核心位置、速度、计时、经济和伤害统一使用**有明确尺度与溢出规则的 64 位定点整数**；表现层在边界转换为 Godot 浮点；
- UGC 权威碰撞只允许盒、球、胶囊和平台预制复合体，视觉网格不能参与裁决；
- UGC 数据中禁止出现 `NodePath`、`Callable`、`Object` 和 `Script`。

定点数合同（[ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md)，2026-08-21 整包拍板）：

| 项 | 锁定值 |
|---|---|
| 空间 / 速度 | `SCALE = 65536`（2^16）内部单位 = 表现层 1 Godot 米；存储 int64（Q48.16） |
| 经济 / 伤害 / 耐久 | 尺度 1 的 int64（1 金 = 1，1 点伤害 = 1） |
| 时间间隔 | Tick 计数；Hz 仍见 [CD-63](../60-plan/63-open-decisions.md) 第 1.5 条 |
| 水平朝向 | BAM：`65536 = 一周` |
| 舍入 | 向零截断，与 GDScript 整数 `/` 一致 |
| 溢出 | 拒绝该次运算，不饱和、不回绕成合法值 |
| 乘法 | 64×64→128 再除；禁止先算 `a * b` 再除 |
| 三角函数 | 4096 项整数 LUT + BAM 索引 + 整数线性插值；禁止引擎 `sin`/`cos` |

实现：`game/src/shared/fixed/`。`float` 换算只允许出现在 `game/src/client/` 与后续 creator 表现映射，不得进入 `shared/` / `simulation/`。

### 1.2 字段标识符（v1）

本节冻结 **Component Schema v1** 的英文字段名与 JSON 形状。尺度与形状约束仍以 [§1.1](#11-数值与碰撞约束) 为准，不在此复述定点合同。实体袋的 wire 形状是：

```text
schema_version = 1
entity_id      正整数稳定 ID
components     以组件名为键的对象；未知键拒绝；允许空袋
```

每个组件 `additionalProperties = false`。权威碰撞 `kind` 只能是 `box` / `sphere` / `capsule` / `platform_prefab`。位置、速度、偏移、路径点、`attack_range`、`knockback`、`speed` 为 §1.1 的空间定点整数；`current` / `maximum` / `durability` / `damage` / `bounty` 为尺度 1 整数；时间字段为 Tick 计数；`yaw_bam` 为 BAM。禁止 `float`、`NodePath`、`Callable`、`Object`、`Script`。

| 组件 | 字段 |
|---|---|
| `transform` | `x`, `y`, `z`, `yaw_bam` |
| `velocity` | `vx`, `vy`, `vz` |
| `health` | `current` ≥ 0，`maximum` ≥ 1，`invuln_ticks` ≥ 0 |
| `team` | `team_id` ≥ 0（0 为空） |
| `score` | `tallies`：字符串键 → 整数。不锁具体统计项 |
| `zone` | `shape`（见上 `kind`），`tags`（非空字符串数组） |
| `spawner` | `prototype_id` ≥ 1，`interval_ticks` ≥ 0，`max_alive` ≥ 0 |
| `hazard` | `damage` ≥ 0，`knockback`，`cooldown_ticks` ≥ 0 |
| `mover` | `path`（`{x,y,z}` 数组），`speed`，`loop`（bool） |
| `interactable` | `state` ≥ 0，`link_group` ≥ 0（0 为未分组） |
| `checkpoint` | `order` ≥ 0，`respawn_dx`, `respawn_dy`, `respawn_dz` |
| `portal` | `target_id` ≥ 1，`yaw_bam`（方向落为水平朝向，与 CD-21 出口朝向一致），`cooldown_ticks` ≥ 0 |
| `destructible` | `durability` ≥ 0，`regen_policy_id` ≥ 0（0 为空；策略表未锁） |
| `inventory` | 仅 `item_state`（CanonicalPayload）。**不**含槽位数/替换/放弃/叠加；见 [CD-63](../60-plan/63-open-decisions.md) §1.1 |
| `path_agent` | `waypoints`（`{x,y,z}` 数组），`speed`，`bounty` ≥ 0 |
| `build_slot` | `whitelist`（原型 ID 数组），`occupant_id` ≥ 0（0 为空） |
| `tower` | `level` ≥ 1，`attack_range`，`cooldown_ticks` ≥ 0，`target_priority` ∈ `front` / `nearest` / `strongest` / `weakest`（[CD-22 §5.1](../20-gameplay/22-bastion.md)） |
| `replication` | `policy_id` ≥ 0（0 为空；策略表未锁，[CD-43](43-networking-and-replay.md) 未命名模式） |

`box` 另需 `hx`/`hy`/`hz`；`sphere` 需 `radius`；`capsule` 需 `radius` 与 `cylinder_height`（与 `KinematicCapsule` 同名）；`platform_prefab` 需 `prefab_id` ≥ 1。

## 2. Rule VM v1

首版规则图先从下列通用节点起步，具体节点数由纵向切片验证，不作为产品承诺。

发布服务将规则图编译为带 `ruleset_version` 的**版本化字节码**；客户端与服务端执行同一套静态类型 GDScript 解释器。禁止运行时直接遍历任意 JSON 图、生成 GDScript 或动态加载脚本。

### 2.1 节点

```text
Event      OnMatchStarted / OnEveryTicks / OnEnteredZone / OnEntityDied / OnVariableThreshold
Query      GetVariable / GetField / CountInZone
Condition  Compare / Logic
Action     SetVariable / Spawn / Despawn / ApplyEffect / EmitGameEvent
```

### 2.2 gas 预算

每条字节码指令有固定 gas 成本；空间查询按结果数收费。单图、单实体、单规则链、单 Tick 都有预算。

超预算时**中止该内容逻辑**并生成可定位错误，不允许拖垮对局进程。

## 3. 命令模型

### 3.1 分类

```text
PlayerCommand  玩家输入或玩法操作
EditCommand    内容编辑
AdminCommand   受权限的开发、测试和运营操作
SystemCommand  服务端内部操作
```

### 3.2 公共字段

所有命令至少包含：

```text
command_id
actor_id
sequence
target_tick
expected_revision
content_version
payload
trace_id
```

### 3.3 服务端处理管线

```text
鉴权
→ Schema 校验
→ 所有权校验
→ 时序与频率校验
→ 玩法语义校验
→ 排入目标 Tick
→ 事务应用
→ 产生 DomainEvent
→ 复制、回放与审计
```

各玩法允许的具体 Intent 列表见 [CD-21 §8](../20-gameplay/21-traprush.md) 与 [CD-22 §7.3](../20-gameplay/22-bastion.md)。名字的代码落点是 `game/src/shared/commands/player_intent_names.gd`。

EDIT 命令必须带白名单 `op`：`place` / `remove` / `set_component`。这三项覆盖摆放、删除和改组件。未知 payload 键拒绝。网格、楼层、传送连线、发布前可达性、AuthoringDocument、Preview Patch、Preview 窗口、3D 占位映射、传送连线 gizmos、检查点顺序 gizmos、可达性叠加、编辑外壳、编辑窗口 3D 映射与 TRAPRUSH 工具面板（含 Place solid / Place hazard / Place crate / Place finish） **不是**新 `op`：带 `transform` 的袋必须落在 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览) 的吸附格上；`portal.target_id` 在 AuthoringWorld 上分类为连线；通路/循环在 `evaluate_reachability` 上检查；桌面与 Web 交换同一份 AuthoringDocument 快照；Preview 用同一套 `op` 在安全点应用到独立会话；桌面 Preview 窗口由 `AuthoringPreviewShell` 托管；窗口内 `AuthoringPreviewMap` 把带 `transform` 的实体画成 1 米占位盒，并把 `portal_links()`、检查点 `order` 与发布前问题码画成表现 gizmos；`AuthoringEditorShell` 把 UI 按钮变成同一套 `op`，并挂同一套 map 按 AuthoringWorld 重建；成功写入（含 Undo / Redo）把同一条 `op` 按 Preview 世界算出的等级转发给已连接的 Preview，转发被拒只脱同步、不回滚编辑；`TraprushEditorPanel` 把检查点、传送门、删除与楼层按钮变成同一套 `op`（楼层只改下一次 `cell_y`）；`AuthoringValidatorPanel` 只读 `evaluate_reachability` 列出问题码，Focus 对焦有 `transform` 的实体，不是新 `op`，不是写入门禁。三张官方赛道 JSON 也不是新 `op`。内部开发 EditorPlugin 也不是新 `op`。本地草稿恢复也不是新 `op`。编辑写入自动进 Preview 也不是新 `op`。TRAPRUSH 拓扑编译也不是新 `op`。Preview 试玩也不是新 `op`。Preview 试玩 MoveIntent 也不是新 `op`。Preview 试玩检查点占用验收也不是新 `op`。Preview 试玩传送占用落地也不是新 `op`。Preview 试玩冲线占用也不是新 `op`。Preview 试玩重置到检查点也不是新 `op`。Preview 试玩 UseItemIntent 可破坏占用也不是新 `op`。

| `op` | payload |
|---|---|
| `place` | `record`：完整 [§1.2](#12-字段标识符v1) 实体袋。目标 `entity_id` 必须尚未存在。 |
| `remove` | `entity_id` ≥ 1。目标必须已存在。 |
| `set_component` | `record`：完整实体袋，整袋替换。目标必须已存在。 |

Undo / Redo 是会话内对成功命令派生的反向 payload（`place`↔`remove`，`set_component` 恢复该实体上一份袋），**不**新增第四个 `op`。转发给 Preview 时复用同一份派生 payload，由 `peek_undo_payload` / `peek_redo_payload` 只读取出。失败的 `try_apply` 不写入、不 bump revision。每次成功修改（含撤销重做）生成新 revision，不回退计数。解码与会话落点见 [§3.4](#34-实现落点)。

### 3.4 实现落点

不复述字段。GDScript 信封与组件袋在：

| 内容 | 路径 |
|---|---|
| 稳定 ID | `game/src/shared/ids/shared_ids.gd` |
| 命令信封 | `game/src/shared/commands/shared_command.gd` |
| EDIT op 名 | `game/src/shared/commands/edit_op_names.gd` |
| EDIT payload 解码 | `game/src/creator/edit_payload.gd` |
| AuthoringWorld | `game/src/creator/authoring_world.gd` |
| AuthoringGrid | `game/src/creator/authoring_grid.gd` |
| 传送连线分类名 | `game/src/creator/authoring_portal_kinds.gd` |
| 发布前可达性 | `game/src/creator/authoring_reachability.gd` |
| 可达性问题码 | `game/src/creator/authoring_reachability_codes.gd` |
| AuthoringSession | `game/src/creator/authoring_session.gd` |
| AuthoringPreview | `game/src/creator/authoring_preview.gd` |
| Preview 补丁等级名 | `game/src/creator/preview_patch_levels.gd` |
| Preview 宿主种类 | `game/src/creator/authoring_preview_host_kinds.gd` |
| AuthoringPreviewShell | `game/src/creator/authoring_preview_shell.gd` |
| AuthoringPreviewMap | `game/src/creator/authoring_preview_map.gd` |
| Preview 目视沙箱 | `game/src/creator/preview_sandbox.tscn` |
| AuthoringEditorShell | `game/src/creator/authoring_editor_shell.gd` |
| AuthoringEditorPluginHost | `game/src/creator/authoring_editor_plugin_host.gd` |
| 内部开发 EditorPlugin | `game/addons/authoring_editor/plugin.cfg` |
| AuthoringDraftStore | `game/src/creator/authoring_draft_store.gd` |
| TraprushEditorPanel | `game/src/creator/traprush_editor_panel.gd` |
| AuthoringValidatorPanel | `game/src/creator/authoring_validator_panel.gd` |
| 编辑外壳目视沙箱 | `game/src/creator/editor_sandbox.tscn` |
| 官方赛道目视沙箱 | `game/src/creator/course_sandbox.tscn` |
| 第二张官方赛道目视沙箱 | `game/src/creator/course_02_sandbox.tscn` |
| 第三张官方赛道目视沙箱 | `game/src/creator/course_03_sandbox.tscn` |
| AuthoringDocument | `game/src/creator/authoring_document.gd` |
| 第一张官方 TRAPRUSH 赛道 | `game/content/official/traprush/course_01.json` |
| 第二张官方 TRAPRUSH 赛道 | `game/content/official/traprush/course_02.json` |
| 第三张官方 TRAPRUSH 赛道 | `game/content/official/traprush/course_03.json` |
| SimulationBundle | `game/src/ugc/simulation_bundle.gd` |
| TRAPRUSH 拓扑编译 | `game/src/ugc/traprush_topology_compiler.gd` |
| TRAPRUSH 拓扑加载 | `game/src/games/traprush/traprush_topology_loader.gd` |
| 周期机关固体切换 | `game/src/games/traprush/hazard_cycle.gd` |
| 对局进程多人仿真循环 | `game/src/games/traprush/match_session.gd`（`fall_dy` 默认 0；boot / Solo 占位 `-SCALE/16`） |
| 对局二进制协议 v1 | `game/src/shared/protocol/match_frame_codec.gd` |
| TRAPRUSH 直播名次 | `game/src/games/traprush/standing.gd` |
| 对局大厅名次表现映射 | `game/src/client/match_standing_map.gd` |
| 对局大厅周期机关表现映射 | `game/src/client/match_hazard_map.gd` |
| 对局大厅固定固体表现映射 | `game/src/client/match_solid_map.gd` |
| 对局大厅离线单人试玩 | `game/src/client/match_offline_session.gd` |
| 对局进程入口 | `game/src/server/match_server.gd` |
| 对局进程实时回路 | `game/src/server/match_realtime.gd` |
| 2 人 Headless 冲线夹具 | `game/src/games/traprush/match_headless_acceptance.gd` |
| TRAPRUSH 单局结算 | `game/src/games/traprush/match_settlement.gd` |
| 实时网关代理 | `backend/realtime-gateway/src/server.ts` |
| 网关进程内 TLS | `backend/realtime-gateway/src/config.ts` |
| 对局票据 HTTP 契约 | `backend/contracts/src/match_ticket.ts` |
| 单局结算 HTTP 契约 | `backend/contracts/src/match_settlement.ts` |
| 对局票据签发/校验 | `backend/control-plane/src/server.ts` |
| 对局重连补票 | `backend/control-plane/src/db/database.ts`（`reconnectTicket`） |
| 官方 TRAPRUSH 赛道 id 与匹配 `seats` | `backend/contracts/src/official_courses.ts` |
| 客户端官方赛道 id 与匹配人数 | `game/src/shared/official_traprush_courses.gd` |
| 对局快照插值 | `game/src/client/match_snapshot_interp.gd` |
| 对局本席移动预测 | `game/src/client/match_local_predict.gd` |
| 匹配 / 房间码 HTTP 契约 | `backend/contracts/src/match_room.ts` |
| 控制面票据校验器 | `backend/realtime-gateway/src/ticket.ts` |
| Preview 试玩 | `game/src/creator/authoring_preview.gd`（`try_start_play` / `try_stop_play` / `try_advance_play` / `try_apply_play_intent` / `try_accept_play_checkpoint` / `try_land_exit` 占用扫门 / `try_cross_play_finish` 占用扫终点 / `ResetToCheckpointIntent` 复活表 / `UseItemIntent` 可破坏占用 / `JumpIntent` 接地跳跃 / `play_fall_dy` 经 `try_move_y_until_blocked` 下落（壳占位 `-SCALE`，每次 Advance 一格） / `TraprushHazardCycle` 周期机关固体切换） |
| UseItem 打箱 | `game/src/games/traprush/destructible_break.gd` |
| 编辑表面名 | `game/src/creator/authoring_surface_names.gd` |
| 领域事件 | `game/src/shared/events/shared_domain_event.gd` |
| 可哈希 payload 白名单 | `game/src/shared/protocol/canonical_payload.gd` |
| 关键状态哈希 | `game/src/shared/protocol/state_hasher.gd` |
| 定点与 BAM | `game/src/shared/fixed/` |
| 组件名 | `game/src/shared/schema/component_names.gd` |
| 碰撞 kind | `game/src/shared/schema/collision_shape_kinds.gd` |
| 炮塔目标优先级 | `game/src/shared/schema/tower_target_priorities.gd` |
| 实体袋校验 | `game/src/shared/schema/component_record.gd` |

JSON Schema 落点：

| 内容 | 路径 |
|---|---|
| 可哈希 payload | `backend/contracts/schemas/canonical_payload.schema.json` |
| 命令信封 | `backend/contracts/schemas/shared_command.schema.json` |
| 领域事件 | `backend/contracts/schemas/shared_domain_event.schema.json` |
| 组件袋 | `backend/contracts/schemas/component_record.schema.json` |
| AuthoringDocument | `backend/contracts/schemas/authoring_document.schema.json` |
| SimulationBundle | `backend/contracts/schemas/simulation_bundle.schema.json` |
| 正反例与校验 | `tools/content-validator/`（由根目录 `npm test` 收集） |

`payload` 只允许 nil / bool / int / String / Array / Dictionary（字符串键）；禁止 float、Object、Callable。PLAYER 命令必须带白名单 `intent` 字符串。EDIT 命令必须带白名单 `op` 字符串，payload 形状见 [§3.3](#33-服务端处理管线)。SYSTEM 命令允许 `actor_id = 0`。Component Schema v1 字段见 [§1.2](#12-字段标识符v1)。AuthoringDocument 字段见 [CD-32 §1.4](../30-ugc/32-editor-and-preview.md#14-共同数据模型)。SimulationBundle v1 字段见本表与 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)「TRAPRUSH 拓扑编译」（含可空 `hazards` 与可空 `solids` 袋）。Preview 试玩、MoveIntent、检查点占用验收、传送占用落地、冲线占用、重置到检查点、UseItemIntent 可破坏占用、JumpIntent 接地跳跃与周期机关固体切换见 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)「Preview 试玩」。对局票据 HTTP JSON Schema 在 `backend/contracts/src/match_ticket.ts`，由控制面 Fastify 路由挂载（含 `POST /match-sessions/:matchId/tickets/reconnect`）。单局结算 HTTP JSON Schema 在 `backend/contracts/src/match_settlement.ts`。Rule VM 图的 JSON Schema 仍未落地。OpenAPI 仍未落地。签名二进制包仍待。
