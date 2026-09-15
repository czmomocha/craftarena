# M6 章节计划：BASTION 最小 1v1

> 类型：实现级章节计划（`docs/plans/`），**不是所有者文档**。
> 里程碑产出与退出条件的所有者是 [CD-61 §2 M6](../../Confirmed-docs/60-plan/61-milestones.md)；玩法规则的所有者是 [CD-22](../../Confirmed-docs/20-gameplay/22-bastion.md)。本文件只把 M6 拆成可审查的章，冲突以那两份为准。
> 日期：2026-09-15。状态：**D1–E2 已交，E3 起未开工。** 五项已拍板（§5.1）；其余三项仍待人类裁决（§5.2），卡在各自那一章之前。**E3 被第 4、5 项挡住**（匹配 HTTP 玩法判别位、结算 HTTP 队伍结果），AI 不得自选、不得开工。D 段交的是**全离线的玩法底座**；E1 交了协议帧与服务端裁剪；E2 交了第一张官方蓝图。对局进程、客户端壳仍没有，**现在开不出一局给人看，第一次有画面仍是 E4**。
> 上位约束：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第一、二、三、四、五、六、九、十五、十七、十八、十九、二十三、二十四条。

## 1. 能不能开工

能，顺序上轮到了。判据是 CD-61 的顺序值，不是感觉：

| 前置 | 状态 |
|---|---|
| M5 | **已退出**（2026-09-13 人类签署，结论「基本通过」） |
| 字体入包 | 已交（2026-09-13） |
| UI 接线第一批（S3 广场） | 已交（2026-09-13 / 09-14） |
| 测试期 VPS Web 分发（M-Export 第二刀） | 已交（2026-09-14）。人类 2026-09-15 另行确认**部署与测试已自行走过**，不阻塞本号 |
| CD-61 明写的下一动 | **M6**，含 UI 接线第二批 S1 主大厅壳（在本号 F1 章内，不提前） |
| D1 的两项硬阻断 | **已拍板**（2026-09-15，均采纳 AI 推荐），见 [§5.1](#51-已拍板2026-09-15) |
| D1–E2 | **已交**（2026-09-15）。下一刀是 **E3**，被 §5.2 第 4、5 项挡住（匹配 HTTP 玩法判别位、结算 HTTP 队伍结果），AI 不得自选、不得开工 |

**D1 曾被两项人类门禁挡住，2026-09-15 已拍板解锁**（结论见 [§5.1](#51-已拍板2026-09-15)）。在那之前 AI 只能写本文件——第一章要锁的是 Schema 与白名单，落在宪法第十八条上，不是可以「先写着等确认」的东西。

两处仓库规则文件已从里程碑级粒度改到「M6 D1」，否则下一个 Agent 加载到的仍是「M6 / M7」这种一整号的指向：

- `.cursor/rules/course-correction-freeze.mdc` §1；
- `.cursor/rules/complete-chapter-prs.mdc` 的「做 / 不做」两段与末四行任务单。

## 2. M6 范围

CD-61 §2 M6 的六项产出，加 CD-61 §2 M-Art 明写落在本号章内的 UI 接线第二批：

| # | 产出（CD-61 原文） | 现状 | 落在本文件哪几章 |
|---|---|---|---|
| 1 | 1v1 战场 | D1 已交（契约）；**E2 已交官方蓝图** | D1、E2 |
| 2 | 互设障碍 | D5 会话层已交；E1 协议层裁剪已交 | D5、E1 |
| 3 | 路径验证 | D2 已交 | D2 |
| 4 | 建塔、升级、出售 | D4 已交 | D4 |
| 5 | 基础兵线与核心 | D3 已交 | D3 |
| 6 | 无预测网络同步 | E1 已交实时帧 v1 扩展（type 5/6）；对局进程与客户端壳仍是 E3 / E4 | E1、E3、E4 |
| + | UI 接线第二批：S1 主大厅壳 | 场景与主题 2026-09-11 落库，**运行时零引用**；`s1_lobby.tscn` 没有脚本、18 处文案未迁 `UiCopy` | F1 |

### 2.1 能直接复用、不重写的

这一节存在的意义是划掉工作量。下列东西一个字都不用改就能服务 BASTION：

- `SimulationWorld` + `Fixed` + `SimulationWorldIndex` / `Move` / `Query`：定点几何、静态盒阔相、扫掠预算；
- Component Schema v1 的五个 BASTION 组件（`path_agent` / `build_slot` / `tower` / `team` / `health` / `spawner`）与 `SharedComponentRecord` 校验；
- `AuthoringDocument` / `AuthoringWorld` / EDIT 三个 `op`（`place` / `remove` / `set_component`）——它们本来就与玩法无关；
- 内容管线：`ContentSign` / `ContentPatch` / `ContentCatalog` / `ContentPlaza` / 控制面代签；
- 对局基建：MatchHost、网关、票据、重连补票、租约、心跳；
- 音频模块（`game/src/audio/`）——只需要新增一个业务层 router，服务层与底层不动；
- Rule VM v1（`OnMatchStarted` / `OnEveryTicks`）可承载阶段与胜负触发；
- UI 基础包：`s1_lobby.tscn` 与 `craft_arena.tres`，含已画好的 BASTION 卡；
- `StateHasher` / `CanonicalPayload` / `OccupancyGadget` / `PlaceholderSpec`。

### 2.2 必须新写的

`BastionBlueprintBundle` + 编译器；waypoint 边图与确定性搜索；`BastionMatchSession`（阶段机 / 经济 / 塔 / 兵 / 核心）；`bastion_play_stubs.gd`（占位数值单一配置源）；BASTION 实时帧；对局进程按玩法分派；客户端对局壳；第一张官方蓝图；`bastion_audio_router.gd`。

### 2.3 M6 明确不碰

属 M7 的：2v2；玩家个人金币 / 主建造区与**队伍公共槽**；队长盲设与队内投票；`DonateResourceIntent`（1v1 没有队友）；镜像系统波次的白名单建造策略切换；自动对打；兵潮性能观测；**蓝图 Edit**（CD-61 把它写在 M7 产出里，所以 M6 的官方蓝图是手写 JSON，不做编辑器面板）；双玩法复用率报告。

其它：**单人对 AI**——CD-12 §1 的大厅树里列了这一项，但 CD-61 §2 M6 的产出清单里没有，最接近的「自动对打」在 M7。本计划按 CD-61 办，不做（[§5.2](#52-待拍板阻断ai-不得自选) 不列它，因为它不是待拍板，是已有文档给出的顺序）。公开 TLS / 每个 PR 的 Web 沙盒排在 **M7 之后**；Android / iOS 烟测与触控 UI 在一期收尾；UI 接线第三批在公开 TLS 之后。

## 3. 三处结构性事实（决定了章节顺序）

### 3.1 权威状态不住在 `SimulationWorld` 里

`SimulationWorld` 只有位姿、胶囊与静态 AABB，**没有血量、金币、队伍**。TRAPRUSH 的进度与门闩住在 `TraprushMatchSession`，`hash_state` 由会话自己拼（`MatchRealtime._lease_state_mark` 还要额外拼箱耐久，因为会话哈希不含它）。

所以 BASTION 的核心血量、金币、塔等级、波次序号、漏怪数必须住在 `BastionMatchSession` 并进它自己的 `hash_state`。**`SimulationCore` 定点合同一个字不改**（红线），也不需要改。

### 3.2 作者文档不用改 Schema，编译产物需要新类型

`AuthoringDocument` 恰好四键、Component v1 已含 BASTION 六个组件，所以**一张 BASTION 蓝图可以就是一份 AuthoringDocument，Schema 一个字节不改**。这是本号最省的一处。

变的是编译产物。`SimulationBundle` 是 TRAPRUSH 拓扑（v2，22 个袋，从 `pads` 到 `ices`）。把 BASTION 塞进去有两处真实代价：ContentHash 覆盖 `to_dictionary()`，动它就牵动已发布内容与旧回放的哈希（宪法第六条）；两个玩法的袋子共用一条解码路径后，改哪边都要重读另一边。推荐见 [§5.2](#52-待拍板阻断ai-不得自选) 第 1 项。

顺带两处 ADR-0006 边界，本计划按「不动金标」处理，不需要新拍板：

- **新增资产 id** 走 `SharedGameplayAssetCatalog` 登记（该文件明写「新增资产在这里登记」），是加行不是改几何，`test_gameplay_asset_contract.gd` 的金标不动；
- **建造槽占地**仍按权威碰撞 AABB 在格网上的投影派生，**不加字段**。ADR-0006 Q2 把「占地独立成字段」推迟到「BASTION 的 `build_slot` 需要占几格时」；M6 的槽位一格一塔，不需要。

### 3.3 实时面与两条 HTTP 都是 TRAPRUSH 形状

| 面 | 现状 | BASTION 缺什么 |
|---|---|---|
| 快照帧 | TRAPRUSH：每玩家 41 字节 + 每箱 16 字节。**E1 已交** type=6 BASTION 快照 | 对局进程还没按席位单播裁剪帧（E3） |
| 命令帧 | TRAPRUSH intent id 1–6。**E1 已交** type=5、id 7–12 | 对局进程还没按玩法分派解码（E3） |
| 匹配 HTTP | `course` 与 `content` 互斥 | 没有玩法判别位 |
| 结算 HTTP | `finishTick` / `acceptedCount` / `padTotal` / `place` | 没有队伍结果。MVP 有 `mvpSlot` 可复用 |

四处都要动，**四处都在宪法第十八条**（Schema 破坏性变更 / 网络协议不兼容变更 / 数据迁移）。这是 M6 最大的一块门禁，不是实现难点——所以本计划把它们集中在 E1 / E3 两章，让人类一次性看清，而不是散在每一章里各批一次。

## 4. 章节清单（11 章）

顺序：**D1 → D2 → D3 → D4 → D5 → E1 → E2 → E3 → E4 → F1 → F2**。

D 段全部离线、不碰协议；E 段上线；F 段接 UI 与退出。每章都是一条链路的闭合，符合 D9 的 5× 粒度。交章时整节替换 [开发机窗口验收](../runbooks/dev-window-check.md) 的「本刀」；无 GUI 行为的章写「无」加原因（CD-52 §3.2），不得写「真机再看一眼」。

D 段五章在窗口里没有可见行为——这是玩法底座的性质，不是省事。**第一次有画面是 E4。** 把这件事写在这里，是为了不让人类在 D 段每交一章都期待一次窗口走查。

### D1 BASTION L0 契约与蓝图编译（**已交，2026-09-15**）

- **交付**：`bastion_blueprint_bundle.gd`（**独立新类型**，自带 `schema_version = 1` 与显式玩法判别键 `gameplay`；`SimulationBundle` 不动）；`bastion_prototype_catalog.gd`（[§5.1](#51-已拍板2026-09-15) 那九个原型的白名单 id + 升级上限 3，形状照 `gameplay_asset_catalog.gd`）；`bastion_play_stubs.gd`（占位数值单一配置源，形状照 `TraprushPlayStubs`）；`bastion_blueprint_compiler.gd`（AuthoringWorld → bundle：双方核心、建造槽、障碍槽、waypoint 边、波次基础表、初始金币 / 基础收入 / 赏金上限 / 时限）；灰盒夹具蓝图落 `game/content/test_fixtures/`；`tools/content-validator/` 加蓝图校验并进 CI。
- **落库路径**（与上面的概念名对照，避免下一个人按概念名去找文件）：L2 的四份进 `game/src/ugc/`——`bastion_blueprint_bundle.gd` / `bastion_blueprint_decode{,_bags}.gd` / `bastion_blueprint_compiler{,_bags,_graph}.gd` / `bastion_prototype_catalog.gd` / `bastion_blueprint_codes.gd`；`bastion_play_stubs.gd` 的落库路径是 **`game/src/games/bastion/play_stubs.gd`**（L3，与 `TraprushPlayStubs` 同形，路径由 `.cursor/rules/course-correction-freeze.mdc` §2 指定）。这么分不是风格：`ugc/` 是 L2 发布门禁，`games/` 是 L3 玩法，L2 不许反过来引用 L3（CD-41 §4）。夹具在 `game/content/test_fixtures/bastion/`，蓝图与 bundle 正反例分两个子目录，**GDScript 解码器与 content-validator 读同一批文件**。
- **一处需要人类在深审时看一眼的借用**：Component Schema v1 没有「对局配置」组件，加一个是 Schema 破坏性变更（宪法第十八条，本号不做），所以八个经济标量落在 `bastion_config` 实体的 `score.tallies` 上——v1 里唯一契约是「字符串键 → 整数、不锁具体统计项」的槽。口径已写进 [CD-42 当前生效值](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)。将来真加了配置组件，改 `BastionBlueprintCompilerBags.read_config` 一处。
- **测试**：正反例——未登记原型 id（**九个之外的一律拒绝**，防止有人从 CD-22 的示例表里自行补全）、`tower.level` 超上限、缺一侧核心、障碍槽为 0、waypoint 悬空边、两侧预算不等、`float` / `NodePath` 注入一律拒绝；**旧 TRAPRUSH bundle 喂进新解码器必须被拒**，且 `SimulationBundle` 的解码与 `to_dictionary()` 逐字节不变（金标断言，守住已发布内容的 ContentHash）。
- **审查**：**深审**（`shared/` 契约 + `ugc/` 编译 + UGC 安全边界）。
- **窗口**：无。纯契约与命令行校验，没有可点的控件。
- **不做**：仿真推进、协议帧、匹配、UI、蓝图编辑面板（M7）；把九项之外的塔 / 兵 / 障碍登记进白名单；改 Component Schema v1 或 Bundle v2。
- **诚实边界**：白名单里那九个原型的**数值是占位桩**，不是产品表（[CD-63 §1.3](../../Confirmed-docs/60-plan/63-open-decisions.md#1-玩法与数值细节) 仍延期）。本章锁的是「哪九个」与「形状」，不是「多少伤害」。

### D2 确定性寻路与「不得完全封路」守卫（**已交，2026-09-15**）

- **落库路径**：与玩法无关的整数边图搜索是 `game/src/simulation/fixed_graph_search.gd`（三项预算超限**拒绝整次搜索**，边权累加溢出既不饱和也不回绕）；守卫是 `game/src/games/bastion/path_guard.gd`，发布前与运行时同一份判据。问题码与 D1 同一份 `bastion_blueprint_codes.gd`。
- **灰盒夹具在本章被改过一次**：原来的两条分支在核心前一格就汇合，于是「封一条还剩一条」在那张图上不成立，守卫的正例测不出来。改成两条分支直到核心才汇合。这不是修 bug，是夹具当初画错了。

- **交付**：`game/src/simulation/` 里**游戏无关**的定点边图搜索（整数边权、按 entity_id 打破平局、节点 / 边 / 展开三项预算上限，超限**拒绝整次搜索**而不是给一条错路——与 `MAX_SWEEP_STEPS` 超限拒绝整段位移同一风格）；`bastion_path_guard.gd`：任一障碍启用或建塔占槽后重算「出兵点 → 核心」可达，不可达即拒绝该次操作（CD-22 §4.3「任意时刻至少保留一条合法路径」）；蓝图发布前可达性问题码，形状照 `authoring_reachability_codes.gd`。
- **测试**：同图同序列得同一条路径与同一 `hash_state`；封死唯一路径被拒、只是绕远被接受；预算超限拒绝；边权溢出拒绝（不饱和、不回绕，宪法第五条 / CD-42 §1.1）。
- **审查**：**深审**（进 `simulation/`，是权威裁决路径）。
- **窗口**：无。GUT + headless。
- **不做**：兵移动、塔、网络。
- **注**：CD-22 §8 已写明寻路是「离散 waypoint / 边图；障碍启用、禁用或修改边成本」，所以这里**不是**新产品决策，只是实现选型；算法预算数字是占位桩，落 `bastion_play_stubs.gd` 一处。

### D3 阶段机 + 镜像波次 + 核心伤害 + 胜负（离线）（**已交，2026-09-15**）

- **落库路径**：`game/src/games/bastion/match_session.gd` 门面 + `match_session_waves.gd`（生成与行进）+ `match_session_view.gd`（哈希与只读视图）。
- **两处实现口径，写在这里免得下次重新讨论**：单位**不进 `SimulationWorld`**（BASTION 的兵沿离散边图走，没有胶囊也不需要扫掠，权威状态住在会话里并进会话自己的 `hash_state`，与 TRAPRUSH 的进度门闩同一种安排）；一拍之内顺序固定为**生成 → 开火 → 行进 → 判胜负**，改顺序就改裁决结果。
- **镜像等价是构造性的**：波次表只有一份，两队的生成 tick 与属性由同一段代码、同一个种子推出，测试只是把它钉住，不是在核对两份可能分叉的数据。

- **交付**：`bastion_match_session.gd` 的五阶段（内容握手 → 互设障碍 → 准备建造 → 镜像波次 → 结算，CD-22 §6），阶段推进只由权威 tick 与锁定驱动，不读墙钟；`spawner` 按同一种子向双方生成**等价波次**（同类型、同数量、同属性、同生成 tick）；`path_agent` 沿 D2 的边图定点移动；到达核心扣 `health`；胜负与漏怪数按 CD-22 §5.2 排序；会话 `hash_state` 含核心血量 / 波次序号 / 漏怪数 / 存活单位位姿。
- **测试**：**两侧波次逐字节等价**（这是本玩法公平性的根据，不是风格偏好，属强断言范围）；同输入同哈希；核心归零即结束；双方都活时按核心生命 → 漏怪数 → 完成击杀时间依次比较；塔不跨区。
- **审查**：常审（`games/`）。
- **窗口**：无。headless 打印阶段与核心血量。
- **不做**：塔开火与经济（D4）、布障（D5）、网络、表现。

### D4 炮塔与经济（建造 / 升级 / 出售 / 目标优先级）（**已交，2026-09-15**）

- **落库路径**：`game/src/games/bastion/match_session_towers.gd`。四类伪造各一条反例已落 `game/tests/unit/test_bastion_towers_and_economy.gd`。
- **建造节奏**取 CD-22 §6 白名单策略里的「全程可建」：准备建造与镜像波次两个阶段都收建造意图，互设障碍阶段不收（战场版本还没锁定）。其它三种节奏属蓝图可选项，M6 不实现。

- **交付**：`build_slot.whitelist` 准入；建造 / 升级（≤3 级，CD-22 §5.1）/ 出售的金币事务；每波固定基础收入 + **有上限的**击杀赏金（CD-22 §6：避免领先方指数滚雪球）；三种塔自动锁敌与开火，四种 `target_priority` 的确定性排序（平局按 entity_id）；伤害在服务端生效，客户端只播表现。
- **测试**：**四类伪造各一条反例**——非白名单原型、非本方槽位、余额不足、超 3 级升级；同输入同哈希；赏金上限生效；出售返还比例是占位桩（不是产品经济）。
- **审查**：**深审**。理由不是代码位置，是 CD-61 §2 M6 的验收句直接点名「伪造金币和伪造建造均被拒绝」——这一章就是那句话的实现。
- **窗口**：无。
- **不做**：狙击 / 电弧 / 增幅塔（不在推荐的最小三塔集内）；捐赠（M7）。

### D5 互设障碍阶段（离线：盲设 → 锁定 → 揭示 → 重验 → 退点）（**已交，2026-09-15**）

- **D3 已经落了哪一半**：阶段本身、锁定标志、倒计时。**本章补齐**点数预算、盲设视图、统一揭示、揭示后重验与退点、`MatchSetupState`、布障命令进回放。
- **落库路径**：`game/src/games/bastion/match_setup_state.gd`（对局级状态 + 磁带）+ `match_session_setup.gd`（会话胶水，守 E9）。公开 API 仍在 `BastionMatchSession` 门面。
- **两处实现口径**：pending **不是活图**，提交时只验槽位 / 白名单 / 预算 / 锁定；封路在揭示时整表重跑，LIFO 撤销并退点。会话层的「盲」是 `visible_obstacles(viewer)` 按观察者裁剪；权威哈希含双方 pending。协议层裁剪已交于 E1。

- **交付**：`MatchSetupState`（CD-22 §7.2）；固定点数预算；只能放在蓝图预留的障碍槽；任一方锁定后不能再改；双方都锁定或倒计时结束统一揭示；揭示后服务端**重新**跑预算与 D2 可达性，非法放置撤销并**退还点数**（CD-22 §4.1 第 6、7 步）；战场版本锁定后进入准备建造；布障命令进回放（CD-22 §7.2 末条）。磁带当时不走 `SharedCommand`（线上 id 是 E1；对局进程接线仍是 E3）。
- **测试**：预算超支拒绝、非槽位拒绝、锁定后改动拒绝、封死路径在揭示时被撤销并退点、回放能复现完整布障序列。
- **审查**：**深审**（受控 P2 拓扑修改 + 安全边界）。
- **窗口**：无。
- **不做**：隐藏布障的**协议层**裁剪（当时属 E1，2026-09-15 已交）；队长与队内投票（M7）。本章的「盲」只在离线会话层成立，**不得**据此说当时协议层已经藏住了对方布局。

### E1 BASTION 实时帧与意图 id（**已交，2026-09-15**）

- **交付**：五个运行阶段意图里四个拿到线上 id（Build / Upgrade / Sell / SetPriority）；互设障碍两步拿到 PlaceObstacle / LockSetup；`DonateResourceIntent` 仍无 id（M7）。BASTION 快照帧（阶段 / 双方核心血量 / 金币 / 塔 / 存活单位 / 波次序号 / 障碍）；布障阶段的**服务端裁剪**（只下发本方放置，揭示 tick 之后才下发双方；缺观察者则整帧拒绝）；解码正反例；CD-43 §1 帧布局与 CD-42「当前生效值」回写。
- **落库路径**：`game/src/shared/protocol/bastion_frame_codec.gd` + `bastion_frame_snapshot.gd`（L0；v1 type 5/6）；会话→帧在 `game/src/games/bastion/match_session_wire.gd`（L3，避免 L0 引用会话）。TRAPRUSH `MatchFrameCodec` 的 type 1–4 布局一个字节不动。
- **审查**：**深审 + 人类事前批准**（宪法第十八条：网络协议不兼容变更）。开工即拍板 §5.2 第 3、6 项，结论见 [§5.1](#51-已拍板2026-09-15)。
- **窗口**：无。纯协议编解码，没有可点的控件；第一次有画面仍是 E4。
- **不做**：客户端预测（CD-61 M6 产出明写「无预测网络同步」，CD-22 §8 也写「玩法命令不预测」）；WebRTC；改已锁的 Tick / 快照 / 心跳 / 插值数字（E3 已锁）；把 DonateResource 编进 1v1；接线对局进程（E3）或客户端壳（E4）。

### E2 第一张官方蓝图（CD-61 §4.2 夹具全覆盖）（**已交，2026-09-15**）

- **交付**：`res://content/official/bastion/blueprint_01.json`——**手写 AuthoringDocument**（蓝图 Edit 属 M7，本号不做面板）；必须满足 CD-61 §4.2 九项：双方核心、双方各一条合法路径、双方各 3 个障碍槽、互设障碍阶段、3 种塔、3 种兵、建造 / 升级 / 出售、核心伤害与胜负、单局队伍结算与 MVP；官方蓝图 id 白名单落 `backend/contracts/src/official_blueprints.ts` 与 `game/src/shared/official_bastion_blueprints.gd`，形状照现有 `official_courses.ts` 与 `official_traprush_courses.gd` 那两处。**不接线匹配 HTTP**（E3）。
- **拍板**：`blueprint_01` = **对称双线**（2026-09-15 人类采纳 AI 推荐）。每侧一条短主路 + 一条绕行分支，两路在核心前才汇合；每侧 3 个障碍槽卡在分支口（1 个三种都能放、2 个只放路障 / 减速）；每侧 3 个建造槽沿主路；5 波、5 分钟局时。Component v1 `spawner` 一波一个原型，所以「快速+集群」「混合」落成第 3 / 第 5 波再出已出现过的类型（快速 → 集群 → 快速 → 重装 → 集群）。经济沿用 `BastionPlayStubs.GRAYBOX_ECONOMY`，不是产品表。
- **测试**：编译零问题码；发布前可达性通过；两侧对称预算相等；五分钟局时的波次基础表能跑完；`res://` 路径注入仍被拒（照官方课那条）；`blueprint_01` 塞进 TRAPRUSH `course` 仍失败。
- **审查**：常审。
- **窗口**：无（要到 E4 才有画面）。
- **不做**：匹配 HTTP 玩法位（E3）；蓝图编辑面板（M7）；把灰盒 3 波原样升格；锁伤害 / 金币 / 冷却。

### E3 对局进程 + 匹配 + 1v1 席位与队伍 + 结算写库

- **交付**：`MatchServerBoot` 按玩法分派（新命令行参数；缺省仍走 TRAPRUSH，旧命令行逐字节兼容）；匹配 HTTP 加玩法判别位；`match_sessions` / `match_queue` / `content_plaza` 加玩法列（`ALTER TABLE ... ADD COLUMN ... DEFAULT` 补旧行，照迁移 `0007_match_official_course` 与后来 UGC 房那次加列的先例）；1v1 = 2 席 + 队伍分配；MatchHost 传参；结算 HTTP 带队伍结果；广场按玩法分列，**BASTION 蓝图不混进 TRAPRUSH 列表**。
- **测试**：匹配 body 正反例（玩法位缺省、三者互斥、非法组合）；迁移前后旧行仍可读；席位与队伍映射；结算写库 409 幂等仍成立。
- **审查**：**深审 + 人类事前批准**（协议变更 + 数据迁移，两条都在第十八条）。
- **阻断**：[§5.2](#52-待拍板阻断ai-不得自选) 第 4、5 项。
- **不做**：跨玩法匹配池混排；改 FIFO 排队规则；把入场票据绑账号。

### E4 客户端 BASTION 对局壳

- **交付**：跟从 BASTION 快照的表现映射（核心 / 建造槽 / 塔 / 单位 / 障碍走 `OccupancyGadget` 那套程序化占位，色板进 `PlaceholderSpec`，**不散落新 `const`**）；建造交互（选槽 → 选原型 → 提交意图 → **等服务端确认**，不预测）；HUD（阶段、倒计时、双方核心血量、金币、波次 n/m、漏怪数）；布障阶段界面（只看得见自己的方案）；`bastion_audio_router.gd` 接已有音频模块（`game/src/audio/**` 零玩法词汇的红线扫描不变，router 住在业务层）。
- **测试**：占位表现**只写烟测**（能构造、不崩、节点数量级正确）——按「章粒度下限与审查分级」§3，不给占位表现写强断言；音频路由表每个 cue id 在 `audio_cue_catalog.gd` 里存在（防改名后静默失声）。
- **审查**：常审。
- **窗口**：**本刀开始有编号步骤**：两个客户端进同一房 → 各自盲设障碍 → 锁定揭示 → 建塔 / 升级 / 出售 → 跑完波次 → 核心归零出结算。
- **诚实边界**：BASTION 的音效素材尚未确认，先复用已登记的通用 UI cue 与现有命中 / 打碎类 cue；**不为用上某个素材发明机制**（照 M5 §3.4 的处理办法）。

### F1 UI 接线第二批：S1 主大厅壳（双玩法入口）

- **交付**：`s1_lobby.tscn` 接进运行时，替换 `match_lobby_*` 自绘 `Window` 的**壳**；新建 `s1_lobby.gd`；18 处硬编码文案迁 `UiCopy`，并把 `s1_lobby.tscn` 从 `test_ui_scene_copy.gd` 的 `PENDING_SCENES` 移到 `MIGRATED_SCENES`（那里有一条反例断言要求它「确实还含中文」，迁完会红，正是提醒）；BASTION 卡从「即将推出 COMING SOON 🔒」改成开放态；双玩法频道入口按 CD-12 §1 的树接线；`project.godot` 的全局 theme **仍不挂**（等第三批接完再统一挂，否则会当场改写还在跑的自绘界面）。
- **测试**：场景文案门禁；`validate_theme.gd` / `validate_scene.gd` 仍绿；大厅公开 API 的回归（照 S3 那刀「只换视图、逻辑与公开 API 不动」的做法）。
- **审查**：常审。
- **窗口**：**整节替换「共用启动」**——人类只打开这一份就能验当前章（CD-52 §3.2）。
- **诚实边界（不得省略）**：**这一章会让 TRAPRUSH 的可玩性签署当场作废。** CD-61 M5 退出记录第 2 条明写签署对象是「当前自绘大厅 + 占位美术 + 占位数值」那一版，换 UI 后结论不自动延续，**须重签**。重签安排在 F2。另：BASTION 卡改开放态会顺带带走那个 🔒，但 **emoji 仍不在字体子集内**（CD-63 §2.6），别处再用 emoji 在 Web 上仍是豆腐块，这一章不解决那件事。
- **不做**：S2 / S4 / S5 / S6（第三批）；**角色选择界面**（见 [§5.3](#53-需要人类澄清的一处口径不一致不是新决策)，不塞进本章）。

### F2 M6 退出验收

- **交付**：新清单 `docs/runbooks/playability-signoff-bastion.md`，形状照 TRAPRUSH 那份，八项换成 BASTION 的体验支柱（赛前博弈、路径可读、塔系组合、低操作高决策、经济取舍、公平约束、结算清晰度、外人 5 分钟上手，对应 CD-22 §2）；**TRAPRUSH 可玩性重签**（F1 换了 UI）；全闭环走查整节替换窗口验收本刀；CD-61 / CD-22 / CD-42 / CD-43 / CD-12 / CD-91 与两份 `.cursor/rules` 回写。
- **审查**：轻审 + 人类签署。
- **诚实边界**：AI 只交清单与步骤，**不代签、不代填结论**。签完之前 M6 不是已退出（宪法第二十四条）。M5 带走的两处缺口——**乱序与重复包未严格注入**（待 Linux `tc netem`）、可玩性签署的对象限定——不因 M6 消失，不得在任何材料里说成已解决。

## 5. 拍板状态

### 5.1 已拍板（2026-09-15）

四项都采纳了 AI 推荐。所有者文档与覆盖链见 [CD-91 D.4](../../Confirmed-docs/90-reference/91-decision-log.md)，本节不复述那里的未覆盖范围。第五项（官方蓝图主题）同日开工 E2 时拍板，也采纳 AI 推荐。

| 项 | 结论 | 所有者 |
|---|---|---|
| 蓝图编译产物载体 | **独立新类型** `BastionBlueprintBundle`，自带 `schema_version` 与显式玩法判别键；`SimulationBundle` 的 22 个袋与 `to_dictionary()` **一个字节不动**。蓝图本身仍是一份 `AuthoringDocument`，**Component Schema v1 不改**。新增资产 id 走 `SharedGameplayAssetCatalog` 登记（加行，不改几何）；建造槽占地仍按 AABB 格网投影派生，不加字段 | [CD-42 当前生效值](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)；键 `bastion_blueprint_bundle` |
| M6 最小塔 / 兵 / 障碍集 | **3 / 3 / 3**：箭塔（单体）+ 火炮塔（范围）+ 冰霜塔（减速）；快速兵 + 重装兵 + 集群兵；路障 + 减速地块 + 分流门。**只锁「M6 用哪九个」**——[CD-63 §1.2](../../Confirmed-docs/60-plan/63-open-decisions.md#1-玩法与数值细节) 的完整清单与 §1.3 的具体数值仍延期，M6 里它们全是落在 `bastion_play_stubs.gd` 一处的占位桩。狙击 / 电弧 / 增幅塔、护盾 / 支援 / 首领兵、护盾柱 / 干扰塔座 / 视野雾区**不在 M6**，D1 的白名单必须把它们判失败 | [CD-22 当前生效值](../../Confirmed-docs/20-gameplay/22-bastion.md)；键 `bastion_minimum_set_m6` |
| 实时帧扩展方式 | **在 v1 上加 type 5/6 + intent id 7–12，不升协议大版本**。TRAPRUSH type 1–4 布局一个字节不动。`DonateResourceIntent` 仍无 id（M7） | [CD-43 §1](../../Confirmed-docs/40-technical/43-networking-and-replay.md#1-序列化分工)；键 `bastion_realtime_frames` |
| 隐藏布障的协议实现 | **服务端裁剪**：布障阶段快照只含本方放置，揭示之后才下发双方；缺观察者则整帧拒绝。不做客户端承诺方案 | [CD-43 §1](../../Confirmed-docs/40-technical/43-networking-and-replay.md#1-序列化分工)；键 `hidden_state_sync` |
| 第一张官方蓝图的主题 | **`blueprint_01` = 对称双线**：每侧一条短主路 + 一条绕行分支，核心前汇合；每侧 3 障碍槽卡在分支口；5 波（快速 → 集群 → 快速 → 重装 → 集群）、5 分钟局时。经济沿用灰盒占位桩，不锁产品数值。匹配 HTTP 仍不认这份 id（E3） | [CD-22 当前生效值](../../Confirmed-docs/20-gameplay/22-bastion.md)；键 `official_bastion_blueprint_01` |

**「3 种障碍」是本次新增的口径，不是文档原有要求。** CD-61 §4.2 明写「3 种塔、3 种兵」，但障碍那一条只写「双方各 3 个障碍**槽**」。这一句留在这里，是为了下次有人回头查「三种障碍是谁定的」时不会误读成夹具本来就要求。

### 5.2 待拍板（阻断，AI 不得自选）

余下三项全部仍是「AI 给推荐、不给结论」，**没有一项被当成结论写进章节交付**。CD-22 §4.2 / §5.1 / §5.2 的表格自己写着「不是锁定清单」。下表第 1、2、3、6、7 行已于 2026-09-15 关闭并迁到 [§5.1](#51-已拍板2026-09-15)，**行号保留**以便先前讨论仍能对上号（覆盖而非删除，照 CD-63 的记法）。

| # | 问题 | 卡住哪章 | AI 推荐与理由 | 依据 |
|---|---|---|---|---|
| 1 | ~~编译产物载体~~ | ~~D1~~ | **已拍板**（2026-09-15）：新类型。结论见 [§5.1](#51-已拍板2026-09-15) | — |
| 2 | ~~最小塔 / 兵 / 障碍集~~ | ~~D1、D3、D4~~ | **已拍板**（2026-09-15）：3 / 3 / 3。结论见 [§5.1](#51-已拍板2026-09-15) | — |
| 3 | ~~实时帧扩展方式~~ | ~~E1~~ | **已拍板**（2026-09-15）：v1 加 type 5/6 + intent id 7–12。结论见 [§5.1](#51-已拍板2026-09-15) | — |
| 4 | **匹配 HTTP 玩法判别位** | E3 | **加玩法字段，缺省 TRAPRUSH**；官方蓝图走独立的 `blueprint` id，与 `course` / `content` 三者互斥。**不把 `course` 塞成 `"bastion:blueprint_01"`**——照 M5 C4「加 `content` 对象而不是把 `course` 塞成 `id@version`」那次的先例 | 宪法第十八条；[CD-42 §3.5](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md#35-匹配与玩家发布-httpc3-已接线c4-已接线) |
| 5 | **结算 HTTP 队伍结果** | E3 | **加可选队伍数组，复用已有 `mvpSlot`**，TRAPRUSH 现有必填字段一律不动（否则已写入的结算记录读不出来）。`place` 在 BASTION 读作队伍名次。一期仍只有单局名次与 MVP，不产生任何账号级排位 | 宪法第十五、十八条 |
| 6 | ~~隐藏布障的协议实现~~ | ~~D5 尾 / E1~~ | **已拍板**（2026-09-15）：服务端裁剪。结论见 [§5.1](#51-已拍板2026-09-15) | — |
| 7 | ~~第一张官方蓝图的主题与机关组合~~ | ~~E2~~ | **已拍板**（2026-09-15）：对称双线。结论见 [§5.1](#51-已拍板2026-09-15) | — |
| 8 | **BASTION 音效素材与 cue 映射** | E4 | 先只用已登记的通用 UI cue 与现有命中 / 打碎类 cue；新素材入库仍是一次人类许可确认 | 宪法第十八条；[CD-42 §1.4](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md#14-音频-cue-bank-v1) |

第 1、2 项曾是硬阻断——没有它们，D1 连文件名都定不下来；第 3、6 项曾挡 E1；第 7 项曾挡 E2；**2026-09-15 已关闭**。第 4、5、8 项卡在各自那一章开工前，**不挡 E3 之前已交的章**。

### 5.3 需要人类澄清的一处口径不一致（不是新决策）

CD-61 §1 的顺序列表把「角色选择界面」排在 **UI 接线第三批之后**，而同一文件「未开工」行与该列表的括注都写「**紧跟主大厅壳**」。主大厅壳在 M6（F1），第三批在公开 TLS 之后——两句给出的位置差了一大截。

本计划**不自行择一**，只把角色选择排在 M6 之外、不塞进 F1。请人类在 CD-61 里定一处；这属于同一份所有者文档内部的口径冲突（宪法第二十六条），不是本计划能覆盖的。

## 6. M6 退出条件

CD-61 §2 M6 的验收句不变：**双方可以完成一局；非法封路、伪造金币和伪造建造均被拒绝。** 本文件补充可核对的形式：

1. 官方蓝图 01 可开局，两个客户端能各自布障 → 建塔 → 跑完全部波次 → 出队伍结算与 MVP；
2. 四类伪造各有一条反例测试且在线上被拒：封死唯一路径、非本方槽位、余额不足、超 3 级升级；
3. 同输入同种子得同一 `hash_state`；布障序列可回放；
4. S1 主大厅壳接线后，**TRAPRUSH 的可玩性签署已重签**（F1 让旧结论作废）；
5. BASTION 可玩性清单由人类走一遍并签署；
6. 2v2、蓝图 Edit、自动对打、双玩法复用率报告**不是**本号退出条件（属 M7）；公开 TLS 与每个 PR 的 Web 沙盒排在 M7 之后。

## 7. 本文件不做的事

- 不改 `SimulationCore` 定点合同；不改已锁的 Tick / 快照 / 心跳 / 插值数字（E3 已锁）；不发明新 Hz；
- 不动 `SimulationBundle` 的 22 个袋，也不动 TRAPRUSH 的帧布局；
- 不改 TRAPRUSH 的推击力度、爆破半径、道具重生（D-F4 / D-F5 / D-F6 保持现值）；
- 不散落几何 / 色板常量：BASTION 占位色板进 `PlaceholderSpec`，玩法占位数值进新的 `bastion_play_stubs.gd`；
- 不把 M5 带走的两处缺口说成已解决；
- 不把 S1 从 M6 拆出去单独开工；不提前开工 Android / iOS 烟测、公开 TLS / PR Web 沙盒、UI 接线第三批、触控 UI；
- 不引入 WebRTC；不把外部网络故障注入工具写进仓库或 CI；
- 不代签、不代填任何人类清单；
- 不发明 M8。

## 8. 本刀自己的门禁

本文件里有两句话只要被后人顺手删掉，下一个读者就会做出错误判断：「D 段交完 ≠ M6 能开一局给人看」与「F1 会让 M5 那份可玩性签署作废」。所以它们有机械门禁：`tools/dev-launcher/tests/m6_plan.test.ts` 钉住本文件的 11 章、§5.2 的八行待拍板、四处第十八条边界，以及 CD-61 §2 M6 / CD-22 与两份 `.cursor/rules` 的指向。

D1–E2 落地时这条门禁**收窄过**：原先钉的是「BASTION 一行实现都没有」，那句话在 D1 之后就假了；后来钉「E1 起未开工」「E2 起未开工」，交完那句也假了。现在改钉三件仍然为真、且同样容易被顺手抹掉的事——E3 起未开工、§4 引子里那句「要到 E4 才有画面」、M6 未退出。

门禁的判定力是**注入故障跑出来的**，不是用 PASS 证明的（做法照 [ui-wiring.md §0.1](../runbooks/ui-wiring.md) 那次教训）：

| 注入（2026-09-15 实测） | 期望 | 实测 |
|---|---|---|
| 把本文件 F1 的「重签」全部换成「再看一眼」 | 非零 | `exit=1`，6 项里 1 项红 |
| 把 CD-61 §2 M6 里「E3 起**未开工**」改成「已全部交付」 | 非零 | `exit=1`，6 项里 1 项红 |
| 把 `.cursor/rules/complete-chapter-prs.mdc` 的指针退回整号 `M6 / M7` | 非零 | `exit=1`（`m5_exit.test.ts`） |
| 抹掉 §4 引子里那句「D 段没有可见行为、要到 E4 才有」 | 非零 | `exit=1`（D1–D4 落地时新增；断言只看 §4 引子，不看本表） |
| 抹掉 CD-22 里「狙击 / 电弧 / 增幅塔……**不在 M6**」那句排除项 | 非零 | `exit=1` |
| 把 CD-63 §1.2 / §1.3 改成「完整清单就此关闭」 | 非零 | `exit=1` |
| 把本文件 §5.1 的「只锁「M6 用哪九个」」改成「锁定清单」 | 非零 | `exit=1` |
| 全部还原 | 零 | 两份测试都 `exit=0` |

最后三行守的是同一件事：**这次拍板只关闭了「M6 用哪九个」，没有关闭完整清单。** 这个区别一旦在任何一份文档里被抹平，下一个人就会从 CD-22 的示例表里自行补全塔和兵（宪法第五节明确禁止的那种「把示例当已确认答案」）。

`tools/dev-launcher/tests/m5_exit.test.ts` 里那条「两份规则指向哪一刀」的断言同时收窄了：从整号 `M6 / M7` 改成具体章（`M6 D1`，随后 D5、E1、E2，E2 落地后是 `M6 E3`），并加了一条反例禁止再退回整号指向——上表第三行就是它。

里程碑归属：M6
是否绕过 placeholder_spec 散落几何/色板常量：否
审查级别：D1 深审（`shared/` 契约 + `ugc/` 编译 + UGC 安全边界）；D2 深审（进 `simulation/`，权威裁决路径）；D3 常审（`games/`）；D4 深审（CD-61 §2 M6 验收句直接点名「伪造金币和伪造建造均被拒绝」）；D5 深审（受控 P2 拓扑修改 + 安全边界）；E1 深审（网络协议不兼容变更）；E2 常审（官方蓝图）
开发机窗口步骤：无。D 段与 E1 / E2 不改任何运行时可见行为，没有可点的控件；M6 第一次有窗口行为是 E4。
