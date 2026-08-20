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

定点数的单位尺度、舍入方式、溢出检查与三角函数策略**未锁定**，见 [CD-63](../60-plan/63-open-decisions.md)。

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

各玩法允许的具体 Intent 列表见 [CD-21 §8](../20-gameplay/21-traprush.md) 与 [CD-22 §7.3](../20-gameplay/22-bastion.md)。
