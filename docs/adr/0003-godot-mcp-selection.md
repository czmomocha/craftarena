# ADR-0003 Godot 主 MCP 的选择

- 状态：**已拍板——采纳选项 A**（2026-08-20 由项目负责人裁定：暂不选定，M2 启动前重新评估）
- 日期：2026-08-20
- 相关：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第七、十二、十八条、[CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)、[CD-63 §2.1](../../Confirmed-docs/60-plan/63-open-decisions.md)

## 背景

CD-61 把「Godot MCP 专项调研项」列为 M0 产出。注意措辞是**调研项**，不是「安装 MCP」：CD-63 §2.1 把「唯一 Godot 主 MCP 的最终选择」列为开发期未决事项，AGENTS.md §5 因此禁止 AI 自行选定。本 ADR 交付调研结论与推荐，安装与否由人类决定。

约束来自三条红线：

- **第七条**：客户端技术栈固定为 Godot 4 Standard + GDScript，禁止创建 `.cs` / `.csproj`。任何要求 Godot .NET 版本的方案直接出局；
- **第十二条**：大型 `.tscn` 修改优先通过 MCP、Editor API 和 UndoRedo。这是 MCP 的主要价值来源，也意味着不支持 `EditorUndoRedoManager` 的方案没有意义；
- **第十八条**：新依赖和许可证属于人类门禁项。MCP 编辑器插件握有工程完整读写权限，外加一个 Node.js 进程，供应链面积不小。

CD-51 §1 另有一条硬约束：**不要在同一个工程里同时启用多个功能重叠的 Godot MCP**，所以这是一次单选。

## 候选调研

调研时间 2026-08-20，数据来自各仓库主页与发布记录。

| 方案 | 插件语言 | 活跃度 | Stars | 关键事实 |
|---|---|---|---|---|
| [IvanMurzak/Godot-MCP](https://github.com/IvanMurzak/Godot-MCP) | **C#** | 高（v0.20.0，2026-07） | 217 | Apache-2.0；要求 Godot .NET；额外带 ai-game.dev 云连接 |
| [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp) | GDScript | 高（v4.1.0，2026-06） | 144 | 场景编辑、输入注入、确定性 playtest、实时游戏状态 |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | GDScript | 低 | 5 274 | MIT；能力仅限启动编辑器、运行工程、抓调试输出，**不做场景编辑** |
| [KeeVeeG/godot-mcp](https://github.com/KeeVeeG/godot-mcp) | GDScript | 新项目 | 13 | 声称 300+ 工具、已测 4.7、含 UndoRedo Helper |
| [emojiiii/godot-mcp](https://github.com/emojiiii/godot-mcp) | GDScript | 新项目 | 0 | 事务化内核、权限分级、dry-run、审计日志，基于 `EditorUndoRedoManager`；目标 4.2+，实测 profile 4.3 |
| [Raunaksplanet/godot-mcp-server](https://github.com/Raunaksplanet/godot-mcp-server) | GDScript | 新项目 | 1 | 40+ 工具，4.2+ |
| Godot MCP Pro（tomyud1） | GDScript | 商业产品 | — | 162 工具，要求 4.4+；闭源付费，许可证需单独审查 |

三个结论：

1. **star 数与可用性完全脱节。** Coding-Solo 拿了 5 274 星，但它的能力范围（启动编辑器、跑工程、读日志）恰好是我们已经用命令行做到的部分，而第十二条真正需要的场景编辑与 UndoRedo 它不提供。
2. **维护最活跃的方案被宪法第七条淘汰。** IvanMurzak 的 Godot-MCP 是 C# 插件、需要 Godot .NET，还引入一条到 ai-game.dev 的云连接。
3. **架构上最贴合本项目的方案没有任何社区验证。** emojiiii 那套事务 + 权限分级 + dry-run + 审计的设计几乎是照着我们的安全要求写的，但 0 star、0 fork，等于把工程写权限交给一个无人复核的新仓库。

换句话说，当前不存在「活跃维护 + 社区验证 + 纯 GDScript + 覆盖 UndoRedo」四项同时成立的选项。

## 推荐

**推荐选项 A：暂不选定，推迟到 M2 启动前重新评估。**

理由：

- **现在还用不上。** M0 全程没有 MCP：`project.godot` 由 `ProjectSettings` API 生成（[ADR-0002](0002-project-godot-generated-by-engine-api.md)），脚本用文件工具写，运行、错误读取、测试全部由命令行完成，CI 也是这套命令。CD-51 §6 本来就把「受审查的 Editor API / 文件方式」写成了 MCP 未拍板时的正式路径，我们已经把它跑通了。
- **M1 的工作性质不需要它。** 下一阶段是定点 SimulationCore 与共享契约，产出以 `.gd` 与测试为主，几乎不碰 `.tscn`。MCP 的价值集中在大量场景编辑上，也就是 M2 的 Edit 框架。
- **再等几个月的信息增量很大。** 这批仓库多数在 2026 年才出现，版本号跳得很快（satelliteoflove 一个月内从 3.19 走到 4.1）。现在选一个新项目，很可能在 M2 之前就要重选一次，而 CD-51 §1 只允许启用一个。
- **风险已经在册。** CD-62 已把「Godot 主 MCP 未选定」记为「中，延期」，本推荐与既有风险判断一致，不需要改变风险等级。

代价是：M2 期间若仍未选定，`.tscn` 的批量修改要靠人工或自建 Editor 脚本，效率低于 MCP。这个代价在 M1 期间不发生。

**若人类希望现在就选，推荐顺序：**

1. **satelliteoflove/godot-mcp** — 四项里唯一活跃维护且功能覆盖场景编辑的 GDScript 方案，144 star 说明有一定真实使用。主要未知项是它对 Godot 4.7 的支持情况和 UndoRedo 完整度，需要按下面的清单实测。
2. **KeeVeeG/godot-mcp** — 明确声称已在 4.7 上测试并实现了 UndoRedo Helper，与我们的引擎版本对得最齐；风险是项目极新、只有 13 star，等于我们做第一批用户。

**明确不推荐**：IvanMurzak（违反第七条）、Coding-Solo（不解决第十二条要的问题）、Godot MCP Pro（闭源付费，第十八条许可证门禁成本高于当前收益）。

## 拍板后的验证清单

无论最终选哪个，安装前必须按 CD-62 的五个维度实测，通过才能写进 CD-51 §1：

1. **UndoRedo**：通过 MCP 创建、修改、重命名节点后，在编辑器里 Ctrl+Z 能逐步回退到原状态，且 `.tscn` diff 干净（第十二条）；
2. **运行**：能启动工程并在运行中读取场景树与属性；
3. **错误读取**：能取到解析错误、运行时错误与我们设为 Error 的类型警告（[ADR-0001](0001-strict-gdscript-typing-gate.md)），且报错定位到文件与行；
4. **Headless**：MCP 不可用或编辑器未开时，现有命令行闭环仍然完整——MCP 只能是加速器，不能成为构建与 CI 的必需依赖；
5. **维护性与安全**：许可证可接受、依赖树可审查、插件只监听回环地址、不含未声明的外呼（IvanMurzak 那条云连接就是反例）。

另外两条项目专属要求：

6. 插件放在 `game/addons/` 下，受 ADR-0001 的 `res://addons` 警告豁免覆盖，不得污染核心目录的类型门禁；
7. `game/addons/<mcp>/` 是否入库需要单独决定——GUT 入库是因为 CI 要跑测试，而 MCP 只服务本地开发，CI 不需要它。

## 拍板结果

- [x] **选项 A：暂不选定，M2 启动前重新评估**（2026-08-20 由项目负责人裁定）
- [ ] 选项 B：选定 satelliteoflove/godot-mcp
- [ ] 选项 C：选定 KeeVeeG/godot-mcp
- [ ] 选项 D：其他方案

生效内容：

- M1 期间不安装任何 Godot MCP，继续走 CD-51 §6 的「受审查的 Editor API / 文件方式」；
- 重估触发点是 **M2 启动前**，届时按本 ADR 的七条清单实测候选，结论写成新的 ADR；
- 在重估完成前，任何 Agent 不得以「提高效率」为由自行安装 MCP（宪法第十八条：新依赖属人类门禁）。

已同步：[CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md)「Godot AI 接入」行与 §4 安装步骤、[CD-63 §2.1](../../Confirmed-docs/60-plan/63-open-decisions.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) 风险行、[CD-91 D.6](../../Confirmed-docs/90-reference/91-decision-log.md)。
