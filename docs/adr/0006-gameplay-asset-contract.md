# ADR-0006 GameplayAsset 契约：权威碰撞、占地、挂点与视觉网格的分离

- 状态：**已拍板并落地**（2026-08-29 人类整包采纳推荐，见 §6）
- 日期：2026-08-29
- 归属：[纠偏方案 2026-08](../plans/course-correction-2026-08.md) **C4 第 2 章**（产出 2「`GameplayAsset` 契约」）
- 上位约束：[CD-00](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第三、四、五、六、九、十七、十八、二十六条
- 相关：[CD-31 §5](../../Confirmed-docs/30-ugc/31-ugc-principles.md)、[CD-42 §1.1 / §1.2 / §3.4](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)、[CD-33 §1](../../Confirmed-docs/30-ugc/33-hot-publish.md)、[CD-92](../../Confirmed-docs/90-reference/92-glossary.md)、[CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md)、[资产烘焙试验](../plans/asset-bake-trial-2026-08.md)
- 为什么必须现在拍：改动落在 SimulationBundle Schema，等级 **P4**（[CD-33 §1](../../Confirmed-docs/30-ugc/33-hot-publish.md)），必须在 M4 冻结 Schema、上线签名管线之前完成；越晚做，已发布内容的迁移面积越大

---

## 1. 背景：今天到底是什么状态

### 1.1 承诺

[CD-31 §5](../../Confirmed-docs/30-ugc/31-ugc-principles.md) 写着平台资产走双轨版本：

- 视觉与音效可通过 `latest` 自动更新；
- **碰撞、占地、导航、挂点属于不可变 `GameplayAssetVersion`**；
- GameplayAsset 变化必须生成新内容版本，不能伪装成运行中 P0/P1 补丁。

[CD-92](../../Confirmed-docs/90-reference/92-glossary.md) 已把 `GameplayAssetVersion` 收进术语表。

### 1.2 实现（可验证）

| 事实 | 证据 |
|---|---|
| `GameplayAsset` 在代码里**零实现** | 全仓搜索 `GameplayAsset` / `gameplay_asset` / `asset_id` / `asset_version`：命中 10 个文件，**全部是文档**（`Confirmed-docs/`、`docs/`、`early-docs/` 与 `placeholder_spec.gd` 的注释），GDScript / TypeScript 标识符 0 个 |
| 创作者**已经能声明**权威形状 | [CD-42 §1.2](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md) 的 `zone.shape`：`box` 需 `hx`/`hy`/`hz`，`sphere` 需 `radius`，`capsule` 需 `radius` + `cylinder_height`，`platform_prefab` 需 `prefab_id`；白名单在 `game/src/shared/schema/collision_shape_kinds.gd` |
| 官方内容**确实写了**形状 | `game/content/official/traprush/course_01.json` 实体 30：`zone.shape = {kind: box, hx: 32768, hy: 32768, hz: 32768}` |
| 编译期把形状**丢掉** | `game/src/ugc/traprush_topology_compiler.gd` 只读 `zone.tags`（`_has_finish_tag` / `_has_solid_tag`），从不读 `zone.shape`；7 个袋写出的是 `entity_id` + `x/y/z` 加各自的 `order` / `durability` / `cooldown_ticks` / `kind` |
| Bundle Schema 里**没有形状字段** | `game/src/ugc/simulation_bundle.gd` 逐袋锁死键数：pad = 8、portal = 10、finish = 4、destructible = 5、hazard = 5、solid = 4、pickup = 5。`backend/contracts/schemas/simulation_bundle.schema.json` 同形 |
| 加载期一律 `cell / 2` | `game/src/games/traprush/traprush_topology_loader.gd` L28 `var half: int = bundle.cell / 2`，随后 7 类实体全部 `spawn_static_box(x, y, z, half, half, half)`；文件头自己写着 `Half-extents are cell / 2` |
| 角色胶囊也是占位推导 | `PlaceholderSpec.CHARACTER_RADIUS` / `CHARACTER_HEIGHT` = `Fixed.SCALE / 8`，由 `match_server` 注入 `SimulationWorld` |

### 1.3 结论：这不是"美术还没来"，是一个正确性缺口

**权威碰撞今天等于视觉占位盒，不是有意的设计，而是"编译丢弃 + 加载硬编码"合流的结果。** 由此产生两个独立问题：

1. **创作者声明被静默忽略**。`zone.shape` 通过了 Schema 校验，却不影响任何裁决。今天恰好 `hx = hy = hz = 32768 = cell / 2`，所以看不出来；创作者一旦填 `hx = 16384`，占用不变，无任何报错。宪法第三条要求 UGC 全部经过验证，**被验证却不被采用的字段是更坏的一种不可信**：它让内容作者以为自己控制了某件事。
2. **一期没有"资产"这一层**。碰撞、占地、挂点没有可引用、可版本化的载体，所以 CD-31 §5 的双轨承诺在数据模型里无处落脚；`latest` 视觉更新与不可变玩法几何今天是同一个 1 米盒。

### 1.4 两个必须一起考虑的边界

**回放哈希**：`SimulationWorld.hash_state()`（L466–484）只写 `tick_index` 与每实体 `x/y/z/yaw/vy`。`radius`、`cylinder_height` 与静态 AABB **不入哈希**（文件头 L7 明写）。含义是：

- 改形状**不会**改哈希算法，也不会让同版本对账失败；
- 但会改轨迹，于是**跨版本回放必然分叉**，而分叉时哈希无法指出原因（形状没被记录进去）。
- ⇒ 形状必须绑定到一个**不可变版本标识**，否则旧回放不可自证。这正是宪法第六条要 `GameplayAssetVersion` 的原因。

**扫掠代价**：`SimulationWorld._sweep_step_count(length, radius)`（L652–658）用 `radius` 当采样步长。半径越小，单次移动的采样次数越多，**当前没有上限**（已登记的宪法第十七条缺口）。⇒ 任何允许创作者自由填写小半径的方案都直接变成 CPU 攻击面，必须在同一次决策里堵住。

---

## 2. 本 ADR 要决定什么

一个契约，六个问题。**Q1 是主问题**，Q2–Q6 是它的必要配套；建议整包拍板，避免出现"选了载体但没定语义"的半成品。

### Q1 — 权威几何由什么承载（主问题）

| 选项 | 形状放哪 | 变更面 | 代价 / 风险 |
|---|---|---|---|
| **A 内联到实体袋** | 每个袋加 `shape_kind` + `hx/hy/hz`（或 `radius`），编译期从 `zone.shape` 透传 | Bundle v2；compiler 读 shape；loader 读袋 | 最小、自证。但**没有资产层**：CD-31 §5 的双轨版本仍无落脚点，视觉/玩法仍靠 1 格 = 1 米隐式对齐；同一种箱子的尺寸在 N 个实体上重复 N 遍，改一次要重编译全部内容 |
| **B（推荐）资产表 + 引用** | Bundle 新增 `assets` 袋：`asset_id` → `{ gameplay_version, collision{kind,dims}, footprint, attach_points }`；实体袋只加 `asset_id` + `gameplay_version` | Bundle v2；新组件 `gameplay_asset`；compiler；loader；两份 JSON Schema；正反例 | 中等。换来：玩法几何**自证且去重**、`GameplayAssetVersion` 有真实字段、视觉不进 bundle（走 `latest`）、创作者只能挑 `asset_id` 从而天然堵住 §1.4 的扫掠攻击面 |
| **C 纯代码注册表** | `asset_id` 进 bundle，几何留在程序内置表 | Bundle v2（只加 id）；新增 registry | wire 最小，但**违反宪法第六条精神**：已发布内容的玩法几何会随程序版本漂移，旧回放不可信；且"不可变版本"变成口头承诺 |
| **D 推迟到 M4** | 不动 | 0 | 直接否掉 C4 的存在理由。M4 要冻结 Schema 并上签名，届时改形状就是**破坏性迁移已签名内容**；且冻结期每多一章就多一批 `cell / 2` 断言 |

### Q2 — 占地（footprint）是否独立于碰撞

CD-31 §5 把"碰撞"与"占地"并列成两项，今天两者都是同一个 `cell / 2` 盒。

| 选项 | 含义 |
|---|---|
| **A（推荐）** | 一期**占地 = 碰撞 AABB 在格网上的投影**，不新增字段；契约里写明它是派生量，等 BASTION 的 `build_slot` 需要"占几格"时再独立 |
| B | 立刻独立成 `footprint{ cells_x, cells_z }`，与碰撞解耦 |

选 A 的代价：CD-31 §5 的"占地"字面上暂时没有独立字段，须在所有者文档写明"一期派生"。选 B 的代价：BASTION 已冻结（§1.1 冻结令），需求无处验证，属于宪法第八条禁止的"先优化"。

### Q3 — 挂点（attach points）一期做到什么程度

一期没有动画、没有炮口、没有特效挂载（D8 已定不做描边；音频只定清单）。

| 选项 | 含义 |
|---|---|
| **A（推荐）** | 契约**留字段位**：`attach_points` 为具名点数组（`name` + 定点 `dx/dy/dz`），一期允许为空，验证器只校验形状与重名，仿真不消费 |
| B | 一期完整实装（需要先定动画状态契约，属 C4 第 4 章） |
| C | 本期不含挂点，同时修改 CD-31 §5 的承诺范围 |

### Q4 — 视觉网格在哪解析

| 选项 | 含义 |
|---|---|
| **A（推荐）** | 视觉**完全不进 bundle**：客户端按 `asset_id` 在本地资产目录解析当前 `latest`。视觉改动因此不产生新内容版本（这正是 C4 验收条"改一次视觉不产生新内容版本"） |
| B | Bundle 记录视觉引用 + 版本，客户端按记录取 | 视觉更新会污染 ContentHash，与 CD-31 §5 的 `latest` 双轨相矛盾 |

### Q5 — 创作者能不能自填尺寸

| 选项 | 含义 |
|---|---|
| **A（推荐）** | 不能。一期资产表 = **平台内置清单**，创作者只能选 `asset_id`。理由：宪法第三条（UGC 不可信）+ §1.4 扫掠代价无上限 + 宪法第十七条（预算必须有上限） |
| B | 可以，但加上下限与预算校验 | 需要先有扫掠代价上限，属于本 ADR 之外的性能工作 |

选 A 后 `zone.shape` 的定位需要一并说明：它**回归 CD-42 §1 的原意「触发与查询区域」**，不再被当作权威碰撞使用。今天 `finish` / `solid` 的占用箱正是"zone 语义被当碰撞用"的产物。

### Q6 — v1 内容怎么迁移

[CD-31 §6](../../Confirmed-docs/30-ugc/31-ugc-principles.md) 承诺"当前 Schema 和前两个版本自动迁移"。

| 选项 | 含义 |
|---|---|
| **A（推荐）** | 保留 v1 解码，迁移规则写死一条：**v1 视为"全部实体引用同一个内置 1 米盒资产"**，等价于今天的行为。三张官方赛道 JSON 是 AuthoringDocument（不是 bundle），可原地补 `gameplay_asset` 组件，也可依赖同一条默认规则 |
| B | 只支持 v2，重新导出全部内容 | 一期内容只有 3 张官方课，成本可接受，但会先违背 CD-31 §6 |

---

## 3. 推荐方案（整包）

**Q1 = B，Q2 = A，Q3 = A，Q4 = A，Q5 = A，Q6 = A。**

形态草案（**字段名待拍板后才写进所有者文档**，此处只为让人类判断代价）：

```text
新组件（Component Schema）  gameplay_asset { asset_id ≥ 1, gameplay_version ≥ 1 }

SimulationBundle v2 新增袋  assets[] {
  asset_id, gameplay_version,
  collision { kind ∈ box|sphere|capsule|platform_prefab, 定点尺寸 },
  attach_points[] { name, dx, dy, dz }      # 一期可空
}
7 个既有袋各加两字段        asset_id, gameplay_version
占地                        由 collision 的 AABB 投影派生，不落字段
视觉网格                    不进 bundle；客户端按 asset_id 取 latest
```

选它的理由：

- **玩法几何自证**。已发布内容自己带着裁决用的形状与版本号，旧回放不依赖"当时程序里那张表长什么样"（选项 C 的致命伤）。
- **一次改动堵三个洞**。创作者声明被忽略（§1.3 第 1 条）、双轨版本无落脚点（§1.3 第 2 条）、扫掠代价可被内容放大（§1.4）——都由"只能引用平台资产"这一条同时解决。
- **不引入新架构**。`assets` 袋与既有 7 个袋同形（纯数据字典 + 键数校验），沿用现成的 `from_dictionary` 校验风格，不需要新目录、新层、新依赖。
- **视觉可以自由迭代**。视觉不进 bundle ⇒ 美术改模型不产生内容版本，正对 C4 的验收条。

---

## 4. 影响面（供人类判断代价，非实现清单）

| 位置 | 变更 |
|---|---|
| `game/src/ugc/simulation_bundle.gd` | `SCHEMA_VERSION` 1 → 2；新增 `assets` 袋解析；7 个 `_parse_*` 的键数断言全部 +2 |
| `game/src/ugc/traprush_topology_compiler.gd` | 收集资产表；读 `gameplay_asset` 组件；不再忽略几何 |
| `game/src/games/traprush/traprush_topology_loader.gd` | `half = bundle.cell / 2` 改为按 `asset_id` 取半长（**这是 §5.1 冻结清单里 `cell/2` 那一行的正式退场点**） |
| `game/src/shared/schema/component_names.gd` + `component_record.gd` | 新增组件名与校验（当前 18 个组件名） |
| `backend/contracts/schemas/simulation_bundle.schema.json`、`component_record.schema.json`、`authoring_document.schema.json` | 同步；**属 `backend/contracts/` ⇒ 深审 + 宪法第十八条门禁** |
| `tools/content-validator/fixtures/simulation_bundle/` | 现有 5 个正例 / 17 个反例需扩；新增"引用不存在的 `asset_id`""`asset_id` 重复""形状 kind 非白名单"等反例 |
| `game/content/official/traprush/course_0{1,2,3}.json` | 按 Q6 决定：补 `gameplay_asset` 组件，或依赖 v1 默认迁移 |
| GUT 用例 | 25 个测试文件触及 `SimulationBundle` / compiler / loader（当前 110 个单测文件、1076 个用例）。占用相交断言会成批变动 |
| 所有者文档 | CD-42 §1.2 / §3.4、CD-31 §5、CD-33（P4 标注）、CD-92；按纠偏 §7 在 C5 一次性同步，并在 CD-91 留痕 |

**诚实边界**：一期 bundle **尚未签名**（CD-42 §3.4 末尾"签名二进制包仍待"）。所以拍板后得到的"不可变 `GameplayAssetVersion`"在一期只是 JSON 字段 + `source_revision` 约定，**不是密码学不可变**。不得对外表述为已具备内容签名。

---

## 5. 不在本 ADR

- **导航**：CD-31 §5 的四项里还有"导航"。一期无导航网格、无寻路，BASTION 的 `path_agent` 随 M6/M7 冻结，没有可验证对象（宪法第八条）。契约里不留导航字段，须在所有者文档同步时写明"一期不含导航，解冻 BASTION 时重开"；
- 具体美术预算数值（面数 / 贴图 / 体积）：[CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 未决，输入材料见[资产烘焙试验](../plans/asset-bake-trial-2026-08.md)；
- 资源目录约定与导入规范、性能预算表：C4 第 3 章；
- 动画状态契约：C4 第 4 章（Q3 选 A 时本 ADR 只留字段位）；
- 第一批 `.glb` 入库与 LFS：C4 第 5 章；
- 本地化键：C4 第 6 章；
- 相机 45° 与 UI 1920×1080 接线（D4 已拍板、尚未接线）；
- Rule VM、内容签名、发布管线、热生效：M4，仍在[冻结](../plans/course-correction-2026-08.md)中；
- 扫掠采样代价上限本身（宪法第十七条缺口）：本 ADR 只通过"创作者不能自填尺寸"避免内容放大它，不解决上限缺失。

---

## 6. 选定

**选项：整包采纳 §3 推荐**（2026-08-29，人类）。

```text
Q1 载体      B（资产表 + 引用）    Q2 占地   A（由碰撞 AABB 派生）
Q3 挂点      A（只留字段位）        Q4 视觉解析 A（不进 bundle，客户端取 latest）
Q5 自填尺寸  A（不能，只能选 id）   Q6 迁移   A（保留 v1 解码，迁移到内置一格资产）
```

所有者文档：字段清单在 [CD-42 §1.2 / §3.4](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)，四项分离的承诺在 [CD-31 §5](../../Confirmed-docs/30-ugc/31-ugc-principles.md)，等级标注在 [CD-33 §1](../../Confirmed-docs/30-ugc/33-hot-publish.md)，来源行在 [CD-91](../../Confirmed-docs/90-reference/91-decision-log.md)。

## 7. 落地状态（2026-08-29）

| # | 项 | 状态 |
|---|---|---|
| 1 | ADR 状态与 CD-91 来源行 | 已做 |
| 2 | 平台内置资产目录 `game/src/shared/schema/gameplay_asset_catalog.gd` | 已做（一条内置资产：占满一格，`asset_id = 1` / `gameplay_version = 1`） |
| 3 | 新组件 `gameplay_asset`（第 19 个组件） | 已做 |
| 4 | Bundle v2：`assets` 袋 + 7 个袋各加 `asset_id` / `gameplay_version` | 已做 |
| 5 | 编译期准入（只认目录里登记的 id 与当前版本） | 已做 |
| 6 | 加载期按资产取半长，`half = cell / 2` 退场 | 已做 |
| 7 | v1 解码 + 迁移到内置一格资产 | 已做，并有"占用逐字节不变"的守门用例（含非默认 `cell`） |
| 8 | 两份 JSON Schema + `SIMULATION_BUNDLE_SCHEMA_VERSION = 2` | 已做；碰撞形状定义跨文件 `$ref` 到 `component_record.schema.json`，不抄第二份 |
| 9 | 内容验证器正反例 | 已做：bundle 22 → 29（新增 6 反例 + 1 正例），组件 +1 正 +1 反 |
| 10 | GUT | 已做：`game/tests/unit/test_gameplay_asset_contract.gd`，1100 用例全绿 |
| 11 | 所有者文档同步 | 已做（不等 C5，理由见下） |
| 12 | 换一次角色视觉，验证 `latest` 语义（2026-09-01） | 已做：`robot_placeholder.glb`（0.74 × 1.03 × 0.61 m）→ `char_runner_base.glb`（0.749 × 1.134 × 0.417 m），只改 `CHARACTER_SCENE_PATH` 一个常量。**没有**产生新内容版本、**没有**改 ContentHash、**没有**动权威碰撞——这正是 Q4 = A 要的效果。旧资产留着不删但已无任何引用。GUT 1153/1153 全绿，其中本 ADR 的分离断言（视觉尺寸 ≠ 权威胶囊 ≠ 占位盒）**一条没改**仍然通过：它们断言的是关系不是尺寸，所以换模型不需要改测试 |

**为什么不等 C5 同步所有者文档**：[纠偏 §7](../plans/course-correction-2026-08.md) 让 CD-42 / CD-31 / CD-33 的行留到 C5 一次性做，但宪法第十九条要求"Schema 变化时同一任务必须更新对应的所有者文档"。Bundle v1→v2 与新组件是结构性 Schema 事实，不是可调参数，且属 P4。按 2026-08-27 D11 的同一口径（安全边界类变更当场写入），本章直接同步，不留到 C5。

### 仍然没做（不因本章消失）

- **一期 bundle 未签名**，所以"不可变 `GameplayAssetVersion`"目前只是 JSON 字段 + 编译期准入，**不是**密码学不可变（CD-42 §3.4 末尾"签名二进制包仍待"）；
- **角色胶囊还不是资产**：`PlaceholderSpec.CHARACTER_RADIUS / CHARACTER_HEIGHT` 仍是 D4 占位常量，不在资产表里。玩家不进 bundle，接线要另开一章。C4 第 5 章换掉的是角色的**视觉**，不是它的权威碰撞；
- **只有 box 有权威实现**：sphere / capsule / platform_prefab 在 Schema 层白名单内，加载层直接拒；
- **扫掠采样代价仍无上限**（宪法第十七条缺口）：本章只用"创作者不能自填尺寸"避免内容放大它；
- **`asset_id → 视觉` 的按资产解析仍未实装**：一期唯一内置资产被 7 类袋共用，按 `asset_id` 接视觉会让终点、检查点垫与箱子共用同一个模型。C4 第 5 章接的是**袋类型**（`solids` 袋 = 踩得到的固体，属玩法语义），不是资产身份。等内容能区分资产后另开一章，届时加的是一张表，不改调用方。理由写在 `game/src/shared/visual_asset_catalog.gd` 文件头。

### 2026-08-30 更新（C4 第 5 章）：视觉与碰撞的数值差异已经成立

本 ADR 原先只能声明"结构已分离、数值今天仍相等，不要对外表述为已经用上了不同的视觉与碰撞"。第一批 `.glb` 入库后这条边界**已经解除**：

| | 值 | 谁决定 |
|---|---|---|
| 角色视觉网格 | 0.74 × 1.03 × 0.61 m | `SharedVisualAssetCatalog`，`latest`，改了不产生内容版本 |
| 地块视觉网格 | 源 1.84 m 见方，等比缩到一格宽的薄板 | 同上；缩放由资产自身 AABB 推出 |
| 权威胶囊 | 半径 / 高各 0.125 格 | `PlaceholderSpec`（D4 占位常量，仍不是资产） |
| 权威静态半长 | `cell / 2`，来自 bundle 的 `assets` 袋 | 已发布内容自带（本 ADR §7 第 6 项） |
| 占位盒 | 1 米立方 | `PlaceholderSpec.BOX_SIZE`，视觉解析失败时的回退 |

有 GUT 用例（`game/tests/unit/test_character_visual_asset.gd`）断言这些不等关系，断言视觉**没有**进 `assets` 袋（键数仍为 4），并断言固体的 `live_solid_boxes()` 半长在铺上地块后**逐项不变**——视觉换了不改裁决。

**耦合方向是单向的**：地块视觉对齐的是它替换掉的占位盒，不是权威 AABB。视觉不读裁决数据（Q4 = A），哪怕两者今天数值相同。
