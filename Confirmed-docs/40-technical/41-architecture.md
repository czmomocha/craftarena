# CD-41 总体架构与分层

> 文档 ID：CD-41
> 单一事实源：共享底座构成、进程与平面拓扑、三种世界的职责、L0–L9 模块分层、Monorepo 目录结构
> 加载建议：新增模块、调整依赖方向、改动目录结构或进程边界时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第五、二十一、二十二条
> 相关：[CD-42 数据契约与 Rule VM](42-contracts-and-rulevm.md)、[CD-43 网络与回放](43-networking-and-replay.md)、[CD-44 部署与容量](44-deployment.md)、[CD-51 开发环境](../50-engineering/51-dev-environment.md)
> 派生自：初稿 v0.2 §0（共享底座）、§30–§33

## 1. 共享底座构成

两个玩法共享以下底座：

| 模块 | 职责 |
|---|---|
| `SharedContracts` | 稳定 ID、Schema、命令、事件、快照协议 |
| `SimulationCore` | 纯数据、固定 Tick 的权威仿真 |
| `UGCRuntime` | 白名单 Archetype、版本化规则字节码解释器、gas 预算 |
| `CreatorTools` | 共用编辑器外壳（代码创建 Editor 窗口）、内部开发 EditorPlugin（Project > Tools）、本地草稿恢复（`user://` latest + 30 检查点）、TRAPRUSH 工具面板、验证器详情、三张官方 TRAPRUSH 赛道 AuthoringDocument、EditCommand、Undo/Redo、AuthoringDocument、独立持续 Preview 窗口、编辑与 Preview 共用 3D 占位映射、传送连线、检查点顺序与可达性叠加 gizmos、TRAPRUSH 拓扑编译（AuthoringWorld → v1 SimulationBundle JSON → 非固体垫盒与传送源点占用盒 + PortalGraph）、Preview 安全点试玩（编译当前 Preview 世界、加载、在最小 order 垫生成胶囊）、Preview 试玩 MoveIntent（开玩后 WASD → 已有 MoveIntent，经 IntentStepper 改胶囊 XZ）、Preview 试玩检查点占用验收（PadAccept，胶囊与垫相交才推进有序进度）、Preview 试玩传送占用落地（PortalLanding.try_land_exit 单跳，胶囊与源点盒相交才落地）、Preview 试玩冲线占用（FinishAccept.try_cross，全部垫完成后胶囊与终点盒相交才记 finish_tick）、Preview 试玩重置到检查点（ResetToCheckpointIntent，经 CheckpointSpawn 回到最近已验收落点）、Preview 试玩 UseItemIntent 可破坏占用（UseItemIntent，经 DestructibleBreak 在 reach 占用上扣耐久，摧毁后箱盒非固体）、Preview 试玩 JumpIntent 接地跳跃（JumpIntent，经 IntentStepper 接地检查后按调用方 play_jump_dy 上移直到阻挡，未接地不位移） |
| `ContentPlatform` | 验证、构建、签名、自动公开、热发布和回滚 |
| `MatchServer` | 一局一 Godot Headless 进程、服务器权威、命令校验、快照同步和回放 |
| `ControlPlane` | TypeScript + Fastify、SQLite、Content Registry、Matchmaker 与结果接收 |
| `RealtimeGateway` | 独立 TypeScript TLS WebSocket 网关 |
| `MatchHost` | 启动、限额、续租和回收每场 MatchServer |

## 2. 平面拓扑

```text
┌────────────────── 内容生产平面 ──────────────────┐
│ Godot Editor Plugin │ 游戏内 Edit │ AI Agent      │
│          ↓ EditCommand / Content Schema           │
│ Validate → Preview → Build → Sign → Auto Publish  │
└───────────────────────────────────────────────────┘
                         ↓
┌────────────────── 平台控制平面 ──────────────────┐
│ Fastify API/Auth/Content/Matchmaking/Result       │
│ sole SQLite owner │ COS │ 固定容量 FIFO           │
└───────────────────────────────────────────────────┘
                         ↓
┌────────────────── 实时接入与进程管理 ─────────────┐
│ TLS WebSocket Gateway → MatchHost                 │
│ 一局一 Godot Headless 进程 │ 可续租 │ 资源回收    │
└───────────────────────────────────────────────────┘
                         ↓
┌────────────────── 对局数据平面 ──────────────────┐
│ Client Intent → Authoritative Match Server        │
│ FixedPoint SimulationCore + Rule VM + Replay      │
└───────────────────────────────────────────────────┘
```

所有客户端只连接一个公网 TLS WebSocket 网关。网关验证一次性对局票据，并代理到内网 MatchServer 端口；Godot 子进程不直接暴露公网。

网关是 Monorepo 内**独立 TypeScript 服务和独立进程**，与 Fastify 控制面共享鉴权契约但分离故障边界。

容量、租约和回收参数见 [CD-44](44-deployment.md)。

## 3. 三种世界

| 世界 | 用途 | 规则 |
|---|---|---|
| `AuthoringWorld` | 地图、蓝图和规则编辑 | 可变、带编辑元数据、支持 Revision |
| `SimulationWorld` | 权威仿真和客户端预测副本 | 纯数据、固定 Tick、稳定 ID |
| `PresentationWorld` | Godot 节点、动画、声音、UI | 非权威、可丢弃重建 |

禁止把 `.tscn` 直接当作 UGC 数据库。`.tscn` 只用于平台可信的表现模板；UGC 使用规范化数据格式。

## 4. 模块分层

| 层 | 模块 | 职责 |
|---|---|---|
| L0 | `SharedContracts` | ID、Schema、命令、事件、协议、错误码 |
| L1 | `SimulationCore` | 定点 World、System、固定 Tick、RNG、状态哈希 |
| L2 | `UGCRuntime` | 内容加载、字节码 Rule VM、gas、迁移、验证 |
| L3 | `MatchServer` | 会话、权威命令、复制、回放、反作弊 |
| L4 | `GameClient` | 输入、预测、插值、校正、表现、平台层 |
| L5 | `CreatorTools` | Authoring、EditCommand、预览、调试 |
| L6 | `ContentPlatform` | 上传、构建、签名、自动公开、回滚、下架 |
| L7 | `ControlPlane` | Fastify、SQLite、账号、草稿、内容、匹配、评分、结果 |
| L8 | `RealtimeGateway` | TLS WebSocket 入口、票据校验、内网代理 |
| L9 | `MatchHost` | 子进程启动、端口、资源、租约、退出与日志 |

## 5. Monorepo 目录

```text
repo/
├─ AGENTS.md
├─ README.md
├─ .cursor/
│  ├─ agents/                    # 角色定义；无审查 Agent
│  ├─ BUGBOT.md                  # 本地/日后 PR Bugbot 规则；非门禁；PR 侧已跳过
│  ├─ hooks.json
│  └─ worktrees.json
├─ .github/
│  └─ workflows/                 # CI；门禁范围见 CD-53 §4.1
├─ game/
│  ├─ project.godot
│  ├─ addons/
│  │  ├─ gut/
│  │  └─ authoring_editor/       # 内部开发 EditorPlugin；非 godot_ai
│  ├─ src/
│  │  ├─ shared/                 # ids/schema/commands/events/protocol
│  │  ├─ simulation/             # fixed-point world/systems/rng/spatial/replay
│  │  ├─ ugc/                    # compiler/validator/bytecode_vm/migration
│  │  ├─ server/                 # Godot Headless match/replication/result
│  │  ├─ client/                 # platform/input/prediction/presentation
│  │  ├─ creator/                # shared shell/edit_commands/preview
│  │  └─ games/
│  │     ├─ traprush/
│  │     └─ bastion/
│  ├─ content/
│  │  ├─ official/
│  │  ├─ schemas/
│  │  └─ test_fixtures/
│  └─ tests/
│     ├─ unit/
│     ├─ integration/
│     ├─ replay/
│     ├─ content/
│     └─ security/
├─ backend/
│  ├─ control-plane/             # Fastify；SQLite 唯一所有者
│  ├─ realtime-gateway/          # 独立 TLS WebSocket 代理
│  ├─ match-host/                # Godot 子进程、端口、租约和资源回收
│  └─ contracts/                 # JSON Schema / OpenAPI / match schema
├─ tools/
│  ├─ dev-launcher/
│  ├─ bot-runner/
│  ├─ content-validator/
│  ├─ redline-scanner/
│  ├─ shell-guard/
│  └─ replay-inspector/
├─ infra/
│  ├─ compose/
│  └─ tencent-cloud/
└─ docs/
   ├─ adr/
   ├─ plans/
   └─ runbooks/
```

Godot 主 MCP 已选定为 Godot AI（[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)）。插件只出现在本机 `game/addons/godot_ai/`，**不预建、不入库**；已提交的 `project.godot` 不启用该插件、不写入 `_mcp_game_helper`。同时只允许这一套 Godot MCP。安装与遥测开关见 [CD-51 §7](../50-engineering/51-dev-environment.md)。

`Confirmed-docs/` 保留在仓库根，是产品与工程规范的唯一事实源；`docs/adr/` 只记录实现级架构决策。

上面是目标形态，不是当前完成度。截至本刀，`game/src/shared/` 已有稳定 ID、命令信封、领域事件、状态哈希、定点运算与 [CD-42 §1.2](42-contracts-and-rulevm.md#12-字段标识符v1) 组件袋；`backend/contracts/schemas/` 已有 L0 信封、`component_record`、`authoring_document` 与 `simulation_bundle` JSON Schema，由 `tools/content-validator/` 做正反例。`game/src/creator/` 已有 AuthoringWorld（put / remove / replace、吸附格、楼层查询、`portal_link` 分类、文档快照 restore）、AuthoringSession（EditCommand 应用、`expected_revision` 门禁、Undo/Redo 反向 payload、表面与文档导入导出）、发布前通路/循环（`evaluate_reachability`）、独立 Preview 会话（安全点 P0–P2 Patch、失败回滚、无结算写）、Preview 窗口宿主（代码创建独立 `Window`，关闭只隐藏）、Preview 3D 占位映射（带 `transform` 的实体 → 1 米 `BoxMesh`）、传送连线 gizmos（`two_way` / `one_way` / `dangling`）、检查点顺序 gizmos（唯一 `order` 连线，重复 order 只打标）、可达性叠加（发布前问题码标到有 `transform` 的实体，不是写入门禁）、编辑外壳（代码创建 Editor 窗口，只发已有 EDIT `op`，成功写入按 Preview 世界的等级转发给已连接 Preview，转发被拒只脱同步）、编辑窗口 3D 映射（同一套 `AuthoringPreviewMap` 按 AuthoringWorld 重建）与 TRAPRUSH 工具面板（检查点 / 传送门 / 删除最后实体 / 楼层切换，仍走已有 `op`）与验证器详情（只读问题列表与对焦，不是写入门禁）与三张官方 TRAPRUSH 赛道（AuthoringDocument JSON，发布检查 ok）与内部开发 EditorPlugin（Project > Tools 打开已有外壳，已提交工程不含 `godot_ai` / `_mcp_game_helper`）与本地草稿恢复（`user://` latest + 30 检查点，空会话打开恢复，不写 `res://`）与编辑写入自动进 Preview（安全点转发同一条 `op`，脱同步须重新连接）与 TRAPRUSH 拓扑编译（`game/src/ugc/` 把 AuthoringWorld 编成 v1 SimulationBundle JSON；加载器把垫子、传送源点和终点生成为非固体静态盒并写入 PortalGraph；不签二进制、不编 Rule VM）与 Preview 安全点试玩（`AuthoringPreview.try_start_play` 编译当前 Preview 世界、加载、在最小 `order` 垫生成胶囊；Play/Stop 与玩家表现桩）与 Preview 试玩 MoveIntent（`try_apply_play_intent` 只接受已有 MoveIntent；窗口可见时 WASD 按世界方向编码；不锁速度/重力/Tick Hz、不结算）与 Preview 试玩检查点占用验收（已有 PadAccept；胶囊与垫相交才推进有序进度；不是完成断言）与 Preview 试玩传送占用落地（已有 PortalLanding.try_land_exit；胶囊与源点盒相交才单跳落地）与 Preview 试玩冲线占用（已有 FinishAccept.try_cross；全部强制检查点完成后胶囊与终点盒相交才记 `finish_tick`；不是冲线断言、不结算）与 Preview 试玩重置到检查点（已有 ResetToCheckpointIntent 与 CheckpointSpawn；不读客户端坐标、不回退进度、不结算）与 Preview 试玩 UseItemIntent 可破坏占用（已有 UseItemIntent 与 DestructibleBreak；reach 占用才扣耐久，摧毁后非固体，不锁爆破表、不结算）与 Preview 试玩 JumpIntent 接地跳跃（已有 JumpIntent 经 IntentStepper 接地检查；play_jump_dy / play_support_dy 是表现桩，未接地不位移，不锁跳跃高度或重力、不结算）与对局进程多人仿真循环（`TraprushMatchSession`：一份编译拓扑装进共享权威 SimulationWorld，1~8 名玩家各自独立 CheckpointTrack / finish_tick / 传送门闩，可破坏箱全员共享，同磁带同哈希序列；无网络、无结算）与对局二进制协议 v1（`MatchFrameCodec`：版本化命令/快照帧，严格拒绝畸形帧，布局见 [CD-43 §1](43-networking-and-replay.md#1-序列化分工)）。M1 仿真与灰盒完成度见 [CD-61](../60-plan/61-milestones.md) M1 退出记录。仍待后续：OpenAPI、Rule VM 图 JSON Schema、BASTION 面板、预算数字、多人 Preview、障碍/道具/推击冲量数值，以及 `bot-runner/` / `replay-inspector/`。红线扫描、worktree、shell-guard、`.cursor/agents/` 与 `.cursor/BUGBOT.md` 的状态不在此复述，见 [CD-53](../50-engineering/53-testing-and-ci.md) 与 [CD-52](../50-engineering/52-ai-workflow.md)。
