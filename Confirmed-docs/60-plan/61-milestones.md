# CD-61 里程碑路线与验收

> 文档 ID：CD-61
> 单一事实源：开发顺序、M0–M7 里程碑产出与验收、阶段退出条件、首个可运行验收场景
> 加载建议：判断当前该做什么、定义任务验收、评估是否可进入下一阶段时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第一、九条
> 相关：[CD-11 范围与平台](../10-product/11-scope-and-platforms.md)、[CD-53 测试与 CI](../50-engineering/53-testing-and-ci.md)、[CD-62 风险登记册](62-risk-register.md)
> 派生自：初稿 v0.2 §0（开发顺序）、§55–§56、附录 A

## 1. 开发顺序

本路线只规定顺序，**不承诺固定周数**。每阶段满足退出条件后才能进入下一阶段；TRAPRUSH 先完成，再复用底座开发 BASTION。

```text
最小 Monorepo 与共享底座
  → TRAPRUSH 纵向切片
  → Edit / Preview / Hot Publish 闭环
  → BASTION 复用底座形成第二个纵向切片
  → 移动端适配
  → 网页 / 微信小游戏减配
  → 鸿蒙 NEXT 二期评估
```

## 2. 里程碑

### M0：环境、Monorepo 与宪法

产出：

- Godot 4.7 Standard 工程；
- Compatibility 基线；
- `AGENTS.md`；
- GUT；
- Godot MCP 专项调研项；
- Headless 启动；
- Fastify + SQLite 最小闭环；
- WebSocket Gateway 与 MatchHost 骨架；
- CI 最小流水线；
- DevLauncher 雏形。

验收：AI 能创建场景、写脚本、运行游戏、读取错误、运行测试并启动 Headless 与后端，但不能自行提交、推送或部署。

状态：**已退出**（2026-08-20）。退出依据：

- Linux CI 首次跑绿；
- 人类按 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) 在 Windows 开发机复跑十步全绿；
- 人类独立打开编辑器，确认 Compatibility 基线与 17 个输入动作。

同日第二台开发机（macOS 26.5.2 arm64）按 CD-51 §4.1 与同一份清单再跑通一次，不改变上述退出结论。执行记录见该清单第 10 步与「编辑器 GUI」节。下一阶段是 M1。提交与推送的现行口径见 [CD-52 §1.1](../50-engineering/52-ai-workflow.md)；GitHub 分支保护落地前，Agent 仍不得创建任何提交。

2026-08-21：M1 启动前完成第二轮 MCP 调研，唯一主 MCP 选定为 Godot AI，并覆盖 ADR-0003 原先的「拖到 M2 再选」。**选定之后仍不把安装并进 M1 仿真任务。** 接入烟测与生产级启用的时机见本节「M0 与 M1 之间」及 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)；安装与遥测开关见 [CD-51 §7](../50-engineering/51-dev-environment.md)。

### M0 与 M1 之间：Godot AI 接入（不阻塞灰盒编码）

这不是新的里程碑编号，而是 M1 开工后允许并行的独立环境任务：

1. **接入烟测**（配置与测试的合适时机）：人类按 [Godot AI 接入烟测](../../docs/runbooks/godot-ai-mcp-setup.md) 安装锁定版本、在第一次启用插件前关闭匿名遥测、Configure Cursor，并按 UndoRedo / 运行 / 错误读取 / Headless 退路签字。未签字前，Agent 改场景仍走文件方式。
2. **M1 期间**：SimulationCore、契约、状态哈希、GUT、Headless 仍是主路径。烟测签字后，MCP 只用于表现层占位，不是 M1 退出条件。
3. **M2 启动门禁 = 生产级启用**：接入清单全绿、遥测关闭已核实、已提交的 `project.godot` 无 MCP autoload / 插件项。此后大型 `.tscn` 必须走 MCP / Editor API / UndoRedo。这是 MCP 在本项目里第一次作为日常主路径，也是「生产级应用」的起点——对象是编辑器里的内容生产，不是玩家包。

该条与多 Agent 并行度提升合并为一次 **M2 启动前工具链评审**（[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 8）：同时处理 ADR-0003 阶段 C 与「先跑 2 个域」是否升到 3（[CD-52 §5](../50-engineering/52-ai-workflow.md)）。

### M1：共享定点仿真与 TRAPRUSH 灰盒

状态：**进行中（阶段 A）**（2026-08-21 启动）。L0 信封、定点运算、L0 JSON Schema、红线扫描与 `CODEOWNERS` 已落地。[CD-52 §5.1](../50-engineering/52-ai-workflow.md) 的 A1、A2、A4 已成立。A3 还缺 worktree 基建，**A1–A4 不得报全绿**。并行仍禁止。

产出：

- SharedContracts；
- 定点 SimulationCore；
- 移动、检查点、传送、障碍和道具；
- 直立式 XYZ kinematic 胶囊与基础推击；
- 单人完整跑道；
- 命令日志和状态哈希。

验收：同一输入可重复得到相同关键状态；单人可完成包含上下左右传送和障碍破坏的赛道。

并行不在 M1 开头启动。四条退出条件见 [CD-52 §5.1](../50-engineering/52-ai-workflow.md)：阶段 A 由主 Agent 串行锁死 L0 契约并补门禁；条件全绿后才按域并行。Schema 验证、红线扫描与 worktree 基建作为阶段 A 工作进入 M1 范围，服务于本节「阶段退出条件」里的自动化通过率与人类可接管两项。

### M2：共享 Edit 框架与 TRAPRUSH 工具

产出：

- AuthoringWorld；
- EditCommand；
- 网格、楼层、传送连线；
- Undo/Redo；
- 可达性验证；
- 独立持续 Preview；
- 桌面完整编辑与 Web 轻量编辑的共同数据模型。

验收：不改 GDScript，只用编辑器做出两张不同赛道；修改到预览 ≤ 10 秒。大型场景编辑须走已生产级启用的 Godot AI MCP / UndoRedo（[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) 阶段 C），MCP 不可用时仍须能以 Editor API 退路完成，且不得把 MCP 做成 CI 依赖。

### M3：权威联机与进程隔离

产出：

- 1～8 人 Headless；
- 一局一进程、MatchHost、TLS WebSocket Gateway；
- 本地移动与远端胶囊碰撞预测；
- 快照、插值和校正；
- 单局名次；
- 离线模式。

验收：客户端不能伪造位置、冲线、道具和障碍破坏；离线结果没有在线写入。

### M4：规则字节码与热发布

产出：

- 版本化字节码 Rule VM；
- gas；
- Preview 安全边界；
- 长期测试环境；
- 内容签名；
- P2/P3 新房生效；
- P0/P1 运行房全量安全边界生效；
- 进程内技术自动回滚。

验收：运行中对局只接收兼容 P0/P1 补丁；P2/P3 只进入新房；回放完整记录基础哈希和补丁序列。

### M5：TRAPRUSH 纵向切片验收

产出：

- 3～5 张官方赛道；
- BotRunner 可达性测试；
- 按需人工网络故障检查；
- 项目负责人可玩性清单；
- Windows 导出；
- Android/iOS 导出烟测。

验收：完整完成"编辑—预览—邀请—发布—游玩—单局结算"闭环。

### M6：BASTION 最小 1v1

产出：

- 1v1 战场；
- 互设障碍；
- 路径验证；
- 建塔、升级、出售；
- 基础兵线与核心；
- 无预测网络同步。

验收：双方可以完成一局；非法封路、伪造金币和伪造建造均被拒绝。

### M7：BASTION 多人模板与复用评估

产出：

- 2v2；
- 玩家个人金币/主建造区与队伍公共槽；
- 队长盲设障碍；
- 镜像系统波次与白名单建造策略；
- 自动对打；
- 兵潮性能观测；
- 蓝图 Edit；
- 双玩法复用率报告。

验收：两个玩法共享同一套编辑器外壳、版本、发布、规则和回放底座；由项目负责人决定下一阶段主推玩法。

## 3. 阶段退出条件

第一轮只有同时满足以下条件才进入产品化：

- TRAPRUSH 与 BASTION 的权威命令、定点回放和版本行为正确；
- Edit 到多人预览 ≤ 30 秒；
- 内容发布和回滚无半状态；
- 离线结果零回写；
- 项目负责人完成两套纵向切片的可玩性清单签署；
- AI 生成代码的自动化通过率和返工率可测量；
- 人类仍能理解和接管核心模块；
- 明确标出尚未自动化的网络、性能、外部真人测试与运维风险。

## 4. 首个可运行验收场景

本节定义**内部固定测试夹具**，不限制创作者内容的局时、波数或人数配置。

### 4.1 TRAPRUSH

一张 90 秒赛道必须包含：

- 起点和终点；
- 3 个顺序检查点；
- 1 个向上层传送；
- 1 个向左或向右区块传送；
- 1 个周期障碍；
- 1 个可破坏障碍；
- 1 个爆破道具；
- 1 个安全路线和 1 个危险捷径；
- 2 人 Headless 对局；
- 单局名次结算。

### 4.2 BASTION

一张 5 分钟战场必须包含：

- 双方核心；
- 双方各一条合法路径；
- 双方各 3 个障碍槽；
- 互设障碍阶段；
- 3 种塔；
- 3 种兵；
- 建造、升级、出售；
- 核心伤害与胜负；
- 单局队伍结算和 MVP。
