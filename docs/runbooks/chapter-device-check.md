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

## 本刀：纠偏 C1 收尾 — 测试机日常更新脚本 + D5 硬直 1.0s 落文档

对应：当前完整章节 PR。这一章闭合的是：VPS 上一条可重复的关服 / 拉 `main` / 重建 / 等就绪；以及人类已选的复活硬直 **1.0 s** 写进纠偏 D5 / CD-91 / CD-63。不是实现 1 秒硬直，也不是代填 ICMP / 协议层数字。

**无开发机 GUI。** 不需要 `npm run dev`，也不要为了验收去停 24h ICMP。

Windows 上用 Git Bash（或测试机 Linux）。仓库根：

### 1. 脚本用法与禁止项

```bash
bash infra/compose/craftarena-compose.sh
bash -n infra/compose/craftarena-compose.sh
```

1. 预期：无参数打印 `Usage`，退出码非 0；`bash -n` 无输出、退出 0。正文有 `update` / `down`。打开脚本，作为命令执行的只有 `compose down`，没有 `down -v`。
2. 失败：无参数却去拉起容器；或脚本里能一键 `down -v`。

### 2. 有测试机时（可选，不要打断 ICMP）

SSH 到测试机，仓库根：

```bash
bash infra/compose/craftarena-compose.sh status
```

1. 预期：打印 `git:` 一行和三个 compose 服务。本刀**不要求**跑 `update`（会杀掉进行中的对局；不影响本机 ping，但不必为验收去做）。
2. 失败：`GODOT_SHA512 empty` 却还继续 build；或 `down` 带了 `-v`。

采协议层 RTT 时再按 [`server-deploy.md` §4.1](server-deploy.md#41-日常更新测试机) 与 §13.2：先 `update`，两边客户端也要新代码。

### 3. D5 文档（无真机）

打开 [纠偏方案 D5](../plans/course-correction-2026-08.md)「你的决定」：道具 A，复活硬直 **1.0 s**。CD-91 D.3 有 `traprush_respawn_stun = 1_second`。

1. 预期：三处一致。`game/src` 里硬直仍是 1 tick 桩，本刀不改。
2. 失败：文档写了 1.0 s 但 PR 把 `RESPAWN_STUN_TICKS` 改成产品值（那是下一章）。

### 本刀不测

- 24 小时 ICMP 的数字（[`server-deploy.md`](server-deploy.md) §8.1，进行中则让它跑完）；
- 远端双机协议层 P50/P90（同手册 §13.2，要先 `update` 再进场）；
- 1.0 s 硬直手感；
- `docker compose down -v`。

### 仍然欠着（不因本章消失）

1.0 s 硬直接线、24 小时 ICMP 回填、远端协议层 RTT 回填、C3 网络参数锁定、D10 首次可玩性结论。

