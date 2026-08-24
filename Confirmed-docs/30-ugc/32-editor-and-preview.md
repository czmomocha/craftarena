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

当前窗口落点是 `AuthoringEditorShell`：代码创建独立 Godot `Window`（非 exclusive、非 transient），只发已有 EDIT `op`。关闭只隐藏，会话保持。打开 Preview 拷贝当时的 AuthoringWorld，之后每次成功写入（含 Undo / Redo）把同一条 EDIT `op` 按分类等级转发为安全点补丁，Preview 跟随编辑。Editor 窗口 `own_world_3d = true`，挂同一套 `AuthoringPreviewMap`，按 **AuthoringWorld** 重建 1 米占位盒与 gizmos。`TraprushEditorPanel` 挂在共用外壳上，提供检查点、传送门、删除最后实体与楼层切换；不新增第四个 EDIT `op`。`AuthoringValidatorPanel` 列出只读 `evaluate_reachability` 问题码；Focus 把 Editor 相机对到有 `transform` 的实体。叠加不是写入门禁。跟随失败不回滚编辑写入。BASTION 面板仍待。`game/addons/authoring_editor/` 注册 EditorPlugin：Project > Tools > Authoring Editor 打开同一套 `AuthoringEditorShell`。关闭只隐藏，会话保持。不改 `main.tscn`，不编 SimulationBundle，不写入 `_mcp_game_helper`，不把 `godot_ai` 写入已提交插件列表。草稿磁盘读写在 `@tool` 的 `plugin.gd` 内完成（Godot 把插件用到的非 `@tool` 脚本当成空文件，`AuthoringDraftStore.record` 在编辑器里不会落盘）。外壳成功写入后发 `world_committed`；空会话打开时由插件读回 `user://authoring_draft.json`。状态栏 `draft` / `disk` 标明 store 是否挂上、上次落盘是否成功。F6 沙箱不挂草稿。2 秒云端上传、5 分钟定时、多写者租约仍待。批量生成、性能分析面板仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

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

桌面完整编辑与 Web 轻量编辑交换同一份 `AuthoringDocument` JSON：`schema_version`、`cell`、`revision`、`entities`（实体为 [CD-42 §1.2](../40-technical/42-contracts-and-rulevm.md#12-字段标识符v1) 袋）。表面名（`internal_dev` / `desktop_full` / `web_light`）只约束工具能力，**不**写入文档。两端发出同一套 EDIT `op`。自由规则图编辑器只在 `internal_dev` 与 `desktop_full`；Web 只用规则模板/表单。Rule VM 图格式仍未落地，v1 文档不含规则图。导入文档替换 `AuthoringWorld` 并清空 Undo/Redo；失败整份拒绝。格子与传送图合法性与 `put` / `replace` 相同。Godot `JSON.parse_string` 可能把整数读成整值 float，解码时只接受能 round-trip 回 `int` 的值，入库仍是整数。官方赛道以同一份 AuthoringDocument 落在 `game/content/official/`；两张 TRAPRUSH 赛道已入库。第三张仍待。`AuthoringDocument.load_from_path` 读盘。预算、走路可达、SimulationBundle 不是本落点。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

## 2. 草稿持久化与协同

- 每条 EditCommand 立即写本地日志，2 秒防抖上传；
- 每 50 条命令或 5 分钟生成检查点，保留最近 30 个；
- 普通草稿只有一个写入者；
- 获授权的他人可只读 Preview 或复制为独立私有草稿；
- 同账号多设备通过编辑租约互斥；
- 编辑器崩溃后自动恢复最近草稿。

当前落点是 `AuthoringDraftStore`：每次成功写入（`try_apply` / Undo / Redo / `import_document`）把最新 AuthoringDocument 记为 `latest`，并按每 50 条（第 1 条也记）追加检查点、最多保留 30 个。文件在 `user://authoring_draft.json`，拒绝写入 `res://`。Headless / GUT 由 store 落盘；Godot 编辑器由 `@tool` `plugin.gd` 响应 `world_committed` 落盘并在空会话打开时读回。损坏或多余键整份拒绝，不覆盖内存世界。工具条 `adopt_world`。F6 沙箱不启用。不是新 `op`，不结算。2 秒防抖上传、5 分钟定时检查点、云端租约仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

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

当前落点是 `AuthoringEditorShell` 把 UI 操作变成 `AuthoringSession.try_apply`（`expected_revision` 门禁，失败不写入）以及 `undo` / `redo`（反向 payload）。`AuthoringWorld` 在成功 `put` / `replace` 上执行：

- **网格吸附**：带 `transform` 的实体袋，XYZ 必须落在吸附格上。默认格边 = `Fixed.SCALE`（1 表现米，[ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md)）。偏离格子的命令整份拒绝，不静默取整。无 `transform` 的袋不参与格子。
- **编辑外壳**：`AuthoringEditorShell` 用代码创建独立 `Window`。格子坐标 × `cell` 后走已有 `place` / `remove`。关闭只隐藏。`open_preview` 按当时世界 `connect_from`，并把跟随打开。EditorPlugin 从 Project > Tools 打开同一套外壳。F6 沙箱见 [§1.1](#11-内部开发编辑器)。
- **编辑 3D 表现映射**：同一套 `AuthoringPreviewMap` 挂在 Editor `Window` 上（`own_world_3d = true`）。按 **AuthoringWorld** 重建，不是 Preview 快照。每次 `try_apply` / `undo` / `redo` / `import_document`（成功或失败）都按当前编辑世界重建节点树。失败写入不留幽灵盒。占位盒是表现桩，不是碰撞体。要看盒子必须 **F6 运行当前场景**。
- **编辑写入自动进 Preview**：成功的 `try_apply` / `undo` / `redo` 把同一条 EDIT `op`（Undo/Redo 用会话已派生的反向 / 正向 payload）转发给已连接的 `AuthoringPreview`。声明等级 = 按 **Preview 世界** 算出的 `PreviewPatchLevels.classify`，不是写入后的编辑世界——`set_component` 的等级取决于被打补丁那一侧的旧袋，按编辑世界算会低报并被 Preview 拒绝。转发用的 `expected_revision` 是写入前的编辑世界 revision，两个世界因此保持同一计数。失败的写入不转发。转发被拒（revision 不齐、越界补丁、`needs_restart`）只把跟随置为脱同步并停止转发，**不**回滚已经成立的编辑写入；恢复跟随要重新 `open_preview`。`import_document` 是整份替换而不是补丁，成功后一律脱同步。Preview 窗口隐藏不影响跟随。状态栏 `follow` 标明当前是否跟随。目视路径：F6 跑 `res://src/creator/editor_sandbox.tscn`，先按 Preview 再继续 Place，新占位盒当场出现在 Preview 窗口。不是新 `op`，不结算。这条链路服务 [§5](#5-初始体验指标) 的预览时延目标，但那些数字仍是目标值，不是已测门禁。
- **TRAPRUSH 拓扑编译**：`TraprushTopologyCompiler` 把 AuthoringWorld 编成 v1 `SimulationBundle` JSON（`schema_version` / `cell` / `source_revision` / `pads` / `portals` / `finish`）。整份世界一次编完，不是增量子图。检查点必须有 `transform`，否则整份拒绝。`dangling` 传送省略，不失败。`two_way` / `one_way` 的落点取目的实体 `transform`；源点占用坐标取源实体 `transform`，缺则整份拒绝。传送袋含 `x` / `y` / `z`（源点）与 `dest_x` / `dest_y` / `dest_z` / `dest_yaw_bam`。`finish` 是 0 或 1 个终点占用袋（`entity_id` / `x` / `y` / `z`）：`zone.tags` 含 `finish` 且有 `transform` 的实体编进去；缺 transform、两份终点、或终点与检查点/传送同实体则整份拒绝。占用半长仍由格子 `cell / 2` 推导，不把 zone 形状锁成占用尺寸。`TraprushTopologyLoader.try_load` 把检查点垫、传送源点和终点生成为非固体静态盒，传送写入 `TraprushPortalGraph`。加载器不生成玩家，不 tick，不编 Rule VM，不签二进制，不结算，不是新 `op`。官方两张赛道必须能编能加载。走路可达与预算仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。
- **Preview 试玩**：安全点 `AuthoringPreview.try_start_play` 把当前 Preview 世界全量编成 v1 SimulationBundle，加载进 SimulationWorld，在最小 `order` 检查点垫（平手取更小 `entity_id`）加上 `respawn_dx/dy/dz` 生成胶囊。胶囊半径/高度由调用方传入，不锁产品尺寸。开玩进入 tick，补丁拒绝直到 `try_stop_play`。`try_advance_play` 只推进仿真 tick，不应用 Rule VM、不结算。`try_apply_play_intent` 只接受已有 `MoveIntent`（调用方 `dx`/`dz`，不发明默认速度），经 `TraprushIntentStepper` 改胶囊 XZ，不调用 tick。空垫或编译失败拒绝开玩，会话保持连接。`AuthoringPreviewShell` 提供 Play / Stop；开玩且窗口可见时把 WASD（`move_forward` / `move_back` / `move_left` / `move_right`）按世界方向编成同一条 MoveIntent。`play_move_step` 默认 `Fixed.SCALE / 16`，是表现桩，不是产品速度，也不是 Tick Hz。窗口隐藏不停玩、不采样键盘；直接 `try_apply_play_intent` 仍可。开玩后占用由 Preview 观察：胶囊与检查点垫相交才经已有 `TraprushPadAccept` 推进有序进度，不是客户端完成断言。起点垫在开玩时若相交即验收；`MoveIntent` 之后再扫重叠垫。`try_accept_play_checkpoint` 可按实体 id 显式验收。胶囊与传送源点占用盒相交才经已有 `TraprushPortalLanding.try_land_exit` 单跳落地（`two_way` 的 dest 也是 portal source，`follow` 会当环拒绝，Preview 不走 `follow`）。落地后门闩 dest 体积直到胶囊离开，避免 paired 往返弹跳。出口被占用则本次等待、本帧不再走 MoveIntent。传送只改姿态，不代验收检查点；跳点仍由 PadAccept 拒绝。全部强制检查点完成后，胶囊与终点占用盒相交才经已有 `TraprushFinishAccept.try_cross` 记 `finish_tick`（权威 `world.tick_index`，未冲线为 -1）；无 FinishIntent，不是客户端冲线断言。传送不代冲线。状态栏 `pads=n/m`、`floor=n`（`y / cell` 向零，与楼层查询同一口径）与 `finish=n`；已验收检查点标记加 `*`。`AuthoringPreviewMap` 把玩家姿态画成 1 米表现桩，不是碰撞体。开玩期间编辑写入转发失败只脱同步，不回滚编辑、不停玩。不接 Jump / Shove / 重置，不锁重力，不接多人试玩、不签二进制。官方两张赛道必须能开玩、走过传送、验收上层检查点并走进终点占用盒冲线。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。
- **TRAPRUSH 工具面板**：`TraprushEditorPanel` 挂在共用 `AuthoringEditorShell` 上。检查点 / 传送门 / 删除最后实体走已有 `place` / `remove`。连续两次 Place portal 把悬空对成 `two_way`。Floor up/down 只改下一次 place 的 `cell_y`，不写世界。不是 BASTION 面板。插件只打开外壳，不新增 `op`。
- **验证器详情**：`AuthoringValidatorPanel` 只读 `evaluate_reachability`，列出已有问题码。Focus 把 Editor 相机对到有 `transform` 的实体。`missing_mandatory_path` 无实体可标，只进列表。不是写入门禁。不是新 `op`。
- **第一张官方赛道**：`game/content/official/traprush/course_01.json` 是一份发布检查通过的 AuthoringDocument：同层检查点加跨层 `two_way` 传送对（纯竖直，z=0），上层另有 `zone.tags` 含 `finish` 的终点占用实体。由 `AuthoringDocument.load_from_path` 读入，编辑外壳 `import_document` 后验证器空列表。不是新 `op`，不是写入门禁。F6 沙箱 `res://src/creator/course_sandbox.tscn` 只供目视。`editor_sandbox.tscn` 仍种悬空传送，供验证器目视。
- **内部开发 EditorPlugin**：`game/addons/authoring_editor/plugin.cfg` 启用后，Project > Tools > Authoring Editor 调用 `AuthoringEditorPluginHost` 打开已有 `AuthoringEditorShell`。只发已有 EDIT `op`。禁用插件时 `_exit_tree` 卸菜单并 `detach`。不是新 `op`，不是写入门禁，不结算。BASTION 面板、批量生成与性能分析仍待。F6 沙箱仍是退路。
- **本地草稿恢复**：`AuthoringDraftStore` 保存 `latest` 与最多 30 个检查点。编辑器里由 `@tool` 插件落盘/读回；GUT 仍走 store。空会话恢复后同步工具条 id。失败写入不改草稿。损坏文件拒绝。不是新 `op`，不结算，不写 `res://content/`。2 秒上传与 5 分钟定时仍待。
- **第二张官方赛道**：`game/content/official/traprush/course_02.json` 是一份发布检查通过的 AuthoringDocument：同层检查点加跨层且侧向（+Z）的 `two_way` 传送对，上层另有 `zone.tags` 含 `finish` 的终点占用实体。与第一张布局不同。由 `AuthoringDocument.load_from_path` 读入，编辑外壳 `import_document` 后验证器空列表。不是新 `op`，不是写入门禁。第三张赛道仍待。F6 沙箱 `res://src/creator/course_02_sandbox.tscn` 只供目视。
- **楼层**：楼层索引 = `y / cell`（向零）。`entity_ids_on_floor` 供楼层切换查询；不另锁层高产品数。
- **传送连线**：从 `portal.target_id` 派生有向边，分类为 `two_way` / `one_way` / `dangling`（配对语义见 [CD-21 §4.2](../20-gameplay/21-traprush.md)）。编辑期允许目标尚未存在；禁止自环，禁止指向已存在但没有 `portal` 的实体。不新增第四个 EDIT `op`。
- **发布前可达性**：`AuthoringSession.evaluate_reachability`（`AuthoringReachability.evaluate`）。**不**在 `try_apply` 上跑。编辑期悬空仍合法。发布期拒绝：悬空传送、`one_way` 跟随链回到已访问节点、重复的 `checkpoint.order`、没有任何检查点、以及有序检查点跨楼层且楼层图不可达。同层相邻检查点视为普通通道，不探测走空洞。`two_way` 配对视为落点终止，不是循环。传送链 hop 上限数值仍未锁（[CD-63](../60-plan/63-open-decisions.md)）；本检查用访问集合找环。问题码落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。这是 TRAPRUSH 发布前通路/循环；BASTION 封路与 BotRunner 走路可达不是本落点。
- **共同数据模型**：`AuthoringDocument` 是 AuthoringWorld 的 JSON 快照，桌面与 Web 互换；表面不入库。见 [§1.4](#14-共同数据模型)。
- **Preview Patch**：独立 `AuthoringPreview` 会话。`connect_from` 拷贝当时的 AuthoringWorld；编辑会话保持打开，后续成功写入由外壳转发进来（见上一条）。`try_apply_patch(level, EditCommand)` 只在安全点（未进入 Preview tick）应用已有 `place` / `remove` / `set_component`，**不**新增第四个 EDIT `op`。成功则 Preview 世界写入且 `preview_revision` +1；失败恢复该次补丁前的拷贝，AuthoringSession 不动。声明等级必须 ≥ 由袋分类出的最低等级（低报拒绝）。P0–P2 可连续应用且不重启；P3 因 Rule VM 未落地而拒绝且不重启；P4 拒绝并 `needs_restart`，须再次 `connect_from`。Preview **永不**结算、评分或在线战绩写。等级定义见 [CD-33 §1](33-hot-publish.md)；袋到等级的映射见下节。
- **Preview 窗口**：`AuthoringPreviewShell` 用代码创建独立 Godot `Window`（非 exclusive、非 transient，不挡住编辑会话）。关闭只隐藏，Preview 会话仍连接。状态标签反映 `connected` / `preview_revision` / `entity_count` / `needs_restart` / `playing` / `pads` / `floor` / `finish` / `reach_ok` / 问题条数。Play / Stop 与 WASD MoveIntent、检查点占用、传送占用、冲线占用见上一条「Preview 试玩」。浏览器 `tab` 名已保留，本刀 `open_from` 拒绝。不改 `main.tscn`。多人试玩仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。
- **Preview 3D 表现映射**：`AuthoringPreviewMap` 挂在 Preview `Window` 上（`own_world_3d = true`）。只把带 `transform` 的实体画成 1×1×1 米 `BoxMesh` 占位；无 `transform` 的袋跳过。位置 = `float(fixed) / float(Fixed.SCALE)` 米，`yaw_bam` / `Fixed.BAM_TURN` → `rotation.y` 弧度（[ADR-0005](../../docs/adr/0005-fixed-point-numeric-model.md)）。权威仍是 Preview 世界的 Q48.16；浮点只出现在 creator 表现边界。每次 `try_apply_patch`（成功或失败回滚）都按当前 Preview 世界重建节点树。占位盒是表现桩，不是碰撞体或玩法尺寸。F6 沙箱 `res://src/creator/preview_sandbox.tscn` 只供目视，不进 CI。要看盒子必须 **F6 运行当前场景**，不要只在编辑器视口里打开 `.tscn`，也不要用 F5 跑主场景。
- **Preview 传送连线可视化**：同一套 `AuthoringPreviewMap` 按 `portal_links()` 分类画 gizmo。`two_way` / `one_way` 在源与目标的 `transform` 之间画线段（`one_way` 另有方向标）；`dangling` 只在源点上方打标，**不**把悬空画到原点。无 `transform` 的 portal 不画。线段厚度与颜色是表现桩，不是碰撞体。
- **Preview 检查点顺序可视化**：同一套 `AuthoringPreviewMap` 把带 `transform` 的 `checkpoint` 标上 `order`。唯一 `order` 按升序连线（与发布前重复分组同一口径：重复 `order` 仍打标但不进入顺序链）。无 `transform` 的检查点不画。
- **Preview 可达性叠加**：同一套 `AuthoringPreviewMap` 在 rebuild 时只读 `evaluate_reachability`，把已有问题码标到带 `transform` 的实体上。`unreachable_checkpoint` 另画跨楼层断段。`missing_mandatory_path` 无实体可标，只进状态。叠加**不是**写入门禁，失败 Patch 仍整份回滚。走路可达与 BotRunner 不是本落点。

预算仍待。走路可达不是本落点。

## 4. Preview 行为

- 编辑器保持打开，Preview 在独立窗口或标签运行；
- Preview 持续连接并接收 P0～P3 增量补丁，无法迁移时才自动重启；
- 多人 Preview 中作者可继续编辑并在安全点推送 P0～P3，测试者收到提示；
- 每次修改都有 Revision，可撤销和比较；
- Preview **永不**产生正式结算、评分或在线战绩。

当前数据落点是 `AuthoringPreview`；窗口落点是 `AuthoringPreviewShell`；3D 表现、传送连线、检查点顺序、可达性叠加与试玩玩家标记的 gizmos 落点是 `AuthoringPreviewMap`（[CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)）；把编辑写入转发进来的是 `AuthoringEditorShell`（见 [§3](#3-从编辑到预览)「编辑写入自动进 Preview」）；把拓扑编译接到试玩的是 `AuthoringPreview.try_start_play`，把 WASD / MoveIntent 接到胶囊的是 `try_apply_play_intent`，把检查点占用接到进度的是 `try_accept_play_checkpoint` / 重叠扫垫，把传送占用接到单跳落地的是 `try_land_exit` / 重叠扫门，把冲线占用接到 `finish_tick` 的是 `try_cross_play_finish` / 重叠扫终点（见 [§3](#3-从编辑到预览)「Preview 试玩」）。独立会话、安全点增量 Patch、失败整份回滚、无结算写。桌面打开独立 `Window`；关闭只隐藏。窗口内按 Preview 世界重建 1 米占位盒、`portal_link` gizmos、检查点 `order` 标记和发布前问题码叠加；Play 时另画玩家表现桩，开玩且窗口可见时 WASD 移动该桩，重叠检查点垫推进 `pads=n/m`，重叠传送落地后 `floor=n`，重叠终点盒后 `finish=n`。浏览器标签与多人试玩房仍待。v1 袋到补丁等级：

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
