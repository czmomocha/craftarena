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

### 3.4 实现落点（M1 阶段 A）

不复述字段。GDScript 信封在：

| 内容 | 路径 |
|---|---|
| 稳定 ID | `game/src/shared/ids/shared_ids.gd` |
| 命令信封 | `game/src/shared/commands/shared_command.gd` |
| 领域事件 | `game/src/shared/events/shared_domain_event.gd` |
| 可哈希 payload 白名单 | `game/src/shared/protocol/canonical_payload.gd` |
| 关键状态哈希 | `game/src/shared/protocol/state_hasher.gd` |
| 定点与 BAM | `game/src/shared/fixed/` |

JSON Schema 落点：

| 内容 | 路径 |
|---|---|
| 可哈希 payload | `backend/contracts/schemas/canonical_payload.schema.json` |
| 命令信封 | `backend/contracts/schemas/shared_command.schema.json` |
| 领域事件 | `backend/contracts/schemas/shared_domain_event.schema.json` |
| 正反例与校验 | `tools/content-validator/`（由根目录 `npm test` 收集） |

`payload` 只允许 nil / bool / int / String / Array / Dictionary（字符串键）；禁止 float、Object、Callable。PLAYER 命令必须带白名单 `intent` 字符串。SYSTEM 命令允许 `actor_id = 0`。Component Schema v1 与 Rule VM 图的 JSON Schema 仍未落地。
