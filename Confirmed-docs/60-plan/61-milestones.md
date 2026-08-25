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

该条与多 Agent 并行度提升合并为一次 **M2 启动前工具链评审**（[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 8）。**2026-08-23 已通过**（[ADR-0004 §8.1](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)）：ADR-0003 阶段 C 成立；并行保持 2 域，第 3 域仍未开。

### M1：共享定点仿真与 TRAPRUSH 灰盒

状态：**已退出**（2026-08-23，见 [PR #76](https://github.com/czmomocha/craftarena/pull/76)）。退出依据：GUT 全绿（[PR #75](https://github.com/czmomocha/craftarena/pull/75) 合入时 402/402）；`TraprushGrayboxAcceptance` 覆盖本节验收中的单人上下/侧向传送、周期机关、破坏、爆破与冲线，并与 TapeReplay 对齐磁带/状态/快照哈希；本节产出清单均已合入。不纳入：§4.1 的 2 人 Headless 与单局名次（属 M3）；Component Schema v1 / OpenAPI、推击冲量数值、`bot-runner/` / `replay-inspector/`（后续）；Godot AI MCP 不是 M1 退出条件。下一阶段是 M2；工具链评审已通过，功能任务尚未开工。阶段记录：L0 信封、定点、JSON Schema、红线扫描、`CODEOWNERS`、worktree 基建、shell-guard hook、本地 `/review-bugbot`、`.cursor/agents/` 与 `.cursor/BUGBOT.md` 已落地。[CD-52 §5.1](../50-engineering/52-ai-workflow.md) 的 A1–A4 已成立。合入靠 CI + 人类批准。待办 14 第一轮：[PR #13](https://github.com/czmomocha/craftarena/pull/13)（检查点/传送）、[PR #14](https://github.com/czmomocha/craftarena/pull/14)（SimulationWorld 骨架）；第二轮：[PR #16](https://github.com/czmomocha/craftarena/pull/16)（XZ 目的地阻挡）、[PR #17](https://github.com/czmomocha/craftarena/pull/17)（MoveIntent / 重置落点 / 推击冷却）；第三轮：[PR #19](https://github.com/czmomocha/craftarena/pull/19)（Jump/Shove 解码）、[PR #20](https://github.com/czmomocha/craftarena/pull/20)（Y 轴目的地阻挡）；第四轮：[PR #22](https://github.com/czmomocha/craftarena/pull/22)（意图驱动仿真）、[PR #23](https://github.com/czmomocha/craftarena/pull/23)（静态盒阻挡）；第五轮：[PR #25](https://github.com/czmomocha/craftarena/pull/25)（可破坏耐久）、[PR #26](https://github.com/czmomocha/craftarena/pull/26)（位移扫掠）；第六轮：[PR #28](https://github.com/czmomocha/craftarena/pull/28)（推击应用）、[PR #29](https://github.com/czmomocha/craftarena/pull/29)（占用感知落地）；第七轮：[PR #31](https://github.com/czmomocha/craftarena/pull/31)（传送落地等待）、[PR #32](https://github.com/czmomocha/craftarena/pull/32)（关闭静态盒阻挡）；第八轮：[PR #34](https://github.com/czmomocha/craftarena/pull/34)（静态盒重叠查询）、[PR #35](https://github.com/czmomocha/craftarena/pull/35)（单人灰盒跑道夹具）；第九轮：[PR #37](https://github.com/czmomocha/craftarena/pull/37)（命令回放带）、[PR #38](https://github.com/czmomocha/craftarena/pull/38)（占用检查点垫）；第十轮：[PR #40](https://github.com/czmomocha/craftarena/pull/40)（周期关键快照环）、[PR #41](https://github.com/czmomocha/craftarena/pull/41)（灰盒垫盒接线）。细轮收尾：[PR #43](https://github.com/czmomocha/craftarena/pull/43)（重叠盒枚举）、[PR #44](https://github.com/czmomocha/craftarena/pull/44)（灰盒命令磁带）。首章（B+A）：[PR #45](https://github.com/czmomocha/craftarena/pull/45)（胶囊占用查询）、[PR #46](https://github.com/czmomocha/craftarena/pull/46)（灰盒快照与周期 hazard）。第二章：[PR #48](https://github.com/czmomocha/craftarena/pull/48)（候选姿态占用查询）、[PR #49](https://github.com/czmomocha/craftarena/pull/49)（InteractIntent）。第三章：[PR #51](https://github.com/czmomocha/craftarena/pull/51)（UseItemIntent）、[PR #52](https://github.com/czmomocha/craftarena/pull/52)（仅 solid 占用查询）；第四章：[PR #54](https://github.com/czmomocha/craftarena/pull/54)（固体支撑探测）、[PR #55](https://github.com/czmomocha/craftarena/pull/55)（灰盒终点垫）；第五章：[PR #57](https://github.com/czmomocha/craftarena/pull/57)（Y 轴直到阻挡）、[PR #58](https://github.com/czmomocha/craftarena/pull/58)（接地跳跃）；第六章：[PR #60](https://github.com/czmomocha/craftarena/pull/60)（调用方下落）、[PR #61](https://github.com/czmomocha/craftarena/pull/61)（XZ 直到阻挡）；第七章：[PR #63](https://github.com/czmomocha/craftarena/pull/63)（tick 内下落）、[PR #64](https://github.com/czmomocha/craftarena/pull/64)（掉出范围查询）已由人类合入。文档 [PR #65](https://github.com/czmomocha/craftarena/pull/65)。体积占用 [PR #66](https://github.com/czmomocha/craftarena/pull/66)、MoveIntent 接触 [PR #67](https://github.com/czmomocha/craftarena/pull/67)。弧 A：Jump/Shove 直到阻挡与掉出范围复位（[PR #68](https://github.com/czmomocha/craftarena/pull/68)）。弧 B：单人灰盒整段可回放（[PR #69](https://github.com/czmomocha/craftarena/pull/69)）。弧 C：PLAYER 磁带回放进灰盒（[PR #70](https://github.com/czmomocha/craftarena/pull/70)）。弧 D：SYSTEM 占用日志进灰盒（[PR #71](https://github.com/czmomocha/craftarena/pull/71)）。弧 E：出界复位与打箱入 SYSTEM 带（[PR #72](https://github.com/czmomocha/craftarena/pull/72)）。弧 F：try_commit_tick 入 SYSTEM 带（[PR #73](https://github.com/czmomocha/craftarena/pull/73)）。弧 G：独立 try_apply_fall 入 SYSTEM 带（[PR #74](https://github.com/czmomocha/craftarena/pull/74)）。弧 H：灰盒基础推击入 PLAYER 带（[PR #75](https://github.com/czmomocha/craftarena/pull/75)）。灰盒切片在弧 H 收束。第 3 域未开。

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

状态：**已退出**（2026-08-24，见 [PR #114](https://github.com/czmomocha/craftarena/pull/114)）。退出依据：「不改 GDScript，只用编辑器做出两张不同赛道」——三张官方 TRAPRUSH 赛道以 AuthoringDocument 入库且布局互异，编辑外壳 `import_document` 后验证器零问题码，Preview 全程可试玩；「修改到预览 ≤ 10 秒」——编辑写入同步转发已连接 Preview（[PR #102](https://github.com/czmomocha/craftarena/pull/102)），headless 实测 place→Preview 同步 50 次平均 8.4ms、最差 14.2ms（2026-08-24 Windows 开发机，一次性脚本不入库，时延自动门禁仍延期）；「大型场景编辑走已生产级启用的 MCP / UndoRedo，MCP 不可用走 Editor API 退路」——工具链评审 2026-08-23 已通过，且本退出评审全部验证在无 MCP 的 headless Godot 下完成；「不把 MCP 做成 CI 依赖」——`.github/workflows/ci.yml` 无任何 MCP 引用。不纳入：多人试玩、重力/下落、Shove/Interact、预算数字、走路可达 / BotRunner、云端上传、时延自动门禁、签名二进制与 Rule VM（分属 M3 / M4 / M5 或 [CD-63](63-open-decisions.md) 待决）。第 3 域仍未开，是否在 M3 启动时开放由人类重审。工具链评审记录（2026-08-23，见 [PR #77](https://github.com/czmomocha/craftarena/pull/77)；[ADR-0004 §8.1](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)）：Godot AI 生产级启用成立；并行保持 2 域。已合入：[PR #78](https://github.com/czmomocha/craftarena/pull/78) Component Schema v1、[PR #79](https://github.com/czmomocha/craftarena/pull/79) EDIT `op` 白名单、[PR #80](https://github.com/czmomocha/craftarena/pull/80) AuthoringWorld 骨架、[PR #81](https://github.com/czmomocha/craftarena/pull/81) EditCommand 应用与 Undo/Redo、[PR #82](https://github.com/czmomocha/craftarena/pull/82) 完整章节提交口径、[PR #83](https://github.com/czmomocha/craftarena/pull/83) 网格吸附、楼层查询与传送连线分类、[PR #84](https://github.com/czmomocha/craftarena/pull/84) 发布前通路与传送循环、[PR #85](https://github.com/czmomocha/craftarena/pull/85) 独立持续 Preview 会话与安全点 Patch、[PR #86](https://github.com/czmomocha/craftarena/pull/86) 桌面完整与 Web 轻量的共同 AuthoringDocument、[PR #87](https://github.com/czmomocha/craftarena/pull/87) 独立 Preview 窗口宿主、[PR #88](https://github.com/czmomocha/craftarena/pull/88) Preview 3D 表现映射、[PR #89](https://github.com/czmomocha/craftarena/pull/89) Preview 传送连线可视化、[PR #90](https://github.com/czmomocha/craftarena/pull/90) Preview 检查点顺序可视化、[PR #91](https://github.com/czmomocha/craftarena/pull/91) Preview 可达性叠加、[PR #92](https://github.com/czmomocha/craftarena/pull/92) 内部开发编辑外壳、[PR #93](https://github.com/czmomocha/craftarena/pull/93) 编辑窗口 3D 表现映射、[PR #94](https://github.com/czmomocha/craftarena/pull/94) TRAPRUSH 工具面板。[PR #95](https://github.com/czmomocha/craftarena/pull/95) 验证器详情、[PR #96](https://github.com/czmomocha/craftarena/pull/96) 第一张官方 TRAPRUSH 赛道、[PR #97](https://github.com/czmomocha/craftarena/pull/97) 第二张官方 TRAPRUSH 赛道、[PR #98](https://github.com/czmomocha/craftarena/pull/98) 内部开发 EditorPlugin、[PR #99](https://github.com/czmomocha/craftarena/pull/99)–[PR #101](https://github.com/czmomocha/craftarena/pull/101) 本地草稿恢复（`user://` latest + 30 检查点，见 [CD-32 §2](../30-ugc/32-editor-and-preview.md#2-草稿持久化与协同)）、[PR #102](https://github.com/czmomocha/craftarena/pull/102) 编辑写入自动进已连接 Preview、[PR #103](https://github.com/czmomocha/craftarena/pull/103) AuthoringWorld 编成 v1 TRAPRUSH `SimulationBundle` 拓扑 JSON 并可加载进 SimulationWorld、[PR #104](https://github.com/czmomocha/craftarena/pull/104) Preview 安全点试玩、[PR #105](https://github.com/czmomocha/craftarena/pull/105) Preview 试玩 MoveIntent、[PR #106](https://github.com/czmomocha/craftarena/pull/106) Preview 试玩检查点占用验收、[PR #107](https://github.com/czmomocha/craftarena/pull/107) Preview 试玩传送占用落地、[PR #108](https://github.com/czmomocha/craftarena/pull/108) Preview 试玩冲线占用、[PR #109](https://github.com/czmomocha/craftarena/pull/109) Preview 试玩重置到检查点、[PR #110](https://github.com/czmomocha/craftarena/pull/110) Preview 试玩 UseItemIntent 可破坏占用、[PR #111](https://github.com/czmomocha/craftarena/pull/111) Preview 试玩 JumpIntent 接地跳跃、[PR #112](https://github.com/czmomocha/craftarena/pull/112) dev-launcher worktree setup 的 Windows spawn 修复、[PR #113](https://github.com/czmomocha/craftarena/pull/113) 第三张官方 TRAPRUSH 赛道。下一阶段候选为 M3 权威联机与 M5 内容 / 导出，由人类选定。

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

状态：**进行中**（2026-08-24 启动，人类选定 M3 先于 M5）。已合入：对局进程多人仿真循环（无网络，`TraprushMatchSession`）、对局二进制协议 v1（`MatchFrameCodec`）、对局进程仿真入口（`match_server.gd` 真仿真 + MatchHost 传参）、对局进程实时回路（WebSocket 监听 + `MatchRealtime` 槽位/命令队列/快照广播）、实时网关代理（[PR #119](https://github.com/czmomocha/craftarena/pull/119)）、控制面真票据签发/校验（[PR #120](https://github.com/czmomocha/craftarena/pull/120)）、MatchHost 自动登记上游（[PR #121](https://github.com/czmomocha/craftarena/pull/121)）、MatchHost 等待 listen 后登记（[PR #122](https://github.com/czmomocha/craftarena/pull/122)）、MatchHost 停止后注销会话（[PR #123](https://github.com/czmomocha/craftarena/pull/123)）、真匹配与房间码（[PR #124](https://github.com/czmomocha/craftarena/pull/124)）、FIFO 等待队列与预计等待（[PR #125](https://github.com/czmomocha/craftarena/pull/125)）、客户端匹配入场与权威快照跟从（[PR #126](https://github.com/czmomocha/craftarena/pull/126)）、权威快照表现映射（[PR #127](https://github.com/czmomocha/craftarena/pull/127)）、对局大厅赛道几何表现映射（[PR #128](https://github.com/czmomocha/craftarena/pull/128)）、对局大厅可破坏箱表现映射（[PR #130](https://github.com/czmomocha/craftarena/pull/130)）、对局大厅传送连线可视化（[PR #131](https://github.com/czmomocha/craftarena/pull/131)）、对局大厅检查点顺序可视化（[PR #132](https://github.com/czmomocha/craftarena/pull/132)）、对局大厅进度与单局名次（[PR #133](https://github.com/czmomocha/craftarena/pull/133)）、机关狂奔离线单人试玩（[PR #134](https://github.com/czmomocha/craftarena/pull/134)）、对局命令门禁与双人 Headless 冲线（[PR #135](https://github.com/czmomocha/craftarena/pull/135)）、机关狂奔单局结算写库（[PR #136](https://github.com/czmomocha/craftarena/pull/136)）、断线重连补票（[PR #137](https://github.com/czmomocha/craftarena/pull/137)）、官方赛道选择（[PR #138](https://github.com/czmomocha/craftarena/pull/138)）、人数按场下发（[PR #139](https://github.com/czmomocha/craftarena/pull/139)）、对局快照插值（[PR #140](https://github.com/czmomocha/craftarena/pull/140)）、对局本席移动预测（[PR #141](https://github.com/czmomocha/craftarena/pull/141)）、对局进程动作数值占位桩（[PR #142](https://github.com/czmomocha/craftarena/pull/142)）。本刀锁：对局大厅本席摄像机跟随——`MatchSnapshotMap.follow_slot` 把 SnapshotCamera 对准本席表现位姿（线上为预测 overlay，Solo 为本地权威），偏移与 Preview 相同；远端不拉镜头；空名单或 Cancel 回到原点。不锁产品镜头、FOV、第三人称、远端外推碰撞、平滑对账、离开对局 HTTP、账号绑定。人类真机按 [章节真机清单](../../docs/runbooks/chapter-device-check.md) 本刀执行；这是人工检查，不是 CI 门禁。大厅 Cancel 必须停场（`play=idle`，WASD 不再移动）。

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

其中 2 人 Headless 对局与单局名次结算属 M3，不作为 M1 退出条件。M1 退出时单人灰盒夹具已覆盖其余条目。

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
