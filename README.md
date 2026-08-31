# Craft Arena 工坊竞技场

Godot 4 + UGC 双玩法（TRAPRUSH / BASTION）项目 Monorepo。代码与仓库标识的命名写法见 [CD-11 §1](Confirmed-docs/10-product/11-scope-and-platforms.md)。

- 工程规则入口：[AGENTS.md](AGENTS.md)
- 规范唯一事实源：[Confirmed-docs](Confirmed-docs/README.md)
- 当前阶段：**纠偏冻结中**。2026-08-26 第三方审视（[docs/audits/2026-08-26-audit.md](docs/audits/2026-08-26-audit.md)）判定「工程纪律罕见优秀，但已经跑偏了赛道」，人类已拍板：纠偏完成前不进行原计划中新的功能开发。可开工范围、占位常量冻结清单与解除条件 E1–E14 见 [纠偏方案 2026-08](docs/plans/course-correction-2026-08.md)，对 Agent 生效的版本在 `.cursor/rules/`。C0 闸门已落地。C1 导出预设、compose、远端双机与 [`server-deploy.md`](docs/runbooks/server-deploy.md) §12 基线已回填（近端 10 分钟与 24h ICMP 均未证伪快照桩；24h 全天丢 1 包、主体仍 ~3ms；7 局空转证实 CPU 先于内存）。C3 **不得**用 ICMP 锁定网络参数。远端协议层 RTT 仍空。C2 两章已合入（`--bot-run`；集成/回放进 CI 与[返工率首份数据](docs/audits/2026-08-27-ai-rework-rate.md)）。C3 第 1–7 章已合入（重力、沿路立足面、爆破球+冲刺、机关击退、`course_01` 安全路 vs 捷径、协议层 ping/pong、BotRunner 安全路）。本刀是 C4 第 8 章：**Preview 每帧不再重建节点树**——上一刀共享 `Mesh` 把「每帧重新实例化模型」压到接近零之后，剩下的 6.7 ms 是节点树本身（49 个占位盒每帧 `free` + `new`）。`AuthoringPreviewMap.rebuild()` 改成**脏检查**：记住上次建图的世界指纹（`AuthoringWorld` 实例身份 / `revision` / 实体数 / 格边 + 两条视觉资产路径），指纹没变整段跳过；试玩里 `AuthoringWorld` 不变，所以每帧成本降到几次 `get_node_or_null`。跳过重建后另两个每帧入口改成幂等：玩家标记复用节点只改姿态；检查点验收标记按传入集合**重写**而不是只追加 `*`（否则 R 复位后留陈旧标）。开玩 / 停玩、`import_document` / `restore_document` 这四个「世界指纹不变或 `revision` 被写回旧值」的入口显式强制重建。12 条新守卫钉的是「该跳过就跳过、该重建就重建」这对性质，**没有**新的毫秒观察值。**仍然欠着**：按实体 diff（一次编辑仍全量重建，但那不在每帧路径上）；Godot AI 插件把 `autoload/_mcp_game_helper` 写回 `project.godot` 由另一条分支单独还。上一刀是 C4 第 7 章：**单网格视觉资产共享 Mesh**——把上一刀记账的两处卡顿还掉，同一个根因是 `PackedScene.instantiate()` 太贵。单网格资产改为提取 `Mesh` 一次并共享、每个实例只 new 一个节点；多网格或带 skin 的资产回退到 `instantiate`。开发机实测（观察值，非门禁）：实例化 36 个地砖 55.9 → **0.16 ms**；挂 / 换课程 `MatchSolidMap.apply_bundle` 64.6 → **1.4 ms**；Preview **每帧** `AuthoringPreviewMap.rebuild` 74.3 → **7.1 ms**。10 条新守卫断言的是「共享同一个 `Mesh` 对象」与「改一个实例的颜色不串到另一个」这对性质，不是毫秒数。此前是 C4 第 6 章：**D4 视口与镜头规格接线**——相机俯角由 43.3° 校到 D4 的斜 45°（距离与 FOV D4 没问，一位没改，但从隐式默认改成显式写在 `placeholder_spec.gd`），UI 基准接成 1920×1080 + `canvas_items` 等比缩放、落在**主窗口** stretch，开发机运行窗 1600×900 改由 `window_*_override` 承担（**运行窗尺寸没变**）。D4 数值同时落 [CD-11 §8.2](Confirmed-docs/10-product/11-scope-and-platforms.md) 与 CD-91，**E8 前半基本满足**（仍空：相机距离/FOV、UI 安全区、BASTION 色板）。人类 4K 屏审查发现两个问题，均已在本刀修掉：（a）**鼠标 hover / 点击与按钮错位**——本刀第一版给嵌入子窗口也设了 `content_scale`，而它在渲染路径不生效、输入路径生效，命中偏 1.5 倍（点 Solo play 中 Poll）且 `Sprint` / `Apply server` 被切出屏幕；改为只由主窗口承担，两条壳各加回归守卫。（b）**帧率与输入迟钝**（上一章引入）——`MatchSnapshotMap.apply_players` 每帧全清全建，接上角色 `.glb` 后每帧要重新实例化 3000 三角面：实测 1 席 7.40 ms、2 席 12.76 ms（60 FPS 只有 16.7 ms 预算），并把按帧走的输入采样率一起拖慢；改为复用席位节点后 **0.015 ms/帧**。**已确诊未修**（各需独立一刀）：Preview 壳按住方向键仍全量重建整个世界、挂课程时一次性实例化 36 个地砖 ≈ 63 ms。**不做**字体入包与本地化键（新第三方资产 + 许可证属人类门禁，子集范围会影响 Web 包体，须人类拍板）。此前：C4 第 4 章单资产预算门禁（`npm run asset-budget` 进 CI）+ 跨平台烘焙命令（[runbook](docs/runbooks/asset-bake.md)）；C4 第 5 章第一批 `.glb` 入库与视觉解析（**E7 满足**）；C3 第 8 章（环境失败硬直 1.0 s）、C4 第 1–3 章（占位常量收敛、[ADR-0006](docs/adr/0006-gameplay-asset-contract.md)、契约落地 Bundle v2）与一刀 freeze-exception（MatchHost 引擎路径不再静默回退）均已合入。自动化烘焙流水线人类 2026-08-30 明确**不放 C4**。
- 冻结前进度：M3 进行中（2026-08-24 启动）。已落地对局多人仿真循环、二进制协议 v1、对局进程仿真入口、实时回路、网关代理、控制面真票据、MatchHost 自动登记、等待 listen 后登记、停止后注销、真匹配/房间码、FIFO 等待队列、客户端匹配入场、权威快照与赛道几何 / 可破坏箱 / 传送连线 / 检查点顺序 / 直播名次表现映射、机关狂奔离线单人试玩、对局命令门禁、全员冲线单局结算写库、断线重连补票、官方赛道选择、人数按场下发、对局快照插值、对局本席移动预测、对局进程动作数值占位桩、对局大厅本席摄像机跟随、对局大厅本席移动朝向、对局大厅本席分色、对局大厅本席检查点占用高亮、对局大厅本席冲线闭环表现、对局大厅本席复位与楼层/箱子 HUD、大厅只读结算面板、对局大厅本席预测避开最新权威固体、真人命令才续租、网关进程内 TLS、权威 Move 位移门禁、对局基础推击（无线上目标 id，服务端推最近其它胶囊，大厅 F）、出界复位（Preview + 对局，开发桩 ±8 格，环境失败后无限复活到最近检查点）；周期机关已进 v1 拓扑（`hazards` 袋用已有 `cooldown_ticks` 切换固体）；对局大厅周期机关表现映射（洋红占位盒，显隐跟固体半周期，HUD `hazards=n/m`）；开发机运行体验（空格走 `jump` 而不是点 Solo play / Play；F5/F6 外框与 Traprush/Preview 窗默认更大并最大化；打开编辑器时若本机已安装 Godot AI 则自动启用）；固定固体占用（`zone.tags` 含 `solid` 编进 v1 可空 `solids` 袋；大厅/Preview 石色 1 米占位；HUD `solids=n/m`）；官方赛道占用（三张课各有洋红周期机关；沿路石色立足面由 C3 第 2 章铺上）；编辑器 Place finish（工具条用已有 `place` 摆金色终点占用；第二份终点仍写入、编译拒绝）；官方赛道立足固体与 Jump（出生点正下一格石色盒；空格在 Solo / Preview 真跳约四分之一格）。C3 第 1 章已把权威重力积分接到对局 / Solo / Preview（对局/Solo 占位加速度每 tick 十六分之一格；Preview Advance 才积分；同一拍 Jump 不被立刻落下；不锁产品重力）。C3 第 3 章把爆破球与冲刺接到权威仿真（官方课出生点叠放拾取；Q 打箱要有弹且服务端 reach 命中；Shift 沿 yaw 冲刺一格且不穿固体）。C3 第 4 章把周期机关命中接到权威仿真（固体半周期占用重叠才击退/复位；不读客户端命中断言）。C3 第 5 章把 `course_01` 做成有落差、有安全路与危险捷径的语义课（+X 五步捷径仍在；从检查点 1 向 +Z 走更长安全路）。C3 第 6 章给在线对局加上协议层 RTT 探针（状态行 `rtt=`）。C3 第 7 章让 BotRunner 能封掉捷径传送门、证明安全路可完成。本刀把环境失败硬直接到 1.0 s。进度见 [CD-61](Confirmed-docs/60-plan/61-milestones.md)。

## 目录

```text
game/       Godot 4 工程（src 按 L0–L5 分层、content、tests）
backend/    control-plane / realtime-gateway / match-host / contracts
tools/      dev-launcher / bot-runner / asset-budget / content-validator / redline-scanner / replay-inspector
infra/      compose / tencent-cloud
docs/       adr / plans / runbooks
```

结构的所有者文档是 [CD-41 §5](Confirmed-docs/40-technical/41-architecture.md)。改目录先改那里。

## 环境搭建

工具选型、精确版本锁定与安装步骤全部以 [CD-51](Confirmed-docs/50-engineering/51-dev-environment.md) 为准，本文件不复述选型理由。

首次在一台新机器上准备环境时按 CD-51 §4 执行。Windows 开发机已经跑通、要在第二台 Mac 上拉同一份代码时，按 [CD-51 §4.1](Confirmed-docs/50-engineering/51-dev-environment.md) 执行，不要再初始化一遍工程。完成后必须跑通 CD-51 §6 的环境验证烟测；**未完成那套闭环不进入正式功能开发**。

烟测的逐步命令、预期输出与历次执行记录见 [环境烟测清单](docs/runbooks/environment-smoke-test.md)。想亲手确认这套环境成立，照它从头跑一遍即可，约 10 分钟。Godot AI MCP 的安装、关遥测与接入签字是另一份清单：[Godot AI 接入烟测](docs/runbooks/godot-ai-mcp-setup.md)，不要和 M0 十步混做。

### 依赖

精确版本号的所有者是 [CD-51 §1](Confirmed-docs/50-engineering/51-dev-environment.md)，本文件不复述。两点仓库事实：Godot 由开发机本地安装、不入库；GUT 随仓库入库在 `game/addons/gut/`，许可证见该目录下的 `LICENSE.md`。

升级引擎或插件按 CD-51 §2 处理，并同步 CD-51 §1 的版本行。

### 环境变量

所有命令通过 `GODOT4` 定位引擎，禁止在脚本里写死绝对路径。Windows 上还额外提供 `GODOT4_CONSOLE`，因为普通 exe 在 PowerShell 里不回显 stdout，读不到 Godot 控制台输出。

```powershell
# 一次性写入用户环境变量，改成你自己的安装路径
[Environment]::SetEnvironmentVariable("GODOT4", "C:\Tools\Godot_v4.7.2-stable_win64.exe", "User")
[Environment]::SetEnvironmentVariable("GODOT4_CONSOLE", "C:\Tools\Godot_v4.7.2-stable_win64_console.exe", "User")
# Godot AI 匿名遥测必须在第一次启用插件前关闭（CD-51 §7.2）
[Environment]::SetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "true", "User")
```

```bash
# macOS / Linux，写入 shell 配置
export GODOT4="/Applications/Godot.app/Contents/MacOS/Godot"
export GODOT_AI_DISABLE_TELEMETRY=true
```

### Godot 工程

`game/project.godot` 已经生成，**不要手写这个文件**，它由引擎的 `ProjectSettings` API 序列化而成。当前已按 CD-51 §5 落实的设置：

- 渲染基线 `gl_compatibility`，桌面、移动、Web 三个平台一致（宪法第七条）；
- 类型相关警告全局设为 Error，`res://addons` 例外（宪法第二十三条，理由见 [ADR-0001](docs/adr/0001-strict-gdscript-typing-gate.md)）；
- CD-51 §5 要求的 17 个输入动作，移动类绑定 physical keycode；
- 脚本与场景文件名 `snake_case`；
- UI 分辨率基准 1920×1080（D4，见 [CD-11 §8.2](Confirmed-docs/10-product/11-scope-and-platforms.md)），按 `canvas_items` / `expand` 等比缩放；开发机运行窗仍是 1600×900 最大化，写在 `window_width_override` / `window_height_override` 上。**代码创建的嵌入子窗口不得自己设 `content_scale_*`**：`gui_embed_subwindows = true` 下它渲染不生效、输入生效，会让鼠标命中与画面错位；
- 启动场景 `res://src/client/main.tscn`，打印一行结构化启动日志并打开机关狂奔匹配大厅（代码创建 Window，相邻快照采样后的玩家位姿、所选官方赛道占用与可破坏箱映射为 1 米占位盒，classified portal 画 gizmo 条，检查点垫标 `order` 且唯一 `order` 连线，最新快照直播名次标到玩家盒上方；本席 Move/Jump 在最新权威上叠加本地 overlay；大厅 WASD 写入 8 向离散水平朝向，玩家盒带面向标记；快速游戏 / 建房发送官方赛道 id 与本场人数，按码加入跟从该房课程与人数；Solo play 走本地内嵌权威并持续显示「离线试玩，成绩不上传」；Headless 不发起 live HTTP/WS）。

这些设置由 `game/tests/unit/test_project_contract.gd` 断言守护，改坏了跑测试就会红。

## 常用命令

以下命令都在 Windows 与 macOS 上、Godot 4.7.2 + GUT 9.7.1 + Node 24 实际执行验证过。CD-51 §4 要求把固定命令写在本文件，**禁止各 Agent 自行猜测参数**。

### Godot

| 用途 | Windows (PowerShell) | macOS (bash/zsh) |
|---|---|---|
| 查看引擎版本 | `& $env:GODOT4_CONSOLE --version` | `"$GODOT4" --version` |
| 打开编辑器 | `& $env:GODOT4 --editor --path game` | `"$GODOT4" --editor --path game` |
| 运行主场景（窗口，真机） | `& $env:GODOT4 --path game` | `"$GODOT4" --path game` |
| 运行并指向远端服务器 | `& $env:GODOT4 --path game -- --server=<主机>` | `"$GODOT4" --path game -- --server=<主机>` |
| Headless 导入检查 | `& $env:GODOT4_CONSOLE --headless --path game --import` | `"$GODOT4" --headless --path game --import` |
| Headless 启动主场景 | `& $env:GODOT4_CONSOLE --headless --path game --quit` | `"$GODOT4" --headless --path game --quit` |
| 单文件语法与类型检查 | `& $env:GODOT4_CONSOLE --headless --path game --check-only -s res://src/client/main.gd` | `"$GODOT4" --headless --path game --check-only -s res://src/client/main.gd` |
| 运行 GUT（unit + integration + replay） | `& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit` | `"$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit` |
| 官方赛道能不能走通 | `& $env:GODOT4_CONSOLE --headless --path game -- --bot-run` | `"$GODOT4" --headless --path game -- --bot-run` |

### 赛道能不能走通（BotRunner）

`--bot-run` 让一个 bot 在权威仿真上真的走一遍官方赛道，每张课打印一行 JSON，最后一行汇总，任一张走不通就 exit 1。

```powershell
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run                       # 三张官方课（course_01 走 +X 捷径）
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run --course=course_03    # 只跑一张
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run --course=course_01 --route=safe   # 封掉 entity 10，走安全路
& $env:GODOT4_CONSOLE --headless --path game -- --bot-run --max-ticks=6000      # 放宽预算
```

`outcome=completable` 时同时给出走通用的动作序列，可以照着重放复验。**`not_completable` 不等于「人也过不去」**：bot 的动作集是离散的（八向各走一整格、跳、用道具、等一 tick），`reason` 会说明是搜索穷尽（`search_exhausted`，较强）还是预算先用完（`budget_exhausted`，只说明没搜完）。完整边界见 `game/src/games/traprush/course_completion_probe.gd` 文件头。

`--route=safe` **只接受** `course_01`：搜索前拿掉 +X 捷径上楼 two_way（entity 10），再重放 C3 第 5 章已经走通的四向安全路。其它课没有这条语义，带这个旗就 exit 1。默认 `--bot-run` 仍走捷径、仍用完整动作集搜索。`--bot-run` 仍不进 CI。

C3 第 2 章沿路地板后（2026-08-27，Windows 开发机）：三张课均为 `completable`（`course_01` / `course_02` 各 5 步；`course_03` 12 步）。C3 第 5 章给 `course_01` 加了更长安全路之后，默认探针仍走捷径。C3 第 7 章用 `--route=safe` 在封掉捷径门后重放那条更长安全路，证明它也能完赛。

跑得不快，这是权威仿真本身的开销：开发机上一次 `commit_tick` 约 8 ms，一次整格移动约 27 ms（胶囊半径决定扫掠要走八步）。会话没有快照/恢复接口，搜索每展开一步都要从头重放。当前三张课分别约 8 / 8 / 77 秒。这些是 Windows 开发机 debug 解释器的数字，不是产品性能指标，也还没在导出包或 Linux 服务器上量过。

### 导出

导出模板必须与引擎同一精确版本，装法与校验和见[导出包核查清单](docs/runbooks/desktop-export-check.md) §1。预设在 `game/export_presets.cfg`，产物落 `export/`（已 gitignore）。

| 用途 | Windows (PowerShell) |
|---|---|
| 导出 Windows 包 | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Windows Desktop" "../export/windows/CraftArena.exe"` |
| 导出 Linux Headless 包 | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Linux Headless" "../export/linux-headless/craftarena-server.x86_64"` |
| 导出 Web 包 | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Web" "../export/web/index.html"` |
| 包内自检（`ok=true` 才算成立） | `& "export\windows\CraftArena.exe" --headless -- --package-check` |

macOS 把 `& $env:GODOT4_CONSOLE` 换成 `"$GODOT4"`。包内自检也能对源码工程跑：`& $env:GODOT4_CONSOLE --headless --path game -- --package-check`，此时 `addons` / `tests` 三条只报告不判定。

关于退出码：GUT 的 `-gexit` 在失败时返回 1（Windows 已测失败路径；macOS 本次只测了全绿路径）。`--check-only` 在 Windows 上失败返回 1；在 macOS 4.7.2 上类型错误会打印 `SCRIPT ERROR` / `Warning treated as error`，但进程退出码仍为 0，本地不要只看 `$?`。Linux CI 按退出码收集 `--check-only` 失败，该失败路径未在 macOS 上复现为非 0，不能把本机行为说成 CI 已经覆盖。

### 后端与工具

后端是 npm workspaces，命令在仓库根目录执行，两个平台写法相同。`.ts` 由 Node 24 原生剥离类型直接运行，没有构建步骤。

| 用途 | 命令 |
|---|---|
| 安装依赖 | `npm install` |
| 类型检查 | `npm run typecheck` |
| 后端与工具单元测试 | `npm test` |
| 宪法红线扫描 | `npm run redline-scan` |
| 单资产预算门禁（[CD-11 §8.1](Confirmed-docs/10-product/11-scope-and-platforms.md)） | `npm run asset-budget`（扫 `game/`）／ `npm run asset-budget <file>.glb` |
| 资产烘焙（开发机，压到预算内） | `npx --yes @gltf-transform/cli@4.4.2 resize in.glb out.glb --width 512 --height 512`（见 [runbook](docs/runbooks/asset-bake.md)） |
| 手动补跑 worktree setup | `npm run setup-worktree` |
| **一键拉起三个后端进程** | `npm run dev` |
| 单独启动控制面 | `npm run control-plane` |
| 单独启动实时网关 | `npm run gateway` |
| 单独启动 MatchHost | `npm run match-host` |

`npm run dev` 是 DevLauncher：启动前若仓库根有 `.env`，用 Node 24 `process.loadEnvFile` 读入（已在环境里的变量优先）。然后顺序拉起控制面、网关、MatchHost，从各自日志里读出实际监听地址后轮询 `/readyz`，三个都就绪才放行；Ctrl+C 一起停。它不复制端口默认值。任一进程在就绪后意外退出，DevLauncher 会停掉其余进程并以非 0 退出，避免留下半死的环境。

DevLauncher 只管本地开发编排，不做守护、重启和资源限制；测试环境的编排见 [CD-44](Confirmed-docs/40-technical/44-deployment.md)。

默认端口、数据库位置等配置项由各服务自己的 `src/config.ts` 通过环境变量读取，默认值写在那里，本文件不复述。MatchHost 必须能读到 `GODOT4`（Windows 优先 `GODOT4_CONSOLE`），否则**拒绝启动**——它不会退到 PATH 上的 `godot`（[CD-51 §4](Confirmed-docs/50-engineering/51-dev-environment.md)）。网关可选 `GATEWAY_TLS_CERT` / `GATEWAY_TLS_KEY`（必须成对指向 PEM）；未设置时明文 `ws`。`npm run dev` 默认不启用 TLS，DevLauncher 的 `/readyz` 探测仍走 http。

### 客户端指向哪台服务器

客户端默认连 `127.0.0.1`。三种改法，优先级从高到低：

| 方式 | 写法 | 说明 |
|---|---|---|
| 命令行 | `-- --server=<主机>` | 只换主机，端口沿用默认；`--` 不能省 |
| 命令行（分别指定） | `-- --control-plane=http://<主机>:8080 --gateway=ws://<主机>:8090` | 端口或协议也要换时用 |
| 环境变量 | `CRAFTARENA_SERVER` / `CRAFTARENA_CONTROL_PLANE` / `CRAFTARENA_GATEWAY` | 双击 exe 时生效 |
| 大厅输入框 | `Server host` 一行加 **Apply server** | 运行中改；对局进行中会被拒 |

地址被拒时状态行出现 `server_error=`，**当前生效值不变**。解析与校验在 `game/src/client/server_endpoint.gd`。

### 远端测试环境（Docker Compose）

产物在 `infra/compose/`，逐步操作、基线采集与云上差异见[远端部署手册](docs/runbooks/server-deploy.md)。手打 `docker compose` 在测试机的 `infra/compose/` 下执行；日常更新从**仓库根**跑脚本（见下表最后一行）：

| 用途 | 命令 |
|---|---|
| 构建镜像（`GODOT_SHA512` 必填） | `docker compose build` |
| 拉起三服务 | `docker compose up -d` |
| 看状态与健康 | `docker compose ps` |
| 跟日志 | `docker compose logs -f` |
| 停止并清理 | `docker compose down`（**不要**加 `-v`，会丢掉 SQLite） |
| 日常更新（拉 main、重建、等就绪） | 仓库根：`bash infra/compose/craftarena-compose.sh update`（手册 [§4.1](docs/runbooks/server-deploy.md#41-日常更新测试机)） |

`match-host` 不发布任何端口，只在 compose 内网被网关访问；对外只开控制面与网关两个端口。测试期传输是明文 `http` / `ws`（人类 2026-08-27 拍板 D11，[CD-62](Confirmed-docs/60-plan/62-risk-register.md) 已登记），**不是产品形态**。

## 持续集成

`.github/workflows/ci.yml` 在推送 `main` 和所有 PR 上运行两个 job：`backend`（`npm run typecheck` + `npm run redline-scan` + `npm run asset-budget` + `npm test`）与 `godot`（导入、逐文件 `--check-only`、Headless 启动烟测、GUT unit/integration/replay）。用的都是上面表里那些命令，本地跑一遍就能复现 CI 的结论。`--bot-run` 不进 CI。两个 job 都带 `lfs: true`：资产预算必须读到真 `.glb`，读到 LFS 指针会被判为失败。

CI 当前实际启用了哪些门禁、哪些还没实现，以 [CD-53 §4.1](Confirmed-docs/50-engineering/53-testing-and-ci.md) 的「当前实现状态」表为准。§4.2–§4.4 的每日 / 每周 / 发布候选清单同样有状态列；没有独立 cron，已落地的集成与回放用例挂在每次 PR 的 GUT 步骤上。`tests/content/` 与 `tests/security/` 仍空，不进 CI（C2 不做 UGC 安全全集）。

## 协作规则

提交、推送与合入 `main` 的边界见 [CD-52 §1.1](Confirmed-docs/50-engineering/52-ai-workflow.md)。宪法第十八条的人类门禁落在合入 `main`、部署与发布。项目级 `.cursor/hooks.json` 会拦向 `main` 的 git 提交/推送，以及 `git worktree remove --force`。

任务完成判定见 [CD-53 §5 Definition of Done](Confirmed-docs/50-engineering/53-testing-and-ci.md)。完整章节 PR 的人类真机步骤义务见 [CD-52 §3.2](Confirmed-docs/50-engineering/52-ai-workflow.md)，可执行清单是 [章节真机清单](docs/runbooks/chapter-device-check.md)（人工检查，不是 CI 门禁）。

## 并行工作区

[CD-52 §5.1](Confirmed-docs/50-engineering/52-ai-workflow.md) 的 A1–A4 已成立，`.cursor/agents/` 与 `.cursor/BUGBOT.md` 已入库。GitHub PR 侧 Bugbot 已跳过，合入靠 CI + 人类批准。M1 已退出（2026-08-23）。工具链评审已通过：MCP 生产级启用；并行保持 2 域，第 3 域未开。M2 第一刀（Component Schema v1）串行进行中；合入后再按域并行。继续按 [CD-52 §5](Confirmed-docs/50-engineering/52-ai-workflow.md) 使用隔离 worktree。下面只服务「一个 Agent 在隔离 worktree 里干活」。禁止 symlink `node_modules`，禁止把 Cursor Automations 配进项目。

Cursor 创建 worktree 时会跑 `.cursor/worktrees.json`：`npm install`、按需从 `$ROOT_WORKTREE_PATH` 拷 `.env` 与 `data/*.sqlite`、按 worktree 目录名写入端口偏移、用 `GODOT4`（Windows 优先 `GODOT4_CONSOLE`）对 `game/` 做 `--import`。主 checkout（与 `$ROOT_WORKTREE_PATH` 相同）不写 `.env`。

端口公式（不要另猜）：`slot * 100` 加到各服务 `config.ts` 默认端口上。`slot` 为目录名哈希映射到 1–9；可用环境变量 `WORKTREE_SLOT=1`…`9` 覆盖。主 checkout 为 slot 0。写进该 worktree 的 `.env` 的键是 `CONTROL_PLANE_PORT`、`GATEWAY_PORT`、`MATCH_HOST_PORT`、`MATCH_HOST_PORT_RANGE_MIN`、`MATCH_HOST_PORT_RANGE_MAX`、`CONTROL_PLANE_URL`、`MATCH_HOST_URL`。

| 用途 | 命令 |
|---|---|
| 在当前目录重跑 setup | `npm run setup-worktree` |
| 后端与工具测试 | `npm test` |
| 拉起该 worktree 的三个后端 | `npm run dev` |
| GUT | 见上面 Godot 表，`--path game` |

IDE 里用 `/worktree` 开隔离工作区。调试 setup 看 Output 面板的 `Worktrees Setup`。不要在 worktree 里放未提交且不可再生的东西（Cursor 可能自动清理）。
