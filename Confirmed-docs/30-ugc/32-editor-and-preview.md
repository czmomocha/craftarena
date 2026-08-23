# CD-32 编辑器分层与预览

> 文档 ID：CD-32
> 单一事实源：三类编辑入口的能力分层、草稿自动保存与协同租约、编辑到预览的链路与体验指标
> 加载建议：改动编辑器 UI、EditCommand、撤销重做、草稿持久化或 Preview 行为时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第十二条
> 相关：[CD-31 UGC 原则](31-ugc-principles.md)、[CD-33 热修改与热发布](33-hot-publish.md)、[CD-21 TRAPRUSH](../20-gameplay/21-traprush.md)、[CD-22 BASTION](../20-gameplay/22-bastion.md)
> 派生自：初稿 v0.2 §7（草稿与协同部分）、§26、§28

## 1. 共享编辑器框架

项目提供三类编辑入口，但**共用同一个编辑器框架**：草稿、EditCommand、历史、Preview、验证和发布流程统一；TRAPRUSH 与 BASTION 只注册各自的 Schema、验证器、工具面板和可视化。

### 1.1 内部开发编辑器

- Godot Editor Plugin；
- 可访问完整白名单和调试数据；
- 支持批量生成、性能分析和验证器详情；
- 开放完整受限规则图；
- 供开发、策划、测试和 AI Agent 使用。

### 1.2 游戏内创作者编辑器

- 桌面安装版显示白名单对象、完整受限规则图和高级调试；
- 桌面 Web 只提供摆放、移动、调参、传送/路径连接、规则模板/表单和即时预览；
- Android/iOS 一期不提供编辑；
- 支持 Undo/Redo；
- 支持单人即时预览；
- 支持邀请好友进入 Preview Session；
- 不暴露文件系统和脚本。

Web 用模板和表单编辑规则；桌面端开放受限规则图。两者生成**同一套 Rule VM 数据**。

### 1.3 对局准备编辑

- 仅 BASTION 的互设障碍阶段使用；
- 只修改当前对局 `MatchSetupState`；
- 受时间、预算、区域和可达性限制；
- 不进入内容发布系统。

### 1.4 共同数据模型

桌面完整编辑与 Web 轻量编辑交换同一份 `AuthoringDocument` JSON：`schema_version`、`cell`、`revision`、`entities`（实体为 [CD-42 §1.2](../40-technical/42-contracts-and-rulevm.md#12-字段标识符v1) 袋）。表面名（`internal_dev` / `desktop_full` / `web_light`）只约束工具能力，**不**写入文档。两端发出同一套 EDIT `op`。自由规则图编辑器只在 `internal_dev` 与 `desktop_full`；Web 只用规则模板/表单。Rule VM 图格式仍未落地，v1 文档不含规则图。导入文档替换 `AuthoringWorld` 并清空 Undo/Redo；失败整份拒绝。格子与传送图合法性与 `put` / `replace` 相同。Godot `JSON.parse_string` 可能把整数读成整值 float，解码时只接受能 round-trip 回 `int` 的值，入库仍是整数。发布前可达性、预算、3D Preview 映射、SimulationBundle 不是本落点。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

## 2. 草稿持久化与协同

- 每条 EditCommand 立即写本地日志，2 秒防抖上传；
- 每 50 条命令或 5 分钟生成检查点，保留最近 30 个；
- 普通草稿只有一个写入者；
- 获授权的他人可只读 Preview 或复制为独立私有草稿；
- 同账号多设备通过编辑租约互斥；
- 编辑器崩溃后自动恢复最近草稿。

Guest 草稿的云端保留期见 [CD-14](../10-product/14-data-and-telemetry.md)；禁止 Fork 的范围见 [CD-31 §4](31-ugc-principles.md)。

## 3. 从编辑到预览

```text
UI 操作
→ EditCommand
→ AuthoringWorld
→ 增量 Schema 校验
→ 语义 / 引用 / 预算校验
→ 编译受影响子图
→ 独立 Preview 窗口或浏览器标签在安全点应用 Patch
→ 成功：生成新 Revision
→ 失败：完整回滚并定位错误对象
```

当前落点是 `AuthoringSession.try_apply`（`expected_revision` 门禁，失败不写入）以及 `undo` / `redo`（反向 payload）。`AuthoringWorld` 在成功 `put` / `replace` 上执行：

- **网格吸附**：带 `transform` 的实体袋，XYZ 必须落在吸附格上。默认格边 = `Fixed.SCALE`（1 表现米，[ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md)）。偏离格子的命令整份拒绝，不静默取整。无 `transform` 的袋不参与格子。
- **楼层**：楼层索引 = `y / cell`（向零）。`entity_ids_on_floor` 供楼层切换查询；不另锁层高产品数。
- **传送连线**：从 `portal.target_id` 派生有向边，分类为 `two_way` / `one_way` / `dangling`（配对语义见 [CD-21 §4.2](../20-gameplay/21-traprush.md)）。编辑期允许目标尚未存在；禁止自环，禁止指向已存在但没有 `portal` 的实体。不新增第四个 EDIT `op`。
- **发布前可达性**：`AuthoringSession.evaluate_reachability`（`AuthoringReachability.evaluate`）。**不**在 `try_apply` 上跑。编辑期悬空仍合法。发布期拒绝：悬空传送、`one_way` 跟随链回到已访问节点、重复的 `checkpoint.order`、没有任何检查点、以及有序检查点跨楼层且楼层图不可达。同层相邻检查点视为普通通道，不探测走空洞。`two_way` 配对视为落点终止，不是循环。传送链 hop 上限数值仍未锁（[CD-63](../60-plan/63-open-decisions.md)）；本检查用访问集合找环。问题码落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。这是 TRAPRUSH 发布前通路/循环；BASTION 封路与 BotRunner 走路可达不是本落点。
- **共同数据模型**：`AuthoringDocument` 是 AuthoringWorld 的 JSON 快照，桌面与 Web 互换；表面不入库。见 [§1.4](#14-共同数据模型)。
- **Preview Patch**：独立 `AuthoringPreview` 会话。`connect_from` 拷贝当时的 AuthoringWorld；编辑会话保持打开，继续 `try_apply` 不自动进 Preview。`try_apply_patch(level, EditCommand)` 只在安全点（未进入 Preview tick）应用已有 `place` / `remove` / `set_component`，**不**新增第四个 EDIT `op`。成功则 Preview 世界写入且 `preview_revision` +1；失败恢复该次补丁前的拷贝，AuthoringSession 不动。声明等级必须 ≥ 由袋分类出的最低等级（低报拒绝）。P0–P2 可连续应用且不重启；P3 因 Rule VM 未落地而拒绝且不重启；P4 拒绝并 `needs_restart`，须再次 `connect_from`。Preview **永不**结算、评分或在线战绩写。等级定义见 [CD-33 §1](33-hot-publish.md)；袋到等级的映射见下节。
- **Preview 窗口**：`AuthoringPreviewShell` 用代码创建独立 Godot `Window`（非 exclusive、非 transient，不挡住编辑会话）。关闭只隐藏，Preview 会话仍连接。状态标签反映 `connected` / `preview_revision` / `entity_count` / `needs_restart`。浏览器 `tab` 名已保留，本刀 `open_from` 拒绝。不编 SimulationBundle、不映射 3D、不改 `main.tscn`。多人试玩仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

预算仍待。连线可视化、检查点可视化、3D 表现映射不是本落点。

## 4. Preview 行为

- 编辑器保持打开，Preview 在独立窗口或标签运行；
- Preview 持续连接并接收 P0～P3 增量补丁，无法迁移时才自动重启；
- 多人 Preview 中作者可继续编辑并在安全点推送 P0～P3，测试者收到提示；
- 每次修改都有 Revision，可撤销和比较；
- Preview **永不**产生正式结算、评分或在线战绩。

当前数据落点是 `AuthoringPreview`；窗口落点是 `AuthoringPreviewShell`（[CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)）。独立会话、安全点增量 Patch、失败整份回滚、无结算写。桌面打开独立 `Window`；关闭只隐藏。浏览器标签与多人试玩房仍待。v1 袋到补丁等级：

| 最低等级 | 判定 |
|---|---|
| P2 | `place` / `remove`，或 `set_component` 的新旧袋并集含 `transform` / `portal` / `checkpoint` / `zone` / `spawner` / `interactable` / `path_agent` / `build_slot` / `mover` |
| P1 | 并集只落在 `health` / `hazard` / `destructible` / `velocity` / `tower`（可另含 P0 组件） |
| P0 | 并集只落在 `replication` / `team` / `score` / `inventory` |
| P3 | 本刀拒绝（Rule VM 图未落地），不置重启 |
| P4 | 拒绝并要求重新 `connect_from` |

`mover` 整袋算 P2（含 path，属拓扑），不把 `speed` 拆成字段级 P1。声明等级可高于分类（按更安全的点应用），不得低于分类。热修改等级的产品定义见 [CD-33 §1](33-hot-publish.md)，本表不复述公开对局列。

## 5. 初始体验指标

这些是目标值，不是当前已验证的自动门禁。

| 场景 | 目标 |
|---|---|
| P0/P1 修改到本地可见 | ≤ 3 秒 |
| P2/P3 修改到单人预览 | ≤ 10 秒 |
| 修改到 1 服 2 客户端联调 | ≤ 30 秒 |
