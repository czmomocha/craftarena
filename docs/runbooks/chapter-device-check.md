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

## 本刀：纠偏 C4 第 4 章 — 单资产预算门禁与跨平台烘焙

对应：当前完整章节 PR。[CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的预算 2026-08-30 已拍板，但当时**没有任何跨平台工具能执行它**——烘焙试验那份脚本硬编码 macOS `sips` 且不入库。这一章补上：一条校验命令（进 CI）+ 一条烘焙命令（开发机）。

**本章无 Godot 内可见行为**：不碰 `game/`、不入库任何资产。要看的全在命令行里，所以**不需要** `npm run dev`，也不需要打开 Traprush 窗口。

1. **空仓库不假绿**：仓库根 `npm run asset-budget`。
   - 预期：输出 `no .glb under game/ — nothing was checked.` 加一句 `this is not a pass.`，退出码 0。
   - 失败：只打一句 `ok` 就退出（那会让人以为门禁查过了）。
   - 为什么这么设计：仓库现在 0 个 `.glb`（E7 后半在第 5 章），门禁必须说清"没查"而不是"通过"。
2. **真实生成产物被拒，并逐张点名**：拿一个 4096 贴图的生成产物来跑。
   ```bash
   npm run asset-budget <你的生成产物>.glb
   ```
   （我这边用的是 `test-res/test-glb/kofizhou_lightai_1787938054928__AIGC_TEMP.glb`，你本机应该还在。）
   - 预期：退出码 **1**，逐行列出 `[texture_size] texture "#0" is 4096x4096`（三张各一行，**带 `#索引`**）与 `[file_bytes] 28.36 MB exceeds the 2.00 MB budget`，末尾指向烘焙 runbook。
   - 失败：绿了；或三张贴图都叫 `<embedded>` 分不出是哪张。
3. **烘焙一次，再验一次**：
   ```bash
   npx --yes @gltf-transform/cli@4.4.2 resize <产物>.glb /tmp/out.glb --width 512 --height 512
   npm run asset-budget /tmp/out.glb
   ```
   - 预期：第一条约 7 秒，打印 `29.74 MB → 803 KB` 量级；第二条 `ok ... largest edge 512, 784.2 KB`，退出码 0。
   - 失败：`npx` 装不上（Windows 上尤其要确认）；或烘焙后仍被拒。
   - macOS 上会打印 `objc[...] libvips-cpp` 两个版本冲突的警告，**可以忽略**（runbook 已记）。
4. **门禁不依赖 native**：确认 `npm audit` 输出 `found 0 vulnerabilities`。
   - 预期：0 漏洞。校验只用 `@gltf-transform/core`（2 个包）；带 4 个 libvips CVE 的 `sharp` 只在第 3 步的 `npx` 临时环境里，不在本仓库依赖树。
   - 失败：audit 报 high —— 那说明 cli 被误写进了 `package.json`。

### 本刀不测

- 任何 `.glb` 入库（第 5 章，E7 后半）；
- 按用途分档的烘焙参数（baseColor / ORM / normal 各自上限）与自动化流水线 —— 人类 2026-08-30 明确**不放 C4**；
- 场景总量 / Draw call / 材质数 / 骨骼上限 —— 仍属 [CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 延期；
- 动画状态契约、本地化键（第 6 章）；
- KTX2 / Basis 压缩路径（校验器**能读** KTX2 尺寸，但没有烘焙路径）。

### 诚实边界

- 烘焙工具**不在 lock 里**，传递依赖不保证逐字节可复现。可接受，因为入库物是产物 `.glb` 且由第 1 步的门禁把关；
- 那 4 个 CVE 仍然存在，只是不在本仓库依赖树。攻击面是"用 libvips 解码不可信图像"，而这里解码的是你自己生成的资产、在开发机上；
- 第 3 步的时间与体积数字来自 **2026-08-30 本机 macOS arm64 一次运行**，不是性能指标。

### 仍然欠着（不因本章消失）

24h ICMP 回填、远端协议层 RTT 回填、C3 网络参数锁定、E6 有美术后的可玩性签署、E7 后半（第一个 `.glb` 入库）、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,510 行（E9 要求 < 400）。

