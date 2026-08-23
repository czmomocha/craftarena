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
| `CreatorTools` | 共用编辑器外壳、玩法专用工具面板、EditCommand、Undo/Redo、AuthoringDocument、独立持续 Preview 窗口、3D 占位映射与传送连线 gizmos |
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
│  │  └─ gut/
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

上面是目标形态，不是当前完成度。截至本刀，`game/src/shared/` 已有稳定 ID、命令信封、领域事件、状态哈希、定点运算与 [CD-42 §1.2](42-contracts-and-rulevm.md#12-字段标识符v1) 组件袋；`backend/contracts/schemas/` 已有 L0 信封、`component_record` 与 `authoring_document` JSON Schema，由 `tools/content-validator/` 做正反例。`game/src/creator/` 已有 AuthoringWorld（put / remove / replace、吸附格、楼层查询、`portal_link` 分类、文档快照 restore）、AuthoringSession（EditCommand 应用、`expected_revision` 门禁、Undo/Redo 反向 payload、表面与文档导入导出）、发布前通路/循环（`evaluate_reachability`）、独立 Preview 会话（安全点 P0–P2 Patch、失败回滚、无结算写）、Preview 窗口宿主（代码创建独立 `Window`，关闭只隐藏）、Preview 3D 占位映射（带 `transform` 的实体 → 1 米 `BoxMesh`）与传送连线 gizmos（`two_way` / `one_way` / `dangling`，权威仍在 Preview 世界）。M1 仿真与灰盒完成度见 [CD-61](../60-plan/61-milestones.md) M1 退出记录。仍待后续：OpenAPI、Rule VM 图 JSON Schema、检查点可视化、多人 Preview、障碍/道具/推击冲量数值，以及 `bot-runner/` / `replay-inspector/`。红线扫描、worktree、shell-guard、`.cursor/agents/` 与 `.cursor/BUGBOT.md` 的状态不在此复述，见 [CD-53](../50-engineering/53-testing-and-ci.md) 与 [CD-52](../50-engineering/52-ai-workflow.md)。
