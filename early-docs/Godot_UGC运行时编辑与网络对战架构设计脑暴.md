# Godot UGC、运行时编辑与网络对战架构设计脑暴

> 文档定位：基于《Godot 引擎发展现状与 AI 游戏开发生态深度调研报告》，针对“UGC + 快速编辑 + 运行时改状态 + 网络对战”四个诉求进行架构脑暴。本文用于收敛技术方向，不是最终技术规格。
>
> 核心前提：服务器权威、客户端不可信；UGC 只能修改数据驱动、可序列化、可验证、受预算约束的内容，不能在权威进程中执行任意用户代码。
>
> 已确认产品约束：轻 3D + UGC；可接受“核心共享 + 小游戏减配”；一期 PC/Steam、Android、iOS，网页/微信小游戏跟进减配端，鸿蒙 NEXT 二期。客户端锁定 Godot 4 Standard + GDScript，不采用 .NET 版作为共享客户端运行时。

---

## 1. 一句话结论

建议采用：

**Godot 4 Standard（GDScript）表现与编辑层 + 纯数据仿真内核 + 受限 UGC 规则虚拟机 + 权威 Headless Server + 命令/快照网络模型 + 不可变内容版本。**

发布节奏与引擎边界一并锁定：

- **一期**：PC/Steam、Android、iOS 原生导出，同一套 `SimulationCore` 与内容协议。
- **减配跟进**：网页与微信小游戏走官方 HTML5/WASM（GDScript）+ 社区小游戏适配层，内容与规则共享，表现、包体、输入和平台 SDK 降级。
- **二期**：鸿蒙 NEXT（HarmonyOS 5 / OpenHarmony 原生）。Godot 官方尚未合入该平台，不能当 Day-1 硬依赖。
- **不选 Godot 4 .NET 版做客户端**：Godot 4 的 C# 项目不能导出 Web；微信小游戏走的就是这条 WASM 链。C# 若出现，只允许用在未来独立于 Godot 客户端的权威服务器，不得进入共享客户端工程。

最重要的边界不是“是否支持热重载”，而是将热重载拆成两类：

1. **状态热修改**：由服务器接收受权限控制的命令，在安全 Tick 边界修改权威状态。
2. **内容热修改**：编辑中的预览会话可以动态替换规则和关卡数据；正式竞技对局锁定内容版本，只允许预先声明为可调参数的字段变化。

这能同时保留 UGC 的表达能力和原型速度，又不破坏竞技对局的公平性、可重放性与可审计性。

---

## 2. 四个诉求转化为工程约束

| 诉求 | 真正需要的能力 | 不能直接采用的做法 |
|---|---|---|
| UGC | 玩家可组合实体、关卡、参数和规则；内容可上传、校验、发布、下架 | 上传并直接执行 `.gd`、原生扩展、任意 `.pck/.tscn/.tres` |
| 快速编辑 | 编辑命令可撤销/重做；增量校验；无需重启即可预览 | 编辑器数据直接耦合运行时 Node 树 |
| 运行时改状态 | 权威命令、事务应用、安全点切换、变更审计 | 客户端直接写位置、生命、得分或规则变量 |
| 网络对战 | 服务器权威、客户端预测、快照校正、版本锁定 | 客户端裁决命中；依赖跨平台严格一致的 Godot 物理锁步 |

### 2.1 第一性原则

1. **服务器是唯一真相源**：客户端只提交意图，不提交结果。
2. **UGC 是不可信输入**：即使内容来自游戏内编辑器，也必须重新校验。
3. **玩法逻辑与 Godot Node 解耦**：Node 是视图和适配器，不是权威数据本身。
4. **规则必须可停止**：所有循环、查询、生成和调用都有静态上限或运行时预算。
5. **对局版本不可变**：`content_id + version + content_hash + ruleset_version` 在开局时锁定。
6. **编辑和游玩使用同一数据协议**：避免“编辑器看起来能运行，服务器却无法解释”。
7. **先做到服务器权威，再做预测优化**：正确性优先于手感优化。
8. **不追求 Godot 物理的跨平台完全确定性**：服务端裁决，客户端短期预测并接受校正。
9. **共享核心必须能在无 CLR 的客户端上运行**：一期所有会进 PC/移动/网页/小游戏的逻辑用 GDScript 或纯数据；不把 Godot 4 C# 当作跨端语言。
10. **平台差异停在适配层**：登录、支付、分享、输入、画质和包体预算按平台替换；`SimulationCore`、规则图和内容包跨端不变。

### 2.2 明确不做

至少在首个可玩版本中不做：

- 任意 GDScript/C# UGC；
- 运行中的竞技局替换完整规则集；
- 全世界全实体同步；
- 客户端参与权威物理裁决；
- 通用 CRDT 多人实时协同编辑；
- 通用脚本语言、UGC 商店和创作者分成系统；
- 跨平台严格确定性锁步；
- 用 Godot 4 .NET / C# 编写需要导出网页或微信小游戏的客户端逻辑；
- 把鸿蒙 NEXT 或主机平台当作一期上线条件；
- 为了“全平台同一二进制、同一画质”拒绝小游戏减配。

### 2.3 引擎版本与发布平台（已确认）

Godot 4 的 Standard 与 .NET 不是免费版/专业版关系，引擎功能（渲染、物理、场景、原生导出）相同。差别只在：**是否把 .NET 运行时嵌进编辑器和游戏，从而能写 C#。**

| 目标 | 一期策略 | 说明 |
|---|---|---|
| PC / Steam | 官方桌面导出 + GodotSteam | 主阵地，成熟 |
| Android | 官方 APK/AAB | 官方原生导出 |
| iOS | 官方 Xcode 工程 | 需 Mac；C# 移动导出即使存在也标 experimental，本项目不用 |
| 网页 | 官方 HTML5（WASM + WebGL 2） | 仅 Standard / GDScript；渲染基线为 Compatibility |
| 微信小游戏 | Web 导出 + 社区适配插件 | 非官方一等公民；主包、API、输入、登录/广告/支付单独适配 |
| 鸿蒙 4 及更早 | 不作为目标 | 安卓兼容层会随新机退场 |
| 鸿蒙 NEXT | 二期 | 官方未合入；仅存在社区 OpenHarmony 移植 |

**为什么网页/微信“支持 WASM”仍不能用 .NET：** WASM 只是指令格式，不是完整宿主。Standard 网页导出把 Godot C++（含 GDScript 虚拟机）编成**一个主 WASM**；C# 还需要旁边再放一套 CLR/BCL，并与引擎互操作。Godot 4 用 `hostfxr` 从原生进程加载 C#，网页上没有该宿主。更关键的是：Godot 占用 WASM **主模块**，GDExtension 可以当**侧模块**加载，而当前 .NET 打出的 WASM 只能当主程序、不能当可动态链接的侧模块，因此嵌不进 Godot 网页导出。Unity 能上微信，靠的是 IL2CPP 把 C# **变成 C++ 再打进同一个 WASM**，并不是在小游戏里跑 CLR。Godot 3 能上 HTML5 C# 是因为当时嵌 Mono；4.0 换成现代 .NET 后这条能力消失，到 4.7 稳定版仍未恢复。即便将来打通，.NET 运行时数 MB 级体积也与小游戏主包预算冲突。

因此客户端工程约定：

1. 下载并锁定 **Godot 4 Standard**；项目中不创建 `.cs` / `.csproj`。
2. 表现层、输入、编辑器插件、平台适配全部 **GDScript**。
3. 要上小游戏时，以 **Compatibility（WebGL 2）** 为最低渲染基线；PC 可用 Forward+ 作为增强，而不是反过来。
4. 仿真热点若超出 GDScript，优先 **GDExtension** 或把 `SimulationCore` 抽成独立服务器进程，而不是为此把客户端改成 .NET 工程。
5. 微信端必须有 `platform/` 适配：`wx` 登录/分享/支付/文件系统、子包、触控与包体裁剪；这些不得泄漏进 `SimulationCore`。
6. 鸿蒙 NEXT 二期再评估社区导出模板；一期不阻塞主架构。

---

## 3. 总体架构

建议把系统分成三个平面、三种世界。

### 3.1 三个平面

```text
┌──────────────────── 内容生产平面 ────────────────────┐
│ Godot Editor Plugin │ 游戏内编辑器 │ AI 原型助手       │
│        ↓ 统一 EditCommand / Content Schema           │
│ 增量校验 → 本地预览 → 上传 → 构建 → 审核 → 签名发布  │
└──────────────────────────────────────────────────────┘
                         ↓ 不可变内容包
┌──────────────────── 平台控制平面 ────────────────────┐
│ 身份/权限 │ 内容注册表 │ 版本管理 │ 匹配 │ 审核 │ 下架 │
└──────────────────────────────────────────────────────┘
                         ↓ 匹配锁定版本
┌──────────────────── 对局数据平面 ────────────────────┐
│ Client 输入意图 → Authoritative Headless Server      │
│                  固定 Tick 仿真 + UGC Rule VM         │
│ Client ← 快照/增量/事件/校正 ← Server                 │
└──────────────────────────────────────────────────────┘
```

### 3.2 三种世界

| 世界 | 用途 | 数据特性 |
|---|---|---|
| `AuthoringWorld` | 编辑关卡、对象和规则图 | 可变、带编辑元数据、支持撤销重做 |
| `SimulationWorld` | 服务器权威仿真与客户端预测副本 | 紧凑、稳定 ID、固定 Tick、无编辑器依赖 |
| `PresentationWorld` | Godot 场景树、动画、音频、UI | 可丢弃并重建，不作为权威状态 |

关键转换：

```text
AuthoringWorld
   └─ Compile + Validate
       └─ SimulationBundle
           ├─ Server SimulationWorld
           └─ Client Presentation Mapping
```

不要把运行时 Godot 场景树序列化后直接当作 UGC 标准格式。场景树适合表现，不适合作为安全、稳定、可迁移的网络协议。

---

## 4. 分层架构

### L0：共享契约层 `SharedContracts`

不依赖 Godot Node，定义所有跨端稳定概念：

- `EntityId`、`PlayerId`、`TickId`、`ContentId`；
- Component Schema；
- 输入命令、编辑命令、领域事件；
- 快照和增量协议；
- 内容包 Manifest；
- 规则图节点类型和参数类型；
- 错误码、版本号、能力标识。

这是客户端、服务器、编辑器、验证器共同依赖的最小内核。

### L1：纯数据仿真层 `SimulationCore`

职责：

- 固定 Tick 驱动；
- 实体/组件数据存储；
- 移动、战斗、生成、计分、胜负等 System；
- 种子随机数与稳定执行顺序；
- 状态哈希、回放和测试；
- 产生领域事件，不直接播放动画或声音。

建议采用轻量 ECS 思路，但不必一开始引入复杂 ECS 框架。核心要求是：**状态是普通数据，System 是受控函数，表现层只是投影。**

### L2：UGC 内容运行层 `UGCRuntime`

职责：

- 加载经过签名的内容包；
- 实例化实体原型和关卡数据；
- 执行受限规则图/DSL；
- 检查能力清单和每 Tick 预算；
- 生成可定位到规则节点的错误；
- 支持 Schema 迁移和兼容性检查。

### L3：权威对局层 `MatchServer`

职责：

- 房间、玩家和会话管理；
- 接收、排序、验证玩家命令；
- 推进权威 Tick；
- 兴趣管理、快照和增量同步；
- 断线重连和全量恢复；
- 反作弊、限流、审计和回放；
- 锁定并验证内容版本。

原型期可用 Godot Headless Server，与客户端共享 **GDScript** 仿真代码。架构上仍应让 `SimulationCore` 不依赖 SceneTree，以便未来拆成独立服务器进程；若届时用 C#/Go/Rust 写权威服，那是服务器实现选择，**不得反向要求客户端改用 Godot .NET 版**。

### L4：客户端表现层 `GameClient`

职责：

- 采集输入并产生 `PlayerCommand`；
- 本地玩家短期预测；
- 远端对象插值；
- 接收权威快照并校正；
- 将 `SimulationWorld` 映射为 Godot Node；
- 播放非权威动画、音效、粒子和 UI；
- 通过 `platform/` 适配 Steam / 移动商店 / 微信，不把平台 SDK 写进仿真核。

### L5：创作工具层 `CreatorTools`

由两种前端共享同一个编辑模型：

1. **Godot Editor Plugin**：内部策划和开发者使用，拥有更强 Gizmo、批量处理、调试和导入能力。
2. **游戏内编辑器**：UGC 创作者使用，只展示白名单对象、组件和规则节点。

二者都只产生 `EditCommand`，不直接操作发布包。

### L6：内容平台层 `ContentPlatform`

职责：

- 上传隔离区；
- 自动验证、构建和资源转码；
- 内容审核；
- 版本、依赖和签名；
- CDN 分发；
- 灰度、下架和回滚；
- 创作者权限与内容可见性。

---

## 5. 建议的模块划分

```text
src/
├─ shared/
│  ├─ ids/                    # 稳定 ID 与版本类型
│  ├─ schema/                 # Component / Rule / Package Schema
│  ├─ commands/               # PlayerCommand / EditCommand / AdminCommand
│  ├─ events/                 # DomainEvent
│  └─ protocol/               # Snapshot / Delta / Ack / Handshake
├─ simulation/
│  ├─ world/                  # 纯数据 World
│  ├─ components/             # Transform、Health、Team、Ability...
│  ├─ systems/                # Movement、Combat、Score、WinCondition...
│  ├─ physics_facade/         # 服务端碰撞/查询抽象
│  ├─ rng/                    # 种子随机数
│  └─ replay/                 # 输入日志、状态哈希、回放
├─ ugc/
│  ├─ package/                # Manifest、Bundle、依赖
│  ├─ compiler/               # AuthoringWorld → SimulationBundle
│  ├─ validator/              # Schema、语义、预算、安全验证
│  ├─ rule_vm/                # 受限规则解释器
│  ├─ migration/              # Schema 迁移
│  └─ asset_pipeline/         # 图片/音频/模型重编码
├─ server/
│  ├─ session/
│  ├─ match/
│  ├─ authority/
│  ├─ replication/
│  ├─ interest/
│  ├─ anti_cheat/
│  └─ persistence/
├─ client/
│  ├─ platform/               # Steam / 商店 / 微信 / 能力探测，不进仿真核
│  ├─ input/
│  ├─ prediction/
│  ├─ interpolation/
│  ├─ reconciliation/
│  └─ presentation/           # Godot Node/动画/UI 适配；小游戏走减配资源
├─ creator/
│  ├─ authoring_model/
│  ├─ editor_plugin/
│  ├─ ingame_editor/
│  ├─ command_history/
│  └─ preview/
└─ tests/
   ├─ unit/
   ├─ replay/
   ├─ network_sim/
   ├─ content_golden/
   └─ security/
```

---

## 6. UGC 内容如何建模

## 6.1 内容包结构

建议使用“可读源格式 + 编译后运行格式”两阶段模型。

### 创作源格式

开发初期可用规范化 JSON，便于 diff、AI 生成、版本迁移和调试：

```text
my_level/
├─ manifest.json
├─ world.json
├─ archetypes.json
├─ rules.json
├─ variables.json
└─ assets/
   ├─ textures/...
   ├─ audio/...
   └─ models/...
```

### 发布运行格式

构建服务把源格式编译成紧凑二进制 `SimulationBundle`，并生成：

- 内容哈希；
- 依赖哈希；
- 能力清单；
- 资源预算报告；
- Schema/规则版本；
- 平台签名。

服务器只加载平台签名后的运行格式。原始玩家上传包永远不直接进入对局服务器。

## 6.2 Manifest 示例

```json
{
  "schema_version": 1,
  "content_id": "ugc.capture_arena",
  "version": 12,
  "title": "Capture Arena",
  "entry_world": "arena_main",
  "ruleset_version": 3,
  "capabilities": [
    "spawn.prefab.whitelist",
    "combat.damage.standard",
    "score.team"
  ],
  "budgets": {
    "max_entities": 500,
    "max_dynamic_bodies": 80,
    "max_rule_ops_per_tick": 10000,
    "max_spawns_per_second": 20
  },
  "dependencies": [],
  "content_hash": "build-generated",
  "signature": "platform-generated"
}
```

## 6.3 实体与组件

每个实体使用稳定 UUID，组件只允许 Schema 注册表中的白名单类型：

```json
{
  "id": "entity:capture_point_a",
  "archetype": "capture_point",
  "components": {
    "transform": {
      "position_mm": [12000, 0, -5000],
      "rotation_mdeg": [0, 90000, 0]
    },
    "capture_zone": {
      "radius_mm": 3500,
      "capture_ticks": 180,
      "score_per_tick": 1
    },
    "replication": {
      "policy": "relevant_area"
    }
  }
}
```

建议：

- 网络关键数值采用整数、定点数或量化数值，例如毫米、毫秒、千分比；
- 禁止把 NodePath、Callable、Object、Script 或任意文件路径写入 UGC；
- 所有引用使用稳定 ID 或内容寻址哈希；
- 编辑器专用字段与运行时字段分离，编译时剥离选择框颜色、辅助线等元数据。

## 6.4 原型 Archetype

`Archetype` 是经过平台批准的组件组合模板。例如：

- `player_spawn`；
- `static_obstacle`；
- `moving_platform`；
- `damage_volume`；
- `pickup`；
- `capture_point`；
- `score_trigger`。

创作者可以实例化和调参，但不能随意挂载未知组件。高级创作者可在能力清单允许时组合组件，仍需通过冲突和预算校验。

## 6.5 规则图 / 受限 DSL

推荐先做事件—条件—动作规则图，而不是通用脚本语言：

```text
Event: MatchStarted
  → Action: SetVariable("round_time", 180)
  → Action: Spawn(archetype="pickup", marker="pickup_a")

Event: EntityEnteredZone(zone="capture_a", entity_tag="player")
  → Condition: TeamOf(event.entity) != Variable("owner_team")
  → Action: AddVariable("capture_progress", 1)
  → Condition: Variable("capture_progress") >= 100
  → Action: SetVariable("owner_team", TeamOf(event.entity))
  → Action: EmitGameEvent("capture_completed")
```

规则节点分四类：

1. `Event`：匹配开始、Tick、进入区域、受到伤害、实体死亡等；
2. `Query`：读取组件、查找标签、空间查询、读取变量；
3. `Condition`：比较、布尔组合、权限与队伍判断；
4. `Action`：改变量、施加伤害、生成白名单实体、发领域事件。

必须禁止：

- 文件系统、网络和系统调用；
- 反射、动态加载、原生对象访问；
- 任意递归；
- 无界循环；
- 任意字符串转类名/方法名；
- 直接调用 Godot SceneTree 或修改 Node；
- 绕过服务器直接发送自定义 RPC。

每条规则执行时消耗 `gas`：

- 节点执行有固定成本；
- 空间查询按结果数额外收费；
- 单规则、单实体、单 Tick、全对局均有预算；
- 超预算时服务器中止规则并记录内容错误，不允许拖垮整个 Match Tick。

## 6.6 变量作用域

变量需要显式声明类型、作用域和复制策略：

| 作用域 | 示例 | 是否持久化 | 典型同步 |
|---|---|---:|---|
| Content Constant | 最大人数、地图尺寸 | 是 | 开局内容包 |
| Match | 回合时间、队伍得分 | 回放需要 | 全局可靠增量 |
| Team | 队伍资源、占领进度 | 回放需要 | 仅相关队伍或全局 |
| Player | 血量、弹药、任务进度 | 视玩法而定 | Owner + Relevant |
| Entity | 门状态、平台位置 | 通常否 | 兴趣范围内 |
| Presentation Only | 粒子强度、镜头震动 | 否 | 可只发事件 |

UGC 创建的变量也必须来自有限类型集：`bool`、有界整数、量化浮点、枚举、稳定 ID、短字符串。禁止任意对象图。

## 6.7 资源模型

玩家资源不应直接作为可执行 Godot 资源加载：

1. 上传到隔离区；
2. 对图片/音频/模型重新解码；
3. 限制分辨率、时长、面数、骨骼数、动画数和压缩倍率；
4. 清除元数据和外部引用；
5. 转换为平台内部格式；
6. 以哈希寻址并由 Manifest 引用。

`.pck` 仅用于平台可信代码或已经审核、重新构建的资源分发，不接收玩家自制 PCK 后直接挂载。

---

## 7. 运行时修改和“热重载”设计

## 7.1 用命令代替直接写状态

所有运行时修改都表达为命令：

```text
PlayerCommand  玩家输入意图：移动、施放、交互
EditCommand    创作修改：新增实体、改属性、连接规则节点
AdminCommand   受权限控制的测试/运营指令：设血量、跳回合、暂停
SystemCommand  服务器内部：生成、销毁、迁移、应用补丁
```

命令统一包含：

```text
command_id / actor_id / permissions / target_tick
expected_revision / payload / content_version / trace_id
```

服务器执行流程：

```text
接收 → 鉴权 → Schema 校验 → 所有权/时序校验 → 语义校验
→ 排队到目标 Tick → 事务应用 → 产生 DomainEvent → 复制与审计
```

## 7.2 热修改分级

| 级别 | 例子 | 编辑预览 | 正式对局 |
|---|---|---:|---:|
| P0 表现 | 材质、音效、UI 文案 | 可热换 | 可按资源版本更新，不影响裁决 |
| P1 参数 | 移速、伤害、回合时间 | 可热换并重置局部状态 | 仅服务器预声明的 Live Tuning 参数 |
| P2 拓扑 | 增删实体、移动出生点 | 安全 Tick 应用 | 通常禁止；非竞技沙盒可授权 |
| P3 规则图 | 改胜负条件、触发链 | 重新编译后热换 | 禁止；下一局使用新版本 |
| P4 Schema | 新组件、新节点类型 | 重启预览实例 | 必须发布新运行时版本 |

### 安全 Tick 与事务

内容补丁不能在 System 执行到一半时生效。推荐：

1. 编辑器提交 Patch；
2. 后台增量编译与校验；
3. 服务器在 Tick 末尾进入安全点；
4. 检查 `expected_revision`；
5. 原子应用 Patch；
6. 执行显式状态迁移；
7. 失败则完整回滚；
8. 广播新 Revision 和受影响状态。

### 预览会话与正式会话

- **Preview Session**：允许 P0～P3，面向单人或受信测试房；每次变更都有版本和回滚点。
- **Published Match**：规则和地图版本开局锁定；默认只允许 P0，以及白名单 P1。
- **Sandbox Match**：房主可在服务器授权下应用 P2，但房间必须标记为非竞技、不可计入排名。

这比“所有模式都支持任意热重载”更容易保证公平性。

---

## 8. 网络对战与状态同步

## 8.1 推荐模型

采用**服务器权威的客户端—服务器模型**：

```text
Client
  ├─ 采样输入
  ├─ 发送 PlayerCommand(seq, target_tick, input)
  ├─ 预测本地玩家
  └─ 保存输入/状态环形缓冲
             ↓
Authoritative Server
  ├─ 校验并排队命令
  ├─ 固定 Tick 执行 SimulationCore + Rule VM
  ├─ 生成状态快照/增量和领域事件
  └─ 保存回放与状态哈希
             ↓
Client
  ├─ 收到权威状态
  ├─ 本地玩家 Reconciliation + 重放未确认输入
  └─ 远端实体插值显示
```

### 原型建议参数

以下只作为起始值，应由玩法测试调整：

- Server Tick：20～30 Hz；
- 输入发送：与 Tick 同频或略高；
- 状态快照：10～15 Hz；
- 客户端插值缓冲：2～4 个快照；
- 回滚缓冲：约 0.5～1 秒；
- 完整快照：低频或基线丢失时发送；
- 增量快照：相对客户端已确认基线编码。

射击、格斗或高速动作玩法可能需要更高 Tick；回合制和轻动作可以更低。不要先锁死数字。

## 8.2 命令协议

客户端发送的是：

```text
player_id
sequence
client_tick
requested_server_tick
command_type
quantized_payload
last_received_snapshot
```

服务器必须验证：

- 玩家是否拥有目标实体；
- 命令是否过早、过晚、重复或乱序；
- 冷却、资源、距离和状态是否允许；
- 单位时间命令数量是否超限；
- Payload 是否满足 Schema 和取值范围。

客户端绝不能发送“我击中了”“我的位置是这里”“我获得了物品”作为最终事实。

## 8.3 Component 级复制策略

每种 Component 声明复制策略：

```text
Never              仅服务器存在，如反作弊标记
OwnerOnly          只发拥有者，如私有任务进度
Everyone           全局比分、回合状态
RelevantArea       空间兴趣范围内实体
TeamOnly           战争迷雾下的队伍信息
EventOnly          爆炸、音效等瞬时表现事件
PredictedOwner     本地玩家可预测，服务器校正
InterpolatedRemote 远端对象插值
```

这样 UGC 只能从有限策略中选择，不能自行把服务器私密字段广播给客户端。

## 8.4 快照、增量和事件

- **快照**回答“现在是什么状态”；
- **增量**回答“相对已确认基线哪些字段改变”；
- **领域事件**回答“发生了什么”，用于表现、回放和审计；
- 事件不能替代状态恢复，因为客户端可能漏包或中途加入。

建议：

- Spawn、Despawn、背包交易、对局阶段切换走可靠通道；
- 位置、速度、朝向等高频状态走不可靠有序通道；
- 状态基线不匹配、断线重连、状态哈希异常时发完整快照；
- 每个快照带 `server_tick + content_version + baseline_id + state_hash`。

## 8.5 预测、回滚与服务器回溯

MVP 只预测本地高频移动：

1. 客户端立即应用自己的输入；
2. 记录输入序号和预测前状态；
3. 服务器返回已确认输入序号和权威状态；
4. 超过容差则回滚到权威状态；
5. 重放尚未确认输入；
6. 表现层平滑追赶，避免视觉瞬移。

远端玩家通常不预测，只插值。技能、生成和得分先由服务器确认再表现，后续再针对手感做有限预测。

若需要射击命中回溯：服务器保存短时间历史碰撞状态，按经限制的客户端输入时间回看；最终仍由服务器裁决。

## 8.6 Godot 物理与确定性

Godot 物理不应被假设为跨平台严格确定。建议：

- 权威物理只在服务器运行；
- 固定 Tick；
- 关键数值量化；
- RNG 固定种子；
- 实体和 System 使用稳定排序；
- 竞技关键判定尽量使用自有简化数学查询；
- 客户端物理只做预测和表现，允许校正；
- 回放以命令日志 + 版本 + 种子为主，并定期记录关键快照。

不要在第一阶段选择全客户端锁步作为主同步方案。

## 8.7 Godot 网络设施如何使用

- 原型期可使用 Godot 高层 Multiplayer API 和 ENet 快速打通连接；
- `MultiplayerSpawner/MultiplayerSynchronizer` 可用于早期验证和非敏感表现同步；
- 生产化后，关键竞技状态建议使用显式消息 Schema 和自定义复制层，避免协议与 ScenePath 强耦合；
- 原生平台优先 ENet/UDP；网页/微信客户端没有同等 UDP 语义，需经 WebSocket 或 WebRTC 网关接入同一套命令/快照协议，仿真核不变；
- 专用服务器使用 Godot Headless 导出，不加载不必要的美术和 UI 资源；
- 12 周纵向切片以桌面 + Headless 为验收环境；微信适配与减配资源管线放在切片验证之后，不要阻塞核心协议。

---

## 9. 编辑状态如何同步

编辑同步和对局同步应使用不同协议，但共享实体 ID 和 Schema。

## 9.1 EditCommand

```text
CreateEntity
DeleteEntity
SetComponentField
AddComponent
RemoveComponent
MoveEntity
CreateRuleNode
ConnectRuleEdge
SetRuleParameter
BatchCommand
```

每个命令包含 `base_revision`。服务端或本地 AuthoringModel 校验后生成新 Revision，并写入命令历史。

### MVP 冲突策略

先做简单且可解释的策略：

- 单作者：本地编辑，上传时校验；
- 小队协作：对象级软锁 + Revision 乐观并发；
- 冲突时拒绝后提交者并返回差异；
- `BatchCommand` 原子提交；
- Undo 实现为反向命令，而不是直接恢复任意内存对象。

CRDT/OT 多人实时协同编辑延后。它会显著增加规则图、实体删除和引用一致性的复杂度，不是验证核心玩法的必要条件。

## 9.2 编辑到预览的增量链路

```text
UI 操作
→ EditCommand
→ AuthoringModel 更新
→ 增量 Schema/语义校验
→ 编译受影响的实体与规则子图
→ Preview Server 在安全 Tick 应用 Patch
→ 返回 ValidationResult + RuntimeStateDelta
→ 编辑器定位错误节点或实体
```

规则图和关卡编辑器必须能显示：

- 错误所在实体/组件/规则节点；
- 当前 Tick 消耗与预算上限；
- 规则触发次数；
- 最近一次输入和输出；
- 服务器拒绝命令的原因；
- 客户端预测校正次数。

---

## 10. 内容验证、安全与发布

## 10.1 验证流水线

```text
上传隔离区
→ 文件类型/大小/压缩倍率检查
→ Schema 校验
→ 引用完整性与稳定 ID 校验
→ 规则图类型检查和可达性检查
→ 权限/能力检查
→ 静态预算检查
→ 资源重新解码与转换
→ Headless 沙盒仿真
→ 机器人回放与压力测试
→ 人工/自动内容审核
→ 编译、哈希、签名
→ Staging 灰度
→ 发布
```

### 必须有的预算

- 最大实体数、动态物理体数；
- 最大碰撞形状复杂度；
- 最大规则节点数和边数；
- 每 Tick 规则操作数；
- 空间查询次数和最大返回数；
- 每秒生成/销毁实体数；
- 纹理尺寸、模型面数、骨骼数、音频时长；
- 单内容包总大小、解压倍率；
- 服务器内存、Tick 时间和网络带宽上限；
- **按平台的额外预算**：微信/网页主包与子包体积、纹理尺寸、网格面数、音频时长；超预算的是平台资源变体，不是另一份规则或另一套仿真。

超预算内容应在发布前拒绝，而不是在线上偷偷降级，因为服务器和客户端采用不同降级结果会导致不一致。

## 10.2 版本策略

```text
ContentId: 逻辑身份
Version: 单调递增发布版本
ContentHash: 具体不可变字节内容
SchemaVersion: 数据格式版本
RulesetVersion: 规则 VM/API 版本
RuntimeVersion: 仿真内核兼容版本
```

匹配握手时校验全部关键版本。玩家缺少内容时从 CDN 下载资源，但权威规则由服务器自己的签名包加载，不能信任客户端副本。

## 10.3 下架与回滚

- 新对局禁止使用已下架版本；
- 运行中的竞技局原则上完成当前对局，严重安全问题则终止；
- 版本不可覆盖，只能发布新版本；
- 排名、回放和举报记录都保存内容版本与哈希；
- 灰度发布按玩家群或房间比例启用。

---

## 11. 快速原型迭代工作流

## 11.1 开发闭环

```text
规则/关卡编辑
→ 自动保存为 EditCommand
→ 增量校验
→ 单人即时预览
→ 一键启动 1 个 Headless Server + N 个本地客户端
→ 网络条件模拟
→ 记录输入、状态哈希和回放
→ 自动测试
→ 上传 Staging
→ 构建、审核、签名
→ 邀请测试
→ 基于数据改下一版
```

目标是让“改一个规则到多人验证”的路径不需要人工复制文件、不需要重启整个 Godot 编辑器、不需要手工改客户端和服务器两份代码。

## 11.2 AI 在流程中的位置

结合调研报告中的 Godot AI 生态，AI 最适合：

- 根据自然语言生成合法的规则图草稿；
- 批量生成关卡数据和测试用例；
- 解释 Validator 错误；
- 驱动 Godot 编辑器创建表现层场景；
- 运行 Headless 测试并读取错误；
- 根据回放和指标定位规则热点。

AI 生成结果必须经过同一 Schema、预算和仿真验证，不获得额外信任。AI 不应绕过规则图直接生成并发布任意 GDScript。

## 11.3 一键本地联调工具

建议尽早制作 `DevLauncher`：

- 启动一个 Headless Server；
- 启动 2～4 个客户端窗口；
- 自动注入测试账号；
- 加载指定内容版本；
- 配置延迟、抖动、丢包、重复包和断线；
- 收集服务器/客户端统一日志；
- 结束后导出回放、状态哈希和性能报告。

这个工具对原型效率的提升，通常比过早搭建复杂 UGC 平台更直接。

---

## 12. 12 周原型路线图

前 12 周只验收 **桌面客户端 + Godot Headless**，证明创作闭环和权威对战。不要把微信导出、鸿蒙移植或 .NET 实验塞进这条关键路径。移动端导出可在桌面切片稳定后按官方模板补；网页/微信减配作为独立里程碑。

### W1～W2：最小共享仿真

产出：

- `SimulationCore` 最小 World；
- Transform、Player、Health、Team、Score 五类组件；
- 固定 Tick、种子 RNG、稳定实体顺序；
- PlayerCommand 和 DomainEvent；
- 单进程可完成一局最小玩法。

验收：同一输入日志重复执行得到相同关键状态哈希。

### W3～W4：数据化关卡与编辑闭环

产出：

- Manifest、World、Archetype Schema；
- 游戏内摆放/移动/属性编辑；
- EditCommand、Undo/Redo；
- AuthoringWorld → SimulationBundle 编译器；
- 保存后无需重启即可刷新单人预览。

验收：不改 GDScript，仅改 JSON/编辑器数据即可做出两张规则相同、布局不同的地图。

### W5～W6：权威网络对战

产出：

- Godot Headless Server；
- ENet 连接与握手；
- 服务端命令校验；
- Spawn/Despawn、低频快照、远端插值；
- 一键多开本地测试。

验收：两个不可信客户端不能自行改血量、位置或得分。

### W7～W8：规则图与运行时状态命令

产出：

- 10～20 个规则节点的最小 Rule VM；
- gas 预算；
- Preview Session 安全 Tick 热更新；
- AdminCommand 权限与审计；
- 规则节点运行时调试面板。

验收：不用写代码即可制作“占点得分”和“拾取物定时刷新”两个玩法变体。

### W9～W10：预测、校正与回放

产出：

- 本地移动预测；
- 权威校正和输入重放；
- 完整快照 + 增量快照；
- 输入回放、关键 Tick 状态哈希；
- 延迟/抖动/丢包仿真。

验收：在目标网络条件下可玩，且能从日志复现关键异常。

### W11～W12：内容管线与试点发布

产出：

- 上传隔离区；
- Schema/语义/预算验证；
- 内容编译、哈希和签名；
- Staging 内容注册表；
- 版本锁定、下架和回滚；
- 3～5 个真实创作者试用。

验收：创作者可以从编辑、测试、上传到邀请好友联机完成全流程，服务器只加载签名版本。

---

## 13. 建议的第一个纵向切片

不要从“通用 UGC 平台”开始。建议选一个窄玩法做完整闭环，例如 2～4 人俯视角占点对战：

### 可编辑内容

- 地形块、障碍、出生点、占领区、拾取物刷新点；
- 回合时长、目标分数、占领速度、拾取物类型；
- 规则图：开局、进入区域、占领完成、玩家死亡、回合结束。

### 权威状态

- 玩家位置、生命、队伍；
- 区域占领进度和归属；
- 队伍得分、剩余时间；
- 拾取物生成和拾取结果。

### 首版不做

- 玩家自定义模型上传；
- 自定义武器脚本；
- 高速弹道回溯；
- 实时多人共同编辑；
- 排位与经济系统。

这个切片足以验证四个核心诉求是否能在同一架构中成立。

---

## 14. 测试与可观测性

## 14.1 自动化测试

- Schema 正反例测试；
- 规则图类型、循环和预算测试；
- Simulation System 单元测试；
- 属性测试：任意合法输入不崩溃、不产生非法状态；
- Golden Content：固定内容包编译结果可比较；
- 回放测试：相同版本、种子、输入得到相同状态哈希；
- 网络仿真：延迟、抖动、丢包、乱序、重复、断线重连；
- 恶意内容：无限生成、深层嵌套、引用环、压缩炸弹、超大资源；
- 长时 Soak Test：Tick 时间、内存、快照尺寸不持续增长。

## 14.2 关键指标

每条日志携带：

```text
match_id / player_id / content_id / content_version
server_tick / command_seq / entity_id / trace_id
```

重点监控：

- Tick P50/P95/P99 耗时；
- Rule VM 每 Tick 操作数；
- 活跃实体和动态物理体数；
- 每客户端快照大小和带宽；
- 命令拒绝原因；
- 预测校正频率和平均误差；
- 状态哈希分歧；
- 内容验证失败阶段；
- 热补丁应用/回滚次数。

---

## 15. 关键取舍

| 决策 | 推荐 | 原因 |
|---|---|---|
| 引擎发行版 | Godot 4 Standard，不用 .NET 版 | 共享客户端必须能导 Web/微信；Godot 4 C# 不能作为侧模块嵌入网页 WASM |
| 客户端语言 | GDScript；热点再 GDExtension | 与引擎集成最紧；避免双运行时和双栈逻辑 |
| 权威服务器语言 | 原型 GDScript Headless；可再拆独立进程 | 先共享仿真代码；C#/Go/Rust 只作为二期服务器选项 |
| 发布节奏 | PC/Steam + 安卓 + iOS 一期；网页/微信减配跟进；鸿蒙二期 | 官方原生端成熟；小游戏靠社区适配；鸿蒙 NEXT 未进官方 |
| 渲染基线 | 跨端按 Compatibility 设计；PC 可增强 Forward+ | WebGL 2 是网页/小游戏上限，不能以 PC 高端管线为共同前提 |
| UGC 逻辑 | 白名单规则图，后续再演化 DSL | 最容易验证、调试和限制预算 |
| 服务端 | Godot Headless 起步 | 共享代码、快速形成完整闭环 |
| 仿真结构 | 纯数据 World + System | 可测试、可回放、与表现解耦 |
| 同步模型 | 权威快照 + 本地有限预测 | 不依赖跨平台确定性 |
| 编辑热更新 | Preview 全量能力，竞技局版本锁定 | 同时保障迭代速度与公平性 |
| 内容格式 | JSON 源格式 + 编译二进制包 | 易编辑、易迁移、运行高效 |
| 协同编辑 | Revision + 对象软锁起步 | 比 CRDT 简单，足够验证需求 |
| Godot 场景 | 表现模板和编辑 UI | 不作为不可信 UGC 的权威格式 |
| 资源上传 | 隔离、重解码、转码、哈希引用 | 阻断脚本与恶意资源风险 |
| 小游戏差异 | `platform/` + 减配资源变体 | 核心玩法与内容协议不变，渠道 SDK 和包体单独适配 |

---

## 16. 常见失败模式

1. **把 `.tscn` 当数据库**：NodePath、脚本绑定和资源依赖使版本迁移与安全校验失控。
2. **为了热更新允许任意 GDScript**：最终无法做服务器安全边界、预算和审核。
3. **客户端同步结果而非输入**：位置、命中、得分会被轻易伪造。
4. **把领域事件当状态同步**：丢包和中途加入时无法恢复完整状态。
5. **过早追求全量预测/回滚**：复杂度吞噬原型周期，先只预测本地移动。
6. **规则图没有执行预算**：合法规则组合也可能形成指数级工作量。
7. **正式对局支持任意热换规则**：回放、排名、公平性和调试全部失去稳定基线。
8. **客户端拿到不该知道的数据**：即使 UI 不显示，作弊程序也能读取；兴趣管理也是信息安全边界。
9. **只做编辑器，不做验证器**：UGC 平台最终会被异常和恶意内容拖垮。
10. **先建平台后找玩法**：应先用一个纵向切片验证创作体验和网络模型。
11. **因网页支持 WASM 就选 Godot .NET 版**：WASM 能跑的是已编进主模块的 Godot+GDScript，不是可被 Godot 动态加载的 CLR；C# 客户端会直接丢失网页/微信导出。
12. **把鸿蒙 NEXT 写进一期范围**：官方平台未就绪，会把不确定的社区移植绑进关键路径。
13. **PC 用 Forward+ 做成唯一渲染路径**：网页/小游戏只能 WebGL 2，后期再拆管线成本高于一开始按 Compatibility 基线设计。

---

## 17. 待进一步确认的问题

这些答案会影响下一版技术规格。标为「已确认」的条目不再作为开放选项：

1. 目标玩法是俯视角动作、FPS、格斗、回合制还是派对游戏？
2. 单局人数、地图大小、目标服务器 Tick 和可接受延迟是多少？
3. **已确认**：一期 PC/Steam、Android、iOS；网页与微信小游戏为共享核心 + 减配，不要求同画质同包体；鸿蒙 NEXT 二期；主机仍未定。
4. UGC 首阶段只允许平台资产，还是允许玩家上传图片、音频和 3D 模型？
5. 是否需要创作中多人协同，还是只需要创作完成后多人试玩？
6. 运行时编辑只用于开发/沙盒，还是正式玩法的一部分？
7. 对局是否进入排名、经济或奖励系统？这决定安全等级。
8. 是否需要服务器弹性扩容、跨区匹配和观战？
9. 是否允许客户端离线运行 UGC？若允许，离线结果能否写入在线账户？
10. **已确认（客户端）**：Godot 侧用 GDScript，不用 C#。权威服务器原型跟客户端共享 GDScript；若拆独立进程，语言可另选，但不回流到 Godot 客户端工程。

---

## 18. 下一步建议

下一份文档应从脑暴收敛为一个具体的“占点对战纵向切片技术规格”，至少明确：

- 组件 Schema v1；
- 15 个以内的规则节点；
- PlayerCommand、Snapshot 和 EditCommand 的字段；
- Server Tick 与复制策略；
- Preview Session 热更新状态机；
- 内容包目录与校验错误格式；
- 一键多开联调工具接口；
- 12 周每周可运行的验收场景；
- 客户端锁定 Godot 4 Standard + GDScript 的工程约定（禁止引入 `.csproj`）；
- `platform/` 能力清单：一期 Steam/移动占位，网页/微信减配作为切片之后的独立里程碑。

如果纵向切片能证明“创作者 10 分钟改规则、30 秒进入双人测试、客户端无法伪造权威结果”，再逐步扩展 DSL、资产上传、协同编辑、内容平台，以及微信减配导出。
