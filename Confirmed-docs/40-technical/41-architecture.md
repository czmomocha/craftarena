# CD-41 总体架构与分层

> 文档 ID：CD-41
> 单一事实源：共享底座构成、进程与平面拓扑、三种世界的职责、L0–L9 模块分层、Monorepo 目录结构
> 加载建议：新增模块、调整依赖方向、改动目录结构或进程边界时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第五、二十一、二十二条
> 相关：[CD-42 数据契约与 Rule VM](42-contracts-and-rulevm.md)、[CD-43 网络与回放](43-networking-and-replay.md)、[CD-44 部署与容量](44-deployment.md)、[CD-51 开发环境](../50-engineering/51-dev-environment.md)
> 派生自：初稿 v0.2 §0（共享底座）、§30–§33

## 当前生效值

> 本节覆盖而非追加。覆盖链见 [CD-91 D.6 / D.8](../90-reference/91-decision-log.md)。

| 项 | 当前口径 |
|---|---|
| 分层 | L0–L9 见 §4。L1 World 门面 + query/move；L2 Bundle 门面 + decode/bags；L3 灰盒门面 + layout/assemble/play、探针门面 + heuristic/search；L4 大厅门面 + chrome/net/sampler/stage/hud/director；L5 Preview 会话/映射/壳均已拆门面 |
| D4 数值落点 | `game/src/shared/placeholder_spec.gd`（唯一配置源） |
| 资产目录 | `game/content/assets/`、`game/content/locale/` |
| E9 | 已拆的壳/会话/映射/仿真世界/bundle/灰盒/探针均 < 400 行。仍超：控制面、MatchHost registry、`authoring_editor_shell.gd`、`traprush_topology_compiler.gd` |
| 仍待 | OpenAPI、Rule VM 图、BASTION 面板、签名发布、账号页 |

## 1. 共享底座构成

两个玩法共享以下底座：

| 模块 | 职责 |
|---|---|
| `SharedContracts` | 稳定 ID、Schema、命令、事件、快照协议 |
| `SimulationCore` | 纯数据、固定 Tick 的权威仿真 |
| `UGCRuntime` | 白名单 Archetype、版本化规则字节码解释器、gas 预算 |
| `CreatorTools` | 共用编辑器外壳（代码创建 Editor 窗口）、内部开发 EditorPlugin（Project > Tools）、本地草稿恢复（`user://` latest + 30 检查点）、TRAPRUSH 工具面板（检查点 / 传送门 / Place solid / Place hazard / Place crate / Place finish）、验证器详情、三张官方 TRAPRUSH 赛道 AuthoringDocument、EditCommand、Undo/Redo、AuthoringDocument、独立持续 Preview 窗口、编辑与 Preview 共用 3D 占位映射、传送连线、检查点顺序与可达性叠加 gizmos、TRAPRUSH 拓扑编译（AuthoringWorld → v1 SimulationBundle JSON → 非固体垫盒与传送源点占用盒 + PortalGraph）、Preview 安全点试玩（编译当前 Preview 世界、加载、在最小 order 垫生成胶囊）、Preview 试玩 MoveIntent（开玩后 WASD → 已有 MoveIntent，经 IntentStepper 改胶囊 XZ）、Preview 试玩检查点占用验收（PadAccept，胶囊与垫相交才推进有序进度）、Preview 试玩传送占用落地（PortalLanding.try_land_exit 单跳，胶囊与源点盒相交才落地）、Preview 试玩冲线占用（FinishAccept.try_cross，全部垫完成后胶囊与终点盒相交才记 finish_tick）、Preview 试玩重置到检查点（ResetToCheckpointIntent，经 CheckpointSpawn 回到最近已验收落点）、Preview 试玩 UseItemIntent 可破坏占用（UseItemIntent，经 DestructibleBreak 在 reach 占用上扣耐久，摧毁后箱盒非固体）、Preview 试玩 JumpIntent 接地跳跃（JumpIntent，经 IntentStepper 接地检查后按调用方 play_jump_dy 上移直到阻挡，未接地不位移）、Preview 周期机关固体切换（try_advance_play 于 world.tick() 之后按已有 cooldown_ticks 切换固体；意图不推进 tick；壳上 Advance tick） |
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
│  │  └─ authoring_editor/       # 内部开发 EditorPlugin；可自动启用本机 godot_ai，插件本身不入库
│  ├─ src/
│  │  ├─ shared/                 # ids/schema/commands/events/protocol；D4 数值唯一落点 `placeholder_spec.gd`
│  │  ├─ simulation/             # fixed-point world/systems/rng/spatial/replay；World 门面 `simulation_world.gd` + query/move
│  │  ├─ ugc/                    # compiler/validator/bytecode_vm/migration；Bundle 门面 `simulation_bundle.gd` + decode/bags
│  │  ├─ server/                 # Godot Headless match/replication/result
│  │  ├─ client/                 # platform/input/prediction/presentation；大厅门面 `match_lobby_shell.gd` + chrome/net/sampler/stage/hud/director；匹配门面 `match_join_session.gd` + codec/accept
│  │  ├─ creator/                # shared shell/edit_commands/preview；Preview 门面 `authoring_preview.gd` + bootstrap/intents/scan/view；Preview 映射门面 `authoring_preview_map.gd` + convert/occupancy/gizmos/overlay/player；Preview 窗口门面 `authoring_preview_shell.gd` + chrome/sampler/hud/play/view
│  │  └─ games/
│  │     ├─ traprush/            # 对局门面 `match_session.gd` + bootstrap/intents/scan/view；灰盒门面 `graybox_course.gd` + layout/assemble/play；探针门面 `course_completion_probe.gd` + heuristic/search
│  │     └─ bastion/
│  ├─ content/
│  │  ├─ official/
│  │  ├─ locale/                 # 本地化 CSV（`craft_arena.*` 键）；解析见 `shared/ui_copy.gd`
│  │  ├─ assets/                 # 平台运行时资产（GLB）；准入见 CD-51 §5.1
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
│  ├─ asset-budget/
│  ├─ content-validator/
│  ├─ godot-project-settings/
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

Godot 主 MCP 已选定为 Godot AI（[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)）。插件只出现在本机 `game/addons/godot_ai/`，**不预建、不入库**；已提交的 `project.godot` 不启用该插件、不写入 `_mcp_game_helper`。打开编辑器时 Authoring Editor 若发现该目录则自动启用。插件写回由 `tools/godot-project-settings/` 还原，见 [CD-51 §7.3](../50-engineering/51-dev-environment.md)。

`Confirmed-docs/` 保留在仓库根，是产品与工程规范的唯一事实源；`docs/adr/` 只记录实现级架构决策。

上面是目标形态。已落地 / 仍待见文首「当前生效值」。红线扫描、worktree、shell-guard 的状态见 [CD-53](../50-engineering/53-testing-and-ci.md) 与 [CD-52](../50-engineering/52-ai-workflow.md)。
