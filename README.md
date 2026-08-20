# Craft Arena 工坊竞技场

Godot 4 + UGC 双玩法（TRAPRUSH / BASTION）项目 Monorepo。代码与仓库标识的命名写法见 [CD-11 §1](Confirmed-docs/10-product/11-scope-and-platforms.md)。

- 工程规则入口：[AGENTS.md](AGENTS.md)
- 规范唯一事实源：[Confirmed-docs](Confirmed-docs/README.md)
- 当前阶段：M0（环境、Monorepo 与宪法），见 [CD-61](Confirmed-docs/60-plan/61-milestones.md)

## 目录

```text
game/       Godot 4 工程（src 按 L0–L5 分层、content、tests）
backend/    control-plane / realtime-gateway / match-host / contracts
tools/      dev-launcher / bot-runner / content-validator / replay-inspector
infra/      compose / tencent-cloud
docs/       adr / plans / runbooks
```

结构的所有者文档是 [CD-41 §5](Confirmed-docs/40-technical/41-architecture.md)。改目录先改那里。

## 环境搭建

工具选型、精确版本锁定与安装步骤全部以 [CD-51](Confirmed-docs/50-engineering/51-dev-environment.md) 为准，本文件不复述选型理由。

首次在一台新机器上准备环境时按 CD-51 §4 执行，完成后必须跑通 CD-51 §6 的 AI 环境验证烟测；**未完成那套闭环不进入正式功能开发**。

### 依赖

精确版本号的所有者是 [CD-51 §1](Confirmed-docs/50-engineering/51-dev-environment.md)，本文件不复述。两点仓库事实：Godot 由开发机本地安装、不入库；GUT 随仓库入库在 `game/addons/gut/`，许可证见该目录下的 `LICENSE.md`。

升级引擎或插件按 CD-51 §2 处理，并同步 CD-51 §1 的版本行。

### 环境变量

所有命令通过 `GODOT4` 定位引擎，禁止在脚本里写死绝对路径。Windows 上还额外提供 `GODOT4_CONSOLE`，因为普通 exe 在 PowerShell 里不回显 stdout，读不到 Godot 控制台输出。

```powershell
# 一次性写入用户环境变量，改成你自己的安装路径
[Environment]::SetEnvironmentVariable("GODOT4", "C:\Tools\Godot_v4.7.2-stable_win64.exe", "User")
[Environment]::SetEnvironmentVariable("GODOT4_CONSOLE", "C:\Tools\Godot_v4.7.2-stable_win64_console.exe", "User")
```

```bash
# macOS / Linux，写入 shell 配置
export GODOT4="/Applications/Godot.app/Contents/MacOS/Godot"
```

### Godot 工程

`game/project.godot` 已经生成，**不要手写这个文件**，它由引擎的 `ProjectSettings` API 序列化而成。当前已按 CD-51 §5 落实的设置：

- 渲染基线 `gl_compatibility`，桌面、移动、Web 三个平台一致（宪法第七条）；
- 类型相关警告全局设为 Error，`res://addons` 例外（宪法第二十三条，理由见 [ADR-0001](docs/adr/0001-strict-gdscript-typing-gate.md)）；
- CD-51 §5 要求的 17 个输入动作，移动类绑定 physical keycode；
- 脚本与场景文件名 `snake_case`；
- 启动场景 `res://src/client/main.tscn`，只打印一行结构化启动日志。

这些设置由 `game/tests/unit/test_project_contract.gd` 断言守护，改坏了跑测试就会红。

## 常用命令

以下命令都在 Windows + Godot 4.7.2 + GUT 9.7.1 + Node 24 上实际执行验证过。CD-51 §4 要求把固定命令写在本文件，**禁止各 Agent 自行猜测参数**。

macOS 一列尚未在真机验证，首次在 mac 上执行后请回来修正本表。

### Godot

| 用途 | Windows (PowerShell) | macOS (bash/zsh) |
|---|---|---|
| 查看引擎版本 | `& $env:GODOT4_CONSOLE --version` | `"$GODOT4" --version` |
| 打开编辑器 | `& $env:GODOT4 --editor --path game` | `"$GODOT4" --editor --path game` |
| Headless 导入检查 | `& $env:GODOT4_CONSOLE --headless --path game --import` | `"$GODOT4" --headless --path game --import` |
| Headless 启动主场景 | `& $env:GODOT4_CONSOLE --headless --path game --quit` | `"$GODOT4" --headless --path game --quit` |
| 单文件语法与类型检查 | `& $env:GODOT4_CONSOLE --headless --path game --check-only -s res://src/client/main.gd` | `"$GODOT4" --headless --path game --check-only -s res://src/client/main.gd` |
| 运行 GUT 单元测试 | `& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` | `"$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` |

关于退出码：`--check-only` 和 GUT 的 `-gexit` 在失败时都返回 1，可以直接作为 CI 门禁条件，两者均已实测确认。

### 后端与工具

后端是 npm workspaces，命令在仓库根目录执行，两个平台写法相同。`.ts` 由 Node 24 原生剥离类型直接运行，没有构建步骤。

| 用途 | 命令 |
|---|---|
| 安装依赖 | `npm install` |
| 类型检查 | `npm run typecheck` |
| 后端与工具单元测试 | `npm test` |
| **一键拉起三个后端进程** | `npm run dev` |
| 单独启动控制面 | `npm run control-plane` |
| 单独启动实时网关 | `npm run gateway` |
| 单独启动 MatchHost | `npm run match-host` |

`npm run dev` 是 DevLauncher：顺序拉起控制面、网关、MatchHost，从各自日志里读出实际监听地址后轮询 `/readyz`，三个都就绪才放行；Ctrl+C 一起停。它不复制端口默认值，所以用 `CONTROL_PLANE_PORT` 等环境变量改端口时不需要同步改它。任一进程在就绪后意外退出，DevLauncher 会停掉其余进程并以非 0 退出，避免留下半死的环境。

DevLauncher 只管本地开发编排，不做守护、重启和资源限制；测试环境的编排见 [CD-44](Confirmed-docs/40-technical/44-deployment.md)。

默认端口、数据库位置等配置项由各服务自己的 `src/config.ts` 通过环境变量读取，默认值写在那里，本文件不复述。

## 持续集成

`.github/workflows/ci.yml` 在推送 `main` 和所有 PR 上运行两个 job：`backend`（`npm run typecheck` + `npm test`）与 `godot`（导入、逐文件 `--check-only`、Headless 启动烟测、GUT）。用的都是上面表里那些命令，本地跑一遍就能复现 CI 的结论。

CI 当前实际启用了哪些门禁、哪些还没实现，以 [CD-53 §4.1](Confirmed-docs/50-engineering/53-testing-and-ci.md) 的「当前实现状态」表为准。

## 协作规则

AI Agent 可自主读写代码、场景、文档与测试，也可运行本地游戏、Headless 与测试，但**未经人类明确确认不得提交、推送、部署或发布**（宪法第十八条）。

任务完成判定见 [CD-53 §5 Definition of Done](Confirmed-docs/50-engineering/53-testing-and-ci.md)。
