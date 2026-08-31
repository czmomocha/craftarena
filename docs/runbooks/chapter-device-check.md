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

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下一行是服务器地址：输入框（placeholder `Server host`，默认填当前控制面主机）加 **Apply server** 按钮。再往下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：玩家是**角色视觉资产**（一个约 1 米高的机器人），本席覆青色薄膜（`OWN_ALBEDO`），远端覆海军蓝薄膜（`REMOTE_ALBEDO`）。橙色盒是可破坏箱；洋红盒是周期机关（固体半周期才出现；官方赛道出生点 −Z 1 个）；**始终固体铺地块视觉**（黄黑警示条地砖，一格一块；官方赛道沿必经路铺立足面，`course_01` 另有出生点 −X 1 个，上层楼板在 −Z 三格）；视觉资产解析不出来时，角色与地块各自回退成原来的占位盒（青色 / 石色）。垫 / 门 / 终点仍是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

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

## 本刀：Godot AI 脏写入不再进提交（freeze-exception，单项）

对应：当前完整章节 PR。这刀不属于任何 C 批次，还的是 C4 第 7 章记的第二笔账：**Godot AI 插件每次运行都把 `autoload/_mcp_game_helper` 与 `res://addons/godot_ai/plugin.cfg` 写回 `game/project.godot`**。它让守卫测试反复变红，并已经漏进过一个 commit。第一笔（Preview 每帧全量重建）已由 C4 第 8 章合入，与本刀无依赖。

**先看清这刀能做什么、不能做什么。** 插件在 `.gitignore` 里、不是本仓库代码，所以**没有办法阻止它写**。这刀做的是另外两件：一条命令把工作树还原、以及让那次写入进不了提交。因此本刀的验收不是「工作树永远干净」，而是「脏了能一键还原，且脏着提交会被拦」。

本刀**不需要**跑 `npm run dev`，也不改 `game/` 下任何玩法代码。

1. **在干净仓库上是空转**（先建立基线）：
   ```bash
   npm run godot-settings:check
   ```
   - 预期：一行 JSON，`"ok":true`、`entries` 为空，退出码 0。
   - 失败：`ok:false` —— 那说明你的工作树现在就是脏的，先做第 3 步再回来。
2. **插件真的会写**（这一步是让你亲眼看见问题存在，不是本刀的产出）：本机已装 `game/addons/godot_ai/` 时，打开一次编辑器：
   ```bash
   & $env:GODOT4 --editor --path game      # macOS: "$GODOT4" --editor --path game
   ```
   关掉编辑器，然后 `git diff -- game/project.godot`。
   - 预期：出现 `+[autoload]` / `+_mcp_game_helper=...`，`editor_plugins/enabled` 里多出 `res://addons/godot_ai/plugin.cfg`。
   - 本机没装该插件：跳过本步，直接手工造一次同样的两行再做第 3、4 步。
3. **一条命令精确还原**：
   ```bash
   npm run godot-settings:scrub
   git diff -- game/project.godot
   ```
   - 预期：scrub 打印被摘掉的条目；`git diff` 之后**完全没有输出**（回到字节一致，不是「差不多」）。再跑一次 scrub 是空转（幂等）。
   - 失败：`git diff` 仍有内容（说明还原不完整，比如空的 `[autoload]` 段没删掉）。
4. **别的改动不会被顺手丢掉**（这是它比 `git checkout --` 好的唯一理由）：先手工在 `game/project.godot` 里随便改一个无关值（例如把 `window/size/window_width_override` 改成 `1601`），再让它同时带上第 2 步那两行，然后 `npm run godot-settings:scrub`。
   - 预期：两行 MCP 条目被摘掉，`1601` **还在**。
   - 失败：`1601` 被一起还原了（那就是 `git checkout --` 的行为，不是本刀要的）。
   - 做完记得把 `1601` 改回去。
5. **脏着提交会被拦**（Agent 路径。人手敲的 git 不经过这个 hook，所以这条只对 IDE Agent 生效）：把第 2 步那两行弄回去，然后
   ```bash
   '{"command":"git add .","cwd":"<仓库绝对路径>"}' | node tools/shell-guard/src/main.ts
   ```
   - 预期：`"permission":"deny"`，消息里含 `game/project.godot` 与 `npm run godot-settings:scrub`。
   - 再试 `git add README.md`：应为 `"permission":"allow"`（守卫只拦会把该文件塞进索引的形式）。
   - 收尾：`npm run godot-settings:scrub`，确认 `git status --short` 里没有 `game/project.godot`，也没有 `game/addons/godot_ai/`。
6. **自动化仍然全绿**：
   ```bash
   npm run typecheck; npm test
   ```
   - 预期：`npm test` 全绿，其中含新工具用例与 shell-guard 新增用例。

### 本刀不测

- **让插件不写**。做不到，见上面那段；
- **人手 git 的拦截**。`.cursor/hooks.json` 只在 IDE Agent 发命令时生效，本仓库没有安装 git 原生 `pre-commit` 钩子（那要改 `core.hooksPath`，属人类门禁）；
- 任何玩法、协议、Preview / 对局表现。这刀一行 `game/` 代码都没改。

### 诚实边界

- **这不是「工作树永远干净」**。插件照旧写，只是现在有一条命令能精确撤销、并且脏着提交会被拦。任何写成「已经不会污染工作树了」的说法都是虚报；
- **拦截只覆盖 Agent 发出的 git**，靠 `.cursor/hooks.json` 的 `beforeShellExecution`（`failClosed: true`）。人手在终端敲 `git commit` 不经过它。CI 拦的是最后一道：磁盘副本脏就让 `npm test` 变红；
- **检测按插件目录名而不是固定 autoload 名**：`addons/godot_ai` 下的任何 autoload 都算本机条目，插件换版本改名也拦得住。反过来，**其他** autoload 一个不碰 —— 将来真要加基础服务 autoload（CD-51 §5）不会被误删，有用例钉着；
- **`enabled` 数组被摘空时保留 `enabled=PackedStringArray()`**，不删这个键。删键与留空键在 Godot 里语义相同，但留空键的 diff 更小；
- 纯文本编辑，不解析完整 ini 语义。不认识的 `enabled=` 写法（例如手工换行过的）会被**原样留下**而不是猜着改，这是故意的：宁可漏报一次让 CI 变红，也不要改坏 `project.godot`。

### 仍然欠着（不因本章消失）

- **git 原生钩子**：装 `pre-commit` 能覆盖人手 git，但需要改本机 `core.hooksPath`，属宪法第十八条的人类门禁项，本刀没做；
- **按实体 diff**：C4 第 8 章已修掉 Preview 的**每帧**重建，但一次编辑仍然全量重建 49 个节点。它不在每帧路径上，优先级低于下面这些；
- 远端协议层 RTT 回填、C3 网络参数锁定、E6 有美术后的可玩性签署、字体与本地化键、动画状态契约、D7 输入抽象层、角色胶囊尚未进资产表、垫 / 门 / 终点仍无独立视觉、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,516 行（E9 要求 < 400）。
