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

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下一行是服务器地址：输入框（placeholder `Server host`，默认填当前控制面主机）加 **Apply server** 按钮。再往下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：本席玩家盒是青色（`OWN_ALBEDO`），远端玩家盒仍是海军蓝（`REMOTE_ALBEDO`）；橙色盒是可破坏箱；洋红盒是周期机关（固体半周期才出现；官方赛道出生点 −Z 1 个）；石色盒是固定固体占用（始终显示；官方赛道沿必经路铺立足面，`course_01` 另有出生点 −X 1 个，上层楼板在 −Z 三格）；垫 / 门 / 终点是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

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

预期：出现标题为 **Traprush** 的窗口；状态行含 `join=idle`、`play=idle`、`tls=off`、`server=127.0.0.1`、`course=3/5/1`（默认 `course_01` 的垫/门/终点占位；门含捷径上楼 `two_way`、安全路侧向 `two_way` 与上楼 `one_way`）。失败：没有窗口、立刻退出、或只有 Headless 日志。

操作：WASD 移动，空格跳跃（大厅按钮不抢空格），Q 或鼠标左键使用道具（打碎眼前箱；官方课出生点已拾爆破球），F 基础推击（推开邻座胶囊，无线上目标 id），Left Shift 或 **Sprint** 沿当前朝向冲刺一格（官方课出生点已拾冲刺），R 重置到最近已验收检查点。点过人数/课程/房间码/服务器框之后，再点 3D 区域或 Create room / Solo play，光标应离开输入框，WASD 才是移动。`course_01` 出生点 −Z 两格有洋红周期机关，有石色踏板可以走到它；踩上时若处于固体半周期会被击退并闪回出生点。

---

## 本刀：`[freeze-exception]` — 恢复 CI 的 Godot 门禁

对应：当前完整章节 PR。**本章无开发机可见行为**：只改了五处测试传参、CI 工作流与四份文档，产品代码一行没动。

不必打开窗口。要复验的是「测试跑得完」和「以后跑不完会变红」，两件事都在命令行里：

### 1. 全量 GUT 能跑完

仓库根，检出本 PR 分支后：

```powershell
& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
```

1. 预期：**几分钟内**打印 `All tests passed!` 并退出，退出码 0。失败：某个脚本停在那里不动超过十分钟——那说明还有同类问题没找干净。
2. 对照：在 `main` 上跑同一条命令，`test_authoring_preview_play.gd` 会停住不动（那是本章要修的症状，不是你的机器坏了）。想跳过对照可以，但别把「main 上也这样」当成正常。

### 2. PR 的 CI 这次真的是 success

在 PR 页面等 CI 跑完，然后核对**最终结论**而不是合并当刻的 `pending`：

```powershell
$j = (gh run view <run-id> --json jobs | Out-String) | ConvertFrom-Json
$j.jobs | ForEach-Object { "$($_.name)  $($_.conclusion)" }
```

1. 预期：两个 job 都是 `success`；`Godot check-only and GUT` 的耗时明显低于 15 分钟。失败：出现 `cancelled` —— 那正是 PR #176 起一直发生、却被读成「还在跑」的那种状态。
2. 在 job 日志里找 `Report slowest test scripts` 这一步，应打印最慢的 10 个测试脚本与总时长。这是以后发现「某个脚本正在慢慢变慢」的唯一信号。

### 本刀不测

- 给 `SimulationWorld._sweep_step_count` 加取样上限（会动权威碰撞落点与状态哈希，另立深审章）；
- 任何玩法、表现或数值变化（本章一处都没有）；
- `main` 分支保护为何仍允许这五次合并（需要人类核对 GitHub 设置，不是本章能改的）。

### 仍然欠着（不因本章消失）

24 小时 ICMP 回填、远端协议层 RTT 回填、C3 网络参数锁定、E6 在有美术之后的可玩性签署；扫掠取样代价无上限（宪法第十七条缺口）。

