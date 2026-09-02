# CD-92 术语表

> 文档 ID：CD-92
> 单一事实源：项目专有术语的定义
> 加载建议：遇到不确定的术语时查阅
> 索引：[Confirmed-docs README](../README.md)
> 派生自：初稿 v0.2 附录 C

## 当前生效值

**术语以本表为准。** 本文件是专有名词定义的所有者；改定义只改本表，其它文档只链到这里。

## 1. 术语

| 术语 | 定义 | 详规 |
|---|---|---|
| AuthoringWorld | 可编辑的创作数据模型 | [CD-41](../40-technical/41-architecture.md) |
| SimulationWorld | 权威纯数据运行世界 | [CD-41](../40-technical/41-architecture.md) |
| PresentationWorld | Godot 表现节点世界 | [CD-41](../40-technical/41-architecture.md) |
| EditCommand | 对创作内容的可审计修改命令 | [CD-42](../40-technical/42-contracts-and-rulevm.md) |
| Preview Session | 允许快速热修改的测试会话 | [CD-32](../30-ugc/32-editor-and-preview.md) |
| Published Match | 内容版本锁定的公开对局 | [CD-33](../30-ugc/33-hot-publish.md) |
| SimulationBundle | 编译、验证和签名后的运行内容 | [CD-33](../30-ugc/33-hot-publish.md) |
| ContentHash | 某一不可变内容版本的字节哈希 | [CD-33](../30-ugc/33-hot-publish.md) |
| PatchHash | 运行中对局按顺序应用的不可变 P0/P1 补丁哈希 | [CD-33](../30-ugc/33-hot-publish.md) |
| MatchSetupState | 单局互设障碍产生的对局级状态，不进入内容发布系统 | [CD-22](../20-gameplay/22-bastion.md) |
| GameplayAssetVersion | 平台资产中影响玩法裁决的不可变版本（碰撞、占地、导航、挂点） | [CD-31](../30-ugc/31-ugc-principles.md) |
| Rule VM | 执行受限规则图的虚拟机 | [CD-42](../40-technical/42-contracts-and-rulevm.md) |
| gas | 规则执行预算 | [CD-42](../40-technical/42-contracts-and-rulevm.md) |
| 单局排名 | 只在当前对局内产生的名次或 MVP，不形成长期段位 | [CD-13](../10-product/13-account-and-session.md) |
| TRAPRUSH | 玩法一《机关狂奔》代号 | [CD-21](../20-gameplay/21-traprush.md) |
| BASTION | 玩法二《双塔要塞》代号 | [CD-22](../20-gameplay/22-bastion.md) |
| MatchHost | 管理 Godot MatchServer 子进程生命周期的监管进程 | [CD-44](../40-technical/44-deployment.md) |
| RealtimeGateway | 唯一公网 TLS WebSocket 入口，代理到内网 MatchServer | [CD-41](../40-technical/41-architecture.md) |
| Godot AI | 本项目唯一 Godot 主 MCP：GDScript 编辑器插件 + 本机 Python（uv）服务，MIT | [CD-51 §7](../50-engineering/51-dev-environment.md)、[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) |
| `_mcp_game_helper` | Godot AI 为编辑器试玩进程注入的 autoload；禁止进入已提交的 `project.godot` 与 MatchServer | [CD-51 §7.3](../50-engineering/51-dev-environment.md) |
| SharedCommand | 所有命令共用的 L0 信封（字段名单见 CD-42，不在此复述） | [CD-42](../40-technical/42-contracts-and-rulevm.md) |
| StateHasher | 关键状态的确定性 SHA-256 哈希器，供回放对账 | [CD-43](../40-technical/43-networking-and-replay.md) |
| BAM | 二进制角：一周 = 65536，用于权威朝向与三角函数索引 | [CD-42 §1.1](../40-technical/42-contracts-and-rulevm.md) |
