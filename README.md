# Craft Arena 工坊竞技场

Godot 4 + UGC 双玩法（TRAPRUSH / BASTION）项目 Monorepo。代码与仓库标识的命名写法见 [CD-11 §1](Confirmed-docs/10-product/11-scope-and-platforms.md)。

- 工程规则入口：[AGENTS.md](AGENTS.md)
- 规范唯一事实源：[Confirmed-docs](Confirmed-docs/README.md)
- 当前阶段：M3 进行中（2026-08-24 启动）。已落地对局多人仿真循环、二进制协议 v1、对局进程仿真入口、实时回路、网关代理、控制面真票据、MatchHost 自动登记、等待 listen 后登记、停止后注销、真匹配/房间码、FIFO 等待队列、客户端匹配入场、权威快照与赛道几何 / 可破坏箱 / 传送连线 / 检查点顺序 / 直播名次表现映射、机关狂奔离线单人试玩、对局命令门禁、全员冲线单局结算写库、断线重连补票、官方赛道选择、人数按场下发、对局快照插值、对局本席移动预测、对局进程动作数值占位桩、对局大厅本席摄像机跟随、对局大厅本席移动朝向、对局大厅本席分色、对局大厅本席检查点占用高亮、对局大厅本席冲线闭环表现、对局大厅本席复位与楼层/箱子 HUD、大厅只读结算面板、对局大厅本席预测避开最新权威固体、真人命令才续租、网关进程内 TLS、权威 Move 位移门禁、对局基础推击（无线上目标 id，服务端推最近其它胶囊，大厅 F）、出界复位（Preview + 对局，开发桩 ±8 格，环境失败后无限复活到最近检查点）；周期机关已进 v1 拓扑（`hazards` 袋用已有 `cooldown_ticks` 切换固体）；对局大厅周期机关表现映射（洋红占位盒，显隐跟固体半周期，HUD `hazards=n/m`）；开发机运行体验（空格走 `jump` 而不是点 Solo play / Play；F5/F6 外框与 Traprush/Preview 窗默认更大并最大化；打开编辑器时若本机已安装 Godot AI 则自动启用）；固定固体占用（`zone.tags` 含 `solid` 编进 v1 可空 `solids` 袋；大厅/Preview 石色 1 米占位；HUD `solids=n/m`）。本刀为编辑器占用摆放（工具条 **Place solid** / **Place hazard** / **Place crate** 走已有 `place`；石色/洋红/橙色占位；不改官方赛道）。进度见 [CD-61](Confirmed-docs/60-plan/61-milestones.md)。

## 目录

```text
game/       Godot 4 工程（src 按 L0–L5 分层、content、tests）
backend/    control-plane / realtime-gateway / match-host / contracts
tools/      dev-launcher / bot-runner / content-validator / redline-scanner / replay-inspector
infra/      compose / tencent-cloud
docs/       adr / plans / runbooks
```

结构的所有者文档是 [CD-41 §5](Confirmed-docs/40-technical/41-architecture.md)。改目录先改那里。

## 环境搭建

工具选型、精确版本锁定与安装步骤全部以 [CD-51](Confirmed-docs/50-engineering/51-dev-environment.md) 为准，本文件不复述选型理由。

首次在一台新机器上准备环境时按 CD-51 §4 执行。Windows 开发机已经跑通、要在第二台 Mac 上拉同一份代码时，按 [CD-51 §4.1](Confirmed-docs/50-engineering/51-dev-environment.md) 执行，不要再初始化一遍工程。完成后必须跑通 CD-51 §6 的环境验证烟测；**未完成那套闭环不进入正式功能开发**。

烟测的逐步命令、预期输出与历次执行记录见 [环境烟测清单](docs/runbooks/environment-smoke-test.md)。想亲手确认这套环境成立，照它从头跑一遍即可，约 10 分钟。Godot AI MCP 的安装、关遥测与接入签字是另一份清单：[Godot AI 接入烟测](docs/runbooks/godot-ai-mcp-setup.md)，不要和 M0 十步混做。

### 依赖

精确版本号的所有者是 [CD-51 §1](Confirmed-docs/50-engineering/51-dev-environment.md)，本文件不复述。两点仓库事实：Godot 由开发机本地安装、不入库；GUT 随仓库入库在 `game/addons/gut/`，许可证见该目录下的 `LICENSE.md`。

升级引擎或插件按 CD-51 §2 处理，并同步 CD-51 §1 的版本行。

### 环境变量

所有命令通过 `GODOT4` 定位引擎，禁止在脚本里写死绝对路径。Windows 上还额外提供 `GODOT4_CONSOLE`，因为普通 exe 在 PowerShell 里不回显 stdout，读不到 Godot 控制台输出。

```powershell
# 一次性写入用户环境变量，改成你自己的安装路径
[Environment]::SetEnvironmentVariable("GODOT4", "C:\Tools\Godot_v4.7.2-stable_win64.exe", "User")
[Environment]::SetEnvironmentVariable("GODOT4_CONSOLE", "C:\Tools\Godot_v4.7.2-stable_win64_console.exe", "User")
# Godot AI 匿名遥测必须在第一次启用插件前关闭（CD-51 §7.2）
[Environment]::SetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "true", "User")
```

```bash
# macOS / Linux，写入 shell 配置
export GODOT4="/Applications/Godot.app/Contents/MacOS/Godot"
export GODOT_AI_DISABLE_TELEMETRY=true
```

### Godot 工程

`game/project.godot` 已经生成，**不要手写这个文件**，它由引擎的 `ProjectSettings` API 序列化而成。当前已按 CD-51 §5 落实的设置：

- 渲染基线 `gl_compatibility`，桌面、移动、Web 三个平台一致（宪法第七条）；
- 类型相关警告全局设为 Error，`res://addons` 例外（宪法第二十三条，理由见 [ADR-0001](docs/adr/0001-strict-gdscript-typing-gate.md)）；
- CD-51 §5 要求的 17 个输入动作，移动类绑定 physical keycode；
- 脚本与场景文件名 `snake_case`；
- 启动场景 `res://src/client/main.tscn`，打印一行结构化启动日志并打开机关狂奔匹配大厅（代码创建 Window，相邻快照采样后的玩家位姿、所选官方赛道占用与可破坏箱映射为 1 米占位盒，classified portal 画 gizmo 条，检查点垫标 `order` 且唯一 `order` 连线，最新快照直播名次标到玩家盒上方；本席 Move/Jump 在最新权威上叠加本地 overlay；大厅 WASD 写入 8 向离散水平朝向，玩家盒带面向标记；快速游戏 / 建房发送官方赛道 id 与本场人数，按码加入跟从该房课程与人数；Solo play 走本地内嵌权威并持续显示「离线试玩，成绩不上传」；Headless 不发起 live HTTP/WS）。

这些设置由 `game/tests/unit/test_project_contract.gd` 断言守护，改坏了跑测试就会红。

## 常用命令

以下命令都在 Windows 与 macOS 上、Godot 4.7.2 + GUT 9.7.1 + Node 24 实际执行验证过。CD-51 §4 要求把固定命令写在本文件，**禁止各 Agent 自行猜测参数**。

### Godot

| 用途 | Windows (PowerShell) | macOS (bash/zsh) |
|---|---|---|
| 查看引擎版本 | `& $env:GODOT4_CONSOLE --version` | `"$GODOT4" --version` |
| 打开编辑器 | `& $env:GODOT4 --editor --path game` | `"$GODOT4" --editor --path game` |
| 运行主场景（窗口，真机） | `& $env:GODOT4 --path game` | `"$GODOT4" --path game` |
| Headless 导入检查 | `& $env:GODOT4_CONSOLE --headless --path game --import` | `"$GODOT4" --headless --path game --import` |
| Headless 启动主场景 | `& $env:GODOT4_CONSOLE --headless --path game --quit` | `"$GODOT4" --headless --path game --quit` |
| 单文件语法与类型检查 | `& $env:GODOT4_CONSOLE --headless --path game --check-only -s res://src/client/main.gd` | `"$GODOT4" --headless --path game --check-only -s res://src/client/main.gd` |
| 运行 GUT 单元测试 | `& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` | `"$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` |

关于退出码：GUT 的 `-gexit` 在失败时返回 1（Windows 已测失败路径；macOS 本次只测了全绿路径）。`--check-only` 在 Windows 上失败返回 1；在 macOS 4.7.2 上类型错误会打印 `SCRIPT ERROR` / `Warning treated as error`，但进程退出码仍为 0，本地不要只看 `$?`。Linux CI 按退出码收集 `--check-only` 失败，该失败路径未在 macOS 上复现为非 0，不能把本机行为说成 CI 已经覆盖。

### 后端与工具

后端是 npm workspaces，命令在仓库根目录执行，两个平台写法相同。`.ts` 由 Node 24 原生剥离类型直接运行，没有构建步骤。

| 用途 | 命令 |
|---|---|
| 安装依赖 | `npm install` |
| 类型检查 | `npm run typecheck` |
| 后端与工具单元测试 | `npm test` |
| 宪法红线扫描 | `npm run redline-scan` |
| 手动补跑 worktree setup | `npm run setup-worktree` |
| **一键拉起三个后端进程** | `npm run dev` |
| 单独启动控制面 | `npm run control-plane` |
| 单独启动实时网关 | `npm run gateway` |
| 单独启动 MatchHost | `npm run match-host` |

`npm run dev` 是 DevLauncher：启动前若仓库根有 `.env`，用 Node 24 `process.loadEnvFile` 读入（已在环境里的变量优先）。然后顺序拉起控制面、网关、MatchHost，从各自日志里读出实际监听地址后轮询 `/readyz`，三个都就绪才放行；Ctrl+C 一起停。它不复制端口默认值。任一进程在就绪后意外退出，DevLauncher 会停掉其余进程并以非 0 退出，避免留下半死的环境。

DevLauncher 只管本地开发编排，不做守护、重启和资源限制；测试环境的编排见 [CD-44](Confirmed-docs/40-technical/44-deployment.md)。

默认端口、数据库位置等配置项由各服务自己的 `src/config.ts` 通过环境变量读取，默认值写在那里，本文件不复述。网关可选 `GATEWAY_TLS_CERT` / `GATEWAY_TLS_KEY`（必须成对指向 PEM）；未设置时明文 `ws`。`npm run dev` 默认不启用 TLS，DevLauncher 的 `/readyz` 探测仍走 http。

## 持续集成

`.github/workflows/ci.yml` 在推送 `main` 和所有 PR 上运行两个 job：`backend`（`npm run typecheck` + `npm run redline-scan` + `npm test`）与 `godot`（导入、逐文件 `--check-only`、Headless 启动烟测、GUT）。用的都是上面表里那些命令，本地跑一遍就能复现 CI 的结论。

CI 当前实际启用了哪些门禁、哪些还没实现，以 [CD-53 §4.1](Confirmed-docs/50-engineering/53-testing-and-ci.md) 的「当前实现状态」表为准。

## 协作规则

提交、推送与合入 `main` 的边界见 [CD-52 §1.1](Confirmed-docs/50-engineering/52-ai-workflow.md)。宪法第十八条的人类门禁落在合入 `main`、部署与发布。项目级 `.cursor/hooks.json` 会拦向 `main` 的 git 提交/推送，以及 `git worktree remove --force`。

任务完成判定见 [CD-53 §5 Definition of Done](Confirmed-docs/50-engineering/53-testing-and-ci.md)。完整章节 PR 的人类真机步骤义务见 [CD-52 §3.2](Confirmed-docs/50-engineering/52-ai-workflow.md)，可执行清单是 [章节真机清单](docs/runbooks/chapter-device-check.md)（人工检查，不是 CI 门禁）。

## 并行工作区

[CD-52 §5.1](Confirmed-docs/50-engineering/52-ai-workflow.md) 的 A1–A4 已成立，`.cursor/agents/` 与 `.cursor/BUGBOT.md` 已入库。GitHub PR 侧 Bugbot 已跳过，合入靠 CI + 人类批准。M1 已退出（2026-08-23）。工具链评审已通过：MCP 生产级启用；并行保持 2 域，第 3 域未开。M2 第一刀（Component Schema v1）串行进行中；合入后再按域并行。继续按 [CD-52 §5](Confirmed-docs/50-engineering/52-ai-workflow.md) 使用隔离 worktree。下面只服务「一个 Agent 在隔离 worktree 里干活」。禁止 symlink `node_modules`，禁止把 Cursor Automations 配进项目。

Cursor 创建 worktree 时会跑 `.cursor/worktrees.json`：`npm install`、按需从 `$ROOT_WORKTREE_PATH` 拷 `.env` 与 `data/*.sqlite`、按 worktree 目录名写入端口偏移、用 `GODOT4`（Windows 优先 `GODOT4_CONSOLE`）对 `game/` 做 `--import`。主 checkout（与 `$ROOT_WORKTREE_PATH` 相同）不写 `.env`。

端口公式（不要另猜）：`slot * 100` 加到各服务 `config.ts` 默认端口上。`slot` 为目录名哈希映射到 1–9；可用环境变量 `WORKTREE_SLOT=1`…`9` 覆盖。主 checkout 为 slot 0。写进该 worktree 的 `.env` 的键是 `CONTROL_PLANE_PORT`、`GATEWAY_PORT`、`MATCH_HOST_PORT`、`MATCH_HOST_PORT_RANGE_MIN`、`MATCH_HOST_PORT_RANGE_MAX`、`CONTROL_PLANE_URL`、`MATCH_HOST_URL`。

| 用途 | 命令 |
|---|---|
| 在当前目录重跑 setup | `npm run setup-worktree` |
| 后端与工具测试 | `npm test` |
| 拉起该 worktree 的三个后端 | `npm run dev` |
| GUT | 见上面 Godot 表，`--path game` |

IDE 里用 `/worktree` 开隔离工作区。调试 setup 看 Output 面板的 `Worktrees Setup`。不要在 worktree 里放未提交且不可再生的东西（Cursor 可能自动清理）。
