# M6 章节计划：BASTION 最小 1v1

> 类型：实现级章节计划（`docs/plans/`），**不是所有者文档**。
> 里程碑产出与退出条件的所有者是 [CD-61 §2 M6](../../Confirmed-docs/60-plan/61-milestones.md)；玩法规则的所有者是 [CD-22](../../Confirmed-docs/20-gameplay/22-bastion.md)。本文件只把 M6 拆成可审查的章，冲突以那两份为准。
> 日期：2026-09-15。状态：**章节划分与八项拍板项待人类裁决；第一章 D1 被 §5.2 第 1、2 项硬阻断，未拍板前不得开工。** 本文件到今天为止**没有一行实现**，BASTION 的落点仍是零（`game/src/games/bastion/` 是空目录）。
> 上位约束：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第一、二、三、四、五、六、九、十五、十七、十八、十九、二十三、二十四条。

## 1. 能不能开工

能，顺序上轮到了。判据是 CD-61 的顺序值，不是感觉：

| 前置 | 状态 |
|---|---|
| M5 | **已退出**（2026-09-13 人类签署，结论「基本通过」） |
| 字体入包 | 已交（2026-09-13） |
| UI 接线第一批（S3 广场） | 已交（2026-09-13 / 09-14） |
| 测试期 VPS Web 分发（M-Export 第二刀） | 已交（2026-09-14）。人类 2026-09-15 另行确认**部署与测试已自行走过**，不阻塞本号 |
| CD-61 明写的下一动 | **M6 / M7**，含 UI 接线第二批 S1 主大厅壳（在 M6 章内，不提前） |

**但「轮到」不等于「可以动手」。** 第一章 D1 要锁的是 Schema 与白名单，落在宪法第十八条的人类门禁上（[§5.2](#52-待拍板阻断ai-不得自选) 第 1、2 项）。AI 在这两项拍板前只能写本文件，不能写 `game/src/games/bastion/` 里的第一行代码。

D1 真正开工那一刀，须一并把两处仓库规则文件从里程碑级粒度改到「M6 D1」，否则下一个 Agent 加载到的仍是「M6 / M7」这种一整号的指向：

- `.cursor/rules/course-correction-freeze.mdc` §1；
- `.cursor/rules/complete-chapter-prs.mdc` 的「做 / 不做」两段与末四行任务单。

## 2. M6 范围

CD-61 §2 M6 的六项产出，加 CD-61 §2 M-Art 明写落在本号章内的 UI 接线第二批：

| # | 产出（CD-61 原文） | 现状 | 落在本文件哪几章 |
|---|---|---|---|
| 1 | 1v1 战场 | 零 | D1、E2 |
| 2 | 互设障碍 | 零 | D5、E1 |
| 3 | 路径验证 | 零。**一期至今没有导航网格、没有寻路**，见 `gameplay_asset_catalog.gd` 文件头「解冻 BASTION 时重开」 | D2 |
| 4 | 建塔、升级、出售 | 零。但 `tower` / `build_slot` 字段已在 Component Schema v1 冻结（CD-42 §1.2），`BuildTowerIntent` / `UpgradeTowerIntent` / `SellTowerIntent` / `SetTowerPriorityIntent` 已登记在 `player_intent_names.gd`，`front` / `nearest` / `strongest` / `weakest` 已在 `tower_target_priorities.gd` | D4 |
| 5 | 基础兵线与核心 | 零。`path_agent` / `health` / `team` / `spawner` 同样已冻结 | D3 |
| 6 | 无预测网络同步 | 零。实时帧 v1 是 TRAPRUSH 形状（见 [§3.3](#33-实时面与两条-http-都是-traprush-形状)） | E1、E3、E4 |
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
| 快照帧 | 每玩家 41 字节（位姿 + `accepted_count` + `finish_tick`）+ 每箱 16 字节 | 阶段、双方核心血量、金币、塔、存活单位、波次序号，一个都没有 |
| 命令帧 | intent id 1–6 | 五个 BASTION 意图**没有线上 id** |
| 匹配 HTTP | `course` 与 `content` 互斥 | 没有玩法判别位 |
| 结算 HTTP | `finishTick` / `acceptedCount` / `padTotal` / `place` | 没有队伍结果。MVP 有 `mvpSlot` 可复用 |

四处都要动，**四处都在宪法第十八条**（Schema 破坏性变更 / 网络协议不兼容变更 / 数据迁移）。这是 M6 最大的一块门禁，不是实现难点——所以本计划把它们集中在 E1 / E3 两章，让人类一次性看清，而不是散在每一章里各批一次。

## 4. 章节清单（11 章）

顺序：**D1 → D2 → D3 → D4 → D5 → E1 → E2 → E3 → E4 → F1 → F2**。

D 段全部离线、不碰协议；E 段上线；F 段接 UI 与退出。每章都是一条链路的闭合，符合 D9 的 5× 粒度。交章时整节替换 [开发机窗口验收](../runbooks/dev-window-check.md) 的「本刀」；无 GUI 行为的章写「无」加原因（CD-52 §3.2），不得写「真机再看一眼」。

D 段前四章在窗口里没有可见行为——这是玩法底座的性质，不是省事。**第一次有画面是 E4。** 把这件事写在这里，是为了不让人类在 D 段每交一章都期待一次窗口走查。

### D1 BASTION L0 契约与蓝图编译（**下一刀，当前被阻断**）

- **交付**：`game/src/games/bastion/` 落第一批文件；`bastion_blueprint_bundle.gd`（新类型，自带 `schema_version = 1` 与显式玩法判别键；`SimulationBundle` 不动）；`bastion_prototype_catalog.gd`（塔 / 兵 / 障碍白名单 id + 升级上限 3，形状照 `gameplay_asset_catalog.gd`）；`bastion_play_stubs.gd`（占位数值单一配置源，形状照 `TraprushPlayStubs`）；`bastion_blueprint_compiler.gd`（AuthoringWorld → bundle：双方核心、建造槽、障碍槽、waypoint 边、波次基础表、初始金币 / 基础收入 / 赏金上限 / 时限）；灰盒夹具蓝图落 `game/content/test_fixtures/`；`tools/content-validator/` 加蓝图校验并进 CI。
- **测试**：正反例——未登记原型 id、`tower.level` 超上限、缺一侧核心、障碍槽为 0、waypoint 悬空边、两侧预算不等、`float` / `NodePath` 注入一律拒绝；**旧 TRAPRUSH bundle 喂进新解码器必须被拒**，且 `SimulationBundle` 的解码与 `to_dictionary()` 逐字节不变（金标断言，守住已发布内容的 ContentHash）。
- **审查**：**深审**（`shared/` 契约 + `ugc/` 编译 + UGC 安全边界）。
- **窗口**：无。纯契约与命令行校验，没有可点的控件。
- **不做**：仿真推进、协议帧、匹配、UI、蓝图编辑面板（M7）。
- **阻断**：[§5.2](#52-待拍板阻断ai-不得自选) 第 1、2 项。**这两项没拍板，本章不得开工。**

### D2 确定性寻路与「不得完全封路」守卫

- **交付**：`game/src/simulation/` 里**游戏无关**的定点边图搜索（整数边权、按 entity_id 打破平局、节点 / 边 / 展开三项预算上限，超限**拒绝整次搜索**而不是给一条错路——与 `MAX_SWEEP_STEPS` 超限拒绝整段位移同一风格）；`bastion_path_guard.gd`：任一障碍启用或建塔占槽后重算「出兵点 → 核心」可达，不可达即拒绝该次操作（CD-22 §4.3「任意时刻至少保留一条合法路径」）；蓝图发布前可达性问题码，形状照 `authoring_reachability_codes.gd`。
- **测试**：同图同序列得同一条路径与同一 `hash_state`；封死唯一路径被拒、只是绕远被接受；预算超限拒绝；边权溢出拒绝（不饱和、不回绕，宪法第五条 / CD-42 §1.1）。
- **审查**：**深审**（进 `simulation/`，是权威裁决路径）。
- **窗口**：无。GUT + headless。
- **不做**：兵移动、塔、网络。
- **注**：CD-22 §8 已写明寻路是「离散 waypoint / 边图；障碍启用、禁用或修改边成本」，所以这里**不是**新产品决策，只是实现选型；算法预算数字是占位桩，落 `bastion_play_stubs.gd` 一处。

### D3 阶段机 + 镜像波次 + 核心伤害 + 胜负（离线）

- **交付**：`bastion_match_session.gd` 的五阶段（内容握手 → 互设障碍 → 准备建造 → 镜像波次 → 结算，CD-22 §6），阶段推进只由权威 tick 与锁定驱动，不读墙钟；`spawner` 按同一种子向双方生成**等价波次**（同类型、同数量、同属性、同生成 tick）；`path_agent` 沿 D2 的边图定点移动；到达核心扣 `health`；胜负与漏怪数按 CD-22 §5.2 排序；会话 `hash_state` 含核心血量 / 波次序号 / 漏怪数 / 存活单位位姿。
- **测试**：**两侧波次逐字节等价**（这是本玩法公平性的根据，不是风格偏好，属强断言范围）；同输入同哈希；核心归零即结束；双方都活时按核心生命 → 漏怪数 → 完成击杀时间依次比较；塔不跨区。
- **审查**：常审（`games/`）。
- **窗口**：无。headless 打印阶段与核心血量。
- **不做**：塔开火与经济（D4）、布障（D5）、网络、表现。

### D4 炮塔与经济（建造 / 升级 / 出售 / 目标优先级）

- **交付**：`build_slot.whitelist` 准入；建造 / 升级（≤3 级，CD-22 §5.1）/ 出售的金币事务；每波固定基础收入 + **有上限的**击杀赏金（CD-22 §6：避免领先方指数滚雪球）；三种塔自动锁敌与开火，四种 `target_priority` 的确定性排序（平局按 entity_id）；伤害在服务端生效，客户端只播表现。
- **测试**：**四类伪造各一条反例**——非白名单原型、非本方槽位、余额不足、超 3 级升级；同输入同哈希；赏金上限生效；出售返还比例是占位桩（不是产品经济）。
- **审查**：**深审**。理由不是代码位置，是 CD-61 §2 M6 的验收句直接点名「伪造金币和伪造建造均被拒绝」——这一章就是那句话的实现。
- **窗口**：无。
- **不做**：狙击 / 电弧 / 增幅塔（不在推荐的最小三塔集内）；捐赠（M7）。

### D5 互设障碍阶段（离线：盲设 → 锁定 → 揭示 → 重验 → 退点）

- **交付**：`MatchSetupState`（CD-22 §7.2）；固定点数预算；只能放在蓝图预留的障碍槽；任一方锁定后不能再改；双方都锁定或倒计时结束统一揭示；揭示后服务端**重新**跑预算与 D2 可达性，非法放置撤销并**退还点数**（CD-22 §4.1 第 6、7 步）；战场版本锁定后进入准备建造；布障命令进回放（CD-22 §7.2 末条）。
- **测试**：预算超支拒绝、非槽位拒绝、锁定后改动拒绝、封死路径在揭示时被撤销并退点、回放能复现完整布障序列。
- **审查**：**深审**（受控 P2 拓扑修改 + 安全边界）。
- **窗口**：无。
- **不做**：隐藏布障的**协议层**裁剪（属 E1，且 CD-63 §1.6 未拍）；队长与队内投票（M7）。本章的「盲」只在离线会话层成立，**不得**据此说协议层已经藏住了对方布局。

### E1 BASTION 实时帧与意图 id（**协议不兼容变更**）

- **交付**：五个 BASTION 意图拿到线上 intent id；BASTION 快照帧（阶段 / 双方核心血量 / 金币 / 塔 / 存活单位 / 波次序号）；布障阶段的**服务端裁剪**（只下发本方放置，揭示 tick 之后才下发双方）；解码正反例；CD-43 §1 帧布局与 CD-42「当前生效值」回写。
- **审查**：**深审 + 人类事前批准**（宪法第十八条：网络协议不兼容变更）。
- **阻断**：[§5.2](#52-待拍板阻断ai-不得自选) 第 3 项（帧扩展方式）与第 6 项（隐藏布障协议，CD-63 §1.6 本来就在待决清单里）。
- **不做**：客户端预测（CD-61 M6 产出明写「无预测网络同步」，CD-22 §8 也写「玩法命令不预测」）；WebRTC；改已锁的 Tick / 快照 / 心跳 / 插值数字（E3 已锁）。

### E2 第一张官方蓝图（CD-61 §4.2 夹具全覆盖）

- **交付**：`res://content/official/bastion/blueprint_01.json`——**手写 AuthoringDocument**（蓝图 Edit 属 M7，本号不做面板）；必须满足 CD-61 §4.2 九项：双方核心、双方各一条合法路径、双方各 3 个障碍槽、互设障碍阶段、3 种塔、3 种兵、建造 / 升级 / 出售、核心伤害与胜负、单局队伍结算与 MVP；官方蓝图 id 白名单落 `backend/contracts/src/official_blueprints.ts` 与 `game/src/shared/official_bastion_blueprints.gd`，形状照现有 `official_courses.ts` 与 `official_traprush_courses.gd` 那两处。
- **测试**：编译零问题码；两侧对称预算相等；五分钟局时的波次基础表能跑完；`res://` 路径注入仍被拒（照官方课那条）。
- **审查**：常审。
- **窗口**：无（要到 E4 才有画面）。
- **阻断**：[§5.2](#52-待拍板阻断ai-不得自选) 第 7 项（蓝图主题与机关组合），照 M5 C1 / C2「04 = 垂直塔 / 05 = 双路线竞速」的先例由人类拍。

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

### 5.1 本计划没有自选任何未决项

三塔三兵三障碍的具体数值、蓝图主题、协议帧形状、隐藏布障的实现方式，全部在下表里以「AI 推荐」的形式出现，**没有一项被当成结论写进章节交付**。CD-22 §4.2 / §5.1 / §5.2 的表格自己写着「不是锁定清单」，CD-63 §1.2 / §1.3 也明写完整清单与具体数值仍延期。

### 5.2 待拍板（阻断，AI 不得自选）

| # | 问题 | 卡住哪章 | AI 推荐与理由 | 依据 |
|---|---|---|---|---|
| 1 | **编译产物载体**：新类型 `BastionBlueprintBundle`，还是扩 `SimulationBundle` | **D1（硬阻断）** | **新类型**，自带 `schema_version = 1` 与显式玩法判别键，`SimulationBundle` 一个字节不动。理由：ContentHash 覆盖 `to_dictionary()`，动 `SimulationBundle` 就牵动已发布内容与旧回放的哈希；22 个袋再混进 BASTION 之后，改哪个玩法都要重读另一个 | 宪法第三、六、十八条；[CD-42 当前生效值](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md) |
| 2 | **最小塔 / 兵 / 障碍集与占位数值** | **D1、D3、D4（硬阻断）** | 照 CD-61 §4.2 夹具取 **3 / 3 / 3**：箭塔（单体）+ 火炮塔（范围）+ 冰霜塔（减速）；快速兵 + 重装兵 + 集群兵；路障 + 减速地块 + 分流门。数值全是占位桩，落 `bastion_play_stubs.gd` 一处并标注「不是产品表」。形状照 D5「一期最小道具 = 爆破球 + 冲刺」那次的先例。**注意**：§4.2 只要求各 3 个障碍**槽**，没规定几种障碍，「三种障碍」是 AI 推荐不是文档要求 | [CD-63 §1.2 / §1.3](../../Confirmed-docs/60-plan/63-open-decisions.md#1-玩法与数值细节)；[CD-22 §4.2 / §5.1 / §5.2](../../Confirmed-docs/20-gameplay/22-bastion.md) |
| 3 | **实时帧扩展方式** | E1 | **在 v1 上加新帧类型 + 新 intent id，不升协议大版本**。依据是现有解码器的行为：`decode_snapshot` / `decode_command` 都先查 `type` 字节、不符即拒，所以加类型不会让 TRAPRUSH 客户端误读，TRAPRUSH 帧布局也一个字节不动。次选是独立 `bastion_frame_codec.gd` 自带版本字节 | 宪法第十八条；[CD-43 §1](../../Confirmed-docs/40-technical/43-networking-and-replay.md#1-序列化分工) |
| 4 | **匹配 HTTP 玩法判别位** | E3 | **加玩法字段，缺省 TRAPRUSH**；官方蓝图走独立的 `blueprint` id，与 `course` / `content` 三者互斥。**不把 `course` 塞成 `"bastion:blueprint_01"`**——照 M5 C4「加 `content` 对象而不是把 `course` 塞成 `id@version`」那次的先例 | 宪法第十八条；[CD-42 §3.5](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md#35-匹配与玩家发布-httpc3-已接线c4-已接线) |
| 5 | **结算 HTTP 队伍结果** | E3 | **加可选队伍数组，复用已有 `mvpSlot`**，TRAPRUSH 现有必填字段一律不动（否则已写入的结算记录读不出来）。`place` 在 BASTION 读作队伍名次。一期仍只有单局名次与 MVP，不产生任何账号级排位 | 宪法第十五、十八条 |
| 6 | **隐藏布障的协议实现**（本来就在待决清单里） | D5 尾 / E1 | **服务端裁剪**：布障阶段快照只含本方放置，揭示 tick 之后才下发双方。不做「客户端提交承诺、揭示时验证」那套——它要求客户端先持有对方数据，与宪法第二条方向相反 | [CD-63 §1.6](../../Confirmed-docs/60-plan/63-open-decisions.md#1-玩法与数值细节)；[CD-22 §4.1](../../Confirmed-docs/20-gameplay/22-bastion.md#41-流程)；宪法第二条 |
| 7 | **第一张官方蓝图的主题与机关组合** | E2 | 对称双线：每侧一条主路 + 一条绕行分支，3 个障碍槽卡在分支口；5 波、5 分钟局时。照 M5 C1 / C2 的先例由人类拍 | [CD-61 §4.2](../../Confirmed-docs/60-plan/61-milestones.md#42-bastion) |
| 8 | **BASTION 音效素材与 cue 映射** | E4 | 先只用已登记的通用 UI cue 与现有命中 / 打碎类 cue；新素材入库仍是一次人类许可确认 | 宪法第十八条；[CD-42 §1.4](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md#14-音频-cue-bank-v1) |

第 1、2 项是**硬阻断**：没有它们，D1 连文件名都定不下来。第 3–8 项卡在各自那一章开工前，不挡 D1。

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

本文件里有两句话只要被后人顺手删掉，下一个读者就会做出错误判断：「D1 被硬阻断」与「F1 会让 M5 那份可玩性签署作废」。所以它们有机械门禁：`tools/dev-launcher/tests/m6_plan.test.ts` 钉住本文件的 11 章、§5.2 的八行待拍板、四处第十八条边界，以及 CD-61 §2 M6 / CD-22 与两份 `.cursor/rules` 的指向。

门禁的判定力是**注入故障跑出来的**，不是用 PASS 证明的（做法照 [ui-wiring.md §0.1](../runbooks/ui-wiring.md) 那次教训）：

| 注入（2026-09-15 实测） | 期望 | 实测 |
|---|---|---|
| 把本文件 F1 的「重签」全部换成「再看一眼」 | 非零 | `exit=1`，6 项里 1 项红 |
| 把 CD-61 §2 M6 的「状态：**未开工**」改成「进行中」 | 非零 | `exit=1`，6 项里 1 项红 |
| 把 `.cursor/rules/complete-chapter-prs.mdc` 的指针退回整号 `M6 / M7` | 非零 | `exit=1`（`m5_exit.test.ts`） |
| 全部还原 | 零 | 两份测试都 `exit=0` |

`tools/dev-launcher/tests/m5_exit.test.ts` 里那条「两份规则指向哪一刀」的断言同时收窄了：从整号 `M6 / M7` 改成具体章 `M6 D1`，并加了一条反例禁止再退回整号指向——上表第三行就是它。

里程碑归属：M6
是否绕过 placeholder_spec 散落几何/色板常量：否
审查级别：轻审（本刀只有文档与一份文档门禁，无产品代码）
开发机窗口步骤：无。本刀不改任何运行时行为，没有可点的控件；M6 第一次有窗口行为是 E4。
