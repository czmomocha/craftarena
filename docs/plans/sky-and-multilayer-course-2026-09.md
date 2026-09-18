# 天空盒与多层官方课（章节计划）

> 实现级计划，**不是所有者文档**。顺序与验收的所有者是 [CD-61](../../Confirmed-docs/60-plan/61-milestones.md)；Schema 与 wire 的所有者是 [CD-42](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)；资产预算与入库形态的所有者是 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 与 [CD-51 §5.1](../../Confirmed-docs/50-engineering/51-dev-environment.md)。冲突以那几份为准。
>
> 日期：2026-09-17。三章：**A1 → A2 → A3**。不发明新里程碑号，不发明 M8。

## 1. 这一段为什么插在 M6 F2 之前

人类 2026-09-17 提出两件需求：TRAPRUSH 对局要有天空盒（官方课用默认那张，自建地图能在两张里选），以及一张多层官方课（终点与起点至少相隔 6 层，最底层满铺不会掉出去，其它层可以掉到低层）。

排位是**只签一次**：[M6 F2](m6-bastion-1v1.md) 要重签 TRAPRUSH 可玩性签署（F1 换了 S1 主大厅壳，让 M5 那份结论作废）。天空与新课同样改变被签对象，放在 F2 之后就要再作废一次。所以插在 F1 之后、F2 之前，F2 那一次重签一并覆盖新 UI + 天空 + 新课。

**M6 F2 仍未开工。** 插入段不改变 M6 的退出条件，也不把 F2 的任何一项挪走。

## 2. 五项已拍板（2026-09-17，人类）

| # | 问题 | 结论 | 次选为什么没选 |
|---|---|---|---|
| 1 | 天空选择的承载 | **新 component 类型 `environment`**（恰好 `sky_id`） | AuthoringDocument 顶层加键是 P4 破坏性变更（`authoring_document.gd` 的 `body.size() != 4` + schema `additionalProperties: false`），且要新增第四个 EditCommand `op`；`zone.tags` 自由字符串拼错会静默忽略 |
| 2 | 贴图分辨率 | **1024 × 512**，并给 CD-11 §8.1 加「独立运行时贴图」档 | 2048×1024 约 8 MB 显存/张，低端机与 WebGL2 有风险；512×256 铺满全屏明显糊 |
| 3 | `course_06` 身份 | **进匹配白名单**（Godot `MATCH_IDS` + backend enum + CD-21 课表行），且必须过完赛探针 | 只做 Solo 示范课（像 `course_f_playable`）等于这张课永远进不了对局 |
| 4 | 插位 | **M6 F1 之后、F2 之前** | 见 §1 |
| 5 | 贴图来源 | **本地 AI 生成工具产物（自有）**，按 [CD-11 §8](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的 AI 资产口径入库 | 不是第三方素材，所以 `ATTRIBUTION.md` 不归档第三方许可条款原文 |

来源见 [CD-91](../../Confirmed-docs/90-reference/91-decision-log.md) 键 `traprush_sky_selection`。

## 3. 三章拆分

### A1 契约与贴图入库（已交，2026-09-17）

**深审。** 一条链路的闭合：内容里怎么表达"这张图用哪个天空" + 贴图真的在包里。

- **组件**：Component Schema v1 第 20 个组件 `environment`，wire 形状恰好 `{"sky_id": int}`，`sky_id >= 0`。复用现有 `place` / `set_component`，**不新增第四个 EditCommand `op`**（[CD-42 §3.3](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md) 那条不许破）。`transform` 不是必填，天空实体不带位姿；
- **目录**：`game/src/shared/sky_catalog.gd`（`SharedSkyCatalog`）。`sky_id = 0` → 默认那张全景，`1` → 低多边形那张。**贴图路径不进 SimulationBundle**，只有语义 id 进（ADR-0006 Q4 = A），所以以后换天空贴图不产生新内容版本、不改 ContentHash。id **只增不减**：编译期按目录门禁，移除 id 会让旧内容重编译失败；
- **袋**：SimulationBundle 第 23 个袋 `environment`，进 `OPTIONAL_FIELDS`，条目恰好 `{entity_id, sky_id}`，至多一个。**空时省略该键**——这是本章的设计核心，见 §4；
- **三级门禁分工**（不许搞反）：`from_dictionary` 解码**不查目录**（已发布内容必须能按发布时的形状读出来，与 ADR-0006 §1.4 同一条精神）；`TraprushTopologyCompiler.compile` **查**目录，未知 id 或多于一个 `environment` 实体整份返回 `null`；客户端渲染查目录，认不出就回退默认天空；
- **资产**：两张 1024×512 全景入库 `game/content/assets/sky/`，无损 RGB8 + mipmap，`detect_3d/compress_to=0`。烘焙走 `game/tools/assets/bake_panorama.gd`（纯 Godot `Image`，零新依赖），命令与实测数字见[资产烘焙 runbook §4](../runbooks/asset-bake.md)；
- **诚实边界**：`npm run asset-budget` 只扫 `.glb`，独立贴图**不在那条 CI 门禁里**（宪法第二十四条）。替代保障是 `--package-check` 的 `sky_textures_loadable` 与 GUT 字节数断言，两者都不是 PR 的资产预算步骤。

### A2 天空渲染与创作者选择（已交，2026-09-18）

**常审**（纯表现，按 [CD-53 §1.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md) 只写烟测，不给占位表现加强断言）。

- 对局壳、Preview、Editor 三处挂天空。**用 `Camera3D.environment`，不用 `WorldEnvironment`**：TRAPRUSH 的 `SnapshotMap` 与 BASTION 的 `BastionFieldMap` 挂在**同一个 `Window` 的同一个 `World3D`** 上（`match_lobby_chrome.gd` 的 `own_world_3d = true`），挂 `WorldEnvironment` 会连带改掉 BASTION 的画面。`Camera3D.environment` 是 Godot 4.7 类文档里的属性（"The Environment to use for this camera"）；
- 官方课的天空从**本地 AuthoringDocument** 读（客户端本来就在 `match_lobby_director_join.gd` 里按 `document_path` 读那份 JSON），UGC 从 bundle 的 `environment` 袋读；
- **必须显式设定环境光来源**。天空一旦作为背景，默认参与 IBL；占位色块是 `UNSHADED`、地块贴图挂在 `emissive`，都不受影响，但角色 `animal-cat.glb` 走 `baseColor + ORM + normal`，**会被天空环境光改变亮度**。这一项要变成有意的选择并记账，不能装作没发生；
- 编辑器加天空下拉（`OptionButton`，走 `set_component` / `place`），Editor → Preview 跟随按 `preview_patch_levels.gd` 现有分级接，**不新发明补丁等级**；
- locale 文案键在本章加（A1 刻意没加）；
- 已知未排除项：两张源图的**左右接缝**没测过。`PanoramaSkyMaterial` 横向环绕，源图若不是严格等距圆柱投影，接缝处可能断裂。A1 的居中裁只动上下不动左右，没引入新接缝问题，也没排除源图自带的。

### A3 多层官方课 `course_06`（未开工）

**常审**；匹配白名单那一处按深审对待。

- **7 层，`y ∈ {-6, -4, -2, 0, 2, 4, 6}`**，起点在最底层、终点在最顶层，**相隔 6 层**，全部落在 ±8 格出界盒内（`out_of_range_reset.gd` 的 `STUB_HALF`，该盒**含 Y**、以世界原点为中心）；
- **层距必须 2 格，不能 1 格**。层距 1 格时上层地板会直接堵住下层的站立位：地板占 `[k-0.5, k+0.5]`，站在其上的胶囊中心在 `k+0.6875`，而 `k+1` 那格占 `[k+0.5, k+1.5]`，中心落在里面就是 blocked；
- **最底层满铺**，掉下去永远落在地板上、不触发出界重生，代价只是重爬。建议底盘 13×13（x、z ∈ [-6,6]），上层几何收在 ±5 格内，这样任何缝隙掉落都必然接到底盘；
- **6 处竖直转移优先用弹射垫和电梯，少用传送门**。`course_completion_probe.gd` 的动作集只有「8 向走整格 / Jump / UseItem / 等一 tick」，而**跳跃爬不上一整格**（该文件原话：「占位跳跃冲量不够爬一整格，人要靠传送」）；传送门的启发式只允许最多两次中转，6 段全靠传送门会让探针预算耗尽，"可完赛"就从硬结论退化成弱证据；
- **顶层两层不放弹射垫**：`LAUNCH_DY` 峰值约 4 格，在 `y = 6` 起跳会冲到 `y = 10`，越过出界盒直接被重生；
- 实体数约 350–400（现有官方课的 5–6 倍）。**不手写 JSON**，用开发期脚本走真实 `EditCommand` 路径构建 `AuthoringSession` 再 `export_document`，产物过 `content-validator`——课程和创作者用同一条写入路径，不出现"只有生成器能造出来的课"；
- 白名单三处 + 课表行：`official_traprush_courses.gd` 的 `MATCH_IDS`、`backend/contracts/src/official_courses.ts` 的 enum、[CD-21](../../Confirmed-docs/20-gameplay/21-traprush.md) 课表；
- 探针要补一份**手写 route**（照 `course_01` 的 `--route=safe` 先例），让完赛是硬结论；
- `course_06` 必须在 F2 签署前进 `npm run bot-run` 集合与[可玩性签署清单](../runbooks/playability-signoff-traprush.md)。

## 4. A1 最硬的那条证据

`game/tests/unit/test_bastion_blueprint_contract.gd` 有两条金标：`COURSE_01_BUNDLE_DIGEST`（`course_01` 编译产物 `to_dictionary()` 的 SHA-256）与 `SIMULATION_BUNDLE_WIRE_KEYS = 26`。

它们存在的理由是守住已发布内容的 ContentHash（宪法第六条）：开局时 `match_session_bootstrap.gd` 会**重算** `content_hash`，`content_catalog.gd` 拿它与已签名值比对。如果 `to_dictionary()` 无条件多吐一个 `environment: []`，**所有已发布 UGC 一开局就会 hash 不匹配**。

所以第 23 个袋**空时省略**。`course_01` 没有 `environment` 组件，于是这两条断言**一个字未改、继续为绿**。这不是"我们相信没事"，是机械证明。

下一个动 `to_dictionary()` 的人请注意：**其余 22 个袋现在总是 emit，这个行为一个字都不要改**——它们当初的空数组已经进了已发布内容的哈希。

## 5. 本计划不做的事

- 不改 `AuthoringDocument` 的四键、不改 `authoring_document.schema.json`；
- 不新增第四个 EditCommand `op`；
- 不改其余 22 个袋的任何字段或 emit 行为；不动 TRAPRUSH 帧布局；
- 不改 `SimulationCore` 定点合同；不改 `STUB_HALF` 出界盒尺寸（产品级 play range 仍属 [CD-63](../../Confirmed-docs/60-plan/63-open-decisions.md) 延期）；
- 不给 BASTION 加天空（同 `World3D` 的隔离靠 `Camera3D.environment`，见 A2）；
- 不改爆破半径、推击力度、道具重生（D-F4 / D-F5 / D-F6）；不改默认相机距离 / FOV；
- 不开 Web 预设的 VRAM 压缩（那是另一个决策）；
- 不把独立贴图说成已被 `asset-budget` 门禁覆盖；
- 不代签任何人类清单；不把 M5 带走的两处遗留说成已解决；
- 不发明 M8。

## 6. 任务单

```text
里程碑归属：M-Art 插入段（天空盒与多层官方课；排在 M6 F1 之后、F2 之前）
是否绕过 placeholder_spec 散落几何/色板常量：否。天空是语义 id + 贴图路径，
  不含几何与色板；A3 的多层课几何是内容数据，不是代码常量
审查级别：A1 深审（shared/ 契约 + backend/contracts/ Schema + 已发布内容兼容性）；
  A2 常审（表现层，占位表现只写烟测）；A3 常审，匹配白名单那一处按深审
开发机窗口步骤：A1 无可见窗口行为（只有契约与资产入库，第一次有画面是 A2）；
  A2 / A3 交章时整节替换 [开发机窗口验收](../runbooks/dev-window-check.md) 本刀
```
