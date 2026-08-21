# CD-53 测试、性能观察与 CI 门禁

> 文档 ID：CD-53
> 单一事实源：测试优先级与强度策略、七类测试层级、性能观察参考值、CI 门禁分级、Definition of Done、首批测试用例
> 加载建议：写测试、改 CI、判断任务是否完成时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第十、十七、二十四条
> 相关：[CD-52 AI 协作规范](52-ai-workflow.md)、[CD-43 网络与回放](../40-technical/43-networking-and-replay.md)、[CD-61 里程碑路线](../60-plan/61-milestones.md)、[CD-62 风险登记册](../60-plan/62-risk-register.md)
> 派生自：初稿 v0.2 §48–§52、附录 B

## 1. 测试原则

优先级：

```text
权威正确性
> UGC 安全
> 可回放与可复现
> Edit / Hot Publish 可靠性
> 网络鲁棒性
> 性能
> 表现质量
```

AI 生成代码必须比普通手写代码有**更强的自动化证据**，因为其产出速度更快，也更容易快速放大错误。

### 1.1 不对称强度策略

- 仿真、命令、Schema、Rule VM、内容编译和热发布坚持**测试先行**；
- 纯表现与 UI 可先实现，再补烟测和视觉检查；
- 网络故障场景只做临时人工测试，不设固定频率；
- 不建立自动性能回归门禁，出现明显问题后再分析优化；
- 纵向切片期间不组织外部真人试玩，由项目负责人按清单签署玩法结论。

> 后四项是明确接受的项目风险，**不能**在对外材料中描述为"已充分验证"。

## 2. 测试层级

### 2.1 静态与 Schema 测试

- GDScript 语法和类型错误；
- 禁止 API 扫描；
- Schema 正反例；
- 字段范围和默认值；
- 引用完整性；
- 稳定 ID 重复；
- 规则图类型；
- 无界循环、递归和超预算检测；
- 内容版本兼容性。

### 2.2 单元测试

- 固定 Tick；
- RNG；
- 移动和检查点；
- 传送可达性与循环检测；
- 障碍耐久和重生；
- 道具效果；
- 塔锁敌优先级；
- 伤害、减速和增益；
- 金币和波次；
- 单局排名；
- 命令权限与频率限制；
- EditCommand 反向命令。

### 2.3 集成测试

- AuthoringWorld 编译为 SimulationBundle；
- Preview 安全 Tick 应用；
- Headless 服务端与多个客户端；
- 断线重连；
- 内容下载和哈希校验；
- P2/P3 新版本只影响新房，P0/P1 按补丁规则进入运行房；
- 回滚后新房恢复旧版本；
- 离线模式不产生在线写请求。

### 2.4 回放测试

- 相同版本、种子和输入得到相同关键状态哈希；
- 定点位置、计时、经济与伤害在客户端和服务器测试夹具中一致；
- TRAPRUSH 传送、破坏和冲线可复现；
- BASTION 障碍布置、建塔、镜像波次和胜负可复现；
- 版本不匹配时拒绝播放；
- 周期关键快照可以恢复并继续执行；
- P0/P1 PatchHash 按原顺序重放。

### 2.5 网络仿真（人工清单，非门禁）

网络故障测试**不进入自动 CI 门禁**，也不设固定执行节奏。有需要时使用统一人工清单覆盖：

- 延迟；
- 抖动；
- 丢包；
- 乱序；
- 重复包；
- 短时断线；
- 基线丢失；
- 恶意高频命令；
- 篡改序号、Tick、目标 ID 和 Payload。

香港真实环境形成样本后，再根据 P90/P95 数据决定是否建立自动门禁，以及是否为 TRAPRUSH 引入 ENet/WebRTC。当前选择只保证"有检查清单"，**不保证稳定回归覆盖**。

### 2.6 UGC 安全测试

- 超大实体数；
- 无限生成；
- 传送循环；
- 不可达终点；
- 塔防路径彻底封死；
- 深层嵌套；
- 引用环；
- 压缩炸弹；
- 非法资源类型；
- 越权组件和字段；
- 规则 gas 耗尽；
- 恶意字符串和异常 Unicode；
- 旧 Schema 内容迁移。

### 2.7 Edit 与热发布测试

- 连续 Undo/Redo 100 次；
- BatchCommand 原子性；
- Preview Patch 成功与失败回滚；
- 编辑器异常退出后草稿恢复；
- 发布中途进程退出；
- 签名失败；
- `latest` 指针原子切换；
- 新旧对局并存；
- 一键回滚；
- 被下架内容不能创建新房；
- 已开始对局仍能按锁定版本完成。

### 2.8 平台测试

- Windows 键鼠；
- Android 触控、切后台、恢复；
- iOS 触控、切后台、恢复；
- 分辨率和安全区；
- Compatibility 渲染一致性；
- Windows/macOS Chrome、Edge 最新两个大版本的 Web 单线程和资源加载；
- 微信包体、文件系统和 API 适配；
- 中端基线设备的帧率与内存，设备与帧率目标见 [CD-11 §8](../10-product/11-scope-and-platforms.md)。

## 3. 性能观察参考

一期**不建立固定性能基准或自动阻断门禁**。以下值只用于埋点和问题定位，不能作为当前已保证的发布指标；出现明显卡顿、服务器超载或用户反馈后再做专项分析。

### 3.1 TRAPRUSH

| 指标 | 目标 |
|---|---|
| 服务端 Tick | 待纵向切片实测决定 |
| 8 人与典型 UGC 实体量的 Tick P99 | 持续记录，不设当前门禁 |
| 客户端观察帧率 | 见 [CD-11 §8](../10-product/11-scope-and-platforms.md) |
| 单客户端快照带宽 | 以压测确定，必须持续记录 P95/P99 |
| 弱网 | 香港真实样本形成后定义 |
| Edit 到双人预览 | ≤ 30 秒 |

### 3.2 BASTION

| 指标 | 目标 |
|---|---|
| 服务端 Tick | 待纵向切片实测决定 |
| 典型高兵潮 Tick P99 | 持续记录，不设当前门禁 |
| 塔锁敌 | 使用空间网格，不允许全量 O(N×M) 扫描 |
| 弱网 | 香港真实样本形成后定义 |
| 同 Archetype 单位 | 批量更新与批量增量编码 |
| Edit 到双人预览 | ≤ 30 秒 |

## 4. CI 门禁

### 4.1 每次变更

- 语法与类型检查；
- `shared/`、`simulation/`、`ugc/`、`server/` 警告视为错误；
- 受影响单元测试；
- Schema 验证；
- 禁止 API 和依赖检查；
- 编辑文件的 linter 诊断；
- 功能 PR 自动生成独立公开 Web 预览。

#### 当前实现状态

上面是本项目的目标门禁清单，不是已经生效的清单。`.github/workflows/ci.yml` 在 M0 只启用了其中一个子集，已于 2026-08-20 在 GitHub Actions 的 Linux runner 上首次跑绿：

| 门禁项 | 状态 | 实现方式 |
|---|---|---|
| 语法与类型检查 | 已启用 | 逐个 `.gd` 文件跑 `--check-only`；`backend/`、`tools/` 跑 `tsc --noEmit` |
| 核心目录警告视为错误 | 已启用 | GDScript 由 `project.godot` 全局配置（[ADR-0001](../../docs/adr/0001-strict-gdscript-typing-gate.md)）并由 GUT 断言守护；TypeScript 由 `tsconfig.json` 的 strict 系列保证 |
| 单元测试 | 已启用（全量，非"受影响"） | GUT 跑 `res://tests/unit`；后端跑 `node --test` |
| Schema 验证 | 已启用（仅 L0 信封） | `tools/content-validator/` 对 `backend/contracts/schemas/` 做正反例，并由根目录 `npm test` 收集。未覆盖 Component Schema / Rule VM。未引入 Ajv（新依赖属宪法第十八条人类门禁） |
| 禁止 API 和依赖检查 | 已启用（宪法红线子集） | `tools/redline-scanner/` + CI step `npm run redline-scan`：`simulation/` 禁 SceneTree/`float`、共享核心禁 `.gdextension`、`game/src` 禁 Godot 3 高信号符号、`game/` 禁 `.cs`/`.csproj`/`.sln`（GUT 仍保留同一条）。Godot 3 黑名单是[官方更名表](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html)的高信号子集，不是穷尽。第二十三条仍由 ADR-0001 覆盖 |
| 编辑文件的 linter 诊断 | 未实现 | 依赖开发机 IDE，未进 CI |
| PR Web 预览 | 未实现 | 等 Web 导出与沙盒环境落地 |
| Godot AI MCP | **不进 CI** | 只服务本机打开的编辑器；Headless / GUT / `npm test` 仍是门禁。不得把 `test_run` / `McpTestSuite` 写成自动回归。接入与生产级启用见 [CD-51 §7](51-dev-environment.md)、[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) |
| Bugbot | **非门禁** | 已拍板引入（[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 6）。本地 `/review-bugbot` 已于 2026-08-21 跑过。`.cursor/BUGBOT.md` 已入库。**GitHub PR 侧已跳过**（Cursor SCM 安装对不上）；合入继续靠本表已启用的 CI + [§4.5](#45-pr-合并规则) 人类批准。不得描述为已覆盖的合并门禁。配置见 [CD-52 §5.2](52-ai-workflow.md) |

按宪法第二十四条，**未在本表标为"已启用"的项目不得在任何材料中描述为已覆盖**。新增门禁时同时改本表和 workflow。

另有一条平台缺口：CI 目前只跑 Linux runner。CD-51 §1 规划的自托管 Windows Runner 尚未搭建，因此 **Windows 与 macOS 上的引擎行为都没有任何自动回归**，只能靠开发机按 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) 人工执行。macOS 上 `--check-only` 在类型错误时退出码仍为 0，本地门禁看日志；Linux CI 仍按退出码收集失败，这条失败路径未在桌面开发机上按 Linux 复测。

### 4.2 每日

- 全量 GUT；
- Headless 多客户端集成；
- 固定回放；
- UGC Golden Content。

### 4.3 每周

- 依赖与许可证变化检查；
- Windows/Android 导出烟测；
- 内容发布和回滚演练。

### 4.4 发布候选

- 全量平台烟测；
- 零阻断级错误；
- 回放一致；
- 新旧内容版本并存；
- 回滚演练通过；
- 项目负责人完成玩法清单签署；
- 人类完成安全与发布确认。

### 4.5 PR 合并规则

PR 合并必须 CI 全绿并至少获得一次人类批准；AI 审查不能替代人类。GitHub PR 侧 Bugbot 已跳过，不构成本条的「一次人类批准」。若日后恢复，其 check 默认仍为 `neutral`，勾选该 check **不会**因为发现问题而阻止合并。

[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 4 把 GitHub 分支保护定为隔离分支提交的硬前置。目标配置：

- `main` 禁止直推，必须走 PR；
- 要求 CI 通过；
- 要求一次人类批准；
- `CODEOWNERS` 覆盖 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/`。

**当前（2026-08-21）：`main` 分支保护已由 GitHub API 复核。** 已启用：要求 1 次批准、过期 review 作废、Require review from Code Owners、禁止 force push、禁止删除 `main`、要求状态检查通过且分支与 `main` 同步。必过检查：`Backend typecheck and tests`、`Godot check-only and GUT`。未启用：`enforce_admins`（仓库管理员仍可绕过）。`.github/CODEOWNERS` 覆盖 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/`。A4 回路已走通一次： [PR #1](https://github.com/czmomocha/craftarena/pull/1)。此后 Agent 可在隔离分支上创建提交，仍不得向 `main` 提交或推送（[CD-52 §1.1](52-ai-workflow.md)）。

每个 PR 的 Web 预览公开访问，但必须使用独立临时沙盒命名空间、测试数据和可销毁凭据，关闭 PR 后清理。合入 `main` 后更新稳定测试链接。

## 5. Definition of Done

任务只有同时满足以下条件才算完成：

1. 功能行为符合任务单；
2. 有自动化测试或明确说明为何无法自动化；
3. 测试实际运行通过；
4. 无新增错误级日志；
5. 网络和权威边界没有被绕过；
6. UGC 输入经过验证；
7. 性能未明显回退；
8. 文档或 Schema 已同步；
9. AI 能解释关键实现和失败模式；
10. 人类完成必要审查；
11. 未把人工临时网络测试或性能观察伪报成自动门禁；
12. AI 没有违反 [CD-52 §1.1](52-ai-workflow.md) 的提交边界，也没有未经许可部署或发布。

## 6. 首批测试用例

1. 传送门 A→B 后不能跳过强制检查点；
2. A→B→A 循环在发布前被发现；
3. 爆破球只能伤害 `destructible`；
4. 障碍重生不会把玩家卡入模型；
5. 客户端伪造冲线被拒绝；
6. 离线冲线结果没有网络写请求；
7. BASTION 路障不能封死唯一路径；
8. 对称阵容障碍预算一致；非对称阵容只能应用平台补偿预设；
9. 客户端伪造金币被拒绝；
10. 同一建造槽并发建塔只有一个成功；
11. P2/P3 新内容版本不改变运行中的旧房，P0/P1 补丁按安全边界生效；
12. `latest` 回滚后新房加载旧签名版本；
13. Rule VM 超 gas 时只中止问题规则；
14. 断线重连后客户端恢复权威快照；
15. 相同回放得到相同关键状态哈希。
