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

## 本刀：freeze-exception — MatchHost 引擎路径不再静默回退

对应：当前 PR（纠偏 [§1.3 例外通道](../plans/course-correction-2026-08.md)，人类 2026-08-30 选 A「单独一刀修」）。它修的是 C4 第 3 章真机验证时坑掉时间的那件事：`GODOT4` 缺失或写错时 MatchHost 悄悄用 PATH 上的 `godot`，一路撑到第一次 `POST /matches` 才回一个**不带原因**的 502，而 `spawn ... ENOENT` 只留在子进程输出里，日志和响应都看不到。

**这一章没有 Godot 内的可见行为变化。** 要看的东西全在后端终端与 HTTP 响应里，所以不需要打开 Traprush 窗口，也不需要做「共用启动」的 0.2。

1. **正常路径没退化**：仓库根 `npm run dev`。
   - 预期：三个 `/readyz` 都就绪；`match-host` 那行 `match host ready` 里多了 `godotSource`（macOS/Linux 上是 `GODOT4`，Windows 上设了 `_console.exe` 就是 `GODOT4_CONSOLE`），`godot` 仍是你机器上的引擎路径。
   - 失败：MatchHost 起不来（先确认 `echo $GODOT4` / `$env:GODOT4` 非空），或日志里没有 `godotSource`。
2. **缺 `GODOT4` 就当场拒绝启动**：另开一个终端，把变量清掉只跑 MatchHost。

   | 平台 | 命令（仓库根） |
   |---|---|
   | macOS | `env -u GODOT4 npm run match-host` |
   | Windows | `$env:GODOT4=""; $env:GODOT4_CONSOLE=""; npm run match-host`（**新开一个** PowerShell，别污染当前会话） |

   - 预期：进程立刻退出，stderr 写明 `GODOT4 must point at the Godot engine executable`（Windows 上是 `GODOT4_CONSOLE or GODOT4 ...`），并提到不会回退到 PATH 上的 `godot`。**没有**任何监听、没有 502。
   - 失败：进程照样起来了（说明还在静默回退），或报错只有一句 `undefined`。
   - 提示：仓库根有 `.env` 且里面写了 `GODOT4` 时，`npm run match-host` 不读它（只有 `npm run dev` 会 `loadEnvFile`），所以这一步照上面做就行。
3. **引擎路径写错时，502 说得出原因**：新终端里把 `GODOT4` 指到一个不存在的文件，只拉起 MatchHost（这一步不需要控制面：失败发生在 listen 之前，还没轮到登记）。

   ```bash
   GODOT4=/nope/godot npm run match-host
   ```

   Windows：`$env:GODOT4="C:\nope\godot.exe"; $env:GODOT4_CONSOLE=""; npm run match-host`

   再在另一个终端开一场：

   ```bash
   curl -sS -i -X POST http://127.0.0.1:8100/matches
   ```

   - 预期：HTTP 502，body 的 `error` 是 `session_listen_failed`，`message` 里能读到 `spawn ... ENOENT`（这是本章的核心：原因进了响应）。MatchHost 终端同时出现一条 `match failed to start` 的 **error** 级日志，带 `godot`、`godotSource`、`recentOutput`。
   - 失败：502 的 `message` 只写「进程在 listen 前退出」而不含 spawn 原因；或者 MatchHost 终端一行日志都没有（这正是修之前的样子）。
   - 收尾：Ctrl+C 停掉终端。端口号若被 worktree 偏移过，按 README「并行工作区」换算，不要照抄 8100。

### 本刀不测

- 任何 Godot 内的表现（本章不碰 `game/`）；
- 引擎版本是否匹配（只查"能不能派生出来"，不查 `--version`）；
- compose 镜像里的路径（`Dockerfile` 已经 `ENV GODOT4=/opt/godot/godot`，未改）；
- C4 第 4 章起的资产预算校验、`.glb` 入库。

### 仍然欠着（不因本章消失）

24 小时 ICMP 回填、远端协议层 RTT 回填、C3 网络参数锁定、E6 在有美术之后的可玩性签署、E7 后半（第一个 `.glb` 入库）；烘焙试验 §7 第 2、3 项（是否引入烘焙工具依赖、是否把烘焙流水线立为一章）仍待人类拍板。

