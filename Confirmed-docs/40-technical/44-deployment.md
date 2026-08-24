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

实现落点：MatchHost（`backend/match-host/`，含租约/端口/回收与 `GodotProcessLauncher`）与对局进程入口（`game/src/server/match_server.gd`，课程→`TraprushMatchSession`→引擎节奏 tick→心跳 JSON→`--max-ticks` 自退/坏配置 exit 1）。进程内 socket 监听仍待后续章节。

## 4. 数据库所有权

- SQLite 是测试期方案，PostgreSQL 为产品化迁移目标；
- 网关、MatchHost 和 Godot **不得直接访问 SQLite**，只能调用控制面 API 或提交事件；
- 迁移触发条件与托管方式未锁定，见 [CD-63](../60-plan/63-open-decisions.md)。

## 5. 运维能力缺口（已接受）

- 回放数据先存储，播放 UI 二期再做；
- 不做备份、主动可用性探测、仪表盘和告警。

对外表述必须遵守 [CD-14 §3](../10-product/14-data-and-telemetry.md) 的可靠性语义。
