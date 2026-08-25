# CD-43 网络、序列化与回放

> 文档 ID：CD-43
> 单一事实源：控制面与对局面的序列化分工、传输选型、契约生成、回放内容与确定性边界
> 加载建议：改动协议、快照、重连、回放或跨端一致性时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第二、五、二十二条
> 相关：[CD-42 数据契约与 Rule VM](42-contracts-and-rulevm.md)、[CD-41 架构](41-architecture.md)、[CD-33 热修改与热发布](../30-ugc/33-hot-publish.md)、[CD-53 测试与 CI](../50-engineering/53-testing-and-ci.md)
> 派生自：初稿 v0.2 §37

## 1. 序列化分工

- 账号、草稿、内容、评分和匹配 API 使用 **JSON**；
- Fastify JSON Schema 是控制面契约的单一事实源，并生成 OpenAPI；
- GDScript 使用生成或半生成客户端并执行契约测试；
- 实时命令与快照使用**纯 GDScript 可实现的版本化二进制 Schema**，不绑定 ScenePath。
- 对局实时面 v1 帧布局（实现：`game/src/shared/protocol/match_frame_codec.gd`；字节序为 PackedByteArray 原生小端）：
  - 命令帧（定长 35 字节）：`[version:u8=1][type:u8=1][tick:s64][intent_id:u8][dx:s64][dz:s64][yaw_bam:s64]`。intent_id：1=Move / 2=Jump / 3=ResetToCheckpoint / 4=UseItem；非 Move 的 dx/dz/yaw 为保留字段，编解码均要求为零；`yaw_bam = -1` 表示省略。命令帧不带 slot，连接身份由服务端持有；
  - 快照帧（变长）：`[version:u8=1][type:u8=2][tick:s64][player_count:u8]`，随后每玩家 41 字节（`x/y/z/yaw_bam` s64×4 + `accepted_count:u8` + `finish_tick:s64`），再 `[crate_count:u8]` 与每箱 16 字节（`entity_id:s64` + `durability:s64`，0 为已毁）；
  - 解码拒绝：版本不符、未知类型、截断、尾随字节、保留字段非零；编码规范（同一逻辑帧恒得同一字节）；新增 intent id 属协议变更，旧解码器拒绝。

## 2. 传输

- 所有客户端一期统一通过 TLS WebSocket 网关接入；
- WebSocket 的可靠有序语义是一期共同基线；
- 实测确认队头阻塞影响后，再立项其他传输（ENet / WebRTC），不提前维护两套传输。

实现落点（2026-08-24）：网关（`backend/realtime-gateway/`）把 `/ws?ticket=` 升级请求交给 `TicketVerifier` 裁决，裁决携带上游对局地址；升级后连接与上游一对一绑定，双向原样转发帧（二进制/文本标志保留），任一侧关闭/出错即关闭另一侧。网关不解析帧内容。

实现落点（2026-08-25）：控制面是票据权威。`POST /match-sessions` 登记一场对局的 `ws`/`wss` 上游；`DELETE /match-sessions/:matchId` 注销该场并删除未用票据；`POST /match-sessions/:matchId/tickets` 签发一次性不透明票据（库内只存 SHA-256）；`POST /tickets/verify` 消费校验并返回上游。网关默认 `ControlPlaneTicketVerifier` 只调校验接口，不查库（宪法第二十一条）。未设置 `GATEWAY_DEV_UPSTREAM` 时不再把任意非空字符串当合法票据。过期窗口是开发期占位（`CONTROL_PLANE_TICKET_TTL_MS`），不锁产品值。MatchHost 拉起后等本场端口 TCP 可连再登记、停止后注销见 [CD-44 §3](44-deployment.md#3-进程隔离与租约)。玩家入场走控制面匹配 JSON（`POST /matchmaking/quick` / `POST /matchmaking/rooms` / 按码加入）；容量满时的 FIFO 与预计等待见 [CD-44 §3](44-deployment.md#3-进程隔离与租约)。Godot 客户端（`game/src/client/`）用注入式 HTTP 解释同一份 JSON，持票后连网关 `/ws?ticket=`，命令帧 tick 为 0，快照只跟从最新已解码帧（旧 tick 忽略、坏帧保留上一份）。`MatchSnapshotMap` 把最新玩家位姿映射为 1 米占位盒；`MatchCourseMap` 把本场编译拓扑的检查点垫、传送门源点与终点占用映射为 1 米占位盒（大厅默认编译与 MatchHost 相同的官方 `course_01`）。`MatchCrateMap` 用同一份编译拓扑的可破坏袋位姿画 1 米占位盒；v1 快照箱子只有 `entity_id` / `durability`，耐久 ≤0 或未列入则撤盒，快照不移动箱子。`MatchPortalLinkMap` 用同一份编译拓扑的 portal 源点与 `dest_*` 画 `two_way` / `one_way` gizmo 条；`one_way` 加方向点；dangling 已由编译省略，不画悬空标。不插值、不预测。不锁账号绑定、重连补票、名次、课程选择 API。端到端真网关冒烟仍是手动网络测试（CD-91 D.8）。

## 3. 回放与确定性

- 客户端保存短期输入和状态环形缓冲；
- 回放保存命令日志、种子、基础内容哈希、P0/P1 补丁序列、运行时版本和周期关键快照；
- 相同版本、种子和输入必须得到相同关键状态哈希；
- 定点 `SimulationCore` 追求跨平台可复现，但网络仍是**服务器权威快照模型**，不改为客户端确定性锁步；
- Godot 浮点物理与视觉节点不参与关键状态哈希。

实现落点（2026-08-24）：对局进程在本场端口监听 WebSocket（`match_server.gd`），连接经 `MatchRealtime` 映射到槽位（按需占用最小空槽、断开释放、满员拒绝）；二进制命令帧（§1 布局）解码后 FIFO 排队，在服务端自己的 commit_tick 边界按到达顺序应用——命令帧里的 tick 只解码、不信任，服务端 tick 权威；每 2 个引擎 tick 广播一帧二进制快照（占位节奏，非产品快照频率，见 §4）。快照含全部已配置槽位（含未占用）与可破坏箱耐久。

## 4. 未锁定项

Tick 频率、输入发送频率、快照频率、插值窗口和对账阈值都由开发期实测决定，见 [CD-63](../60-plan/63-open-decisions.md)。

网络故障测试的执行方式与门禁状态见 [CD-53 §2.5](../50-engineering/53-testing-and-ci.md)。
