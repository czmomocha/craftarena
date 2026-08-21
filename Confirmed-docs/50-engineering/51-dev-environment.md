# CD-51 开发环境搭建

> 文档 ID：CD-51
> 单一事实源：工具选型与版本锁定策略、资产入库规则、密钥管理边界、Windows / macOS 安装步骤、Godot 项目初始设置、AI 环境烟测清单、Godot AI MCP 安装与遥测开关
> 加载建议：搭建或修复环境、升级依赖、调整项目设置、安装或关闭 Godot 主 MCP 遥测时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第七、十八、二十三条
> 相关：[CD-41 架构](../40-technical/41-architecture.md)、[CD-52 AI 协作规范](52-ai-workflow.md)、[CD-53 测试与 CI](53-testing-and-ci.md)、[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)
> 派生自：初稿 v0.2 §39–§42

## 1. 基础工具

| 工具 | 选型 |
|---|---|
| 游戏引擎 | Godot **4.7.2-stable** Standard；编辑器与导出模板锁定同一精确版本，所有开发机与 CI 必须一致 |
| 游戏脚本 | GDScript；核心目录强制静态类型 |
| 控制面 | TypeScript + Node.js + Fastify |
| 测试期数据库 | SQLite；仅控制面直接访问 |
| 实时入口 | 独立 TypeScript TLS WebSocket 网关 |
| AI IDE | Cursor |
| Godot 主 MCP | **Godot AI**（[hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)，MIT）；编辑器插件 **3.1.5** + 同版本 PyPI 包 `godot-ai==3.1.5`，由本机 [uv](https://docs.astral.sh/uv/) / `uvx` 拉起 Python 服务。唯一启用的 Godot MCP，理由与阶段见 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)。**匿名遥测必须关闭**（§7.2）。插件**不入库**（`game/addons/godot_ai/` 已 gitignore）；CI 与 Headless 不依赖它 |
| 单元测试 | GUT **9.7.1**（MIT）；随仓库入库于 `game/addons/gut/`，升级须同步本行 |
| 版本管理 | GitHub 私有 Monorepo；受保护 `main`；Git LFS |
| 3D 工具 | Blender，统一导出 GLB/glTF |
| 服务端本地环境 | Godot Headless + Node.js 服务；Docker Compose 可选 |
| CI | 目标为 GitHub Actions Linux + 自托管 Windows Runner。**当前只有 Linux 一档在跑**，自托管 Windows Runner 尚未搭建；Windows 与 macOS 开发机上的引擎行为都靠人工执行 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) |
| 云环境 | 腾讯云香港计算与 COS；本地 + 一个长期测试环境 |

不要在同一个工程里同时启用多个功能重叠的 Godot MCP，以免 AI 选择错误工具或重复修改场景。Godot AI 的 Python 服务只绑回环地址；禁止为了「远程 Agent」打开 `--allow-host`。

## 2. 资产入库与版本锁定

- 可复现所需的 `.blend`、原始音频、高分辨率源文件，以及运行时 GLB/压缩音频进入 Git LFS；`.godot/imported` 不提交；
- 引擎、插件、npm 包和导出模板锁定精确版本；
- 每月集中评估补丁升级；大版本只在里程碑边界试验，且必须可回退。

## 3. 密钥边界

- 仓库只允许提交本地或 PR 沙盒可随时销毁的**假凭据**；
- 长期测试环境的数据库、COS、JWT、内容签名等密钥必须放 GitHub Secrets 或服务器外部配置，不得进入 Git 历史或 Web 构建。

## 4. Windows 初始安装

1. 下载 Godot 4.7.2-stable Standard，不下载 .NET 版；
2. 安装 Git；
3. 安装 Cursor；
4. 安装 Blender；
5. 配置 Godot 可执行文件环境变量；
6. 新建项目时选择 Compatibility；
7. 安装 GUT；
8. 创建 `AGENTS.md` 和项目规则；
9. 建立 `game/`、`backend/`、`infra/`、`docs/` 的 Monorepo 骨架；
10. **不要在这一步安装 Godot MCP。** 主 MCP 已选定为 Godot AI，但安装、关遥测与接入烟测是独立任务，见 §7，禁止与新建工程、GUT、Monorepo 骨架混在一次变更里；
11. 运行最小编辑、启动、Headless、Fastify、网关和测试闭环。

第 5 步的环境变量约定：所有命令通过 `GODOT4` 定位引擎，禁止把安装路径写死在脚本里。Windows 上还需要 `GODOT4_CONSOLE` 指向同版本的 `_console.exe`，否则 PowerShell 读不到引擎 stdout。

```powershell
[Environment]::SetEnvironmentVariable("GODOT4", "<安装目录>\Godot_v4.7.2-stable_win64.exe", "User")
[Environment]::SetEnvironmentVariable("GODOT4_CONSOLE", "<安装目录>\Godot_v4.7.2-stable_win64_console.exe", "User")
```

若该机器稍后要跑 §7 接入烟测，把 `GODOT_AI_DISABLE_TELEMETRY=true` 写进同一组用户环境变量，且必须早于第一次启用插件。不要把绝对路径写进仓库脚本。

第 6 步不经项目管理器 GUI，改由引擎 API 脚本生成 `project.godot`，理由见 [ADR-0002](../../docs/adr/0002-project-godot-generated-by-engine-api.md)。

**具体可执行的命令行不在本文件维护**，一律以仓库 [README.md](../../README.md) 的命令表为准，禁止让每个 Agent 自己猜参数。

## 4.1 在已有仓库的第二台机器上（macOS）

本节给「Windows 开发机已经跑通、另一台 Mac 要拉同一份代码」用。第 6–9 步（新建工程、装 GUT、写 AGENTS.md、建骨架）不要再做，那些已经在仓库里。

2026-08-20 已在 macOS 26.5.2（arm64）真机跑通。逐步命令与签字记录见 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md)；固定命令以 [README.md](../../README.md) 的 macOS 列为准。本节只写安装顺序。

与 Windows 不同、跑烟测时不要照搬的两点：`--check-only` 在类型错误时会打印 `Warning treated as error`，但进程退出码仍为 0（以日志为准）；MatchHost 拉起的对局只有一个 Godot 进程，没有 `_console.exe` 外层。

1. 安装 Git，并启用 Git LFS（`git lfs install`）。仓库有 LFS 指针，跳过会让后续 `--check-only` 和 GUT 读到指针文件而不是真文件；
2. 安装 Node.js **24.x**（与 `package.json` 的 `engines.node` 一致）；
3. 安装 Cursor；
4. 下载 Godot **4.7.2-stable Standard** 的 macOS 包，不下载 .NET 版；解压后的 `.app` 放进 `/Applications`；
5. 只设 `GODOT4`，指向 `.app` 包内的可执行文件。macOS 没有 Windows 那种 GUI / console 双 exe，不要设 `GODOT4_CONSOLE`；
6. 克隆仓库（私有仓库，用有权限的 GitHub 账号）。**不要**再跑一遍 Windows 上已经做过的项目初始化；
7. **不必为了跑环境烟测而安装 Godot AI。** 若这台 Mac 也要用 MCP 改场景，另按 §7 做接入烟测：先写遥测环境变量，再装锁定版本插件；不要从 Asset Library 抓「最新」；不要提交 `game/addons/godot_ai/` 或 `project.godot` 里的插件 / `_mcp_game_helper` 行；
8. 在仓库根目录 `npm ci`，再按 README 的 macOS 列做一次 `--headless --import`（干净检出没有 `.godot/` 导入缓存）；
9. 按 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) 的 macOS 列从头跑一遍；另开一次编辑器做 GUI 检查。若该机器也要用 MCP 改场景，再按 [Godot AI 接入烟测](../../docs/runbooks/godot-ai-mcp-setup.md) 签字。

环境变量示例（路径按本机实际安装位置改）：

```bash
export GODOT4="/Applications/Godot.app/Contents/MacOS/Godot"
# 若要跑 Godot AI 接入烟测，必须先于启用插件：
export GODOT_AI_DISABLE_TELEMETRY=true
```

写入 `~/.zshrc` 或 `~/.bashrc` 后新开终端生效。验证：`"$GODOT4" --version` 必须输出 `4.7.2.stable`，且与 Windows 开发机、CI 使用同一精确版本。

## 5. Godot 项目初始设置

必须先配置：

- 渲染器：Compatibility；
- 物理 Tick：由每个玩法的 `SimulationCore` 自己固定推进，不直接依赖帧率；
- 数值：核心位置、速度、计时、经济和伤害使用定点整数；
- 输入动作：移动、跳跃、使用道具、交互、编辑器相机、建造、升级、出售；
- 语言：GDScript；
- 类型：`shared/`、`simulation/`、`ugc/`、`server/` 静态类型且警告视为错误；UI/工具可有限使用 `Variant`，进入核心边界前必须校验。Godot 4.7 无法按目录收紧警告，落地方式见 [ADR-0001](../../docs/adr/0001-strict-gdscript-typing-gate.md)；
- 文件命名：`snake_case`；
- 资源导入：统一 GLB；
- 自动加载：只放稳定的基础服务，不把大量玩法状态塞进 Autoload；
- 日志：开发构建输出结构化日志；
- 导出：Windows、Linux Headless、Android、iOS 占位预设；
- Web 预设在核心切片稳定后加入。

## 6. AI 环境验证烟测

环境搭好后，AI 必须完成以下闭环：

1. 读取项目版本、依赖锁和目录；
2. 若该开发机已按 §7 完成 Godot AI 接入烟测签字，可通过 MCP 创建一个临时测试场景（须走编辑器 UndoRedo）；否则使用受审查的 Editor API/文件方式。M0 环境烟测已用文件方式跑通，不必为了 MCP 重做那十步；
3. 创建一个静态类型 GDScript；
4. 运行语法检查；
5. 启动游戏并读取控制台；
6. 运行一个 GUT 测试；
7. 启动一个 Headless 实例；
8. 启动 Fastify、网关与 MatchHost 的最小健康闭环；
9. 删除临时测试内容；
10. 输出实际使用的命令和结果。

**未完成这套闭环，不进入正式功能开发。** 人类须按同一份清单在开发机复跑并签字；仅有 AI 执行记录不够。

可执行版本与历次执行记录见 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md)。上面十步是本节拥有的要求，那份 runbook 只是它的落地形式；步骤增减先改这里。M0 退出时该闭环已由 AI 与人类在 Windows 上各跑通一次；2026-08-20 人类在第二台开发机（macOS）按同一清单再跑通一次，记录见清单第 10 步。

## 7. Godot AI（唯一主 MCP）

选型理由、分阶段启用与「生产级」含义见 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)。本节只拥有：**装什么版本、按什么顺序装、遥测怎么关、什么不许进 Git**。逐步命令与签字表见 [Godot AI 接入烟测](../../docs/runbooks/godot-ai-mcp-setup.md)。

### 7.1 接入阶段（不要和功能任务搅在一起）

| 阶段 | 何时 | 做什么 | 不做 |
|---|---|---|---|
| 文档拍板 | M0 已退出、M1 启动前（已完成） | 锁定唯一主 MCP 与遥测政策 | 不改 `game/` 工程 |
| 接入烟测 | M1 期间可并行的**独立环境任务** | 本机装 uv、先写 §7.2、装 3.1.5 插件、Configure Cursor、按 ADR 清单签字 | 不并入 SimulationCore；不改 CI；不提交插件与 `project.godot` 脏写入 |
| M1 默认路径 | 接入烟测签字之前 / 之后 | 签字前：`.gd` + GUT + Headless。签字后：允许 MCP 改表现层占位场景 | MCP 不是 M1 退出条件；编辑器没开时任务仍须能用命令行完成 |
| 生产级启用 | **M2 启动门禁** | 清单全绿、遥测核实、入库卫生、大型 `.tscn` 走 MCP / UndoRedo | 不把 Godot AI 打进玩家包、MatchServer 或 CI |
| 生产级应用 | M2 及以后的编辑器工作 | AuthoringWorld、Edit UI、官方赛道表现场景 | `game_eval`、Vision Routing、`--allow-host`、第二套 MCP、用 `McpTestSuite` 替代 GUT |

升级插件或 PyPI 包视为依赖变更：改本文件 §1 版本行、runbook 里的 sha256、再在开发机重跑接入烟测。大版本只在里程碑边界试验，且必须可回退（§2）。

### 7.2 匿名遥测：强制关闭

上游默认向外发送工具名、成败、耗时、匿名安装 UUID 与平台 / 版本字段（不含源码与场景内容）。本项目不接受该默认值。关闭必须在**第一次启用插件之前**完成，避免启动事件先发出去。

三道开关要一起用，缺一不可：

1. **用户环境变量**（主开关，Godot / Cursor / `uvx` 子进程都能继承）：

   ```powershell
   [Environment]::SetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "true", "User")
   ```

   ```bash
   export GODOT_AI_DISABLE_TELEMETRY=true
   ```

   写入后必须新开终端，并重启已运行的 Cursor 与 Godot。不要用跨工具变量 `DISABLE_TELEMETRY`，以免误伤其他 CLI。

2. **编辑器 Clients & Tools 窗口**（主 Dock 上那颗按钮，不是主面板本身）：打开后到 **Tools** 页，关掉底部 **Telemetry**，点 **Apply and Restart Server**。该偏好写入 EditorSettings。Vision Routing 在同一窗口的 **Settings** 页，默认关，不要打开。

3. **Cursor attach 参数**：关遥测后必须再点一次 Dock 里 Cursor 的 **Configure**，使 `godot-ai attach` 带 `--disable-telemetry`。开关变更后旧配置会显示 `configured_mismatch`。

核实（服务已按 opt-out 重启后）：Windows 上 `%APPDATA%\godot-ai\customer_uuid.txt`、macOS 上 `~/Library/Application Support/godot-ai/customer_uuid.txt` 必须不存在。opt-out 生效时不应创建安装 UUID、不应起遥测线程。这是开发机工具遥测，**不是** [CD-14](../10-product/14-data-and-telemetry.md) 的玩家玩法遥测口径。

### 7.3 安装顺序

1. 写入 §7.2 环境变量并重启 Cursor / Godot；
2. 安装 `uv`（Windows 优先 `winget install --id astral-sh.uv -e`，macOS 优先 `brew install uv`）；
3. 从 GitHub Release **v3.1.5** 下载 `godot-ai-plugin.zip`，校验 sha256 后将 `addons/godot_ai` 放到 `game/addons/godot_ai/`。禁止用 Asset Library 的滞后包充当锁定版本；
4. 编辑器中启用插件 **Godot AI**；
5. 点 **Clients & Tools**：**Tools** 页关 Telemetry 并 Apply；**Settings** 页 Vision Routing 保持关，Remote access 保持空；只绑 `127.0.0.1`；
6. Dock 为 **Cursor** 执行 Configure，关遥测后再 Configure 一次，然后重启 Cursor；
7. 按接入烟测清单做 UndoRedo / 运行 / 错误读取 / Headless 退路 / 遥测核实；
8. 删除临时场景；`git checkout -- game/project.godot` 丢掉插件列表与 `_mcp_game_helper`；确认 `game/addons/godot_ai/` 未进入 `git status`。

`_mcp_game_helper` 是插件为编辑器「试玩进程」注入的 autoload。上游导出时可从内存剥掉它，但 **Headless MatchServer 跑的是源码工程**。因此已提交的 `project.godot` 不得出现该 autoload，也不得把 `godot_ai` 写进 `editor_plugins`。本机日常用 MCP 时可以启用插件；提交前必须把这两处还原。

### 7.4 与自动加载政策的关系

§5 规定自动加载只放稳定的基础服务。Godot AI 的 helper **不是**基础服务，只允许存在于未提交的本机 `project.godot`。Agent 若发现工作区把 `_mcp_game_helper` 或 `godot_ai` 插件项写进了待提交 diff，必须在提交前还原，不得当作「项目设置的一部分」保留。
