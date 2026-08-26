# 章节真机清单

本文件是 [CD-52 §3.2](../../Confirmed-docs/50-engineering/52-ai-workflow.md) 的可执行版本：人类验收**当前完整章节 PR** 时照「本刀」逐步做。

它存在的理由是：自动化测试证明算法，不代替你在开发机窗口里看见的表现。任何人检出该 PR 分支，按本刀从头做一遍，就能自己判断这章在真机上是否成立。

- 适用范围：Windows 与 macOS 开发机；窗口化运行主场景。Headless `--quit` **不是**真机。
- 这是人工检查，**不是** CI 门禁（宪法第二十四条）。
- 命令以 [README.md](../../README.md) 为准，不要另猜参数。
- Agent 开下一章 PR 时必须**整节替换「本刀」**，不要把旧章步骤留在下面让人验错对象。无开发机可见行为的章：本刀只写「无」和一句原因。

---

## 怎么用

1. 检出待审 PR 的分支（不要用过期的 `main` 冒充本章）。
2. 先做下面「共用启动」（本刀写了「不需要三后端」则可跳过 `npm run dev`）。
3. 只做 **本刀** 的编号步骤。每步有「预期」和「失败」。全部预期满足才勾 PR 里的真机项。
4. 合入后本刀会被下一章替换；历史步骤以该章 PR 正文为准。

---

## 共用启动（大厅窗口）

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：本席玩家盒是青色（`OWN_ALBEDO`），远端玩家盒仍是海军蓝（`REMOTE_ALBEDO`）；橙色盒是可破坏箱；垫 / 门 / 终点是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n` 与 `crates=n/m`。

### 0.1 后端（本刀需要在线入场时）

仓库根目录：

```bash
npm run dev
```

预期：控制面、网关、MatchHost 三个 `/readyz` 都就绪后 DevLauncher 才放行。不要在半就绪时开游戏。停：对该终端 Ctrl+C。

Worktree 端口偏移见 README「并行工作区」；本文件不复述端口号。

### 0.2 打开窗口化主场景

**不要**用 Headless `--quit`。

| 平台 | 命令（仓库根） |
|---|---|
| Windows | `& $env:GODOT4 --path game` |
| macOS | `"$GODOT4" --path game` |

也可以先 `& $env:GODOT4 --editor --path game` / `"$GODOT4" --editor --path game`，再在编辑器里运行主场景。

预期：出现标题为 **Traprush** 的窗口；状态行含 `join=idle`、`play=idle`、`tls=off`、`course=3/2/1`（默认 `course_01` 的垫/门/终点占位）。失败：没有窗口、立刻退出、或只有 Headless 日志。

操作：WASD 移动，空格跳跃（大厅按钮不抢空格），Q 或鼠标左键使用道具（打碎眼前箱），F 基础推击（推开邻座胶囊，无线上目标 id），R 重置到最近已验收检查点。点窗口内部一次，确保键盘焦点在游戏窗口而不是终端。

---

## 本刀：开发机运行窗口、空格跳跃与 Godot AI 自动启用

对应：当前完整章节 PR。锁的是 **空格不再点大厅 Solo play / Preview Play**、**F5/F6 外框与内嵌 Traprush/Preview 窗默认更大并最大化**、**打开编辑器时若本机已安装 Godot AI 则自动启用**。已提交 `project.godot` 仍不含 `godot_ai` 插件项与 `_mcp_game_helper`。不是产品镜头/FOV。

### 1. 大厅空格是跳跃，不是 Solo play

前置：共用启动 0.2。本刀不需要三后端。

操作：点 **Solo play**，点 3D 区域一次，再按 **空格**。不要再点 Solo play。

预期：不会重新点一次 Solo play（对局不会被按钮再点一遍）；空格走 `jump` 动作。官方赛道无立足点时跳跃仍可能是空操作，但按钮不得被空格点亮。失败：每按一次空格都像又点了 Solo play。

### 2. 运行外框与 Preview 窗默认够大

前置：关掉上次运行。本刀不需要三后端。

操作：在编辑器 **F6** 运行 `res://src/creator/preview_sandbox.tscn`。看外层游戏窗和里面的 **Preview** 窗。不要先手动拖大。

预期：外框接近最大化；Preview 窗也是大窗（默认 1280×720 并最大化），不用先拖外框才能看清 3D。失败：仍是约 640×360 小窗，必须拖外框才看得见。

### 3. 重开编辑器后 Godot AI 仍启用

前置：本机已按 [CD-51 §7](../../Confirmed-docs/50-engineering/51-dev-environment.md) 把 `game/addons/godot_ai/` 装在工程里。

操作：完全退出 Godot，再打开本工程编辑器。看 **项目 → 项目设置 → 插件**（或 Project Settings → Plugins）里 **Godot AI**。

预期：Godot AI 为启用，不必再勾一次。失败：每次重开都是未启用。

### 本刀不测

- 产品镜头/FOV、把 `godot_ai` 目录或 `_mcp_game_helper` 提交进 Git、官方赛道真正跳起来（无固体立足点）。
