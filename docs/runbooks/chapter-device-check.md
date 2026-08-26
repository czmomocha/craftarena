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

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：本席玩家盒是青色（`OWN_ALBEDO`），远端玩家盒仍是海军蓝（`REMOTE_ALBEDO`）；橙色盒是可破坏箱；洋红盒是周期机关（固体半周期才出现；官方赛道出生点 −Z 1 个）；石色盒是固定固体占用（始终显示；官方赛道出生点 −X 1 个、正下方 1 个）；垫 / 门 / 终点是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

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

## 本刀：纠偏 C1 第一章 — 导出预设与包内核查

对应：当前完整章节 PR。这是本项目**第一次真正离开开发机**，所以「真机」在本刀里指**导出的安装包**，不是编辑器运行源码。

前置：先按[导出包核查清单](desktop-export-check.md) §1 装好 4.7.2-stable 导出模板并核对 SHA512。本刀不需要三后端。

### 1. 三个预设都能导出

仓库根依次执行（macOS 把 `& $env:GODOT4_CONSOLE` 换成 `"$GODOT4"`）：

```powershell
& $env:GODOT4_CONSOLE --headless --path game --export-release "Windows Desktop" "../export/windows/CraftArena.exe"
& $env:GODOT4_CONSOLE --headless --path game --export-release "Linux Headless" "../export/linux-headless/craftarena-server.x86_64"
& $env:GODOT4_CONSOLE --headless --path game --export-release "Web" "../export/web/index.html"
```

预期：三条退出码都是 0，`export/` 下出现 `CraftArena.exe` + `.pck`、`craftarena-server.x86_64` + `.pck`、以及 9 个 Web 文件。失败：出现 `Cannot export project with preset ... due to configuration errors`（引擎不会列出具体项，见核查清单 §5 第 2 条）。

### 2. 包内自检必须 `ok=true`

```powershell
& "export\windows\CraftArena.exe" --headless -- --package-check
```

预期：打印一行 JSON，含 `"ok":true`、`"failures":[]`、`"template_build":true`、`"packed_addons":[]`，退出码 0。失败：`failures` 非空——尤其 `no_godot_ai_packed`，那意味着 Godot AI 插件又漏进了玩家包。

### 3. 双击运行 Windows 包，开窗并能跳

1. 双击 `export\windows\CraftArena.exe`（**不加** `--headless`）。
2. 预期：出现标题 **Traprush** 的窗口，状态行含 `join=idle`、`play=idle`、`tls=off`、`course=3/2/1`。失败：闪退、黑窗、或只有控制台。
3. 点 **Solo play**，点窗口内部一次，按 WASD 移动、空格跳跃。预期：青色本席盒会动、会跳、会落回脚下石色盒，与编辑器里跑源码时一致。
4. 与 `& $env:GODOT4 --path game` 的画面并排比一次颜色与明暗。预期：一致。失败：包里的盒子发白、发黑或颜色不同——那是 Compatibility 下运行时创建材质的问题，Headless 自检查不出来。

### 4. Web 包能在浏览器里开到大厅

```powershell
python -m http.server 8060 --directory export\web
```

浏览器开 `http://127.0.0.1:8060/`。预期：加载条走完后出现同一个大厅画面，能点 **Solo play**。失败：白屏（多半是改了 `variant/thread_support` 却没给服务端配 COOP / COEP 响应头）。

### 本刀不测

- 联机：`wss://` 需要真域名 + 受信证书，属 C1 部署那一章；
- Linux 包在真机上跑：需要香港 VPS，同上；
- 移动端导出、代码签名、安装器、自动更新；
- 任何玩法数值、重力、道具——那是 C3。
