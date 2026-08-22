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
| `CreatorTools` | 共用编辑器外壳、玩法专用工具面板、EditCommand、Undo/Redo、独立持续 Preview |
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

上面是目标形态，不是当前完成度。截至 M1 阶段 B 弧 B（单人灰盒整段可回放）合入，`game/src/shared/` 已有稳定 ID、命令信封、领域事件、状态哈希与定点运算；`game/src/simulation/` 已有 Tick 计数的 SimulationWorld、确定性 RNG、直立胶囊重叠、XZ/Y 目的地阻挡、静态 AABB、沿半径的离散扫掠、占用感知 try_set_pose、关闭静态盒阻挡、静态盒重叠查询、重叠盒枚举、胶囊占用查询、候选姿态占用查询、仅 solid 占用查询、调用方 support_dy 的固体支撑探测、try_move_y_until_blocked（最后未阻挡 Y 样本）、try_move_xz_until_blocked（最后未阻挡 XZ 样本，剩余位移丢弃）、只读掉出范围查询（is_below_min_y / is_above_max_y / is_outside_xz，未知 id 为 false）、is_volume_blocked（无实体 id 的体积占用）、SimReplayBuffer 命令回放带、SimSnapshotRing 周期关键快照环与状态哈希；`game/src/games/traprush/` 已有有序检查点、传送链（跳数由调用方传入）、MoveIntent / JumpIntent / ShoveIntent / InteractIntent / UseItemIntent 解码、检查点复活落点、推击冷却门闩、IntentStepper（Move 与接地 Jump 均直到阻挡；Jump 仅在调用方 support_dy 的 solid 支撑时起跳）、尺度 1 的 Destructible 耐久、ShoveApply 用 try_move_xz_until_blocked 推开目标、PortalLanding 在出口空闲时落地、占用则等待、GrayboxCourse 单人灰盒夹具、PadAccept 占用检查点垫、灰盒垫盒接线、灰盒命令磁带、灰盒周期关键快照、调用方周期的开关阻挡盒、重叠时的 InteractIntent 伤害、调用方 reach 的 UseItemIntent 爆破 stub、TraprushFinishAccept、灰盒终点垫（non-solid）与 finish_tick 哨兵 -1（不入 hash_state）、GrayboxCourse.try_apply_fall（委托 try_move_y_until_blocked，不入带不 tick）、try_commit_tick(fall_dy)（先 fall 再 tick）、try_reset_if_out_of_range（调用方边界，出界回最近检查点落点，不入带不 tick）、GrayboxAcceptance 整段可回放夹具（同一输入覆盖 CD-61 §4.1 除 2p/名次外的检查点、传送、周期机关、破坏、爆破与冲线，得到相同磁带哈希、状态哈希、快照哈希与 finish_tick；检查点/传送/冲线仍用占用 + set_pose，不发明寻路；磁带仍不回放进 world）（尚无把命令磁带回放进 SimulationWorld 的夹具；2 人 Headless 与单局名次属 M3）；`backend/contracts/schemas/` 已有对应的 L0 JSON Schema，由 `tools/content-validator/` 做正反例；`tools/redline-scanner/` 扫描宪法第五、七、十一条的可机械化红线；`.cursor/worktrees.json` 负责隔离工作区 setup；`.cursor/hooks.json` + `tools/shell-guard/` 拦向 `main` 的 git 写操作；`.cursor/agents/` 有六份角色定义（无审查 Agent）；`.cursor/BUGBOT.md` 给 PR 侧 Bugbot 提供门禁 2 红线与 CD-00 链接，**不是合并门禁**。Component Schema v1 的代码与 JSON Schema、OpenAPI、障碍/道具/推击冲量，以及 `bot-runner/` / `replay-inspector/` 仍待后续任务。
