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

## 2. 传输

- 所有客户端一期统一通过 TLS WebSocket 网关接入；
- WebSocket 的可靠有序语义是一期共同基线；
- 实测确认队头阻塞影响后，再立项其他传输（ENet / WebRTC），不提前维护两套传输。

## 3. 回放与确定性

- 客户端保存短期输入和状态环形缓冲；
- 回放保存命令日志、种子、基础内容哈希、P0/P1 补丁序列、运行时版本和周期关键快照；
- 相同版本、种子和输入必须得到相同关键状态哈希；
- 定点 `SimulationCore` 追求跨平台可复现，但网络仍是**服务器权威快照模型**，不改为客户端确定性锁步；
- Godot 浮点物理与视觉节点不参与关键状态哈希。

## 4. 未锁定项

Tick 频率、输入发送频率、快照频率、插值窗口和对账阈值都由开发期实测决定，见 [CD-63](../60-plan/63-open-decisions.md)。

网络故障测试的执行方式与门禁状态见 [CD-53 §2.5](../50-engineering/53-testing-and-ci.md)。
