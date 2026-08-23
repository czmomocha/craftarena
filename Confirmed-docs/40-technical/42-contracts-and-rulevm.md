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

EDIT 命令必须带白名单 `op`：`place` / `remove` / `set_component`。这三项覆盖摆放、删除和改组件。未知 payload 键拒绝。网格、楼层、传送连线、发布前可达性、AuthoringDocument、Preview Patch、Preview 窗口、3D 占位映射、传送连线 gizmos、检查点顺序 gizmos、可达性叠加、编辑外壳与编辑窗口 3D 映射 **不是**新 `op`：带 `transform` 的袋必须落在 [CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览) 的吸附格上；`portal.target_id` 在 AuthoringWorld 上分类为连线；通路/循环在 `evaluate_reachability` 上检查；桌面与 Web 交换同一份 AuthoringDocument 快照；Preview 用同一套 `op` 在安全点应用到独立会话；桌面 Preview 窗口由 `AuthoringPreviewShell` 托管；窗口内 `AuthoringPreviewMap` 把带 `transform` 的实体画成 1 米占位盒，并把 `portal_links()`、检查点 `order` 与发布前问题码画成表现 gizmos；`AuthoringEditorShell` 把 UI 按钮变成同一套 `op`，并挂同一套 map 按 AuthoringWorld 重建；打开 Preview 不自动跟后续编辑。

| `op` | payload |
|---|---|
| `place` | `record`：完整 [§1.2](#12-字段标识符v1) 实体袋。目标 `entity_id` 必须尚未存在。 |
| `remove` | `entity_id` ≥ 1。目标必须已存在。 |
| `set_component` | `record`：完整实体袋，整袋替换。目标必须已存在。 |

Undo / Redo 是会话内对成功命令派生的反向 payload（`place`↔`remove`，`set_component` 恢复该实体上一份袋），**不**新增第四个 `op`。失败的 `try_apply` 不写入、不 bump revision。每次成功修改（含撤销重做）生成新 revision，不回退计数。解码与会话落点见 [§3.4](#34-实现落点)。

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
| 编辑外壳目视沙箱 | `game/src/creator/editor_sandbox.tscn` |
| AuthoringDocument | `game/src/creator/authoring_document.gd` |
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
| 正反例与校验 | `tools/content-validator/`（由根目录 `npm test` 收集） |

`payload` 只允许 nil / bool / int / String / Array / Dictionary（字符串键）；禁止 float、Object、Callable。PLAYER 命令必须带白名单 `intent` 字符串。EDIT 命令必须带白名单 `op` 字符串，payload 形状见 [§3.3](#33-服务端处理管线)。SYSTEM 命令允许 `actor_id = 0`。Component Schema v1 字段见 [§1.2](#12-字段标识符v1)。AuthoringDocument 字段见 [CD-32 §1.4](../30-ugc/32-editor-and-preview.md#14-共同数据模型)。Rule VM 图的 JSON Schema 仍未落地。OpenAPI 仍未落地。
