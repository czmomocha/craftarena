# ADR-0003 Godot 主 MCP 的选择

- 状态：**已拍板——选定 Godot AI**（2026-08-21 由项目负责人裁定；覆盖 2026-08-20 的选项 A）。阶段 C 生产级启用已通过（2026-08-23，见 [ADR-0004 §8.1](0004-multi-agent-adoption-timing-and-architecture.md)）
- 日期：2026-08-20（初稿） / 2026-08-21（选定） / 2026-08-23（阶段 C 通过）
- 相关：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第七、十二、十八条、[CD-51](../../Confirmed-docs/50-engineering/51-dev-environment.md)、[CD-52](../../Confirmed-docs/50-engineering/52-ai-workflow.md)、[CD-61](../../Confirmed-docs/60-plan/61-milestones.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)

## 背景

CD-61 把「Godot MCP 专项调研项」列为 M0 产出。注意措辞是**调研项**，不是「安装 MCP」。M0 退出时本 ADR 采纳选项 A（暂不选定，M2 启动前重估）。M0 全部完成后、M1 启动前，项目负责人完成第二轮调研并拍板唯一主 MCP。

约束来自三条红线：

- **第七条**：客户端技术栈固定为 Godot 4 Standard + GDScript，禁止创建 `.cs` / `.csproj`。任何要求 Godot .NET 版本的方案直接出局；
- **第十二条**：大型 `.tscn` 修改优先通过 MCP、Editor API 和 UndoRedo。不支持 `EditorUndoRedoManager` / `EditorPlugin.get_undo_redo()` 的方案没有意义；
- **第十八条**：新依赖和许可证属于人类门禁项。MCP 编辑器插件握有工程完整读写权限，外加一个本机 Python 进程，供应链面积不小。

CD-51 §1 另有一条硬约束：**不要在同一个工程里同时启用多个功能重叠的 Godot MCP**，所以这是一次单选。

## 候选调研

2026-08-20 第一轮只覆盖了若干 GitHub 仓库，**漏掉了已在 Godot Asset Library 上架、且与 Cursor 一键配置对齐的 Godot AI**。2026-08-21 补入。数据来自各仓库主页、Asset Library 与发布记录。

| 方案 | 插件语言 | 活跃度 | 关键事实 |
|---|---|---|---|
| **[hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)**（Godot AI） | **GDScript** 插件 + **Python (uv)** 本机 MCP 服务 | 高（v3.1.5，2026-08-11；Asset Library #5050） | **MIT、免费开源**；~43 个 MCP 工具 / 120+ 操作；官方推荐 Godot 4.7+；Cursor 等客户端可由编辑器 Dock 一键 Configure；默认绑 `127.0.0.1`；匿名遥测**默认开**，可用环境变量与 Dock 开关关闭 |
| [IvanMurzak/Godot-MCP](https://github.com/IvanMurzak/Godot-MCP) | **C#** | 高 | Apache-2.0；要求 Godot .NET；额外带 ai-game.dev 云连接 |
| [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp) | GDScript | 高 | 场景编辑、输入注入、确定性 playtest |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | GDScript | 低（高 star） | MIT；能力仅限启动编辑器、运行工程、抓调试输出，**不做场景编辑** |
| [KeeVeeG/godot-mcp](https://github.com/KeeVeeG/godot-mcp) | GDScript | 新项目 | 声称 300+ 工具、已测 4.7、含 UndoRedo Helper |
| [emojiiii/godot-mcp](https://github.com/emojiiii/godot-mcp) | GDScript | 新项目 | 事务化内核、权限分级、dry-run、审计日志 |
| Godot MCP Pro（tomyud1） | GDScript | 商业产品 | 闭源付费，许可证需单独审查 |

三个仍然成立的结论：

1. **star 数与可用性完全脱节。** Coding-Solo 的能力范围恰好是本仓库已经用命令行做到的部分，第十二条真正需要的场景编辑与 UndoRedo 它不提供。
2. **维护很活跃但要求 .NET 的方案被宪法第七条淘汰。** IvanMurzak 是 C# 插件，还引入云连接。
3. **Godot AI 补上了第一轮「活跃维护 + 纯 GDScript 插件 + 场景编辑 + Cursor 接入」的缺口。** MCP 协议进程是 Python 而不是再嵌一套 Node；插件本身是 GDScript，不引入 `.cs`。Python 侧由 `uv`/`uvx` 按**精确包版本**拉起，不把 CPython 工具链写进游戏工程。

## 选定

**选定 Godot AI（`hi-godot/godot-ai`）作为本仓库唯一 Godot 主 MCP。**

精确版本、安装顺序、遥测开关与接入阶段的所有者是 [CD-51](../../Confirmed-docs/50-engineering/51-dev-environment.md)；任务里何时允许调用 MCP 的所有者是 [CD-52](../../Confirmed-docs/50-engineering/52-ai-workflow.md)。本 ADR 只锁定「选谁、为什么、分几段启用、什么叫生产级」。

理由：

- **许可证与成本**：MIT、免费、源码公开，第十八条可审查；
- **引擎与语言**：GDScript 编辑器插件，官方推荐 4.7+，对齐本仓库锁定的 4.7.2-stable Standard；
- **能力覆盖第十二条**：场景 / 节点 / 信号 / 资源编辑，插件通过 `EditorPlugin.get_undo_redo()` 接入编辑器撤销栈；`batch_execute` 可在失败时回滚一批命令；
- **与现有命令行闭环正交**：MCP 需要打开的编辑器会话。Headless、CI、MatchServer 继续走 README 里的命令，不把 MCP 做成构建依赖；
- **匿名遥测可关**：默认会向外发送工具名、成败、耗时、匿名安装 UUID 与平台信息。本项目**强制关闭**，关闭方式见 CD-51 §7.2，不得只靠「声称匿名」而保持默认开。

明确不采用：IvanMurzak（第七条 + 云连接）、Coding-Solo（不解决场景编辑）、Godot MCP Pro（闭源付费）、以及任何第二套功能重叠的 Godot MCP。

## 分阶段启用（时机）

选定 ≠ 立刻把 MCP 变成日常主路径，更不等于玩家侧生产依赖。按里程碑切开，避免和第十二条、第九条抢同一任务。

```text
现在（M0 已退出，M1 尚未开始）
  文档拍板：唯一主 MCP = Godot AI；遥测必须关；插件不入库
      ↓
接入烟测（独立环境任务，可与 M1 灰盒编码并行，但不得并进 SimulationCore）
  本机装 uv → 先写遥测环境变量 → 装锁定版本插件 → Dock 再关一次遥测
  → Configure Cursor → 按七条清单 + 遥测核实签字
      ↓
M1 默认路径
  SimulationCore / 契约 / GUT / Headless：继续文件 + 命令行
  仅当接入烟测已在该开发机签字：允许用 MCP 改表现层占位场景
      ↓
M2 启动门禁 = 生产级启用
  七条清单全绿、遥测关闭核实、project.godot 无 MCP autoload 脏写入、
  大型 .tscn 必须走 MCP / Editor API / UndoRedo
      ↓
M2 及以后
  AuthoringWorld、Edit UI、官方赛道表现场景：这是 MCP 的正式主场
  玩家包、MatchServer、CI：永远不依赖 Godot AI
```

### 阶段 A — 现在：只改文档

本决策落 ADR 与所有者文档。任何 Agent **仍不得**在未跑接入烟测的机器上自行拷贝插件、改 `project.godot` 的插件列表，或把 MCP 写进 CI。

### 阶段 B — 接入烟测：配置与测试的合适时机

这是**第一次允许在开发机安装**的时机，也是遥测开关必须生效的时机。

- **为什么不塞进 M1 的定点仿真任务**：M1 产出是 `.gd`、契约和状态哈希，几乎不碰大型 `.tscn`。把供应链、uv、编辑器插件和 Cursor MCP 配置混进 SimulationCore，违反第九条。
- **为什么也不再拖到 M2 才第一次安装**：M2 一开始就要高频改场景。把「装得起来、遥测确实关了、UndoRedo 能用」留到 M2 第一周，会让 Edit 框架和工具调试缠在一起。
- **谁做**：人类按 [Godot AI 接入烟测](../runbooks/godot-ai-mcp-setup.md) 在 Windows 开发机执行并签字；若继续用第二台 Mac 做场景编辑，Mac 上再签一次。AI 可以协助对照清单，但不能跳过人类签字。
- **通过之前**：CD-51 §6 第 2 步继续走受审查的文件方式；Agent 不得把「编辑器没开 / MCP 连不上」当成任务失败。
- **通过之后**：该开发机上允许 MCP，但仍不是 CI 依赖，也不是 M1 退出条件。

### 阶段 C — M2 启动：生产级启用

「生产级」在这里**只指开发工具链达到可日常依赖的工程标准**，不是把 Godot AI 打进玩家包。M2 启动前必须同时成立：

1. 阶段 B 的七条清单在将要改场景的开发机上全绿；
2. 匿名遥测关闭已核实（环境变量 + Dock 开关 + attach 参数，见 CD-51 §7.2）；
3. 入库卫生：`game/addons/godot_ai/` 不进 Git；已提交的 `project.godot` 不出现 `godot_ai` 插件项、不出现 `_mcp_game_helper` autoload；
4. 大型 `.tscn` 的默认修改路径切到 MCP / Editor API / UndoRedo（宪法第十二条从「优先」变成 M2 场景任务的验收口径）。

未满足以上四条，不得把「用 MCP 搭两张赛道」写成 M2 任务的唯一路径。命令行与文件方式仍是 MCP 不可用时的退路。

**2026-08-23**：以上四条已成立（烟测签字见 [接入清单第 10 步](../runbooks/godot-ai-mcp-setup.md)；入库卫生以已提交 `project.godot` 为准）。阶段 C **通过**。不重选 MCP。大型 `.tscn` 的默认路径切换见 [CD-52 §7.1](../../Confirmed-docs/50-engineering/52-ai-workflow.md)。

### 阶段 D — M2 及以后：真正的生产级应用

MCP 的正式主场是内容生产平面里的**编辑器侧**工作，不是对局数据平面：

| 允许（开发机 + 打开的编辑器） | 禁止 |
|---|---|
| AuthoringWorld 表现场景、Edit / HUD / 大厅节点树、官方赛道灰盒布局 | 把 Godot AI 当作 MatchServer、导出包或 CI 的依赖 |
| 经 UndoRedo / `batch_execute` 的节点与资源编辑 | 无上下文重写整个 `.tscn` |
| 用 `logs_read` / `project_run` 读编辑器与试玩报错 | 用 `editor_manage(op="game_eval")` 执行任意运行时脚本，或把它当成权威仿真 |
| 用 `api_manage` 查 Godot 4 ClassDB，减少猜 API | 用 Godot AI 自带的 `test_run` / `McpTestSuite` 替代 GUT 与 CD-53 门禁 |
| — | 开启 Vision Routing（会把截图发到 Groq / Gemini / xAI） |
| — | `--allow-host` 把 HTTP MCP 绑出回环 |
| — | 同时启用第二套 Godot MCP |

玩家导出：Godot AI 3.1.x 会在导出时从内存里剥掉 `_mcp_game_helper`，但这**不能**代替「已提交的 `project.godot` 根本不写该 autoload」。Headless MatchServer 跑的是源码工程，不是导出包；autoload 一旦入库，就会进权威进程。

## 拍板后的验证清单

接入烟测（阶段 B）与生产级启用（阶段 C）共用下列条目。未通过不得声称「MCP 已可用」。

1. **UndoRedo**：通过 MCP 创建、修改、重命名节点后，在编辑器里 Ctrl+Z 能逐步回退到原状态，且临时场景的 `.tscn` diff 可解释（第十二条）；
2. **运行**：能 `project_run`（或等价）启动工程，并在运行中读取场景树或日志；
3. **错误读取**：能取到解析错误、运行时错误与我们设为 Error 的类型警告（[ADR-0001](0001-strict-gdscript-typing-gate.md)），且报错定位到文件与行（`logs_read(source="editor", include_details=true)` 或写脚本响应里的 `diagnostics`）；
4. **Headless**：MCP 不可用或编辑器未开时，README 中的命令行闭环仍然完整——MCP 只能是加速器，不能成为构建与 CI 的必需依赖；
5. **维护性与安全**：MIT 已确认；插件只监听回环；禁止 `--allow-host`；Python 包版本与插件版本一致；无未声明云连接（Vision Routing 保持默认关）；
6. **目录与类型门禁**：插件若出现在本机 `game/addons/godot_ai/`，落在 ADR-0001 的 `res://addons` 警告豁免内，不得污染 `shared/` / `simulation/` / `ugc/` / `server/`；
7. **不入库**：GUT 入库是因为 CI 要跑测试；Godot AI 只服务本地打开的编辑器。`game/addons/godot_ai/` 进入 `.gitignore`，CI 不安装 uv、不启动该插件。

另外三条本项目专属：

8. **遥测**：首次启用插件之前就写入 `GODOT_AI_DISABLE_TELEMETRY=true`；Dock 设置里 Telemetry 为关；Cursor 的 attach 参数含 `--disable-telemetry`；重启服务后本机不出现 `customer_uuid.txt`；
9. **`project.godot` 卫生**：启用插件往往会写入插件列表和 `_mcp_game_helper` autoload。烟测结束后必须把这两处从待提交变更里丢掉，已提交副本只保留 GUT；
10. **不替代权威仿真**：MCP 改的是 PresentationWorld / 编辑器对象。位置、命中、胜负仍只由服务端 `SimulationWorld` 裁决。

## 拍板结果

- [ ] ~~选项 A：暂不选定，M2 启动前重新评估~~（2026-08-20 曾采纳；**2026-08-21 由选项 E 覆盖**）
- [ ] 选项 B：选定 satelliteoflove/godot-mcp
- [ ] 选项 C：选定 KeeVeeG/godot-mcp
- [ ] 选项 D：其他方案（当时未列名）
- [x] **选项 E：选定 Godot AI（hi-godot/godot-ai）**（2026-08-21 由项目负责人裁定）

生效内容：

- 唯一主 MCP 为 Godot AI；精确版本与安装步骤见 CD-51 §1 / §7；
- 匿名遥测必须关闭，关闭时机是**第一次启动带插件的编辑器之前**；
- 接入烟测与 M1 SimulationCore 拆开；阶段 C 生产级启用已于 2026-08-23 通过（[ADR-0004 §8.1](0004-multi-agent-adoption-timing-and-architecture.md)）；
- 插件不入库；禁止第二套 Godot MCP；
- 在人类按接入清单签字前，任何 Agent 不得以「提高效率」为由自行安装或把 MCP 写进 CI（宪法第十八条：新依赖属人类门禁，本 ADR 只授权按 CD-51 执行，不授权跳过烟测）。

已同步：[CD-51](../../Confirmed-docs/50-engineering/51-dev-environment.md)、[CD-52](../../Confirmed-docs/50-engineering/52-ai-workflow.md)、[CD-61](../../Confirmed-docs/60-plan/61-milestones.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)、[CD-63 §2.1](../../Confirmed-docs/60-plan/63-open-decisions.md)、[CD-91 D.6](../../Confirmed-docs/90-reference/91-decision-log.md)、[CD-41 §5](../../Confirmed-docs/40-technical/41-architecture.md)。
