# CD-44 单区固定容量部署

> 文档 ID：CD-44
> 单一事实源：部署形态、容量与排队规则、会话租约与回收、进程隔离、数据库所有权与访问约束
> 加载建议：改动部署、容量、匹配排队、MatchHost、租约或数据库访问路径时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第十六、二十一、二十二条
> 相关：[CD-41 架构](41-architecture.md)、[CD-14 数据与遥测](../10-product/14-data-and-telemetry.md)、[CD-62 风险登记册](../60-plan/62-risk-register.md)
> 派生自：初稿 v0.2 §38

## 1. 部署形态

一期采用最简单可控的部署，只有"本地 + 长期测试"两个长期环境，不存在正式 Production。

```text
腾讯云香港长期测试环境
├─ Fastify Control Plane
│  └─ SQLite（仅此服务直接读写）
├─ TypeScript Realtime Gateway
├─ MatchHost
│  └─ 每场对局启动一个 Godot Headless 子进程
├─ COS（内容包、资源、回放）
└─ 文件 / 结构化日志
```

## 2. 容量与排队

- 不跨区；
- 不做自动扩缩容；
- 按 **50 CCU** 固定容量设计；
- 容量满时进入 FIFO 队列并显示预计等待时间；
- 编辑但未进入对局的用户不占 MatchServer 名额；
- 支持快速游戏与房间码；
- 不做技能匹配；
- 不做观战连接。

## 3. 进程隔离与租约

- 一场对局一个 Godot Headless 进程，避免 UGC 异常影响其他房间；
- MatchHost 分配内网端口、限制资源、处理租约并回收；
- 默认会话租约 **30 分钟**；
- 只有**通过校验并改变权威状态的真人命令**可续租；心跳、重复命令、被拒命令和机器人流量不得续租；
- 连续 **10 分钟**无此类输入则关闭进程；
- 每场对局进程异常时尽力保留最后关键快照和日志。

实现落点：MatchHost（`backend/match-host/`，含租约/端口/回收与 `GodotProcessLauncher`）与对局进程入口（`game/src/server/match_server.gd`，课程→`TraprushMatchSession`→引擎节奏 tick→心跳 JSON→`--max-ticks` 自退/坏配置 exit 1）。对局进程实时回路已落地（2026-08-24）：进程在本场端口监听 WebSocket（`--bind` 占位 0.0.0.0，公网暴露由部署层与网关拓扑阻止），命令/快照走 [CD-43 §1](43-networking-and-replay.md#1-序列化分工) 二进制帧，槽位/排队/广播语义见 [CD-43 §3](43-networking-and-replay.md#3-回放与确定性) 实现落点。运行入口是 `--scene res://src/server/match_server.tscn`：`-s` 直跑 extends Node 的脚本不会实例化场景（4.7 表现为主循环不启动）。控制面已能登记对局上游并签发入场票据（见 [CD-43 §2](43-networking-and-replay.md#2-传输)）。MatchHost 拉起对局进程后对本场端口做 TCP 探测（连 `127.0.0.1`，与广告主机无关），可连后再调用控制面 `POST /match-sessions` 登记同一 `matchId` 与 `ws` 上游（广告主机默认 `127.0.0.1`，可由 `MATCH_HOST_UPSTREAM_HOST` 覆盖；超时与轮询间隔是实现默认，不是产品锁定值）。listen 超时、进程先退出或登记失败则杀掉子进程，`POST /matches` 回 502。MatchHost 不查库（宪法第二十一条）。停止对局前若心跳带有全员冲线结算记录，先 `POST /match-sessions/:matchId/settlement` 写库（409 视为已写入）；写失败则本场不注销并回 502。随后调用控制面 `DELETE /match-sessions/:matchId` 注销同一场；控制面同时删除该场未用票据，结算记录保留。控制面 404 视为已经注销。注销失败时本地进程已停，显式 `DELETE /matches/:id` 回 502。控制面匹配入口（2026-08-25）：`POST /matchmaking/rooms` 让 MatchHost 拉起一场并写入房间码后签发首张票据；`POST /matchmaking/rooms/:roomCode/join` 按码加入（大小写不敏感）；`POST /matchmaking/quick` 加入最旧未满且赛道相同的公开房，没有则拉起新场。快速游戏与建房 JSON 可带官方赛道 id（空 body 默认 `course_01`）；按码加入走房内已锁课程。席位随 MatchHost 登记写入，已签发票据数达到席位即满。MatchHost 容量满时控制面把快速游戏/建房写入 FIFO，回 202 与位次、预计等待；`GET /matchmaking/queue/:token` 查询，`DELETE` 取消。会话注销后按 FIFO 出队：快速游戏可进最旧未满且赛道相同的公开房，建房只拉新场。预计等待 = 当前位次 × `CONTROL_PLANE_QUEUE_SLOT_ESTIMATE_MS`，队列 TTL 为 `CONTROL_PLANE_QUEUE_TTL_MS`，二者都是开发期占位，不是产品局时或锁定窗口。房间码字表与长度是开发期占位，不是产品锁定值。控制面只调 MatchHost HTTP，MatchHost 对控制面仍回 503，不查库。Godot 客户端大厅消费同一套匹配/队列 JSON 并经网关入场，见 [CD-43 §2](43-networking-and-replay.md#2-传输) 与 [CD-12 §1](../10-product/12-product-structure.md#1-入口结构)。快照表现映射见 [CD-43 §2](43-networking-and-replay.md#2-传输)。断线后控制面补发同席位新票，网关把 `slot` 接到上游 URL，见 [CD-43 §2](43-networking-and-replay.md#2-传输)。MatchHost `POST /matches` 接受同一官方 id 与本场 `seats`（1～8，省略为 2），映射成 Godot `--course=` / `--players=` 后按同一人数登记。快速游戏只进同课同人数未满房；队列记住 `seats`。不锁账号绑定。对局进程 boot 把跳跃/支撑/道具伤害与触达套成与 Preview 相同的占位值（官方 `course_01` 出生点 UseItem 可打碎 +Z 箱；Jump 在官方赛道仍为空操作）。不锁产品数值。

## 4. 数据库所有权

- SQLite 是测试期方案，PostgreSQL 为产品化迁移目标；
- 网关、MatchHost 和 Godot **不得直接访问 SQLite**，只能调用控制面 API 或提交事件；
- 迁移触发条件与托管方式未锁定，见 [CD-63](../60-plan/63-open-decisions.md)。

## 5. 运维能力缺口（已接受）

- 回放数据先存储，播放 UI 二期再做；
- 不做备份、主动可用性探测、仪表盘和告警。

对外表述必须遵守 [CD-14 §3](../10-product/14-data-and-telemetry.md) 的可靠性语义。
