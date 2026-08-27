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

## 本刀：纠偏 C2 第一章 — 赛道能不能走通，占位桩收敛到一处

对应：当前完整章节 PR。这一章闭合的是「有没有办法知道一张赛道能不能通关」：`--bot-run` 让一个 bot 在权威仿真上真的走一遍官方课，走通就给出一串可以照着重放的动作。

同时做了一件必须一起验的事。动作与胶囊占位桩原先抄在对局进程、大厅 Solo、Preview、本地预测四处，现在收敛进 `game/src/games/traprush/play_stubs.gd`（冻结令 §3 要求新增消费方从单一配置源注入，而 bot 就是第五个消费方）。**收敛的验收标准是「手感一点没变」**，所以第 2、3、4 步全都在问「和合入前是不是一样」。任何一处不一样都是回归，不是改进。

第 1 步是命令行，第 2、3 步是窗口且不需要后端，第 4 步需要三后端。

### 1. 三张官方课都能走通

```powershell
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run
echo $LASTEXITCODE
```

约 45 秒，其中 `course_03` 一张就占 36 秒左右——慢是权威仿真本身的开销，不是卡死。

预期：三行 `"event":"bot_run_course"`，每行 `"outcome":"completable"`；`course_03` 那行的 `actions` 里能看到一个 `use_item`（那张课有箱挡路，bot 自己发现要先打掉）。最后一行 `"event":"bot_run_summary"` 含 `"ok":true`，退出码 `0`。

失败：任何一行是 `"not_completable"`。**先看 `reason` 再下结论**——`budget_exhausted` 只说明预算先用完了，加 `--max-ticks=6000` 重试；`search_exhausted` 才是「在 bot 的动作集内确实没路」。两者都不等于「人也过不去」。

### 2. Solo：跳跃与下落和合入前一样

前置：关掉上次运行。不需要后端。

操作：仓库根 `& $env:GODOT4 --path game`（macOS `"$GODOT4" --path game`）。出现 **Traprush** 窗后点 **Solo play**，点窗口内部一次。先等一两秒看青色盒是否贴到脚下石色盒顶。按一下**空格**，再等一两秒。然后按 **D** 走出立足盒，再等一两秒。

预期：开玩后不久青色盒贴在出生点正下方石色盒顶，不是停在半空；按空格后明显离地约四分之一格，随后落回盒顶；走出立足盒后继续往下掉（官方赛道沿 +X 没有地板）。

失败：跳得比以前明显高或低、落得比以前明显快或慢、一直停在出生高度不贴盒、或走离立足盒仍悬空。这一步是在验收敛没有改动数值。

### 3. Preview：Advance tick 才落，一次落一整格

前置：关掉上次运行。不需要后端。

操作：仓库根 `& $env:GODOT4 --editor --path game`，**F6** 运行 `res://src/creator/course_sandbox.tscn`。Preview 窗点 **Play**，点窗口内部一次。先点一次 **Advance tick**，按一下**空格**，观察，再点 **Advance tick**。

预期：Play 后第一次 Advance tick 把表现桩贴到脚下石色盒；空格后明显离地约四分之一格并**停在空中**直到下一次 Advance tick；再点才落回盒顶。

失败：空格后立刻落地，或 Advance tick 后仍停空中。Preview 的下落比对局大一档（一次点击落一整格，对局是每 tick 十六分之一格），这个差异是有意保留的——收敛后两者仍应不同。

### 4. 在线对局：跳跃与下落也没变

前置：`npm run dev`，等三个 `/readyz` 都就绪。

操作：开窗口化主场景，把人数输入框从 `2` 改成 `1`，点 **Create room**，等进对局。点窗口内部一次，按空格，再按 **D** 走出立足盒。

预期：与第 2 步相同的跳跃高度与下落速度。状态行 `play=in_match`。

失败：跳跃或下落与 Solo 明显不同。对局进程和 Solo 现在读同一份配置源，不一致说明 `PlayStubs.apply_match` 没接上。

### 本刀不测

- BotRunner 的 Node 包装（`tools/bot-runner/`）：本章没做，`--bot-run` 自身已经给出结论与退出码，再加一层只是转发；
- 把 `--bot-run` 接进 CI：本章不改 CI，跑一次 45 秒的东西要不要进门禁是单独的决定；
- 第 4 张及以后的赛道、UGC 赛道：冻结令 §1 不得开工；
- 任何玩法数值调整（跳跃高度、重力、道具伤害）：收敛只搬家不改值，改值是 C3。

### 仍然欠着：C1 的远端部署与基线

上一章（C1 第二章）的 **B 段从未执行**：`infra/compose/` 的 compose 与 Dockerfile 到今天仍未在任何机器上真构建过，双机对局与网络 / 资源基线也没采。那部分照 [`server-deploy.md`](server-deploy.md) 从 §1 走到 §12，要交回的东西列在该章 PR 正文里，其中 §12 那张「哪些零延迟参数不成立」的表是 C1 的主要产出。本章与它互不依赖，但它不会因为本章合入而消失。
