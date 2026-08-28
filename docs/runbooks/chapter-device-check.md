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

## 本刀：纠偏 C3 第 7 章 — BotRunner 证明 course_01 安全路可完成

对应：当前完整章节 PR。这一章闭合的是 G3 的自动一半：默认探针仍走 +X 捷径；`--route=safe` 封掉 entity 10 之后仍 `completable`，步数明显更多。不是锁定 Tick / 快照 / 插值，也不是 D10 人类「好不好玩」签字（那一步你自己玩完再写）。

**不需要三后端。** Headless `--bot-run` 与 Solo 窗口即可。

### 1. 默认探针仍走捷径

仓库根：

```powershell
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run --course=course_01
```

1. 预期：一行 `event=bot_run_course`，`outcome=completable`，`route=any`，`steps` 是个位数（通常 5），`forbid_portals` 为空数组。最后一行 `event=bot_run_summary` 且 `ok=true`，进程 exit 0。
2. 失败：`not_completable`；或 `steps` 已经二十以上（默认不该去走安全路）；或进程非 0。

### 2. 封掉捷径传送门后仍能走通

```powershell
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run --course=course_01 --route=safe
```

这一条重放 C3 第 5 章那条四向安全路（约三十步），不是现场 A*。开发机通常几十秒内结束。不要用默认 3000 tick 预算去跑它。

1. 预期：`outcome=completable`，`route=safe`，`forbid_portals` 含 `10`，`steps` **明显大于**第 1 步（至少二十）。exit 0。
2. 失败：`budget_exhausted` / `search_exhausted`；或 `steps` 仍是个位数（说明没封住捷径）；或对 `course_02` 带 `--route=safe` 却绿了（应 exit 1）。

可选对照：`--bot-run --course=course_02 --route=safe` 应立刻 `error=safe_route_requires_course_01` 并 exit 1，不必等搜索。

### 3. Solo：人走两条路（给 D10 用，本章不代签）

按上面共用启动 **0.2**（不需要 0.1）。点 **Solo play**。

1. 捷径：从出生点连按 W（+X）约五格，应上楼并冲线。预期：石色窄路两侧是坑；状态行 `finish=` 有值。失败：掉下去回出生点却没走偏；或五格后没冲线。
2. Cancel 再 Solo。安全路：先 W 两格到检查点 1，再按 S（+Z）走进更长走廊，经侧向传送到左侧区块，再上楼与捷径汇合后冲线。预期：步数明显多于捷径；走下石路会下落并闪回检查点。失败：走廊走到一半无故复位；或侧向门不落地。
3. 道具：出生点已拾爆破球与冲刺。面对出生点箱子按 Q，箱应消失。按 Left Shift 或点 **Sprint**，应沿朝向冲一格且不穿固体。失败：Q 无反应；或冲刺穿墙。
4. 机关：走到出生点 −Z 两格洋红盒，固体半周期踩上应被击退/复位。失败：踩实心洋红盒毫无反应。

本步没有「必须觉得好玩」的预期。D10 是你（加 2–3 名熟人）事后给的非正式结论，AI 不得代填。

### 本刀不测

- 24 小时 ICMP（[`server-deploy.md`](server-deploy.md) §8.1）；
- 远端双机协议层 P50/P90（同手册 §13.2）；
- 改快照频率或插值窗口；
- 0.5 / 1.0 / 1.5 秒产品硬直；
- `--bot-run` 进 CI。

### 仍然欠着（不因本章消失）

D5 复活硬直（候选已写在纠偏方案 D5，待人类选）、24 小时 ICMP 执行与回填、远端协议层 RTT 回填、C3 网络参数锁定、D10 首次可玩性结论。

