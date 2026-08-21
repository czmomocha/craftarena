# AGENTS.md

本文件是本仓库对所有 AI Agent 与人类协作者的最高工程规则入口。

第三节是 [CD-00 项目执行宪法](Confirmed-docs/00-constitution/CONSTITUTION.md) 的镜像，由宪法第一条要求在项目初始化时同步写入仓库根目录。**冲突时以 CD-00 为准**；修改 CD-00 必须同步修改本文件。

## 1. 最小上下文

任何任务开始前只加载两份文档，合计约 250 行：

1. [CD-00 项目执行宪法](Confirmed-docs/00-constitution/CONSTITUTION.md)
2. [Confirmed-docs 索引](Confirmed-docs/README.md)

其余文档按索引第 3 节的任务路由表**按需读取**。禁止为了"了解背景"通读全部文档。

`Confirmed-docs/` 是本项目产品、技术与工程规范的唯一事实源。`early-docs/`、`early-concepts/` 只是历史归档与早期调研，不构成任何决策依据，不得被引用。

## 2. 标准任务循环

```text
读取 AGENTS.md 与路由表命中的文档
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

不得用"代码看起来正确"代替运行证据。完整分工、任务单模板与提交边界见 [CD-52](Confirmed-docs/50-engineering/52-ai-workflow.md)。

## 3. 二十六条红线

### 第一条：范围优先

一期只做 [CD-11 范围与平台](Confirmed-docs/10-product/11-scope-and-platforms.md) 列出的纵向切片。任何新增系统必须说明它服务于哪个一期验收项，否则延期。

### 第二条：服务器唯一权威

位置确认、命中、道具效果、障碍破坏、金币、建造、伤害、冲线和胜负均由服务端裁决。客户端只提交意图。

### 第三条：UGC 永远不可信

任何来自客户端、创作者、AI 和外部文件的内容都必须经过 Schema、语义、预算、安全和仿真验证。

### 第四条：UGC 是数据，不是代码

禁止玩家上传或执行 GDScript、C#、GDExtension、原生库和任意 PCK。规则表达只能使用白名单 Rule VM。

### 第五条：仿真与表现分离

`SimulationWorld` 不依赖 SceneTree，核心数值使用定点整数；Godot Node 只负责输入适配、受控查询和表现映射。禁止把 Node 或 Godot 浮点物理当作权威数据库。

### 第六条：版本不可变

已发布基础内容不可覆盖，只能发布新版本。公开对局开局锁定基础内容哈希，运行中不得替换 P2/P3；P0/P1 必须以不可变补丁序列在玩法安全边界应用并进入回放。等级定义见 [CD-33](Confirmed-docs/30-ugc/33-hot-publish.md)。

### 第七条：客户端技术栈固定

使用 Godot 4 Standard + GDScript。禁止创建 `.cs` / `.csproj`。Compatibility 是共同渲染基线。共享玩法与编辑核心禁止 GDExtension；平台适配层只有在 Web 存在空实现时可例外。

### 第八条：先验证再优化

先实现服务器权威、定点仿真和正确回放，再加入预测；出现可观察瓶颈后再做复杂优化。不得把 GDExtension 引入共享核心。

### 第九条：小步可验证

每个任务必须有明确输入、输出和验收测试。一次变更只解决一个主要问题，禁止无关重构。

### 第十条：测试是完成条件

AI 或人类不能以"实现完了"代替测试证据。没有执行结果的测试等于没有测试。

### 第十一条：AI 不得猜 API

不确定的 Godot API 必须查官方文档或项目内已验证用法。禁止生成 Godot 3 语法。

### 第十二条：场景修改必须可撤销

大型 `.tscn` 修改优先通过 MCP、Editor API 和 UndoRedo。禁止无上下文地重写整个场景文件。

### 第十三条：热发布必须可回滚

任何内容激活都必须保留上一签名基础版本。P0/P1 全量运行时补丁必须能由进程内技术阈值自动回滚；禁止原地覆盖。

### 第十四条：离线结果永不回写

离线模式不发结算写请求。恢复在线后也不补传离线战绩和奖励。

### 第十五条：单局排名不扩张

一期只提供单局名次和 MVP。任何 MMR、段位、赛季、长期排行榜需求必须重新立项。

### 第十六条：单区固定容量

一期不引入跨区、弹性扩容和观战。一局一 Headless 进程，由 MatchHost 续租和回收，容量不足时排队。具体参数见 [CD-44](Confirmed-docs/40-technical/44-deployment.md)。

### 第十七条：性能有预算

实体数、规则 gas、查询次数、包体和单任务资源必须有安全上限，超限 UGC 在发布前拒绝。工程性能数值当前只作观察参考，不得虚构为自动回归门禁。

### 第十八条：高风险操作需要人类门禁

以下操作必须由人类确认：

- Schema 破坏性变更；
- 网络协议不兼容变更；
- 数据删除和迁移；
- 新依赖和许可证；
- 安全边界变化；
- AI 发起的提交、推送、部署、发布或回滚；
- 管理员终止对局；
- 项目范围和平台变更。

### 第十九条：文档随代码变化

命令、Schema、规则节点、目录、运行方法和验收标准变化时，同一任务必须更新对应的所有者文档。

### 第二十条：可解释性优先

人类无法理解、AI 无法解释、测试无法证明的实现不得进入主线。

### 第二十一条：数据库单一所有者

一期只有 Fastify 控制面可以直接读写数据库。网关、MatchHost 和 Godot MatchServer 必须通过 API 或事件交互，为后续迁移保留边界。

### 第二十二条：公网进程不直连

客户端只能连接 TLS WebSocket 网关。Godot MatchServer 使用内网临时端口，不直接暴露公网。

### 第二十三条：类型严格度分区

`shared/`、`simulation/`、`ugc/`、`server/` 必须静态类型且警告视为错误；UI 和工具层可有限使用 `Variant`，进入核心边界前必须完成 Schema 校验。

### 第二十四条：测试声明必须真实

网络故障测试是临时人工检查，性能值是观察参考，外部真人测试尚未执行。任何 AI 或人类不得把这些内容表述为稳定自动门禁或已验证能力。

### 第二十五条：测试环境风险不等于产品能力

开放注册、无注册保护、公开未过滤用户名、自动公开 UGC、无主动作弊处置、无监控、无备份和无 UGC 授权条款均为当前明确风险，清单见 [CD-62](Confirmed-docs/60-plan/62-risk-register.md)。正式公开运营前必须重新立项评审。

### 第二十六条：文档单一事实源与索引先行

每类事实只有一个所有者文档，归属表见 [索引第 5 节](Confirmed-docs/README.md#5-单一事实源归属表)。禁止在非所有者文档中复述参数，只允许链接。新决策先落所有者文档，再在 [CD-91](Confirmed-docs/90-reference/91-decision-log.md) 追加来源。

## 4. 决策优先级

冲突时按以下顺序裁决：

```text
安全与权威正确性
> 当前版本内的数据一致性与可回滚
> 可复现与可测试
> 已拍板产品范围
> 迭代速度
> 性能优化
> 视觉效果
```

该顺序**不能**自动覆盖 [CD-62](Confirmed-docs/60-plan/62-risk-register.md) 中已明确记录的风险接受项。与之冲突时必须由人类重新拍板，AI 不得自行"修正"产品决策。

## 5. 遇到未决事项

1. 先查 [CD-63 开发期决策清单](Confirmed-docs/60-plan/63-open-decisions.md)。若事项在清单内，说明它**没有默认答案**，禁止自行选定。
2. 再查 [CD-91 决策记录](Confirmed-docs/90-reference/91-decision-log.md)，确认是否已有被覆盖的历史选择。
3. 仍未决时，创建 Issue 或 `docs/adr/` 下的 ADR 并请求人类拍板，给出选项与推荐，但不实现。
4. 文档中的示例表格（道具、炮塔、单位、障碍等）都是原型候选，不是锁定清单。

## 6. 仓库目录

目录结构的所有者文档是 [CD-41 §5](Confirmed-docs/40-technical/41-architecture.md#5-monorepo-目录)，改动目录必须先改那里。

| 路径 | 内容 |
|---|---|
| `Confirmed-docs/` | 产品与工程规范的唯一事实源 |
| `.github/workflows/` | CI；实际生效的门禁范围见 CD-53 §4.1 |
| `game/` | Godot 4 工程；`src/` 下按 L0–L5 分层 |
| `backend/` | 控制面、实时网关、MatchHost、接口契约 |
| `tools/` | DevLauncher、BotRunner、内容验证器、回放检查器 |
| `infra/` | Compose 与腾讯云部署配置 |
| `docs/` | 实现级 ADR、计划、运维手册 |
| `early-docs/` | 历史归档，**不构成决策依据** |
| `early-concepts/` | 早期概念图，**不入库**，只在本地保留 |

`game/src/` 中 `shared/`、`simulation/`、`ugc/`、`server/` 四个目录受第二十三条约束：静态类型且警告视为错误。

## 7. 语言与提交约定

- 技术文档、Issue 和 ADR 以中文为主；
- 代码标识符、协议字段和 Git 提交信息使用英文；
- 文件命名使用 `snake_case`；
- 提交遵循带 scope 的 Conventional Commits；
- PR 合并必须 CI 全绿并至少获得一次人类批准，AI 审查不能替代人类。

> macOS 默认文件系统大小写不敏感，而 Linux CI 敏感。引用路径时大小写必须与磁盘上完全一致，否则在 mac 上能跑、进 CI 才失败。

## 8. 命令

环境要求与安装步骤的所有者文档是 [CD-51](Confirmed-docs/50-engineering/51-dev-environment.md)。**实际可执行的固定命令写在 [README.md](README.md)**，禁止每个 Agent 自己猜命令行参数。Godot 主 MCP 的安装、遥测开关与接入签字见 [CD-51 §7](Confirmed-docs/50-engineering/51-dev-environment.md) 与 [Godot AI 接入烟测](docs/runbooks/godot-ai-mcp-setup.md)；使用边界见 [CD-52 §7](Confirmed-docs/50-engineering/52-ai-workflow.md)。
