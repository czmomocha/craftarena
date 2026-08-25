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

预期：出现标题为 **Traprush** 的窗口；状态行含 `join=idle`、`play=idle`、`course=3/2/1`（默认 `course_01` 的垫/门/终点占位）。失败：没有窗口、立刻退出、或只有 Headless 日志。

操作：WASD 移动，空格跳跃，Q 或鼠标左键使用道具（打碎眼前箱），R 重置到最近已验收检查点。点窗口内部一次，确保键盘焦点在游戏窗口而不是终端。

---

## 本刀：大厅只读结算面板

对应：当前完整章节 PR。锁的是**同一条结算面板链路**：MatchHost 对仍在跑的场解析心跳，一旦有合法 `settlement` 就 POST 控制面（409 视为已写入）；大厅在**线上**全员冲线后轮询 GET，200 后状态行出现 `settled=`。Solo 冲线只有本地 `result=`，**没有** `settled=`（客户端不 POST、Solo 不 GET）。不是离开对局 HTTP、MMR 或限时未全员冲线结算。

先做 A（Solo，不需要三后端），再做 B（1 人 Quick play，需要 `npm run dev`）。B 才是本章主路径。

### A. 离线 Solo（只有本地 `result=`）

不需要 `npm run dev`。若已在线对局，先点 **Cancel** 回到 `play=idle`。

1. 课程框保持 `course_01`。点 **Solo play**。点窗口内部一次，确保键盘焦点在游戏窗口。
2. 按住 **D** 走到第二垫（+X 约 2m），走进约 +X 3m 的青色传送门，落地后继续向 +X 走到金色终点盒。

   预期：状态行含 `result=`，**没有** `settled=`。失败：出现 `settled=`（说明客户端写了库或 Solo 误 GET）。

3. 点 **Cancel**。

   预期：`offline=` 不再是 `playing`；没有 `result=` / `settled=`。失败：点了之后还能继续走。

点 **Cancel** 结束后再做 B。

### B. 快速游戏（1 人：本地 `result=` 之后出现 `settled=`）

需要「共用启动」0.1 与 0.2。人数改成 `1`，这样不必等第二人。走完 `course_01` 的路径与 A 相同（D 进门再进终点）。

1. 课程框 `course_01`，人数框改成 `1`。点 **Quick play**。
2. 等状态行出现 `join=ready`、`play=in_match`、`seats=1`、`seat=0`、`mapped=1`。若长时间停在 `connecting` 或 `error=`，先看 `npm run dev` 三个进程是否仍在。
3. 点窗口内部一次。按住 **D** 进传送门，再走进终点。

   预期：先出现本地 `result=`（1 人应为 `result=` 且含 `mvp=0`），此时可以还没有 `settled=`。失败：冲线后没有 `result=`。

4. 停在终点，最多等约 **20 秒**（MatchHost 默认 15s 扫描心跳 + 大厅 1s 轮询）。

   预期：状态行出现 `settled=#1s0 mvp=0`，且仍有 `result=`。失败：20 秒后仍没有 `settled=`（Host 没写库或大厅没 GET）；或 join 变成 `failed`（把 GET 404 当成了入场失败）。

5. 点 **Cancel** 停场（不要点窗口关闭，见共用启动说明：Traprush 是嵌入子窗口，关闭只是隐藏）。

   预期：`join=idle` `play=idle`，没有 `tick=` / `result=` / `settled=`。失败：点了之后 `tick=` 仍在涨，或 `settled=` 还在。

### 本刀不测

- 离开对局 HTTP、MMR、限时未全员冲线结算；
- GET 在 Host 写入前必须立刻 200（允许先 404 再出现 `settled=`）；
- 第二人同屏；
- 长按 R 的时长（CD-63 待决）；
- 走路可达、合法路径距离、检查点到达时间；
- 产品皮肤、产品镜头、空格跳（官方赛道无立足点）；
- 账号绑定、远端外推、平滑对账。
