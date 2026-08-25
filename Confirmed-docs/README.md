# Confirmed-docs 索引

> 文档 ID：CD-INDEX
> 版本：v1.0（由 `Godot_UGC双玩法第一版策划案与技术方案初稿.md` v0.2 拆分而成）
> 日期：2026-08-20
> 状态：长期维护。本文件夹是本项目产品、技术、工程规范的唯一事实源。

## 1. 这个文件夹是什么

`Confirmed-docs/` 存放**已确认**的工作文档。所有决策在这里落地，其他地方的描述都不作数：

| 位置 | 地位 |
|---|---|
| `Confirmed-docs/` | 唯一事实源，长期维护 |
| `Godot_UGC双玩法第一版策划案与技术方案初稿.md` | 已退役，仅作历史归档，不再更新 |
| `early-docs/` | 早期调研依据，不构成决策 |
| `Godot引擎发展现状与AI游戏开发生态深度调研报告.md` | 外部调研参考 |

## 2. 怎么读（重要）

**常驻**：[CD-00 项目执行宪法](00-constitution/CONSTITUTION.md) + 本索引。任何任务都必须先加载这两份，合计约 250 行。

**按需**：其余文档只在任务命中时读取。禁止为了"了解背景"通读全部文档——这正是拆分本文档群要解决的问题。

每份文档头部都有 `单一事实源` 和 `加载建议` 字段，可据此判断是否需要打开。

## 3. 任务路由表

先看这张表决定读哪几份，再动手。

| 你要做的事 | 必读 | 通常还需要 |
|---|---|---|
| 改 UI、HUD、菜单、大厅布局 | CD-00 | [CD-12 产品结构](10-product/12-product-structure.md) |
| 调玩法数值、道具、机关、炮塔 | CD-00 | [CD-21 TRAPRUSH](20-gameplay/21-traprush.md) 或 [CD-22 BASTION](20-gameplay/22-bastion.md)、[CD-63 开发期决策清单](60-plan/63-open-decisions.md) |
| 改仿真核心、定点数、System | CD-00 | [CD-41 架构](40-technical/41-architecture.md)、[CD-42 数据契约与 Rule VM](40-technical/42-contracts-and-rulevm.md)、[CD-53 测试与 CI](50-engineering/53-testing-and-ci.md) |
| 改命令、快照、协议、回放 | CD-00 | [CD-43 网络与回放](40-technical/43-networking-and-replay.md)、CD-42 |
| 改 Component Schema、Rule VM 节点 | CD-00 | CD-42、[CD-31 UGC 原则](30-ugc/31-ugc-principles.md) |
| 改编辑器、EditCommand、Preview | CD-00 | [CD-32 编辑器与预览](30-ugc/32-editor-and-preview.md)、CD-31 |
| 改验证器、发布流水线、热生效 | CD-00 | [CD-33 热修改与热发布](30-ugc/33-hot-publish.md)、CD-31 |
| 改账号、登录、离线、单局结算 | CD-00 | [CD-13 账号与会话](10-product/13-account-and-session.md) |
| 改后端 API、数据库、网关、MatchHost | CD-00 | [CD-44 部署与容量](40-technical/44-deployment.md)、CD-41、[CD-14 数据与遥测](10-product/14-data-and-telemetry.md) |
| 搭建或修复开发环境 | CD-00 | [CD-51 开发环境](50-engineering/51-dev-environment.md) |
| 安装、关闭遥测或使用 Godot 主 MCP | CD-00 | [CD-51 §7](50-engineering/51-dev-environment.md)、[CD-52 §7](50-engineering/52-ai-workflow.md)、[ADR-0003](../docs/adr/0003-godot-mcp-selection.md) |
| 写测试、改 CI 门禁 | CD-00 | [CD-53 测试与 CI](50-engineering/53-testing-and-ci.md) |
| 判断当前该做什么、验收标准 | CD-00 | [CD-61 里程碑路线](60-plan/61-milestones.md) |
| 评估范围、平台、设备、商业化 | CD-00 | [CD-11 范围与平台](10-product/11-scope-and-platforms.md) |
| 想知道"某个设计为什么是这样" | — | [CD-91 决策记录](90-reference/91-decision-log.md) |
| 发现某件事没定过 | CD-00 | [CD-63 开发期决策清单](60-plan/63-open-decisions.md)、[CD-62 风险登记册](60-plan/62-risk-register.md) |
| 作为 AI Agent 接手任务 | CD-00 | [CD-52 AI 协作规范](50-engineering/52-ai-workflow.md) |
| 写本章真机步骤或按清单验收 | CD-00 | [CD-52 §3.2](50-engineering/52-ai-workflow.md)、[章节真机清单](../docs/runbooks/chapter-device-check.md) |
| 启用或调整多 Agent 并行 | CD-00 | [CD-52 §5](50-engineering/52-ai-workflow.md)、[ADR-0004](../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) |

## 4. 完整文档地图

### 00 常驻宪法

| ID | 文档 | 内容 |
|---|---|---|
| CD-00 | [CONSTITUTION.md](00-constitution/CONSTITUTION.md) | 26 条工程红线、决策优先级、未决事项处理方式 |

### 10 产品

| ID | 文档 | 内容 |
|---|---|---|
| CD-11 | [11-scope-and-platforms.md](10-product/11-scope-and-platforms.md) | 项目名称与命名规范、项目愿景、一期锁定边界、必做与不做、平台矩阵、设备与表现基线 |
| CD-12 | [12-product-structure.md](10-product/12-product-structure.md) | 大厅结构、玩法频道、内容发现与排序 |
| CD-13 | [13-account-and-session.md](10-product/13-account-and-session.md) | 在线规则、Guest 与注册、离线模式、单局排名 |
| CD-14 | [14-data-and-telemetry.md](10-product/14-data-and-telemetry.md) | 数据保留周期、遥测口径、可靠性语义 |

### 20 玩法

| ID | 文档 | 内容 |
|---|---|---|
| CD-21 | [21-traprush.md](20-gameplay/21-traprush.md) | 机关狂奔：定位、操作、地图传送、障碍、道具、单局流程、Edit 范围、网络基线 |
| CD-22 | [22-bastion.md](20-gameplay/22-bastion.md) | 双塔要塞：定位、战场结构、互设障碍、炮塔、波次与胜负、单局流程、Edit 范围、网络基线 |

### 30 UGC 与编辑

| ID | 文档 | 内容 |
|---|---|---|
| CD-31 | [31-ugc-principles.md](30-ugc/31-ugc-principles.md) | UGC 能力边界、内容与发布规则、资产版本、Schema 兼容、法律边界 |
| CD-32 | [32-editor-and-preview.md](30-ugc/32-editor-and-preview.md) | 三类编辑入口、编辑到预览链路、体验指标 |
| CD-33 | [33-hot-publish.md](30-ugc/33-hot-publish.md) | P0–P4 热修改等级、发布流水线、热生效与回滚边界、代码热更新禁区 |

### 40 技术

| ID | 文档 | 内容 |
|---|---|---|
| CD-41 | [41-architecture.md](40-technical/41-architecture.md) | 总体架构、三种世界、L0–L9 分层、仓库目录 |
| CD-42 | [42-contracts-and-rulevm.md](40-technical/42-contracts-and-rulevm.md) | Component Schema v1、Rule VM v1、命令模型与服务端处理管线 |
| CD-43 | [43-networking-and-replay.md](40-technical/43-networking-and-replay.md) | 序列化分工、传输、回放与确定性边界 |
| CD-44 | [44-deployment.md](40-technical/44-deployment.md) | 单区固定容量部署、会话租约、进程隔离、数据库所有权 |

### 50 工程

| ID | 文档 | 内容 |
|---|---|---|
| CD-51 | [51-dev-environment.md](50-engineering/51-dev-environment.md) | 工具选型与版本锁定、Windows 安装、Godot 项目设置、AI 环境烟测、Godot AI 安装与遥测开关 |
| CD-52 | [52-ai-workflow.md](50-engineering/52-ai-workflow.md) | 人机分工、任务循环、任务单模板、完整章节 PR 的人类真机步骤义务、AI 使用规则、多 Agent 与协作约定、Godot AI MCP 使用边界 |
| CD-53 | [53-testing-and-ci.md](50-engineering/53-testing-and-ci.md) | 测试原则与层级、性能观察参考、CI 门禁、Definition of Done、首批测试用例 |

### 60 计划与风险

| ID | 文档 | 内容 |
|---|---|---|
| CD-61 | [61-milestones.md](60-plan/61-milestones.md) | M0–M7 里程碑、阶段退出条件、首个可运行验收场景 |
| CD-62 | [62-risk-register.md](60-plan/62-risk-register.md) | 已接受与已治理风险登记册 |
| CD-63 | [63-open-decisions.md](60-plan/63-open-decisions.md) | 明确延期的决策、跳过项、正式运营前阻断清单 |

### 90 参考

| ID | 文档 | 内容 |
|---|---|---|
| CD-91 | [91-decision-log.md](90-reference/91-decision-log.md) | 访谈决策追踪矩阵，记录每项选择的来源与覆盖关系 |
| CD-92 | [92-glossary.md](90-reference/92-glossary.md) | 术语表 |

## 5. 单一事实源归属表

同一个事实只允许有一个"所有者"文档。其他文档需要提到它时**只能链接，不能复述参数**。

| 事实类别 | 所有者 |
|---|---|
| 项目名称与命名规范 | CD-11 |
| 一期做什么 / 不做什么 | CD-11 |
| 平台矩阵、设备基线、帧率目标、商业化 | CD-11 |
| 大厅与内容发现 | CD-12 |
| 账号、Guest 生命周期、离线规则、单局排名 | CD-13 |
| 数据保留天数、遥测、备份与可靠性承诺 | CD-14 |
| TRAPRUSH 全部玩法规则 | CD-21 |
| BASTION 全部玩法规则 | CD-22 |
| 创作者能做什么 / 不能做什么、发布与撤回规则 | CD-31 |
| 编辑器形态与预览行为 | CD-32 |
| 热修改等级、发布流水线、回滚 | CD-33 |
| 模块分层、目录结构、进程拓扑 | CD-41 |
| Component Schema、Rule VM、命令字段 | CD-42 |
| 协议编码、传输、回放内容 | CD-43 |
| 容量、租约、部署形态、数据库所有权 | CD-44 |
| 工具版本、安装步骤、项目设置、Godot 主 MCP 与其遥测开关 | CD-51 |
| AI 权限边界、工作流、完整章节 PR 的人类真机步骤义务与 Godot AI 使用边界 | CD-52 |
| 测试层级、CI 门禁、DoD、性能观察值 | CD-53 |
| 里程碑与验收 | CD-61 |
| 风险状态 | CD-62 |
| 未决事项 | CD-63 |
| 决策来源与历史 | CD-91 |
| 术语定义 | CD-92 |

## 6. 维护规则

1. **改动先找所有者**。新决策写进所有者文档，不要在方便的地方顺手加一段。
2. **决策必须留痕**。任何新拍板或推翻旧决策，同时在 CD-91 追加一行，注明覆盖关系。
3. **红线变更走宪法**。只有影响全局不变量的决策才写入 CD-00，且必须由人类明确批准。
4. **参数不进宪法**。CCU、天数、时长这类可调参数留在所有者文档，宪法只写不变量并链接。
5. **冲突裁决顺序**：CD-00 宪法 > 所有者文档 > 其他文档中的引用性描述 > 已退役的初稿文档。
6. **未决事项不许默认**。CD-63 中的条目没有默认答案，AI 不得把示例或推荐项当成已确认结论。
7. **新增文档必须登记**。加文档就要更新第 4、5 节，否则视为未生效。
