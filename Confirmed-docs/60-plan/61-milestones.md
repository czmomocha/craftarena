# CD-61 里程碑路线与验收

> 文档 ID：CD-61
> 单一事实源：开发顺序、M0–M3 / M-Export / M-Art / M4a / M4b / M5–M7 产出与验收、插入段（创作者可测 / F 线 / 可玩性深化）、CD-11 §4 所有者、阶段退出条件、首个可运行验收场景
> 加载建议：判断当前该做什么、定义任务验收、评估是否可进入下一阶段时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第一、九条
> 相关：[CD-11 范围与平台](../10-product/11-scope-and-platforms.md)、[CD-53 测试与 CI](../50-engineering/53-testing-and-ci.md)、[CD-62 风险登记册](62-risk-register.md)
> 派生自：初稿 v0.2 §0（开发顺序）、§55–§56、附录 A；2026-09-02 人类批准 [重排草案](../../docs/plans/cd-61-rearrangement-draft.md) §8 后回写

## 当前生效值

> 本节覆盖而非追加。覆盖链见 [CD-91 D.10](../90-reference/91-decision-log.md)。

| 项 | 当前口径 |
|---|---|
| 效力 | **本文件是现行口径**。人类 2026-09-02 接受草案 §8 后回写。批准记录见 [cd-61-rearrangement-draft.md](../../docs/plans/cd-61-rearrangement-draft.md) |
| 已退出 | M0、M1、M2 |
| 已收口插入 | 创作者可测；**F 线**（FA–FH + 可读性）；**可玩性深化**（第一至十八批；2026-09-09 人类验证第十八批后宣布收口）；**M4a**（第 1–5 章：Rule VM + Preview P3 安全边界）；**M4b**（第 1–5 章：签名 / `latest` / P0P1 回滚 / 广场 / 账号认领） |
| 进行中 | M3（表现层增强不阻塞 M3 退出，归 M-Art；深化段已收口的表现不再挡本号）；**M5**（A1 / A2 / A3 / B1 / B2 / C1 / C2 / C5 已交；C3 / C4 已拍未接线） |
| 部分交付 | M-Export（C1 三预设；**Web 游玩分发第一刀已交**；Android / iOS 排到一期收尾）；M-Art（C4 契约与第一批 `.glb`；与 F 线重叠项已交） |
| 未开工（顺序，不是冻结） | M5 其余章（下一实现刀 **C3**；随后 C4；C6 待 §5.2 问题 6）；M6、M7；Android / iOS 烟测（一期收尾）；角色选择界面（紧跟主大厅壳，不提前开工） |
| 纠偏闸门 | **已解除**（2026-09-03）。C0–C5 不是里程碑号。此后本文件进度顺序生效 |
| 解冻后顺序 | 创作者可测（已收口）→ F 线（已收口）→ Web 游玩分发（第一刀已收口）→ 可玩性深化（已收口）→ M-Art 剩余已拍板项 → **M4a** → M4b → M5 → 公开 TLS / PR Web 沙盒 → M6 / M7 → **一期收尾**（字体入包、Android / iOS 烟测、触控 UI） |

## 1. 开发顺序

本路线只规定顺序，**不承诺固定周数**。每阶段满足退出条件后才能进入下一阶段；TRAPRUSH 先完成，再复用底座开发 BASTION。纠偏冻结令已于 2026-09-03 解除，见 [纠偏方案](../../docs/plans/course-correction-2026-08.md) 与 [解除记录](../../docs/audits/2026-09-03-freeze-lift.md)。

```text
已完成的底座（M0–M2）
  → 权威联机收尾（M3；表现增强归 M-Art / 可玩性深化，不阻塞 M3 退出）
  → 纠偏闸门 C0–C5（已结束，不是里程碑号）
  → 创作者可测（插入：XYZ 放置、Place pickup、Preview 并排；已收口，不是新里程碑号）
  → F 线（插入：趣味性增强 F1–F4；示范课 `course_f_playable` **不计入** M5 官方课；已收口，不是新里程碑号，不发明 M8）
  → Web 游玩分发（M-Export 第一刀已收口：导出 Web 包、浏览器能跑、测试期 Solo、大厅填主机+端口打自备 VPS；不是公开 TLS，不是每个 PR 的沙盒）
  → 可玩性深化（插入：游戏性、第一张 TRAPRUSH 玩法与表现、UGC、编辑调试；不是新里程碑号，不发明 M8；**已收口**（2026-09-09））
  → 表现/美术剩余项（M-Art：与深化段重叠的表现在深化段做；字体入包仍推迟到一期收尾）
  → Rule VM（M4a）
  → 内容平台 + 账号/草稿云（M4b）
  → TRAPRUSH 纵向验收（M5）
  → 公开 TLS / 每个 PR 的 Web 沙盒（仍属 M-Export 产出，2026-09-03 拍板推迟）
  → BASTION（M6 / M7；主大厅壳双玩法入口随 BASTION 落地）
  → 角色选择界面（紧跟主大厅壳；2026-09-10 立项，不发明新里程碑号，不提前开工）
  → 一期收尾：字体入包、Android / iOS 导出烟测（不是风险项，不挡前面任何号）、触控 UI（D7）
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

状态：**进行中**（2026-08-24 启动，人类选定 M3 先于 M5）。已合入：对局进程多人仿真循环（无网络，`TraprushMatchSession`）、对局二进制协议 v1（`MatchFrameCodec`）、对局进程仿真入口（`match_server.gd` 真仿真 + MatchHost 传参）、对局进程实时回路（WebSocket 监听 + `MatchRealtime` 槽位/命令队列/快照广播）、实时网关代理（[PR #119](https://github.com/czmomocha/craftarena/pull/119)）、控制面真票据签发/校验（[PR #120](https://github.com/czmomocha/craftarena/pull/120)）、MatchHost 自动登记上游（[PR #121](https://github.com/czmomocha/craftarena/pull/121)）、MatchHost 等待 listen 后登记（[PR #122](https://github.com/czmomocha/craftarena/pull/122)）、MatchHost 停止后注销会话（[PR #123](https://github.com/czmomocha/craftarena/pull/123)）、真匹配与房间码（[PR #124](https://github.com/czmomocha/craftarena/pull/124)）、FIFO 等待队列与预计等待（[PR #125](https://github.com/czmomocha/craftarena/pull/125)）、客户端匹配入场与权威快照跟从（[PR #126](https://github.com/czmomocha/craftarena/pull/126)）、权威快照表现映射（[PR #127](https://github.com/czmomocha/craftarena/pull/127)）、对局大厅赛道几何表现映射（[PR #128](https://github.com/czmomocha/craftarena/pull/128)）、对局大厅可破坏箱表现映射（[PR #130](https://github.com/czmomocha/craftarena/pull/130)）、对局大厅传送连线可视化（[PR #131](https://github.com/czmomocha/craftarena/pull/131)）、对局大厅检查点顺序可视化（[PR #132](https://github.com/czmomocha/craftarena/pull/132)）、对局大厅进度与单局名次（[PR #133](https://github.com/czmomocha/craftarena/pull/133)）、机关狂奔离线单人试玩（[PR #134](https://github.com/czmomocha/craftarena/pull/134)）、对局命令门禁与双人 Headless 冲线（[PR #135](https://github.com/czmomocha/craftarena/pull/135)）、机关狂奔单局结算写库（[PR #136](https://github.com/czmomocha/craftarena/pull/136)）、断线重连补票（[PR #137](https://github.com/czmomocha/craftarena/pull/137)）、官方赛道选择（[PR #138](https://github.com/czmomocha/craftarena/pull/138)）、人数按场下发（[PR #139](https://github.com/czmomocha/craftarena/pull/139)）、对局快照插值（[PR #140](https://github.com/czmomocha/craftarena/pull/140)）、对局本席移动预测（[PR #141](https://github.com/czmomocha/craftarena/pull/141)）、对局进程动作数值占位桩（[PR #142](https://github.com/czmomocha/craftarena/pull/142)）、对局大厅本席摄像机跟随（[PR #143](https://github.com/czmomocha/craftarena/pull/143)）、对局大厅本席移动朝向（[PR #144](https://github.com/czmomocha/craftarena/pull/144)）、对局大厅本席分色（[PR #145](https://github.com/czmomocha/craftarena/pull/145)）、对局大厅本席检查点占用高亮（[PR #146](https://github.com/czmomocha/craftarena/pull/146)）、对局大厅本席冲线闭环表现（[PR #147](https://github.com/czmomocha/craftarena/pull/147)）、对局大厅本席复位与楼层/箱子 HUD（[PR #148](https://github.com/czmomocha/craftarena/pull/148)）、大厅只读结算面板（[PR #149](https://github.com/czmomocha/craftarena/pull/149)）、对局大厅本席预测避开最新权威固体（[PR #150](https://github.com/czmomocha/craftarena/pull/150)）、真人命令才续租（[PR #151](https://github.com/czmomocha/craftarena/pull/151)）、网关进程内 TLS（[PR #152](https://github.com/czmomocha/craftarena/pull/152)）、权威 Move 位移门禁（[PR #153](https://github.com/czmomocha/craftarena/pull/153)）、对局基础推击（[PR #154](https://github.com/czmomocha/craftarena/pull/154)）、出界复位（[PR #155](https://github.com/czmomocha/craftarena/pull/155)）、周期机关进拓扑（[PR #156](https://github.com/czmomocha/craftarena/pull/156)）、对局大厅周期机关表现映射（[PR #157](https://github.com/czmomocha/craftarena/pull/157)）、开发机运行体验（[PR #158](https://github.com/czmomocha/craftarena/pull/158)）、固定固体占用（[PR #159](https://github.com/czmomocha/craftarena/pull/159)）、编辑器占用摆放（[PR #160](https://github.com/czmomocha/craftarena/pull/160)）、官方赛道占用（[PR #161](https://github.com/czmomocha/craftarena/pull/161)）、编辑器 Place finish（[PR #162](https://github.com/czmomocha/craftarena/pull/162)）、官方赛道立足固体与 Jump（[PR #163](https://github.com/czmomocha/craftarena/pull/163)）。本刀锁：权威下落接到对局 / Solo / Preview——`fall_dy` 默认 0；boot / Solo 占位 `-Fixed.SCALE / 16`；Preview 壳占位 `-Fixed.SCALE`；`MatchRealtime` 先下落再意图再 tick；Solo 每帧先 advance 再采样空格；Preview 意图不下落，Advance tick 才落；纯下落不续租。不锁产品重力加速度、不铺官方沿路地板、在线 overlay 假跳。人类真机按 [开发机窗口验收](../../docs/runbooks/dev-window-check.md) 本刀执行；这是人工检查，不是 CI 门禁。

产出：

- 1～8 人 Headless；
- 一局一进程、MatchHost、TLS WebSocket Gateway；
- 本地移动与远端胶囊碰撞预测；
- 快照、插值和校正；
- 单局名次；
- 离线模式。

验收：客户端不能伪造位置、冲线、道具和障碍破坏；离线结果没有在线写入。

诚实边界：一期最小道具 = **爆破球 + 冲刺**，不是完整道具表；无控保护与产品数值仍属 [CD-63](63-open-decisions.md)。表现层增强（镜头、HUD 字段、皮肤）**不是 M3 退出条件**，解冻后归 M-Art / F 线 / 可玩性深化，不阻塞 M3。

### F 线：趣味性增强（插入，不是里程碑号）

状态：**已收口**（2026-09-07）。人类拍板（D-F1）开 F 线；F1–F4 在 M4a 之前。该句中「安卓 / iOS 烟测排在 F 线之后」已被后续顺序覆盖，见 [CD-91 D.10](../90-reference/91-decision-log.md) `cd61_order = web_first_mobile_phase1_end`。示范课 `course_f_playable` **不计入** M5 官方课 3～5 张。不发明 M8。

已交八章：FA 时间闭环 → FB 音频与预警 → FC 可见世界 → FD 跳跃 → FF 参数面板 → FE 移动平台 → FG 编辑效率 → FH 示范课 `course_f_playable`。其后可读性：拉开示范课、HUD / 世界标签缩字、斜 45° 滚轮调距。推击 / 爆破 / 道具重生数值不改（D-F4 / D-F5 / D-F6）。

### 可玩性深化（插入，不是里程碑号）

状态：**已收口**（2026-09-09）。人类验证第十八批后宣布收口。下一动是 M4a。不发明 M8。

人类 2026-09-07 拍板：F 线之后**首要任务是完善游戏功能**，不是移动端导出。Android / iOS 烟测排到 **一期收尾**；移动端导出不是风险项。Web 游玩分发第一刀已交（见本节 M-Export）。决策来源见 [CD-91 D.10](../90-reference/91-decision-log.md) `cd61_order = web_first_mobile_phase1_end` 与 `playability_insert = closed_2026_09_09`。

本插入段服务第一张 TRAPRUSH：更好玩、更能编、更能给外人试。四条能力轨（具体章按 5× 拆；[CD-63](63-open-decisions.md) 未拍板项不得自选）：

1. **游戏性**：在已锁道具与数值内丰富第一张 TRAPRUSH 的课体验与反馈。D-F4 / D-F5 / D-F6 保持现值。
2. **表现性**：官方课 / 示范课的可见世界与动效。与 M-Art 剩余重叠的项在本段做，本号不重复。皮肤池等 D-F9、默认相机距离 / FOV、字体入包仍未拍或已推迟。
3. **编辑调试**：创作者工具可观测、可调、可复现；Web 轻量 Edit 的摆放 / 移动 / 调参 / Preview（规则模板等 M4a）。
4. **UGC**：验证、草稿、Preview 调试。签名发布属 M4b；Rule VM 属 M4a，本段已收口、不抢。

已交第一批（2026-09-08，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 传送带（固体 + `zone.tags` 的 `conveyor` + `transform.yaw_bam` 四向；不新增组件、不改 Component Schema v1）。`SimulationBundle` 加可选 `conveyors` 袋，省略与空数组等价，旧编译体照常解码 | **开关门 / `InteractIntent` 未做**：要两处协议不兼容变更（命令帧新增 intent id + 快照帧新增开合状态），属宪法第十八条 |
| 游戏性 | 失败惩罚可读：服务端记 `hazard` / `out_of_range` / `crushed` 与发生 tick，HUD 在窗口期内显示原因 / 复位落点 / 硬直倒计时 | 原因**不进 v1 快照帧**，线上读不到；不进 `hash_state`（是既有事件的读出别名） |
| 游戏性 | 多层寻路：下一个目标 + 屏幕八向箭头 + 楼层差 + 距离，HUD 一行 + 本席头顶世界箭头 | 纯表现读出 |
| 表现性 | 传送门跳变镜头滑行（约 0.35 s），只对**跳变**触发，常态跟随不加延迟 | 占位值，D4 没问过镜头过渡 |
| 表现性 | 传送门占位模型（底座 + 立环 + 门芯 + 旋翼）与课内动效（旋翼按 tick 转、当前目标垫与已开放终点呼吸） | 程序化网格，不是定稿美术、不是新 `.glb`；不改资产预算 |
| 编辑调试 | **Web 轻量 Edit 入口**：玩家包大厅「创作课程」/ `--edit` / `?edit=1` 打开同一套编辑外壳并排 Preview；surface 能力分级第一次被真的执行（批量生成与验证器详情只留给 `internal_dev`）；草稿独立落 `user://creator_draft.json` | 当时 **浏览器上未实测**（开发机 `export_templates` 为空）。已被第十七批覆盖 |
| UGC | Preview 连续试玩（默认自动推进，可关回单步）；验证摘要给轻量 surface | — |

已交第二批（2026-09-08，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 传送带接到示范课 `course_f_playable` revision 4（+Z 六格侧廊三块带子 + 连接固体） | 官方 01–03 仍无传送带；匹配 HTTP 仍只那三张 |
| 游戏性 | 电梯：竖直 `mover` + `zone.tags` 的 `lift`。不另开袋、不改 Component Schema v1。路径必须纯 Y，否则编译拒绝。Place lift 默认沿 +Y 两格 | 水平往返仍走 Place mover |
| 游戏性 | 弹射垫：固体 + `zone.tags` 的 `launch` + `transform.yaw_bam`。`SimulationBundle` 加可选 `launches` 袋（省略 ≡ 空）。支撑上升沿弹一次（`LAUNCH_DY = JUMP_DY * 2`，水平送出一格） | 与 conveyor / mover 同实体拒绝。不改协议帧 |
| 编辑调试 | Place lift / Place launch（弹射垫与传送带一样每摆一块 yaw 顺时针 90°） | 占位仍是石色固体，没有专用模型 |

已交第三批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 跳跃弧覆盖 F 线 snappy：`JUMP_DY = SCALE/4`，`FALL_DY = -SCALE/32`（约 8 拍到顶、峰值约 1.125 格） | 不改 `SimulationCore` 定点数；推击 / 爆破 / 重生仍延期 |
| 表现性 | 同层 hop 冻结跟随高度；换层落地或乘电梯（仍接地）才改镜头 Y | 不改默认距离 / FOV；在线快照无 `vy`，线上不冻 Y |
| 编辑调试 | 上升中（`vy > 0`）不当移动平台乘客，Preview 原地跳不再按 crush 复位 | 下落仍可乘电梯 |

已交第四批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 踩区开关门：固体 + `zone.tags` 的 `switch` / `gate` + 已有 `interactable.link_group`。`SimulationBundle` 加可选 `switches` / `gates` 袋（省略 ≡ 空）。开合是当前占用的纯函数 | **不接线 `InteractIntent`**；开合不进快照；无锁存 / 延时关门。线上表现用快照位姿重算 |
| 游戏性 | 示范课 `course_f_playable` revision 5：主路第一格开关门（出生点 +X 一格 y=−1 青绿开关，其 +Z 一格 y=0 紫墙；不挡冲线） | 官方 01–03 仍无开关门；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place switch / Place gate（默认 `link_group=1`） | 占位青绿踏板 / 紫墙，没有专用模型 |

已交第五批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 能量墙：可破坏占用 + `zone.tags` 的 `energy_wall`。`SimulationBundle` 加可选 `energy_walls` 袋（省略 ≡ 空）。打碎走已有 UseItem | 权威碰撞仍是一格盒；不改爆破半径（D-F5）；无独立耐久表 |
| 表现性 | 传送带 / 电梯 / 弹射垫 / 开关 / 门 / 能量墙挂程序化占位（`OccupancyGadget`），不再铺成石色地块或纯色 1 米盒 | 不是定稿美术、不是新 `.glb`；不改资产预算 |
| 游戏性 | 示范课 `course_f_playable` revision 6：主路 x=5、+Z 一格能量墙（不挡 +X 冲线） | 官方 01–03 仍无能量墙；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place energy wall | 占位半透青板 |

已交第六批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 开关传送：传送占用 + `zone.tags` 的 `portal_switch` + 已有 `interactable.link_group`。`SimulationBundle` 加可选 `portal_switches` 袋（省略 ≡ 空）。关上时不落地 | **不接线 `InteractIntent`**；开合不进快照；无锁存 / 延时。传送门自己的占用不会开组 |
| 表现性 | 未开的开关传送旋翼停、亮度压到 `FX_PORTAL_LOCKED_MODULATE` | 占位值；线上用快照位姿近似占用 |
| 游戏性 | 示范课 `course_f_playable` revision 7：主路 x=4、+Z 一格开关传送（`link_group=2`，不挡 +X 冲线；对端在 −Z 五格且始终可回） | 官方 01–03 仍无开关传送；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place gated portal（两次点击成 `two_way`，与 Place portal 共用待配对 id） | 两端都带 tag；默认 `link_group=1` |

已交第七批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 地刺：固体 + `zone.tags` 的 `spike`。被支撑 ⇒ 环境失败（hazard） | 权威碰撞仍是一格盒；不改协议帧 |
| 游戏性 | 喷火：周期机关 + `zone.tags` 的 `flame`。盒子永远非固体；半周期「开」时重叠 ⇒ 环境失败 | 与滚柱的差别是挡路 vs 穿过去会被烫。`HAZARD_COOLDOWN_STUB=1` 对喷火不可读，Place 用 30 tick |
| 游戏性 | 压板：竖直 `mover` + `zone.tags` 的 `crusher`。重叠且不是它的乘客 ⇒ crush | 路径必须纯 Y，否则编译拒绝。水平往返仍走 Place mover |
| 游戏性 | 示范课 `course_f_playable` revision 8：主路 +Z 一侧地刺 / 喷火 / 压板（不挡 +X 冲线） | 官方 01–03 仍无这三项；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place spike / Place flame / Place crusher | 程序化占位，不是定稿美术 |

已交第八批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 滚柱：周期机关 + `zone.tags` 的 `roller`。半周期固体挡路（与喷火相反） | Place 用 cooldown 30，和喷火一样可读。未打 tag 的旧 `hazard` 行为不变 |
| 游戏性 | 碎石 / 障碍核心：可破坏占用 + `rubble` / `obstacle_core`。打碎走已有 UseItem | 耐久仍是开发桩 1；不改爆破半径。权威仍是一格盒 |
| 游戏性 | 示范课 `course_f_playable` revision 9：主路 +Z 一侧滚柱，+Z 两格碎石 / 核心（不挡 +X 冲线） | 官方 01–03 仍无这三项；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place roller / Place rubble / Place core | 程序化占位，不是定稿美术 |

已交第九批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 道具栏 HUD：Solo / Preview 显示爆破球 / 冲刺持有数 | **不进 v1 快照帧**，线上画不出来；不改协议 |

已交第十批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 摆锤：水平 `mover` + `zone.tags` 的 `pendulum`。重叠且不是乘客 ⇒ crush | 路径必须纯水平，否则编译拒绝。竖直砸仍走 Place crusher |
| 游戏性 | 示范课 `course_f_playable` revision 10：主路 +Z 两格摆锤（不挡 +X 冲线） | 官方 01–03 仍无摆锤；匹配 HTTP 仍只那三张 |
| 编辑调试 | Place pendulum | 程序化占位，不是定稿美术 |

已交第十一批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 冰面：固体 + `zone.tags` 的 `ice` + `transform.yaw_bam`。支撑时按走路步长滑 | 可逆走相消、可侧向走下。不改协议帧 |
| 游戏性 | 示范课 `course_f_playable` revision 10：主路 +Z 两格冰面（不挡 +X 冲线） | 官方 01–03 仍无冰面 |
| 编辑调试 | Place ice（每摆一块 yaw 顺时针 90°） | 程序化占位，不是定稿美术 |

已交第十二批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 失败次数 HUD：Solo / Preview 显示本局环境失败次数 | **不进 v1 快照帧**，线上画不出来；不进 `hash_state` |

已交第十三批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 表现性 | 打碎碎裂反馈：可破坏占用离开 live set 时喷 4 块占位碎片，约 0.35 s 后消失 | 碎片不是占用、不进权威；换课不喷 |
| 游戏性 | Preview 开玩后耐久为 0 的箱子隐藏 | 编辑态仍显示，停玩后 rebuild 回来 |

已交第十四批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 表现性 | 楼层着色：普通固体按 `y/cell` 上层偏绿、下层偏品红 | 机关占位不染色；不是产品材质 |

已交第十五批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 表现性 | 压板 / 摆锤预警脉冲：gadget 按 tick 缩放 | 喷火 / 滚柱仍走已有半周期预警盒 |

已交第十六批（2026-09-09，一次章节 PR）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 示范课 `course_f_playable` revision 11 从侧廊展览改成有路线选择的一局。危险捷径沿 +X（z=0）：能量墙挡在 x=1，须站其 −Z 侧 Q 打碎；喷火 / 滚柱 / 摆锤 / 压板在主路上。安全路沿 z=+2，途中下到检查点 1 再绕回，经开关门与冰面；传送带在 z=+3 外侧。`--bot-run --course=course_f_playable` 重放危险捷径脚本 | 官方 01–03 仍无这些机关；匹配 HTTP 仍只那三张。不接线 `InteractIntent`。完整搜索会在喷火半周期上烧预算，所以 bot-run 走脚本而不是 A* |

已交第十七批（2026-09-09）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 编辑调试 | **Web 轻量 Edit 真机闭环**：`/play/?edit=1` 保留查询串；关窗 / 返回大厅拉回大厅；Web 草稿 `force_fs_sync`；浏览器走导出包验收 | 规则模板仍属 M4a。嵌入子窗仍是同一画布上的两块面板，不是第二个浏览器 tab |

已交第十八批（2026-09-09）：

| 轨 | 交付 | 诚实边界 |
|---|---|---|
| 游戏性 | 示范课 `course_f_playable` revision 12：危险捷径只留能量墙挡路（UseItem reach 只探 +Z，须站其 −Z 侧 Q），打碎后沿 +X 走完；喷火 / 滚柱 / 摆锤 / 压板改到 −Z 侧廊，捷径不再空等半周期。电梯离开安全路格子。`--bot-run --course=course_f_playable` 重放这条无等待脚本 | 完整搜索仍可能在侧廊周期机关上烧预算，所以 bot-run 仍走脚本 |
| 游戏性 | 新机关接到官方 01–03 侧廊：01 安全路外侧 z=+6（冰 / 传送带 / 开关门）；02 出生点 −Z（喷火 / 滚柱 / 地刺）；03 地面空格（弹射 / 电梯 / 压板 / 摆锤 / 开关传送）。+X 五步捷径与 course_01 安全路脚本不改 | 匹配 HTTP 仍只这三张。官方 01/02 不加额外可破坏（出生点 Q 仍只清那一只箱）。能量墙 / 碎石 / 核心留在示范课。不接线 `InteractIntent`。不改协议帧 |

退出：**已发生**（2026-09-09）。人类验证第十八批后宣布收口。下一动是 M4a。不设固定章数，不发明 M8。

### M-Export：平台导出与 Web

从 M5 前移。C1 已交 Windows / Linux Headless / Web 预设与包内核查，见 [CD-51 §5](../50-engineering/51-dev-environment.md)。

产出（剩余，按开工顺序）：

- **Web 游玩分发**（**第一刀，已交**）。验证 Web 端能运行、实现与桌面一致的可玩路径：用已有 Web 预设导出；浏览器打开能进一局；**测试期允许 Solo**；联机用大厅填写的**主机 + 端口**打自备 VPS（链接发给外人即可）。不是公开运营 TLS，不是每个 PR 的自动沙盒。明文口径见 [CD-11 §9](../10-product/11-scope-and-platforms.md)；Solo 口径见 [CD-13 §3](../10-product/13-account-and-session.md)。
- Web 轻量 Edit UI（可玩性深化的编辑轨已交入口、surface 分级与**浏览器真机闭环**；规则模板等 M4a）；
- 公开运营前 TLS / 域名 / 受信证书（**推迟到 M5 之后**，见 [CD-11 §9](../10-product/11-scope-and-platforms.md)）；
- 每个 PR 的公开临时 Web 沙盒（**推迟到 M5 之后**；[CD-53 §4.1](../50-engineering/53-testing-and-ci.md) 仍未实现）；
- Android / iOS 导出烟测（**一期收尾**；不是风险项，不挡可玩性深化 / M4a / M4b / M5 / M6 / M7）；
- Steam 预留（核心切片稳定后接入）。

验收：三套已有预设仍可用；Web 试玩包能发给外人打开——Solo 能完一局，或按所给链接 + 端口连上 VPS 测试服进一局；公开 Web 联机走 TLS（M5 之后补）；Android / iOS 在一期收尾能装上并进一局。触控 UI 仍属 D7，排在移动端烟测之后、同属一期收尾。

状态：**部分交付**。人类 2026-09-08：Web 游玩分发第一刀已交（浏览器 Solo、大厅 `主机[:控制面端口]`、查询串、控制面 CORS 与可选 `/play/`）。安卓 / iOS 烟测排到一期收尾。公开 TLS 与 PR Web 沙盒仍在 M5 之后。不发明 M8。

### M-Art：表现与美术

不解冻编号。解冻后、M5 可玩性签署前。C4 已交契约、占位规格与第一批 `.glb`。与 F 线重叠的 HUD / 动效 / 按 `asset_id` 解析 / 传送门已在 F 线做。其后与可玩性深化重叠的表现项跟深化段走，本号不重复。

产出（剩余）：

- 字体入包（**推迟到一期收尾**，不挡本号其它项、不挡 M-Export / M4a）；
- 按 `asset_id` 解析视觉（F 线 FC，已交）；
- 传送门模型（F 线 FC 占位；深化段可补专用模型，若仍无模型须诚实标注）；
- ~~clip / 绑定动画~~ **已交**（2026-09-05，路线 A）：`PlayAnimVisual` 把 C4 八态接到角色视觉，四态播 clip、四态程序化姿态；角色资产换 `animal-cat.glb`。只在 Solo / Preview 接线（v1 快照缺 `vy` / `stun`）。动画时长与过渡仍属 CD-63。口径见 [CD-21 §3.4](../20-gameplay/21-traprush.md)；
- 镜头、HUD 字段、皮肤、动效（**不阻塞 M3**；HUD 计时 / 结算表已由 F 线 FA 接线；皮肤池等 D-F9 未拍不开）。

验收：官方课占用不再依赖无资产回退盒（传送门若仍无模型须诚实标注）；可玩性签署能看见规格内的美术，而不是纯色块。

状态：**部分交付**。纠偏冻结令已解除。纠偏 E6（方案 §6，**不是** M5）已于 2026-09-02 签署：好玩。字体入包除外；未拍板的皮肤 / 镜头产品值不在深化段自选。

### M4a：Rule VM

原 M4 的 L2 半边。可玩性深化已于 2026-09-09 收口。不再以 Android / iOS 烟测为前置。

状态：**已收口**（2026-09-09）。第 1–5 章已交：信封 / 解释器 / gas / 图编译 / Event 分发 / §2.1 Query·Logic·Action 最小子集 / Preview P3 安全点重编译、公开对局禁止。其它 §2.1 事件仍编译拒绝。规则图不写入 AuthoringDocument / SimulationBundle。不发明 M8。下一动是 M5（M4b 第 1–5 章已收口）。

产出：

- 版本化字节码 Rule VM；
- gas；
- Preview 安全边界。

验收：白名单节点可解释；超 gas 拒绝；Preview 安全点行为与 [CD-33](../30-ugc/33-hot-publish.md) 等级一致。

### M4b：内容平台 + 账号

原 M4 的 L6 半边，并挂上 CD-11 §4 无主的账号 / 草稿云 / 内容广场。**不另开里程碑号，不发明 M8。**

状态：**已收口**（2026-09-10）。第 1–5 章已交：`ContentSign` sidecar + 控制面发布 HTTP + Godot `ContentCatalog` 按 `latest` 开新房；P0/P1 sidecar 补丁（`ContentPatch`：PatchHash = StateHasher 规范编码 ops 的 SHA-256；HMAC 覆盖 `content_id` + LF + `base_version` + LF + `seq` + LF + hash；信封七键）全量下发到同一 `content_id` + 锁住 `base_version` 的运行房，开局 latch 或检查点垫验收后生效；P2/P3 拒绝。进程内 `note_fault` 立刻追加反向 PatchHash（不走发布 HTTP）。`POST /content/:id/rollback` 把 `latest` 切回已签名旧版本，历史仍可读；下一发布号 = 已存 max(version)+1。结算 Godot payload 带 `content_hash` / `patch_hashes`，控制面结算 HTTP 不改。官方课仍不要求信封。内容广场：发布自动进公共列表；四标签；词库名；占用袋标签；`POST /content/:id/plays` 标已验证；评分拒绝自由文本；大厅 Solo 已签名 UGC。账号认领：Guest ID + 恢复密钥；用户名 + 密码；认领 Guest 云端最新草稿。匹配 HTTP 课表仍只 `course_01`/`course_02`/`course_03`。发布 HTTP 与入场票据仍不绑账号。不改 Bundle Schema。不发明 M8。下一动是 M5。

产出：

- 内容签名；
- P2/P3 新房生效；
- P0/P1 运行房全量安全边界生效；
- 进程内技术自动回滚；
- 内容广场；
- 账号认领草稿（本地 Guest 草稿已有，见 [CD-13](../10-product/13-account-and-session.md)）。

验收：运行中对局只接收兼容 P0/P1 补丁；P2/P3 只进入新房；回放完整记录基础哈希和补丁序列。

### M5：TRAPRUSH 纵向切片验收

状态：**进行中**（2026-09-10 A1 开工；**A1 / A2 / A3 / B1 / B2 / C1 / C2 / C5 已交**）。M4b 第 1–5 章收口后本号轮到。章节拆分见 [M5 章节计划](../../docs/plans/m5-traprush-vertical-slice.md)（11 章，实现级计划，不是本文件的替代）：人类当日已拍板章节顺序、音频模块基建、素材格式 OGG、总线与默认音量、音频资产预算（该计划 §5.1；预算数值落 [CD-11 §8.3](../10-product/11-scope-and-platforms.md)）。人类 2026-09-11 拍板 04 = 垂直塔、05 = 双路线竞速（该计划 §5.2 问题 2），并确认本地音频授权可用于正式 OGG 入库（该计划 §5.2 问题 1）。同日拍板 C3 控制面代签与 C4 匹配 `content` 对象（该计划 §5.2 问题 3 / 4；宪法第十八条）。C5 把 `tools/bot-runner/` 建成薄壳（该计划 §5.2 问题 5 的 bot-runner 半边）。C3 / C4 **已拍未接线**；下一实现刀是 C3。C6 仍待问题 6。不发明 M8。

产出：

- 3～5 张官方赛道（第 4 张及以后本号收）；
- BotRunner 可达性测试；
- 按需人工网络故障检查；
- 项目负责人可玩性清单；
- 编辑—预览—邀请—发布—游玩—单局结算闭环（发布依赖 M4b）；
- **音频系统**（人类 2026-09-10 拍板挂入本号）：独立、游戏无关、业务层与底层解耦的可复用音频模块，加 TRAPRUSH 的音效与背景音乐接线。BASTION 复用同一模块，不重开号。落点 `game/src/audio/`（目录归 [CD-41 §5](../40-technical/41-architecture.md)），玩法映射留在业务层。来源见 [CD-91 D.1](../90-reference/91-decision-log.md) `m5_audio_module = engine_agnostic_reusable_layer`。

导出归 **M-Export**，不再作为本号退出条件。Android / iOS 烟测排到一期收尾，不构成本号前置或退出项。

验收：完整完成"编辑—预览—邀请—发布—游玩—单局结算"闭环。音频部分的验收是：Solo / Preview / 联机三条路径都有声，Headless 与 CI 静默，`game/src/audio/**` 通过「零玩法词汇」红线扫描。

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

## 5. 一期必做项所有者

[CD-11 §4](../10-product/11-scope-and-platforms.md#4-一期必须完成) 每条必做项在本文件都有里程碑所有者。批准记录见 [草案](../../docs/plans/cd-61-rearrangement-draft.md)。

| # | CD-11 §4 必做项 | 所有者 |
|---|---|---|
| 1 | Godot 4 + GDScript 骨架 | **M0**（已退出） |
| 2 | 桌面客户端与 Headless 权威服 | **M0** 骨架 + **M3** 真仿真 |
| 3 | TRAPRUSH 线上纵向切片 | **M5** |
| 4 | BASTION 最小纵向切片 | **M6 / M7** |
| 5 | 共用游戏内 Edit | **M2**（已退出） |
| 6 | Web 轻量 Edit、桌面完整 Edit、共享框架 | 桌面完整 + 共享框架 = **M2**；Web 轻量 Edit = **M-Export** |
| 7 | Edit → Validate → Preview → Publish | Edit/Preview = **M2**；Publish = **M4b** |
| 8 | 不可变版本、签名、P0/P1 补丁、回滚 | **M4b** |
| 9 | 单局排名与结算 | **M3** |
| 10 | 离线单人试玩 | **M3** |
| 11 | 香港区固定容量与排队 | 容量模型 = [CD-44](../40-technical/44-deployment.md) / **M3** 排队；远端部署手册 = **M-Export** |
| 12 | Fastify、SQLite、COS、网关、MatchHost | **M0** 骨架 + **M3** 真匹配 |
| 13 | AI 工作规则、测试门禁、变更审计 | **M0** + [CD-52](../50-engineering/52-ai-workflow.md) / [CD-53](../50-engineering/53-testing-and-ci.md) |
| 14 | 每个 PR 的公开临时 Web 沙盒预览 | **M-Export** |
| 15 | PC/Steam、Android、iOS 工程预留与基本导出验证 | **M-Export** |

Rule VM 属 **M4a**（从原 M4 拆出的 L2 半边；不在 CD-11 §4 十五条里单独成行）。可玩性深化已收口。本号按顺序开工。Android / iOS 不是 M4a 前置。

原先无主的三条纵向线：

| 纵向线 | 所有者 |
|---|---|
| 表现 / 美术 | **M-Art** |
| 平台导出与 Web | **M-Export** |
| 账号 + 草稿云 + 内容平台 | **M4b** |
