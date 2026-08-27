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

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下一行是服务器地址：输入框（placeholder `Server host`，默认填当前控制面主机）加 **Apply server** 按钮。再往下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：本席玩家盒是青色（`OWN_ALBEDO`），远端玩家盒仍是海军蓝（`REMOTE_ALBEDO`）；橙色盒是可破坏箱；洋红盒是周期机关（固体半周期才出现；官方赛道出生点 −Z 1 个）；石色盒是固定固体占用（始终显示；官方赛道出生点 −X 1 个、正下方 1 个）；垫 / 门 / 终点是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

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

预期：出现标题为 **Traprush** 的窗口；状态行含 `join=idle`、`play=idle`、`tls=off`、`server=127.0.0.1`、`course=3/2/1`（默认 `course_01` 的垫/门/终点占位）。失败：没有窗口、立刻退出、或只有 Headless 日志。

操作：WASD 移动，空格跳跃（大厅按钮不抢空格），Q 或鼠标左键使用道具（打碎眼前箱），F 基础推击（推开邻座胶囊，无线上目标 id），R 重置到最近已验收检查点。点窗口内部一次，确保键盘焦点在游戏窗口而不是终端。

---

## 本刀：纠偏 C2 第二章 — 测试目录不再空转，门禁状态与返工率可核对

对应：当前完整章节 PR。这一章闭合的是「文档写了集成 / 回放 / 每日门禁，目录和 CI 却是空的」：`game/tests/integration/` 与 `game/tests/replay/` 各有真实用例，CI 的 GUT 步骤收集这三个目录，CD-53 §4.2–§4.4 每项都有状态列，返工率第一份数据在 [docs/audits/2026-08-27-ai-rework-rate.md](../audits/2026-08-27-ai-rework-rate.md)。

**不需要大厅窗口，不需要三后端。** 第 1 步是命令行；第 2 步是打开两份文档核对「已启用」没有说成「每日 cron」。

### 1. 本地 GUT 跑 unit + integration + replay

```powershell
& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
echo $LASTEXITCODE
```

预期：输出里能看到 `res://tests/integration/test_traprush_authoring_to_match.gd` 与 `res://tests/replay/test_traprush_official_tape_replay.gd`；`---- All tests passed! ----`；退出码 `0`。

失败：缺这两个脚本、只跑了 `tests/unit`、或非 0 退出。不要用旧的「只跑 unit」命令冒充本章。

### 2. 门禁状态表没有把「每次 PR」写成「每日 / 每周流水线」

打开 [CD-53](../../Confirmed-docs/50-engineering/53-testing-and-ci.md) §4.2 / §4.3 / §4.4 的「当前实现状态」表。

预期：§4.2 写明没有独立每日 cron，集成是进程内 `MatchRealtime`、回放不能从环形缓冲恢复世界；§4.3 / §4.4 未实现项标「未实现」。返工率文件 §2 的 R1 对 `game/src` 是 4.8%、R2 是 0%。

失败：表里出现「已覆盖每日全量」或「已有 weekly workflow」，或把 4.8% 读成「AI 质量已经够好」。

### 本刀不测

- 大厅 / Preview / 对局窗口：本章不改表现，无开发机可见行为；
- `--bot-run`：上一章已有，本章不接进 CI；
- `tests/content/` 与 `tests/security/`：C2 明确不做 UGC 安全全集，golden 仍未实现；
- 真多 OS 客户端、真 socket、从快照恢复世界再继续：尚未实现，状态表已标明。

### 仍然欠着：C1 §12 的实测数字

C1 远端部署与双机对局已由人类于 2026-08-27 验证。[`server-deploy.md`](server-deploy.md) §12 那张「哪些零延迟参数不成立」的表在数字回填前仍是空的。没有这张表，C3 不得锁定 Tick / 快照 / 插值。本章与它互不依赖。

