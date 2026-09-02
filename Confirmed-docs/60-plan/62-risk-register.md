# CD-62 风险登记册

> 文档 ID：CD-62
> 单一事实源：所有已识别风险的状态与当前处理方式
> 加载建议：评估新方案是否触碰已接受风险、对外描述项目能力、或准备正式运营评审时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第二十四、二十五条
> 相关：[CD-63 开发期决策清单](63-open-decisions.md)、[CD-14 数据与遥测](../10-product/14-data-and-telemetry.md)、[CD-53 测试与 CI](../50-engineering/53-testing-and-ci.md)
> 派生自：初稿 v0.2 §57

## 当前生效值

> 本节覆盖而非追加。覆盖链见 [CD-91](../90-reference/91-decision-log.md)。

| 项 | 当前状态 |
|---|---|
| 网页/微信包体超限 | **未开始**（治理动作） |
| `_mcp_game_helper` 进包 / Headless | **已缓解**（C1 第一次真导出证伪旧说法后，exclude + 自检 + scrub） |
| 传送迷路或跳关 | **已缓解**（检查点与发布前通路有；镜头过渡零实现） |
| 测试期远端明文 | **已接受**（D11） |
| 单人审查带宽超载 | **已缓解**（D9 粒度 5× + 审查分级；E10 周 PR 上限仍待观察） |
| 零延迟锁定网络参数 | **已治理**（E3：现桩升锁定，不改数字） |
| 扫掠取样无上限 | **已治理**（C5 第 15 章：单次 256，超限拒绝） |
| 静态盒全量扫描 | **已治理**（C5 第 16 章：均匀格阔相；胶囊仍线性） |

## 状态定义

| 状态 | 含义 |
|---|---|
| 已治理 | 有明确机制降低发生概率或影响 |
| 已缓解 | 有部分机制，但残余风险仍然显著 |
| 已接受 | 明确知情并选择不处理，仅适用于当前长期测试环境 |
| 未解决 | 阻断项，正式公开运营前必须解决 |

**重要**：[CD-00 第二十五条](../00-constitution/CONSTITUTION.md) 规定，"已接受"不代表产品具备对应能力。AI 不得自行"修正"这些决策，也不得在对外材料中把它们描述为已验证。

## 登记表

| 风险 | 状态 | 当前处理 |
|---|---|---|
| AI 高速生成导致架构漂移 | 高，已治理 | 单一主 Agent、隔离子任务、核心 TDD、逐任务人类审查。Schema 验证、红线扫描与 `CODEOWNERS` **已进 CI**（[CD-53 §4.1](../50-engineering/53-testing-and-ci.md)） |
| 固定点 3D kinematic 实现复杂 | 高，已接受 | 限制直立角色和基础碰撞体；先灰盒验证状态哈希 |
| TRAPRUSH 实体碰撞、硬卡口和无自动解堵 | 高，已接受 | 基础推击提供最低破局手段；不承诺消除恶意堵路 |
| 无网络自动门禁且人工测试无固定频率 | 高，已接受 | 如实标记未保证；协议层已有一场近端样本（§13），仍不得用 ICMP 立项「可玩性」门禁，也不得凭一场 ~16ms 锁参数 |
| 无性能回归门禁，Web 8 人和 BASTION 兵潮可能晚发现瓶颈 | 高，已接受 | 只保留观测埋点，明显异常后专项优化 |
| 无内容级局时/波数上限 | 高，已缓解 | MatchHost 可续租；连续无有效输入回收（参数见 [CD-44](../40-technical/44-deployment.md)） |
| P0/P1 对所有运行中房间立即全量发布 | 高，已缓解 | 玩法安全边界、不可变 PatchHash、进程内技术自动回滚（机制在文档；运行时管线仍待 M4b） |
| 自动公开、无发布限频、无列表去重 | 高，已接受 | 每账号仅一个并发验证；刷屏只人工清理 |
| 开放注册、无 CAPTCHA/限频、公开未过滤用户名 | 极高，已接受 | 单账号验证并发可被批量账号绕过；正式公开运营前必须重审 |
| 对局票据签发/校验接口无调用方鉴权 | 高，已接受 | 长期测试环境；正式运营前必须加内网身份与账号绑定。不得把一次性消费表述为防伪造门禁 |
| UGC 无权利条款、授权或同意流程 | **阻断项，未解决** | 不得据此宣称具备正式公开运营条件 |
| 作弊异常只记录、不踢出或封禁 | 高，已接受 | 服务端继续拒绝非法结果，但不具备主动处置能力 |
| 只有日志、无探测/仪表盘/主动告警 | 高，已接受 | P1 回滚仅依赖进程内硬阈值；故障通常等待人工发现 |
| SQLite/COS 无备份 | 极高，已接受 | 明确数据可能永久丢失；云存储不作可靠性承诺 |
| AI 发布资产不保留来源记录 | 高，已接受 | 投诉后人工逐案判断；无法提供完整来源证明 |
| 纵向切片期间无外部真人测试 | 高，已接受 | 负责人按清单签署；不得宣称创作者体验已验证 |
| SQLite 单实例锁竞争和迁移成本 | 中，已治理 | 仅 Fastify 直接访问；保留 PostgreSQL 迁移边界 |
| 传送迷路或跳关 | 高，已缓解 | 检查点序列与发布前通路/循环验证已有。**镜头过渡零实现**，不能再标「已治理」 |
| BASTION 互设障碍不公平 | 高，已治理 | 同预算、盲设、路径硬验证、槽位与补偿预设（机制在文档；玩法未开工） |
| 网页/微信包体超限 | 中，未开始 | Compatibility 基线与 Web 导出预设已有；**没有**资源变体、分包或按需模块。2026-08-26 无美术时 Web 合计 38.46 MB、wasm brotli 仍约 7 MB。2026-09-02 第一批 `.glb` 后 Web 合计 46.37 MB、pck 0.46→8.36 MB、wasm brotli 仍 6.77 MB，首屏约 15.1 MB，已超过微信主包 4 MB。数字见 [desktop-export-check.md §6](../../docs/runbooks/desktop-export-check.md) |
| Godot 主 MCP 供应链与编辑器权限 | 中，已缓解 | 已选定唯一主 MCP 为 Godot AI（MIT，GDScript 插件 + 本机 Python）。阶段 C 生产级启用已通过（2026-08-23）。插件不入库；仅回环；禁止 `--allow-host` 与 Vision Routing。清单见 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) |
| Godot AI 匿名遥测默认开启 | 中，已治理 | 第一次启用插件前写入 `GODOT_AI_DISABLE_TELEMETRY=true`，Dock 再关 Telemetry，Cursor attach 带 `--disable-telemetry`。口径见 [CD-51 §7.2](../50-engineering/51-dev-environment.md)，不属于 [CD-14](../10-product/14-data-and-telemetry.md) 玩家遥测 |
| `_mcp_game_helper` 写入 `project.godot` 后进入 Headless / 导出包 | 高，已缓解 | **第一次真导出**（2026-08-26）证明旧「已缓解」不成立：`res://addons/godot_ai/` 会被打进 release 包。现缓解：三预设 `exclude_filter` 含 `addons/*`、包内自检 `no_godot_ai_packed` / `no_addons_packed`、`npm run godot-settings:scrub` / `:check`、Agent `git commit`/`git add` 由 `tools/shell-guard/` fail closed 拦截。残余：插件仍会写回本机 `project.godot`；人手敲的 git 不被拦；源码 Headless 若脏工程仍可能加载 helper。口径见 [CD-51 §7.3](../50-engineering/51-dev-environment.md) 与 [desktop-export-check.md §5](../../docs/runbooks/desktop-export-check.md) |
| 多 Agent 并行放大 review 负担 | 高，已缓解 | 启用判据 A1–A4 与并行度上限见 [CD-52 §5](../50-engineering/52-ai-workflow.md)。门禁覆盖率不足时禁止并行 |
| Cursor 托管 worktree 自动清理可能丢失未提交产出 | 中，已缓解 | 任务粒度半天到两天；任务结束即开 PR。隔离分支提交须等分支保护落地后才允许，见 [CD-52 §1.1](../50-engineering/52-ai-workflow.md) |
| Bugbot / Cloud Agent 需要仓库读写权限 | 中，已接受 | 属安全边界扩大，随 [ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 批准。GitHub PR 侧 Bugbot 已跳过（SCM 安装对不上）；合入靠 CI + 人类批准。不启用 fail-on-unresolved-issues。Cloud Agent 仍须分支保护 |
| 测试期把明文 `http`/`ws` 打到远端测试机 | 高，已接受 | 纠偏 D11（2026-08-27）：C1 不配域名与 Let's Encrypt。不得对外表述为已具备 TLS。正式公开运营前必须回到宪法第二十二条。手册不写死 IP/域名，见 [纠偏方案 §4.0.1](../../docs/plans/course-correction-2026-08.md) |
| 单人审查带宽超载 | 高，已缓解 | 纠偏前 7 天 102 个 PR。D9：章粒度 5×、审查分级深/常/轻。E10（周合入上限内且深审有逐行记录）仍待观察，不能标「已治理」 |
| 在零延迟条件下锁定网络参数 | 高，已治理 | C1 已列出：近端 ICMP 未证伪快照/心跳/插值桩；7 局空转证实 CPU 先于内存。§13 一场近端协议层样本（P50=16ms）同样未证伪。2026-09-02 E3：人类把现桩升为锁定值，**不改代码常量**。ICMP / 该场不是改 Hz 的依据 |
| 扫掠取样无上限 | 中，已治理 | C5 第 15 章：`MAX_SWEEP_STEPS = 256`，超限拒绝整段，不粗化密度。`radius=1` 下落一整格不再能把 CI 跑死。残余：超预算位移会失败而不是变粗 |
| 静态盒全量扫描 | 中，已治理 | C5 第 16 章：`SimulationWorldIndex` 均匀格阔相，窄相与 ID 顺序不变。溢出 / 超 125 格走 always-test。残余：胶囊—胶囊仍全量 |
