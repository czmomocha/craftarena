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

操作：WASD 移动，空格跳跃，Q 或鼠标左键使用道具（打碎眼前箱），R 重置到最近已验收检查点。点窗口内部一次，确保键盘焦点在游戏窗口而不是终端。

---

## 本刀：网关进程内 TLS

对应：当前完整章节 PR。锁的是 **网关可在进程内终结 TLS**：成对设置 `GATEWAY_TLS_CERT` / `GATEWAY_TLS_KEY` 后客户端走 `wss`；都不设则仍明文 `ws`（本机开发）。对局进程上游仍是内网明文 `ws`。默认 `npm run dev` 不启用 TLS。生产 CA、控制面 HTTPS、MatchHost 子进程 TLS 仍待。

### 1. 默认明文仍能玩

前置：共用启动 0.1（`npm run dev`）与 0.2。

预期：状态行含 `tls=off`、`join=idle`、`play=idle`。失败：没有 `tls=`，或显示 `tls=on`。

### 2. Quick play 仍走明文网关

操作：点 **Quick play**。

预期：状态行仍含 `tls=off`；`join` 离开 idle（出现 `pending=1`，或 `play=connecting` / `in_match`）。失败：进不去、或变成 `tls=on`。

### 3. wss 不在本窗口手测

自签夹具与未信任证书拒绝握手由 `npm test` 覆盖。不要改 `npm run dev` 去挂证书；DevLauncher 的 `/readyz` 仍走 http。

### 本刀不测

- 生产 CA 信任链、控制面 HTTPS、MatchHost 子进程 TLS；
- 离开对局 HTTP、账号绑定、平滑对账、远端外推。
