# CD-52 AI 主导开发方式

> 文档 ID：CD-52
> 单一事实源：人机分工与 AI 权限边界、标准任务循环、任务单模板、AI 使用规则、多 Agent 协作、项目治理与语言约定、Godot AI MCP 使用边界
> 加载建议：AI Agent 接手任务时必读；调整协作流程或权限边界时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第九、十、十一、十二、十八、二十条
> 相关：[CD-53 测试与 CI](53-testing-and-ci.md)、[CD-51 开发环境](51-dev-environment.md)、[CD-61 里程碑路线](../60-plan/61-milestones.md)、[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)、[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)
> 派生自：初稿 v0.2 §43–§47

## 1. 角色分工

### 1.1 AI 负责

- 拆解需求和形成任务计划；
- 搜索项目上下文和官方文档；
- 编写与重构 GDScript；
- 创建数据 Schema、规则和测试夹具；
- 通过 MCP 修改场景和编辑器对象（仅限该开发机已完成 [CD-51 §7](51-dev-environment.md) 接入烟测签字；边界见 §7）；
- 生成单元、集成、回放、网络和安全测试；
- 运行测试、读取错误并修复；
- 生成占位 UI、低模资产草稿、音效草稿；
- 更新文档、变更记录和风险列表；
- 根据日志和指标定位问题；
- 批量生成合法 UGC 内容做压力测试。

**权限边界**：AI 可以自主读取和修改代码、场景、文档和测试，也可运行本地游戏、Headless 与测试。

提交与推送按 [ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 对 `ai_autonomy = edit_test_no_commit_release` 的收窄解释执行（[CD-91 D.6](../90-reference/91-decision-log.md)）：

- **允许**：在隔离的 agent 分支或 git worktree 上创建提交，并推送到对应的非保护远程分支。这是 Cursor Cloud Agent 与 `/worktree` 的运行时形态，也避免未提交产出被 worktree 清理丢失。
- **禁止，且属宪法第十八条人类门禁**：向 `main` 或任何受保护分支提交或推送；合并 PR；部署；发布；回滚线上内容。人类门禁落在 PR 合并（`pr_merge_gate = required_ci_one_human`）与 GitHub 分支保护。
- **机械化拦截**：项目级 `.cursor/hooks.json` 的 `beforeShellExecution` 拦向 `main` / 受保护分支的提交与推送，以及 `git worktree remove --force`。该 hook **必须** `failClosed: true`（Cursor 默认 fail-open，崩溃即放行）。判定逻辑在 `tools/shell-guard/`，由 `npm test` 覆盖。
- **硬前置**：GitHub 分支保护未配置完成之前，上述「允许」条款不生效，仍按原字面执行——Agent **不得**创建任何提交或推送。分支保护的目标项见 [CD-53 §4.5](53-testing-and-ci.md)，当前是否已配置以那一节为准。

### 1.2 人类负责

- 产品方向和范围拍板；
- 玩法是否好玩的最终判断；
- 高风险架构、协议和安全边界确认；
- Schema 破坏性变更审批；
- 线上发布、回滚和终止对局审批；
- AI 资产投诉、相似性争议与下架/替换的最终判断（不构成逐项发布前审批）；
- 商业、合规、隐私和平台政策判断；
- 对 AI 无法解释或无证据的结论进行否决。

一期只有一名核心负责人，由同一人承担策划、技术决策与验收。人类在每个可验证任务结束后审查结果与 diff；架构、Schema、协议、安全边界和新依赖必须**事前**审批。

## 2. 标准任务循环

```text
读取 AGENTS.md 与相关文档
→ 明确任务输入、输出和不做事项
→ 搜索现有实现
→ 给出最小变更方案
→ 先写或更新测试
→ 实现
→ 运行自动化测试
→ 运行场景 / Headless 验证
→ 检查日志与性能
→ 人类审查
→ 人类决定是否合入 main / 部署 / 发布
→ 更新文档和任务状态
```

AI 不得用"代码看起来正确"代替运行证据。

读取"相关文档"时使用 [README 任务路由表](../README.md#3-任务路由表)，不要通读全部文档。

## 3. 任务单模板

```text
目标：
背景：
允许修改：
禁止修改：
隔离方式：worktree | cloud | 无
输入文件：
验收标准：
必须运行的测试：
性能或安全预算：
输出物：
```

`隔离方式` 必填。阶段 A（§5.1 的四条退出条件未全绿）只允许 `无`，即单 Agent 串行、共享当前 checkout。阶段 B 起必须填 `worktree` 或 `cloud`：**Cursor 的 subagent 默认共享父 Agent 的 checkout，不显式要求隔离会静默互相覆盖。** 不得留空。

功能任务应控制在**半天到两天**可验证的粒度。禁止用"实现完整 UGC 平台"这类无法审查的任务驱动 Agent。任务结束时由人类审查后立刻开 PR，不要让未提交产出跨夜留在 worktree 里（Cursor 托管 worktree 会自动清理，见 [CD-62](../60-plan/62-risk-register.md)）。提交粒度见 [§3.1](#31-提交粒度完整章节)。

### 3.1 提交粒度：完整章节

人类拍板（2026-08-23）：**能做成完整一章，就按完整一章提交审查。** [CD-91 D.6](../90-reference/91-decision-log.md) 的 `git_workflow = trunk_short_pr` 仍然禁止「整个里程碑一个 PR」，但禁止把同一条链路拆成多份不能独立验收的半成品。

一章 = 同一条产品或技术链路的一次闭合：需要锁的契约 + 实现 + 正反例测试 + 所有者文档落点。人类一次审查应能回答「这章是否成立」，而不是「另一半合入后才有意义」。

- 允许：Component Schema v1 整袋冻结；EditCommand 应用到 AuthoringWorld 并带 Undo/Redo；网格吸附、楼层查询与传送连线分类；发布前通路与传送循环；独立持续 Preview 会话与安全点 Patch；桌面完整与 Web 轻量的共同 AuthoringDocument；独立 Preview 窗口宿主；Preview 3D 表现映射；Preview 传送连线可视化；Preview 检查点顺序可视化；Preview 可达性叠加；内部开发编辑外壳；编辑窗口 3D 表现映射；TRAPRUSH 工具面板；验证器详情；第一张官方 TRAPRUSH 赛道 AuthoringDocument；第二张官方 TRAPRUSH 赛道 AuthoringDocument；第三张官方 TRAPRUSH 赛道 AuthoringDocument；内部开发 EditorPlugin；本地草稿恢复；编辑写入自动进已连接 Preview；AuthoringWorld 编成 v1 TRAPRUSH SimulationBundle 并可加载进 SimulationWorld；Preview 安全点试玩（编译当前 Preview 世界、加载、在最小 order 垫生成胶囊）；Preview 试玩 MoveIntent（开玩后 WASD → 已有 MoveIntent）；Preview 试玩检查点占用验收（已有 PadAccept，胶囊与垫相交才推进有序进度）；Preview 试玩传送占用落地（已有 PortalLanding.try_land_exit 单跳，胶囊与源点盒相交才落地）；Preview 试玩冲线占用（已有 FinishAccept.try_cross，全部垫完成后胶囊与终点盒相交才记 finish_tick）；Preview 试玩重置到检查点（已有 ResetToCheckpointIntent + CheckpointSpawn，不读客户端坐标）；Preview 试玩 UseItemIntent 可破坏占用（已有 UseItemIntent + DestructibleBreak，reach 占用才扣耐久，不锁爆破表）；Preview 试玩 JumpIntent 接地跳跃（已有 JumpIntent + IntentStepper 接地检查，play_jump_dy / play_support_dy 是表现桩，未接地不位移，不锁跳跃高度或重力）；对局进程多人仿真循环（`TraprushMatchSession`：共享权威 SimulationWorld，1~8 名玩家独立进度/冲线 tick/传送门闩，可破坏箱共享，同磁带同哈希序列，无网络无结算）；对局二进制协议 v1（命令/快照版本化编解码，严格拒绝畸形帧，不锁 Tick/快照频率）；对局进程仿真入口（`match_server.gd` 真仿真 + MatchHost 传 `--course`/`--players`，心跳不续租）；对局进程实时回路（`match_server.gd` WebSocket 监听 + `MatchRealtime` 槽位/命令队列/快照广播，命令 tick 不信任，快照节奏占位）；实时网关代理（票据裁决携带上游、双向原样转发、开发期 `GATEWAY_DEV_UPSTREAM` 固定上游，真票据签发仍待）；控制面真票据签发/校验（登记对局上游、一次性签发与消费校验返回上游，网关 `ControlPlaneTicketVerifier` 走控制面，`GATEWAY_DEV_UPSTREAM` 仍为显式旁路，不锁账号绑定/重连补票）；MatchHost 自动登记上游（拉起后 `POST /match-sessions` 登记同一 `matchId` 与 `ws` 上游，失败杀进程并 502，不查库，不锁真匹配/房间码/账号绑定/重连补票/会话注销）；MatchHost 等待 listen 后登记（对本场端口 TCP 探测至可连再登记，超时或进程先退出则杀进程并 502，探测连 `127.0.0.1`，不注销会话、不锁真匹配/房间码）；MatchHost 停止后注销会话（显式停止/回收/进程退出/关机后 `DELETE /match-sessions/:matchId`，未用票据作废，404 视为已注销，注销失败本地已停且显式 DELETE 回 502，不查库，不锁真匹配/房间码/账号绑定/重连补票）；真匹配与房间码（控制面 `POST /matchmaking/quick` 加入最旧未满房或拉起新场，`POST /matchmaking/rooms` 建房发码，按码加入，席位内签发票据，MatchHost 容量满回 503，不查库，不锁 FIFO 等待队列/预计等待、账号绑定、重连补票）；FIFO 等待队列与预计等待（容量满时控制面入队回 202，`GET /matchmaking/queue/:token` 查位次与预计等待，`DELETE` 取消，注销后按 FIFO 出队签发票据；预计等待=位次×开发期占位间隔，MatchHost 不查库，不锁账号绑定、重连补票）；客户端匹配入场与权威快照跟从（Godot 大厅走快速游戏/建房/按码加入与 FIFO 轮询，持票经网关 `/ws?ticket=` 入场，发送已有命令帧并跟从最新快照；不插值、不预测，不锁账号绑定、重连补票、名次）；权威快照表现映射（最新快照玩家位姿映射为 1 米占位盒，旧 tick / 坏帧不重建；箱子无位姿不画 3D；不插值、不预测，不锁赛道几何、名次、账号绑定、重连补票）；对局大厅赛道几何表现映射（编译拓扑的检查点垫、传送门源点与终点占用映射为 1 米占位盒，默认官方 course_01；缺课/坏袋不重建；箱子仍不画 3D；不插值、不预测，不锁名次、账号绑定、重连补票、课程选择 API）。
- 禁止：只锁 EDIT `op` 名、AuthoringWorld 只有 put/remove、把 apply 留到下一份 PR；禁止为了「两域都有 diff」而各交半章。
- 仍禁止：把 BASTION 面板、第三张赛道、预算数字、2 秒云端上传塞进同一个 PR。

并行 2 域时，每个域交出的也必须是完整一章。决策来源见 [CD-91 D.6](../90-reference/91-decision-log.md) `pr_scope = complete_chapter`。

## 4. AI 使用规则

1. 先读项目现有代码，再生成代码；
2. 优先查 Godot 4.7 官方文档，不凭记忆猜 API；
3. 禁止 Godot 3 API；
4. 不直接大范围手改 `.tscn`；优先通过 MCP/Editor API 和 UndoRedo。M2 生产级启用已于 2026-08-23 成立：大型场景任务必须走这条路径。接入烟测尚未在该机器签字、或编辑器未开时，退回受审查的文件 / Editor API 方式，不得把「MCP 没连上」当成任务失败；
5. 不随意使用 `@tool`，避免编辑器死循环。内部开发 EditorPlugin 的 `plugin.gd` 必须 `@tool`（Godot 要求）；不得把 `@tool` 扩到 `AuthoringWorld` / `SimulationCore`；
6. 不引入新依赖，除非说明必要性、许可、维护风险和平台支持；
7. 不引入 C#；
8. `SimulationCore`、命令、Schema、Rule VM、网络与热发布必须测试先行；纯表现/UI 可先实现后补烟测和视觉检查；
9. 不把客户端结果当权威结果；
10. 不在 UGC 中执行任意代码；
11. 提交与推送边界见 §1.1；不得部署或发布；
12. 无法解释的代码不得合入；
13. 遇到 Schema、网络协议、数据删除和发布策略变更时必须请求人类确认；
14. AI 资产通过格式、性能和许可证元数据自动检查后可以进入测试发布包，不要求逐项人工质量审批；
15. AI 资产不强制保存模型、提示词、种子或来源；收到权利投诉时由人类逐案判断是否下架或替换；
16. 给 Godot 引擎官方仓库贡献时遵守其 AI 贡献政策；本项目游戏代码不受该贡献禁令影响；
17. 唯一 Godot 主 MCP 是 Godot AI，使用边界见 §7；禁止再启用功能重叠的第二套 Godot MCP。

## 5. 多 Agent 协作

决策来源：[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)。本节是启用时机、运行时形态与角色表的所有者。

始终由**一个主 Agent** 统筹。子 Agent 只在互不重叠的模块或独立工作区并行，禁止同时修改同一场景、Schema 或协议。Cursor 没有 Agent Teams 那样的共享任务列表与成员间消息，「统筹」靠任务单与 prompt 纪律，不是运行时保证。

### 5.1 启用时机

并行度的瓶颈是人类审查带宽，不是编排工具。启用判据是门禁覆盖率，不是里程碑编号。**下列四条全部成立之前，任何 Agent 不得以「提高效率」为由开启多域并行。**

| # | 条件 |
|---|---|
| A1 | `game/src/shared/` 有 v1 契约，且被 GUT 单测覆盖 |
| A2 | 契约变更被 `CODEOWNERS` 标为需要人类批准 |
| A3 | Schema 验证、禁止 API 扫描、worktree 并行环境三条门禁上线（是否已进 CI 以 [CD-53 §4.1](53-testing-and-ci.md) 为准） |
| A4 | 仓库里走通至少一次「Agent 产出 → PR → CI 全绿 → 人类 review → 人类合并」 |

当前（2026-08-22）**A1–A4 已成立。** A1 / A4 见 [PR #1](https://github.com/czmomocha/craftarena/pull/1)。A2：`.github/CODEOWNERS` + GitHub code owner 审查。A3：L0 JSON Schema、红线扫描、`.cursor/worktrees.json` 与 DevLauncher `loadEnvFile` 已落地。`.cursor/hooks.json` 已入库（`failClosed: true`）。本地 `/review-bugbot` 已按 [ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) §6.1 第 9 项执行。`.cursor/agents/` 已按 §5.3 入库（无审查 Agent）。`.cursor/BUGBOT.md` 已入库。任务单「隔离方式」行见 §3。**GitHub PR 侧 Bugbot 已跳过**（Cursor SCM 安装对不上，审查改回 CI + 人类批准；本地 `/review-bugbot` 仍可用）。阶段 B 待办 14 第一轮：玩法 [PR #13](https://github.com/czmomocha/craftarena/pull/13)、仿真 [PR #14](https://github.com/czmomocha/craftarena/pull/14)。第二轮：玩法 [PR #17](https://github.com/czmomocha/craftarena/pull/17)、仿真 [PR #16](https://github.com/czmomocha/craftarena/pull/16)。第三轮：玩法 [PR #19](https://github.com/czmomocha/craftarena/pull/19)、仿真 [PR #20](https://github.com/czmomocha/craftarena/pull/20)。第四轮：玩法 [PR #22](https://github.com/czmomocha/craftarena/pull/22)、仿真 [PR #23](https://github.com/czmomocha/craftarena/pull/23)。第五轮：玩法 [PR #25](https://github.com/czmomocha/craftarena/pull/25)、仿真 [PR #26](https://github.com/czmomocha/craftarena/pull/26)。第六轮：玩法 [PR #28](https://github.com/czmomocha/craftarena/pull/28)、仿真 [PR #29](https://github.com/czmomocha/craftarena/pull/29)。第七轮：玩法 [PR #31](https://github.com/czmomocha/craftarena/pull/31)、仿真 [PR #32](https://github.com/czmomocha/craftarena/pull/32)。第八轮：玩法 [PR #35](https://github.com/czmomocha/craftarena/pull/35)、仿真 [PR #34](https://github.com/czmomocha/craftarena/pull/34)。第九轮：玩法 [PR #38](https://github.com/czmomocha/craftarena/pull/38)、仿真 [PR #37](https://github.com/czmomocha/craftarena/pull/37)。第十轮：玩法 [PR #41](https://github.com/czmomocha/craftarena/pull/41)、仿真 [PR #40](https://github.com/czmomocha/craftarena/pull/40)。细轮收尾：玩法 [PR #44](https://github.com/czmomocha/craftarena/pull/44)、仿真 [PR #43](https://github.com/czmomocha/craftarena/pull/43)。首章（B+A）：玩法 [PR #46](https://github.com/czmomocha/craftarena/pull/46)、仿真 [PR #45](https://github.com/czmomocha/craftarena/pull/45)。第二章：玩法 [PR #49](https://github.com/czmomocha/craftarena/pull/49)、仿真 [PR #48](https://github.com/czmomocha/craftarena/pull/48)。第三章：玩法 [PR #51](https://github.com/czmomocha/craftarena/pull/51)、仿真 [PR #52](https://github.com/czmomocha/craftarena/pull/52)。第四章：玩法 [PR #55](https://github.com/czmomocha/craftarena/pull/55)、仿真 [PR #54](https://github.com/czmomocha/craftarena/pull/54)。第五章：玩法 [PR #58](https://github.com/czmomocha/craftarena/pull/58)、仿真 [PR #57](https://github.com/czmomocha/craftarena/pull/57)。第六章：玩法 [PR #60](https://github.com/czmomocha/craftarena/pull/60)、仿真 [PR #61](https://github.com/czmomocha/craftarena/pull/61)。第七章：玩法 [PR #63](https://github.com/czmomocha/craftarena/pull/63)、仿真 [PR #64](https://github.com/czmomocha/craftarena/pull/64) 由人类合入。文档 [PR #65](https://github.com/czmomocha/craftarena/pull/65)。仿真 [PR #66](https://github.com/czmomocha/craftarena/pull/66)、玩法 [PR #67](https://github.com/czmomocha/craftarena/pull/67)。弧 A：玩法 [PR #68](https://github.com/czmomocha/craftarena/pull/68)（Jump/Shove 直到阻挡与掉出范围复位）。弧 B：玩法 [PR #69](https://github.com/czmomocha/craftarena/pull/69)（单人灰盒整段可回放）。弧 C：玩法 [PR #70](https://github.com/czmomocha/craftarena/pull/70)（PLAYER 磁带回放进灰盒）。弧 D：玩法 [PR #71](https://github.com/czmomocha/craftarena/pull/71)（SYSTEM 占用日志进灰盒）。弧 E：玩法 [PR #72](https://github.com/czmomocha/craftarena/pull/72)（出界复位与打箱入 SYSTEM 带）。弧 F：玩法 [PR #73](https://github.com/czmomocha/craftarena/pull/73)（try_commit_tick 入 SYSTEM 带）。弧 G：玩法 [PR #74](https://github.com/czmomocha/craftarena/pull/74)（独立 try_apply_fall 入 SYSTEM 带）。弧 H：玩法 [PR #75](https://github.com/czmomocha/craftarena/pull/75)（灰盒基础推击入 PLAYER 带）。M1 已退出（2026-08-23，见 [CD-61](../60-plan/61-milestones.md)）。工具链评审已通过（2026-08-23，[ADR-0004 §8.1](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)）：MCP 生产级启用；并行保持 2 域。M2 第一刀 Component Schema v1 已落入 [CD-42 §1.2](../40-technical/42-contracts-and-rulevm.md#12-字段标识符v1)；[PR #81](https://github.com/czmomocha/craftarena/pull/81) 已闭合 EditCommand 应用与 Undo/Redo。[PR #82](https://github.com/czmomocha/craftarena/pull/82) 锁定完整章节提交口径。[PR #83](https://github.com/czmomocha/craftarena/pull/83) 锁网格 / 楼层 / 传送连线。[PR #84](https://github.com/czmomocha/craftarena/pull/84) 锁发布前通路与传送循环。本刀锁 Preview 试玩 UseItemIntent 可破坏占用（[CD-32 §3](../30-ugc/32-editor-and-preview.md#3-从编辑到预览)）。第 3 域未开。

### 5.2 运行时形态

一期使用 Cursor 原生能力，零自建编排框架。下表是已拍板的运行时形态。`.cursor/worktrees.json`、`.cursor/hooks.json`、`.cursor/agents/` 与 `.cursor/BUGBOT.md` 已入库。GitHub PR 侧 Bugbot 已跳过，合入靠 CI + 人类批准；不得把 Bugbot 描述为合并门禁。

| 能力 | 位置 / 用法 | 约束 |
|---|---|---|
| 工作区隔离 | IDE `/worktree`、CLI `-w/--worktree`、Cloud Agent 独立 VM | 默认上限与自动清理见 Cursor 文档；不要在 worktree 里放未提交且不可再生的东西 |
| 角色定义 | 项目级 `.cursor/agents/*.md` | frontmatter 只有 `name`、`description`、`model`、`readonly`、`is_background`。**没有 `tools` 白名单**；不得声称 `readonly: true` 是已证实的硬边界 |
| 提交拦截 | `.cursor/hooks.json` 的 `beforeShellExecution` | 见 §1.1；必须 `failClosed: true` |
| 代码审查 | 合入靠 CI + 人类批准。本地 `/review-bugbot` 可选；GitHub PR 侧 Bugbot **已跳过** | 配置在 `.cursor/BUGBOT.md`（若日后 PR 侧恢复则加载它）。本地 `/review-bugbot` **会**注入根目录 `AGENTS.md`。GitHub PR 侧因 Cursor SCM 安装对不上而跳过，不要再把它写成流程前置。findings 默认 `neutral`，**不是 CI 门禁**（[CD-53 §4.1](53-testing-and-ci.md)）。实测见 [CD-91 D.6](../90-reference/91-decision-log.md) `bugbot_pr_side` |
| worktree 基建 | `.cursor/worktrees.json` 的 `setup-worktree-windows` / `setup-worktree-unix` | `npm install`、按需拷本地文件、Godot `--import`、写端口偏移。**禁止 symlink `node_modules`**。Windows 上 `npm.cmd` 由 `runCommand` 包 shell spawn（Node ≥ 24 无 shell 直产 `.cmd` 抛 EINVAL）；`.exe` 与类 Unix 不包 |

一期**不引入** Multica 类平台，**不用** Cursor Automations（配置无法入库）。重估触发点见 ADR-0004 §6.4。

并行度上限 **3**，先跑 **2** 个域，确认审查节奏后再加第 3 个。不要一上来开 5 个。M1 已退出；2026-08-23 工具链评审裁定**保持 2 域**，第 3 域仍未开。升到 3 须另一次人类拍板。域划分见 [CD-61](../60-plan/61-milestones.md) 与 [ADR-0004 §8.1](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md)。

### 5.3 角色

按任务临时分工。角色定义在 `.cursor/agents/`：

| 角色 | 文件 | 职责 |
|---|---|---|
| 架构 Agent | `architecture.md` | 维护边界、ADR 和 Schema |
| 玩法 Agent | `gameplay.md` | 实现 TRAPRUSH/BASTION System |
| 编辑器 Agent | `editor.md` | EditCommand、UI 和 Preview |
| 网络 Agent | `networking.md` | 命令、快照、重连和回放 |
| 测试 Agent | `testing.md` | 生成测试、恶意输入和性能场景 |
| 资产 Agent | `assets.md` | 生成占位资源并执行导入检查 |
| 审查 | **不建文件** | 由 Bugbot 承担。Cursor subagent 继承父 Agent 的全部工具，做不成硬只读 |

frontmatter 只有 `name`、`description`、`model`、`readonly`、`is_background`。没有 `tools` 白名单。这些文件**不**等于已经开启多域并行。

任何 Agent 产物都必须进入同一代码库、同一测试门禁和同一人类审批流程。

## 6. 项目治理与语言约定

- 任务和里程碑使用 GitHub Issues/Projects；
- 实现级架构决策写入仓库 `docs/adr/`；产品与工程规范写入 `Confirmed-docs/`；
- 技术文档、Issue 和 ADR 以中文为主；
- 代码标识符、协议字段和 Git 提交信息使用英文；
- 提交遵循带 scope 的 Conventional Commits。

## 7. Godot AI MCP 使用边界

安装、版本、遥测开关与接入时机的所有者是 [CD-51 §7](51-dev-environment.md)。选型与阶段定义见 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)。本节只约束 Agent **已经连上 MCP 之后**怎么用。

### 7.1 按里程碑

- **M1**：默认仍用文件工具写 `.gd` 与测试。仅当该开发机已完成接入烟测签字，才可用 MCP 改表现层占位场景；不得用 MCP 表达权威仿真状态。
- **M2（生产级启用已于 2026-08-23 成立）**：大型 `.tscn` 必须走 MCP / Editor API / UndoRedo；优先 `batch_execute` 做可回滚的一批节点操作，改完在编辑器里确认 Ctrl+Z 仍然有效。这是 M2 场景任务的验收口径，不是可选项。
- **任何阶段**：编辑器未开或 MCP 不可用时，Headless、GUT 与 README 命令仍是正路。不得把 Godot AI 写进 CI job，不得在 MatchServer 进程里依赖 `_mcp_game_helper`。

### 7.2 禁止

- `editor_manage(op="game_eval")`：这是对运行中游戏的任意求值，不能当调试便门，更不能当权威逻辑；
- 用 `test_run` / `McpTestSuite` 替代 GUT 或 [CD-53](53-testing-and-ci.md) 门禁；编辑器内试跑只是辅助；
- 开启 Vision Routing（截图会离开本机）；
- `--allow-host` 或把 MCP HTTP 绑到非回环地址；
- 提交 `game/addons/godot_ai/`、`project.godot` 里的 `godot_ai` 插件项、或 `_mcp_game_helper` autoload；
- 为「让 MCP 更好用」向已提交工程添加新的 Autoload 或放宽核心目录类型门禁。

### 7.3 提交前

若本机为了开 MCP 改脏了 `game/project.godot`，提交前必须还原 `godot_ai` 插件项与 `_mcp_game_helper` autoload。已提交插件列表只保留 GUT 与 `authoring_editor`。工作区里出现 `game/addons/godot_ai/` 是 gitignore 预期内的本机文件，不得 `git add`。

`.cursor/` 入库边界：

| 入库 | 不入库 |
|---|---|
| `agents/`、`hooks.json`、`worktrees.json`、`BUGBOT.md` | `mcp.json`（含本机绝对路径）、`permissions.json`（自然语言指令，官方明确不是安全边界） |

不要把用户目录里带绝对路径的 attach 片段拷进仓库。不要把 `permissions.json` 入库后当成门禁。
