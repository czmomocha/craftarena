# ADR-0004 多 Agent 并行开发的启用时机与架构选型（Cursor 版）

- 状态：**已拍板**（2026-08-21 由项目负责人裁定八项决策，结果见 §8）
- 日期：2026-08-21（初稿，基于 CodeBuddy Code 能力） / 2026-08-21（**本版：改写为 Cursor 实际能力并拍板**）
- 提出背景：M0 已退出（2026-08-20），M1 尚未启动。项目负责人询问「多 Agent 何时真正 run 起来」以及「自建 / 用现成 CLI 编排 / 用 Multica 类平台」
- 改写原因：初稿的架构选型建立在 CodeBuddy Code 的 **Agent Teams**、agent frontmatter 的 **`tools:` 白名单**、**`.worktreeinclude`**、**`worktree.symlinkDirectories`** 四项能力之上。经核对 Cursor 官方文档，**这四项 Cursor 全都没有**。初稿的时机判据（§3、§4.1、§4.2）与工具无关，本版保留；架构选型（§5）与落地清单（§6）整段重写
- 相关：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第九、十、十八、二十条、[CD-52 §5](../../Confirmed-docs/50-engineering/52-ai-workflow.md)、[CD-53 §4.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)、[CD-61](../../Confirmed-docs/60-plan/61-milestones.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)、[CD-91 D.6](../../Confirmed-docs/90-reference/91-decision-log.md)、[ADR-0003](0003-godot-mcp-selection.md)

---

## 0. 摘要（先看这一节）

| 问题 | 结论（已拍板，见 §8） |
|---|---|
| 什么时候开始真正并行？ | **不是 M1 开头，而是 M1 中段——`shared/` 契约冻结之后**。判据是一条可测量的闸门（§4.1），不是日期。**这条与工具无关，改用 Cursor 不影响它** |
| 架构自建还是用现成的？ | **用 Cursor 原生的 `/worktree` + subagent + hooks，零自建**。但必须知道 Cursor 与 CodeBuddy 的能力差异（§5.1），尤其是**「只读审查 Agent」在 Cursor 里做不成硬约束**，该角色已改由 Bugbot 承担 |
| Multica 这类平台？ | **一期不引入**。结论不变，但论证要更新：Cursor 自带 Agents Window 与原生 worktree 管理，Multica 想补的「可见性缺口」在 Cursor 下更小了 |

一句话结论不变：**并行度的瓶颈不是编排工具，是「机械可判定的验收门禁」的覆盖率。**

本版发现三个 Cursor 特有的冲突点，初稿里不存在，已随 §8 一并拍板：

1. **Cloud Agent 的工作模型与 `ai_autonomy = edit_test_no_commit_release` 字面冲突**（§5.4）——Cloud Agent 就是 clone 仓库、在自己分支上 commit、push 回来。D.6 明确写了 Agent 不得提交/推送。**已定：收窄口径为「禁止推 `main`/受保护分支」，GitHub 分支保护成为硬前置**；
2. **「审查 Agent 只读」在 Cursor 里没有等价物**（§5.3）——subagent frontmatter 没有 `tools` 白名单，`readonly: true` 是否为硬边界官方未说明。**已定：该角色作废，改由 Bugbot 承担**；
3. **Cursor 托管的 worktree 有全机 25 个上限，且自动清理会删除你手工 `git worktree add` 建的目录**（§5.2）。**已定：登记为 CD-62 风险，靠「任务结束即开 PR、不让未提交产出跨夜」缓解**。

---

## 1. 现状核对（不是文档描述，是磁盘上的事实）

2026-08-21 实测：

| 维度 | 事实 |
|---|---|
| 提交数 | 9（`67da704` … `89d336c`），单分支 `main` + `origin/main`，**无 PR 历史** |
| `game/src/` | 只有 `client/main.gd` 与 `server/match_server.gd` 两个真脚本。`shared/`、`simulation/`、`ugc/`、`creator/`、`games/traprush/`、`games/bastion/` **全是 `.gitkeep` 空目录** |
| `game/tests/` | `unit/test_project_contract.gd` 一个测试。`integration/`、`replay/`、`content/`、`security/` 都是 `.gitkeep` |
| `backend/` | 四个 workspace 都有实代码 + 各一个 `node --test` 测试文件 |
| `backend/contracts/` | 只有 `health.ts`。CD-91 定的 `api_contract = json_schema_openapi` **未落地** |
| `tools/` | 只有 `dev-launcher` 是实的；`bot-runner`、`content-validator`、`replay-inspector` 是空目录 |
| CI | 单 workflow `ci.yml`，两个 job（backend typecheck+test、godot check-only+GUT），只跑 Linux |
| Cursor 配置 | 仓库内**没有** `.cursor/` 目录。协作规则全部靠根目录 `AGENTS.md` 一份文件。`.gitignore` 已预留 `.cursor/mcp.json` 一行（ADR-0003 落下的），说明「`.cursor/` 将来会存在但部分内容不入库」已被预期 |
| 依赖体积 | 根 `node_modules` **39.5 MB**，`devDependencies` 只有 3 个（`@types/node`、`@types/ws`、`typescript`）。npm workspaces 管 5 个包 |
| 无 | CODEOWNERS、PR 模板、pre-commit hook、`.cursor/hooks.json`、`.cursor/worktrees.json`、`.cursor/BUGBOT.md`、gdlint/gdformat 配置 |

关键推论：**现在不存在可并行的工作面。** L0 `SharedContracts` 是空的，而 M1 所有产出（SimulationCore、移动、检查点、传送、障碍、道具、命令日志、状态哈希）全部依赖 L0 的类型定义。此刻开三个 Agent，它们的第一件事都是发明自己那版 `FixedPoint` 和 `EntityId`，然后互相冲突。

**依赖体积这一行是新增的，它直接消掉了初稿的一个待办。** 初稿计划用 `worktree.symlinkDirectories: ["node_modules"]` 避免每个 worktree 重装依赖。Cursor 没有这个配置项，而且官方**明确反对** symlink 依赖（「This can cause issues in the main worktree」）。但 39.5 MB × 3 个 worktree 是可以直接忽略的成本，所以正确做法是每个 worktree 老实 `npm install`，不做任何 symlink 技巧，也不为此更换包管理器（换包管理器属宪法第十八条的新依赖门禁，不值得为这点磁盘开销触发）。

---

## 2. 已经拍过的板（不要重新决策）

CD-91 D.6 已锁定，本 ADR 只做落地，不改这些：

- `ai_parallelism = lead_isolated_domains` — 单主 Agent + 隔离域并行。**并行本身已被批准**，问题只是时机与形式；
- `ai_autonomy = edit_test_no_commit_release` — Agent 不得提交/推送/部署。**注意：这一条与 Cursor Cloud Agent 的工作模型直接冲突，已由 §8 决策 4 收窄解释，见 §5.4。这是本 ADR 唯一动了 D.6 既有决策的地方**；
- `human_review_granularity = task_and_gate` — 逐任务 + 门禁两级人类审查；
- `git_workflow = trunk_short_pr`、`pr_merge_gate = required_ci_one_human`；
- `human_team_size = solo_owner` — 唯一人类。这是本 ADR 最硬的约束条件；
- `project_scaffold = minimal_custom` — 不自建脚手架。

CD-62 已登记的对应风险：「AI 高速生成导致架构漂移 / 高，已治理 / 单一主 Agent、隔离子任务、核心 TDD、逐任务人类审查」。本 ADR 的任何建议都不得削弱这四项治理手段。

---

## 3. 为什么"时机"问题的答案不是一个日期

单人 + 多 Agent 的真实约束是一条不等式：

```text
你的审查带宽  ≥  Σ(每个 Agent 的产出 × 该产出需要人眼判断的比例)
```

Agent 数量翻倍会让左边不变、右边翻倍。唯一能让不等式重新成立的办法是**压低「需要人眼判断的比例」**——也就是让机器先把能判的判掉。

这正是宪法第十条（测试是完成条件）和 CD-53 §1「AI 生成代码必须比手写代码有更强的自动化证据」在讲的事，只是换成了并行度的语言。

所以启用时机的判据是**门禁覆盖率**，不是里程碑编号，也不是"感觉准备好了"。

Cursor 官方文档有一条与此高度吻合的提醒，值得直接引用作为佐证：subagent「The benefit is context isolation, not speed」，并且「Running five subagents in parallel uses roughly five times the tokens of a single agent」。**官方自己都不把 subagent 当加速手段卖。** 期待「开 5 个 Agent 快 5 倍」在文档层面就是错的。

---

## 4. 三阶段路线（§8 决策 1、5、7 已批准）

### 4.1 阶段 A：M1 前半段——单 Agent 串行，锁死契约

**做什么**：由主 Agent（就是当前这种会话）串行完成两件事，中间不并行。

1. **L0 `SharedContracts` 落地并冻结 v1**：稳定 ID、定点数类型与运算、命令结构、事件、状态哈希接口。这是所有下游模块的唯一共享面；
2. **同时补齐 §4.2 的三条自动化门禁**（可与 1 交替进行，因为 2 主要改 CI 和 `tools/`，与 1 改 `game/src/shared/` 不冲突）。

**为什么必须串行**：契约是并行的前提，而契约本身无法并行——它是所有并行域的交集。让两个 Agent 同时设计 `FixedPoint` 与 `EntityId` 只会产出两套不兼容的定义。宪法第九条（一次变更只解决一个主要问题）在这里应当从字面上执行。

**退出条件（也就是"什么时候可以开始并行"的正式答案）**：

| # | 条件 | 怎么验证 |
|---|---|---|
| A1 | `game/src/shared/` 有 v1 契约，且被 GUT 单测覆盖 | `-gdir=res://tests/unit` 全绿 |
| A2 | 契约变更被显式标记为人类门禁项 | 见 §4.2 的 CODEOWNERS 一条 |
| A3 | 三条自动门禁上线（Schema 验证、禁止 API 扫描、worktree 并行环境可用） | CI 里能看到对应 step；`/worktree` 建出的工作区能直接跑 `npm test` 与 GUT |
| A4 | 走通至少一次「Agent 产出 → PR → CI 全绿 → 你 review → 你合并」的完整回路 | 仓库里有第一个 PR |

A4 不能跳过。当前 9 个提交全部直推 `main`，`trunk_short_pr` 与 `pr_merge_gate` 这两条决策在实践中**从未执行过一次**。让多个 Agent 同时走一条你自己都没走过的流程，是在同时调试两件事。

### 4.2 阶段 A 期间要补的三条门禁（这才是唯一需要"自建"的东西）

这三条都不是 Agent 框架，是**机械判定器**。总量估计 200–300 行，全部可由 Agent 自己写。**门禁 1 和门禁 2 与用哪个 IDE 完全无关，初稿内容原样保留；门禁 3 因为工具变化而重写。**

**门禁 1：契约与 Schema 验证**（补 CD-53 §4.1 表里的「Schema 验证：未实现」）

- `backend/contracts/` 落 JSON Schema（CD-91 `api_contract = json_schema_openapi` 早已拍板，只是没做）；
- `tools/content-validator/`（目前空目录）实现 Schema 正反例校验，接进 `npm test`；
- 效果：Agent 改了契约却没同步 Schema，CI 直接红。这是把「架构漂移」从人眼检测变成机器检测。

**门禁 2：禁止 API 与红线扫描**（补「禁止 API 和依赖检查：部分」）

当前只有「不得出现 `.cs`/`.csproj`」一条 GUT 断言。至少再加这几条可机械判定的宪法红线：

| 红线 | 可机械化的检查 |
|---|---|
| 第五条 仿真表现分离 | `game/src/simulation/` 内不得出现 `Node`、`get_tree`、`SceneTree`、`_process` |
| 第五条 定点数 | `simulation/` 内不得出现 `float` 字面量与 `float` 类型声明（豁免需显式注解） |
| 第七条 无 GDExtension | 共享核心目录不得出现 `.gdextension` 引用 |
| 第十一条 无 Godot 3 API | 扫已知 Godot 3 符号名黑名单 |
| 第二十三条 类型严格 | 已由 ADR-0001 全局 Error 覆盖，无需新增 |

放在 `tools/` 下一个脚本 + 一个 CI step 即可。**这是并行的杠杆点**：宪法里每多一条能被机器执行的红线，你就少一份必须亲自盯的 review 负担，可并行度就上升一档。

**门禁 3：并行工作区基建（Cursor 版，与初稿完全不同）**

初稿这一条的四个待办里，有两个在 Cursor 里不存在、需要替换：

| 初稿待办（CodeBuddy） | Cursor 下的处理 |
|---|---|
| 根目录加 `.worktreeinclude` | **Cursor 没有这个机制**（那是 Claude Code / Conductor 的）。等价物是 `.cursor/worktrees.json` 里的 setup 脚本，用 `$ROOT_WORKTREE_PATH` 显式从主 checkout 拷本地文件 |
| `worktree.symlinkDirectories: ["node_modules"]` | **Cursor 没有此配置项，且官方反对 symlink 依赖**。改为 setup 脚本里直接 `npm install`（39.5 MB，可接受，见 §1） |
| 端口偏移约定 | 保留，但落地方式要改，见下 |
| `CODEOWNERS` | 保留，与 IDE 无关 |

具体做 `.cursor/worktrees.json`，官方支持三个 key：`setup-worktree-windows`、`setup-worktree-unix`、`setup-worktree`（通用兜底，OS 专用优先）。本项目是 Windows 主开发机 + macOS 第二台，所以两个 OS 键都要写。脚本要做四件事：

1. `npm install`（新 worktree 的 `node_modules` 不随 git 走）；
2. 从 `$ROOT_WORKTREE_PATH` 拷 gitignore 掉的本地文件（`.env` 类、`data/*.sqlite` 按需）；
3. Godot 首次 `--import` 生成 `.godot/`（该目录是 gitignore 的，每个 worktree 必须各有一份，**不能共享，也不能 symlink**）；
4. 写出该 worktree 专属的端口偏移。

**端口偏移这一条有个初稿没查清的实现障碍。** `backend/*/src/config.ts` 全部直接读 `process.env`（`CONTROL_PLANE_PORT` 8080 / `GATEWAY_PORT` 8090 / `MATCH_HOST_PORT` 8100 / MatchHost 子进程端口段 `MATCH_HOST_PORT_RANGE_MIN..MAX` 42000–42099），而 `tools/dev-launcher/src/main.ts` 只是 `spawn` 子进程让它们继承环境——**全链路没有任何一处读 `.env` 文件**。所以 setup 脚本写一个 `.env` 出来是不生效的，两条路选一条：

- **✅（已选定，随 §8 决策 7 批准，落在 §6.1 待办 7）** 给 DevLauncher 加三行 `process.loadEnvFile()`（Node 24 内置），让它在 spawn 之前把 worktree 的 `.env` 读进 `process.env`，子进程自然继承。一处改动、可写单测、Agent 不可能忘；
- 让 setup 脚本产出一个需要人工 `source` / dot-source 的 shell 片段。零代码改动，但 Agent 一定会忘记 source，然后浪费你一个下午查一个"莫名其妙连不上"的 bug。

**这一条现在不做，将来一定会付那个下午。** 初稿的这句判断在 Cursor 下依然成立，只是原因从「没约定」变成了「约定了但读不到」。

`CODEOWNERS`：把 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/` 标为需要你本人批准。这是宪法第十八条（Schema 破坏性变更、协议不兼容变更需人类门禁）的机械化落地，是**唯一一条真正跑在 Agent 权限之外**的门禁——它由 GitHub 执行，Agent 无论怎么配置都绕不过。

### 4.3 阶段 B：M1 后半段 — M2 —— 3 个域并行（建议起点）

契约冻结后，M1 剩余工作天然分成互不重叠的域：

| 域 | 目录 | M1 产出对应项 |
|---|---|---|
| 仿真域 | `game/src/simulation/` + `tests/unit/`、`tests/replay/` | 定点 SimulationCore、固定 Tick、RNG、状态哈希、直立 XYZ kinematic 胶囊 |
| 玩法域 | `game/src/games/traprush/` | 移动、检查点、传送、障碍、道具、基础推击 |
| 工具域 | `tools/bot-runner/`、`tools/replay-inspector/`、CI | 命令日志与回放检查器、可达性 bot |

三个域的**文件集合完全不相交**，这正是 CD-52 §5「子 Agent 只在互不重叠的模块或独立工作区并行」要求的形态。共享面只有 L0 契约，而它在阶段 A 已冻结——需要动契约时，走 CODEOWNERS 门禁回到你手上，这是特性不是缺陷。

**这里有一条 Cursor 特有的硬要求，不是可选项。** Cursor 官方文档明确说：subagent **默认共享父 agent 的 checkout**，多个 subagent 并发编辑同一工作区会互相覆盖，隔离必须在 prompt 里**显式要求**（官方例句：「each in its own environment」）。CodeBuddy 的 `--worktree` 是命令行开关，忘了加就没隔离，很容易发现；Cursor 是「不说就没有」，而且症状是文件被静默覆盖。所以：

> 阶段 B 的任务单模板（CD-52 §3）必须新增一行「隔离方式」，取值 `worktree` 或 `cloud`，且不允许留空。

**并行度上限 3（§8 决策 5 已定）。** Cursor 官方**没有给出本地并行数上限**（云端只有定性的「as many as you want」），所以这个 3 不是技术限制，纯粹来自「你是唯一 reviewer」和 token 成本线性叠加。先跑 2 个域，确认 review 节奏能跟上再加到 3。**不要一上来开 5 个。**

**M2 是并行收益最大的阶段**，因为编辑器（`creator/`）、UGC 运行时（`ugc/`）、内容验证（`tools/content-validator/`）三者依赖关系松、代码量大。同时提醒：ADR-0003 定的 Godot 主 MCP 重估触发点也是「M2 启动前」，两件事撞在同一个时间点，建议合并成一次「M2 启动前的工具链评审」。

### 4.4 阶段 C：M3 及以后——按需扩到 4–5 个域

M3（权威联机）之后天然出现更多正交域：Godot MatchServer / TS 网关 / MatchHost / 客户端预测。此时可以考虑：

- 把 **Bugbot 的 PR 侧审查**常态化，作为你 review 之前的第一道筛子，并评估是否启用 fail-on-unresolved-issues 把它从「提示」升成门禁。（注意：初稿这里写的是让「审查 Agent」常驻，该角色已由 §8 决策 3 作废，见 §5.3）；
- 让「测试 Agent」专职生成 CD-53 §2.6 的 UGC 恶意输入用例——这类工作产出量大、正确性可由「是否被验证器拒绝」机械判定，是最适合放给 Agent 的活。

---

## 5. 架构选型：Cursor 能给什么，不能给什么

### 5.1 能力对照：初稿假设 vs Cursor 事实

初稿 §5.1 的能力表逐行核对结果。**这张表是本次改写的核心，五行里有三行需要改变做法。**

| CD-52 / D.6 的需求 | 初稿计划（CodeBuddy） | Cursor 事实 | 影响 |
|---|---|---|---|
| 隔离域物理并行 | `codebuddy --worktree sim-core` | ✅ **有，而且更强**：IDE 内 `/worktree`、`/apply-worktree`、`/delete-worktree`、`/best-of-n`；CLI `-w/--worktree`；Agents Window 有原生 UI。路径统一在 `~/.cursor/worktrees/<project>/<name>` | 直接可用，见 §5.2 的两个坑 |
| 单主 Agent 统筹隔离子任务 | **Agent Teams**（lead spawn 成员、共享任务列表、成员间消息） | ❌ **Cursor 没有这个功能**。最接近的是官方命名的 **Orchestrator pattern**（Planner → Implementer → Verifier），但它只是**建议的 prompt 编写范式，没有任何运行时支撑**；`/multitask` 能并行跑异步 subagent，但成员间无协调 | `ai_parallelism = lead_isolated_domains` 仍能落地，但「统筹」从工具保证降级为**你的 prompt 纪律** |
| 子 Agent 角色定义入库 | `.codebuddy/agents/*.md` | ✅ `.cursor/agents/*.md`（项目级，优先于 `~/.cursor/agents/`）。frontmatter **只有五个字段**：`name`、`description`、`model`、`readonly`、`is_background` | 可用，但字段远少于预期 |
| **审查 Agent 只读，物理上无法改代码** | `tools: Read, Grep, Glob, Bash` 白名单 | ❌ **Cursor frontmatter 没有 `tools` 字段**。官方原话：「Subagents inherit all tools from the parent, including MCP tools」 | **初稿这条最重要的安全论证不成立**，见 §5.3 |
| 硬拦截 Agent 的 `git commit` / `git push` | `PreToolUse` hook | ✅ **有，而且官方示例就是这个用途**：`.cursor/hooks.json` 的 `beforeShellExecution`，示例脚本名就叫 `block-git.sh`。`matcher` 匹配完整命令字符串，可写 `"git commit\|git push"` | 可用，但有两个陷阱，见 §5.3 |
| 架构/Schema 变更事前审批 | agent frontmatter `permissionMode: plan` | ⚠️ **Cursor 的 Plan Mode 是会话级，不是 agent 级**。IDE 里手动切换，CLI 用 `--mode plan`。无法在 `.cursor/agents/*.md` 里声明「这个角色必须先出计划」 | 降级为约定；硬门禁只能靠 CODEOWNERS + PR |
| 本地代码审查 | 无对应物 | ✅ **Cursor 多给了一个**：`/review-bugbot`、`/review` 内置 skill，推送前本地跑；PR 侧 Bugbot 自动审查。配置在 `.cursor/BUGBOT.md` | 这是**净收益**，见 §5.5 |
| 独立机器/VM 并行 | 无对应物 | ✅ **Cursor 多给了一个**：Cloud Agent，每个独立 VM + 独立分支 | **但与 D.6 冲突**，见 §5.4 |

净结论：**Cursor 在「物理隔离」和「代码审查」两个维度比初稿假设的更强，在「角色权限约束」和「多 Agent 协调编排」两个维度明显更弱。** 由于本项目的瓶颈是 review 带宽（§3），而 Cursor 强在审查、弱在编排，这个交换对本项目是**净有利**的——但前提是你接受 §5.3 的降级。

### 5.2 worktree：可以用，但有两个必须知道的坑

**坑 1：全机 25 个上限，且自动清理会删掉你手工建的 worktree。** Cursor 3.5+ 有 `cursor.worktreeMaxCount`（默认 25，**所有 workspace 共享这一个配额**）和 `cursor.worktreeCleanupIntervalHours`。官方文档明说清理时会重新扫描 worktree 根目录，「worktrees created outside the manager (for example, worktrees created by `/worktree` skills or `git worktree add`) are eligible for deletion」。

对本项目的含义：**不要在 Cursor 管理的 worktree 里放任何未提交且不可再生的东西。** 这与宪法第十四条（离线结果永不回写）无关，但和「AI 不得提交」这条组合起来有个真实风险——Agent 在 worktree 里干了两天活、按 D.6 不许提交、然后 worktree 被自动清理掉。**缓解办法**：阶段 B 的任务粒度本来就要求半天到两天（CD-52 §3），并且每个任务结束时由你 review 后立刻开 PR，不要让未提交的产出跨夜留在 worktree 里。

**坑 2：`.godot/` 每个 worktree 一份，不能共享。** 这一条初稿已经识别到了，Cursor 下没有变化，只是从「`.worktreeinclude` 带不进去」变成「setup 脚本要显式 `--import`」。

### 5.3 「只读审查 Agent」：初稿最重要的安全论证在 Cursor 下不成立

初稿写：「**关键**：审查 Agent 可以只给 `Read, Grep, Glob, Bash`，物理上无法改代码」，并在 §7 把它列为正面后果之一（「让『只读检查』成为物理事实而非约定」）。

**在 Cursor 里做不到。** 官方文档明确：subagent 继承父 agent 的**全部**工具，包括 MCP 工具。frontmatter 里没有 `tools` 字段。可用的手段只有三层，按硬度排序：

| 手段 | 配置位置 | 硬度 | 限制 |
|---|---|---|---|
| `readonly: true` | `.cursor/agents/*.md` frontmatter | **未知**。官方定义是「runs with restricted write permissions (no file edits, no state-changing shell commands)」，但**是否为硬性安全边界，文档没有说明** | 最省事，但不能在文档里声称它是硬门禁（宪法第二十四条） |
| `beforeShellExecution` + `preToolUse` hook | `.cursor/hooks.json`（项目级，入库可 review） | **硬**，但必须显式写 `failClosed: true`——**hook 崩溃/超时/返回非法 JSON 时默认是 fail-open 放行的** | ⚠️ `preToolUse` 的输入 schema **没有 subagent 标识字段**，所以它对整个会话的所有工具调用生效，**无法只针对审查 Agent**。能按 subagent 过滤的只有 `subagentStart`/`subagentStop`，而它们的 `matcher` 匹配的是内置类型名，自定义 agent 的 `name` 能否作为 matcher 值文档未明确 |
| `permissions.deny` | `.cursor/cli.json`（项目级）或 `~/.cursor/cli-config.json` | **硬，且是真正的 token 白/黑名单**：`Shell(rm)`、`Write(**/*.key)`、`Read(.env*)`、`Mcp(server:tool)`，deny 优先于 allow | ⚠️ **只在 Cursor CLI 生效，GUI 不读这个文件** |

还有一个必须写清楚的反面事实：桌面端的 Run Modes 用的是 `~/.cursor/permissions.json` / `<project>/.cursor/permissions.json`，里面是**自然语言指令**（`autoRun.allow_instructions` / `block_instructions`），由 Auto-review 分类器判断。**官方明确警告「Auto-review is not a security boundary」，分类器会误判。** 按宪法第二十四条，它不能被写成门禁。

三个候选（**已拍板：选定 R1**，见 §8 决策 3）：

- **✅ 选项 R1（已选定）**：放弃「只读审查 Agent」这个形态，改用 **Bugbot**（§5.5）。Bugbot 本来就是只读审查工具，跑在 PR 侧或本地 `/review-bugbot`，不需要任何权限技巧。审查 Agent 这个角色在 CD-52 §5 的表里改注为「由 Bugbot 承担」；
- 选项 R2：保留审查 Agent，用 `readonly: true`，并在 CD-52 里明确标注这是软约束，不写进 CD-53 §4.1 的门禁表；
- 选项 R3：审查工作全部走 Cursor CLI（`agent -p --mode ask` + `.cursor/cli.json` 的 `permissions.deny`），换取真正的硬约束。代价是审查脱离 IDE 交互，且要多维护一套 CLI 配置。

选定 R1 的直接后果：**`.cursor/agents/` 下不建审查 Agent**。一期不引入 `.cursor/cli.json` 的 `permissions.deny`（R3 的配置），避免维护两套互不通用的权限机制。R3 保留为将来的升级路径——若 Bugbot 被证明漏检本项目关心的宪法红线，再评估。

用 `beforeShellExecution` 拦 git 写操作这一条**不受 R1 影响，照做**——它是会话级的、正是我们想要的粒度，且官方示例就是这个用途。这是宪法第十八条在 Cursor 里唯一能做成硬拦截的部分，必须配 `failClosed: true`。**但拦截范围由 §5.4 的决策 4 定义，不是「拦一切 commit/push」**。

### 5.4 Cloud Agent：一个初稿里不存在的直接冲突

Cursor Cloud Agent（原名 Background Agent）的工作模型是：**clone 仓库到独立 VM → 在独立分支上工作 → commit → push 回你的仓库**。文档另有一条：**Cloud Agent 不使用 Run Modes，永远不会向你请求批准**（因为它跑在自己的机器上）。

对照 D.6：`ai_autonomy = edit_test_no_commit_release`——**Agent 不得创建提交、推送、部署或发布。**

这不是可以绕过去的实现细节，而是字面冲突：**用 Cloud Agent 就等于让 Agent commit 并 push。** 而 Cloud Agent 恰好是 §4.3「隔离域并行」最干净的落地形态（独立 VM 比本地 worktree 隔离得更彻底，且不占本地磁盘、不受 25 个上限约束）。

三个候选口径（**已拍板：选定 C1**，见 §8 决策 4）：

| 选项 | 口径 | 代价 |
|---|---|---|
| **✅ C1（已选定）** | 收窄 `ai_autonomy` 的解释：**禁止的是「向 `main` 或任何受保护分支提交/推送」和「部署/发布」，允许在隔离的 agent 分支上 commit/push**。理由：`git_workflow = trunk_short_pr` + `pr_merge_gate = required_ci_one_human` 已经保证只有你能合进 `main`，agent 分支上的 commit 反而**提高**了可审查性（有 diff、有历史、不会被 worktree 清理弄丢） | 必须在 CD-91 D.6 追加一条明确的解释行，不能靠"我们心里知道"。另外必须配 GitHub 分支保护，否则「只有你能合并」是空话 |
| C2 | 一期完全不用 Cloud Agent，只用本地 worktree | 放弃更彻底的隔离；受 25 个 worktree 上限和自动清理影响；本地机器承担全部算力 |
| C3 | 严格按字面执行，同时禁用 Cloud Agent 和本地 Agent 的一切 git 写操作 | 等于 C2 加一条 hook，但要接受「Agent 两天的产出只存在于未提交的工作区」这个真实的丢失风险（§5.2 坑 1） |

选定 C1 后，两件事变成**硬前置**而不是可选项：

1. **GitHub 分支保护必须先配好**（§6.1 待办 5），否则 C1 的全部安全性论证都是空话。顺序上它必须早于第一个 Cloud Agent 任务；
2. **`beforeShellExecution` hook 的拦截范围要按 C1 重写**：不再是「拦一切 `git commit` / `git push`」，而是「拦向 `main` 或受保护分支的推送」。这比初稿的规则复杂，判定逻辑要写在 hook 脚本里并**配单测**——一条判断错了就等于门禁不存在。

Cloud Agent 的三条前置条件同时生效：需要**已连接 SCM + 付费套餐 + 仓库读写权限**，计费按所选模型 API 定价。「仓库读写权限」这一项本身就是宪法第十八条的安全边界变化，随本决策一并批准，需在 CD-62 登记。

### 5.5 Bugbot：Cursor 多给的一件东西（**已拍板引入**）

初稿里没有对应物。Bugbot 直接冲着本项目的核心瓶颈（§3 的 review 带宽）来。**§8 决策 6 已批准引入，启用顺序是「本地 `/review-bugbot` 先行，PR 侧等第一个 PR 走通之后再开」**，理由是先确认它对本项目的红线检出质量，再让它进入 PR 流程。

- **本地**：`/review-bugbot`、`/review` 两个内置 skill，推送前跑，默认审查分支相对 base 的全部变更（含未提交）。它会存 diff 的 patch ID，之后开 PR 时远端 Bugbot 认出同一 patch ID 会跳过重复审查；
- **PR 侧**：GitHub 上自动跑，生成名为 `Cursor Bugbot` 的 check；
- **配置**：`.cursor/BUGBOT.md`，根目录的总是加载，且支持嵌套（审查 `backend/` 文件时会额外加载 `backend/.cursor/BUGBOT.md`）。

三个必须知道的限制：

1. ⚠️ **`.cursor/rules/*.mdc` 对 Bugbot 不生效**，官方明说。给 Bugbot 的指令只能写在 `.cursor/BUGBOT.md`。本项目的规则全在 `AGENTS.md`，而**文档没有说 Bugbot 会读 `AGENTS.md`**——这一点必须实测，不能假设；
2. ⚠️ **findings 默认是 `neutral` 结论**，所以**光在分支保护里勾上这个 check 并不会因为发现问题而阻止合并**，要额外启用 fail-on-unresolved-issues。按宪法第二十四条，在启用那个开关之前，不得把 Bugbot 描述为门禁；
3. 单条规则截断在 30,000 字符，合并总量上限 100,000 字符，超出会**静默省略**。用 `bugbot run verbose=true` 能看到本次实际加载了什么。

**这里和宪法第二十六条（单一事实源，禁止在非所有者文档中复述参数）有一处真实张力：** `.cursor/BUGBOT.md` 是 Bugbot 唯一能读的入口，但宪法红线的所有者文档是 CD-00。解决办法是 `.cursor/BUGBOT.md` **只写「§4.2 门禁 2 表里那几条机械可判定的红线」+ 指向 CD-00 的路径**，不复述任何数值参数。是否需要在里面内联更多内容，取决于第 1 条的实测结果。

### 5.6 选项 B：引入 Multica 这类平台（**已拍板：一期不做**）

调研事实（2026-08-21）：Multica 是开源 Agent 管理平台，Workspace / Issue / Agent / Runtime / Daemon / Skill 六个概念，统一调度 Claude Code、Codex、OpenClaw、OpenCode 等 CLI。自托管需要 Go 后端 + Next.js 前端 + PostgreSQL 17 + pgvector，daemon 跑在本机，反向代理必须正确处理 WebSocket。当前版本 v0.1.23。

⚠️ 一条**未核实**的事实：上述 CLI 清单里没有 Cursor CLI（`agent`）。它是否被 Multica 支持我没有查证。如果不支持，那么在 Cursor 主力开发的前提下，这个选项连技术前提都不成立。

**为什么现在不该引入**（四条理由里有两条因为换到 Cursor 而变强了）：

1. **它解决的不是你的瓶颈。** 你的瓶颈是 review 带宽和门禁覆盖率（§3），不是"看不清 Agent 在干什么"。**这一条在 Cursor 下更成立**：Cursor 自带 Agents Window（多 agent 管理界面、pin 会话、diff 视图）、原生 worktree 管理与清理、`agent ls` 列会话。Multica 想补的可见性缺口，Cursor 已经补掉大半。（Cursor 还有 Automations 做定时/事件触发，但本项目按 §5.8 不用它——即便刨掉这一项，剩下的可见性也够了）；
2. **成本方向与既有决策冲突。** 一期数据库是 SQLite，PostgreSQL 是明确的迁移目标而非当前依赖（CD-91 D.7 `postgres_deployment = sqlite_control_plane`）。为一个开发期工具引入 PostgreSQL 17 + pgvector，是在项目主线之外多养一个 stateful 服务。CD-62 已登记「SQLite/COS 无备份」为极高风险——再加一个需要运维的数据库会让这个风险面变大；
3. **v0.1.23。** 宪法第十八条把新依赖列为人类门禁项。0.x 版本、破坏性变更可能、无官方生产部署最佳实践，正是该门禁要拦的东西；
4. **收益要到多人协作才兑现。** 一期 `human_team_size = solo_owner`。

**这不是"永远不用"。** 重估触发点见 §6.4。

### 5.7 选项 C：自建多 Agent 框架（**已拍板：不做**）

违反 `project_scaffold = minimal_custom`，且与宪法第一条（范围优先）直接冲突——自建 Agent 编排框架服务不了 CD-11 的任何一个一期验收项。

**唯一例外**是 §4.2 那三条门禁脚本。但那些是「机械判定器」，不是 Agent 框架：它们不调度 Agent、不管理会话、不做通信，只是在 CI 里跑并返回 0/1。任何 Agent 框架都需要它们，而它们不需要任何 Agent 框架。**这个区分很重要：优先投资门禁，不要投资编排。**

值得一提的是 Cursor 官方博客 [Agent swarms and the new model economics](https://cursor.com/blog/agent-swarm-model-economics) 描述了 planner/worker 树状 swarm、专用 VCS、中立第三方 agent 解决合并冲突。⚠️ **那是厂商内部研究实验的记述，不是可用的产品功能**，文档里没有任何对应配置接口。不得作为本项目的规划依据。

### 5.8 Automations（**已拍板：一期不用**，理由是"配置无法入库"）

Cursor Automations 是按计划（cron）或事件（PR opened/pushed/merged、CI completed、Slack、Webhook、Linear、Sentry 等）触发的 Cloud Agent。

⚠️ **它的配置只存在云端 dashboard / Agents Window UI，官方文档没有给出任何可提交进仓库的配置文件格式。** 仓库里能版本化的只有 automation 运行时加载的 `.cursor/hooks.json` 和 `.cursor/environment.json`。

这与宪法第十九条（文档随代码变化）和第二十六条（单一事实源）有直接张力：一个影响 CI 行为、且无法 review、无法回滚、无法在 PR 里看到 diff 的自动化配置，不该在一期引入。另外 Automations **强制使用模型的最大上下文窗口，没有 context 档位开关**，成本不可控。

**已定：一期不用 Automations。** 定时类需求（如 CD-53 §4.2 的每日全量 GUT、§4.3 的每周依赖检查）用 GitHub Actions 的 `schedule` 触发器，那个是入库的 YAML。

---

## 6. 落地清单

### 6.1 阶段 A 待办（按此顺序）

| # | 事项 | 归属文档需同步 |
|---|---|---|
| 1 | L0 `SharedContracts` v1 + GUT 单测 | CD-42 |
| 2 | `backend/contracts/` JSON Schema + `tools/content-validator/` 校验，接进 `npm test` | CD-53 §4.1 表 |
| 3 | 宪法红线扫描脚本（§4.2 门禁 2 表）+ CI step | CD-53 §4.1 表 |
| 4 | `CODEOWNERS`：`game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/` 需你批准 | — |
| 5 | **GitHub 分支保护**：`main` 禁止直推、要求 PR、要求 CI 通过、要求一次批准。**这是 §5.4 选项 C1 的前提，不做的话「只有你能合并」是空话** | CD-53 §4.5 |
| 6 | `.cursor/worktrees.json`：`setup-worktree-windows` + `setup-worktree-unix`，做 `npm install` / 拷本地文件 / Godot `--import` / 写端口偏移四件事 | README「常用命令」加一节 |
| 7 | DevLauncher 加 `process.loadEnvFile()`（§4.2 门禁 3 已选定的路径）+ 单测 | README |
| 8 | `.cursor/hooks.json`：`beforeShellExecution` 按 §5.4 选项 C1 的口径拦「向 `main` / 受保护分支的推送」+ `git worktree remove --force`，**必须 `failClosed: true`**，判定逻辑**必须配单测**。落地宪法第十八条 | CD-52 §1.1 权限边界 |
| 9 | 走通第一个 PR 全流程，其中跑一次本地 `/review-bugbot`，并**实测 Bugbot 是否读 `AGENTS.md`**（§5.5 限制 1） | — |

### 6.2 阶段 B 启动时待办

| # | 事项 |
|---|---|
| 10 | `.cursor/agents/` 下按 CD-52 §5 角色表建 agent 定义，**不含审查 Agent**（§8 决策 3 选定 R1，该角色由 Bugbot 承担）。注意 frontmatter 只有 `name`/`description`/`model`/`readonly`/`is_background` 五个字段，初稿设想的 `tools` 白名单与 `permissionMode: plan` 都不存在 |
| 11 | CD-52 §3 任务单模板新增必填行「隔离方式：worktree \| cloud」。**Cursor 的 subagent 默认共享父 checkout，不显式要求隔离就会静默互相覆盖** |
| 12 | `.cursor/BUGBOT.md`：只写机械可判定红线清单 + 指向 CD-00 的路径。内联多少内容取决于待办 9 的 `AGENTS.md` 实测结果 |
| 13 | 开启 PR 侧 Bugbot（§8 决策 6 定的顺序是本地先行、PR 侧等第一个 PR 之后） |
| 14 | 先开 2 个域跑一轮，确认 review 节奏，再加第 3 个 |

### 6.3 需要同步修改的所有者文档（宪法第十九、二十六条）

本 ADR 已于 2026-08-21 获批。下列所有者文档已按本节要求同步，清单见 §8：

- **CD-52 §5**：现在只有 15 行的角色表，需补：启用时机的门禁判据（§4.1）、worktree/cloud 隔离形态与「必须显式声明」这条硬要求、并行度上限 3（先跑 2）、`.cursor/agents/` 的位置约定。**「审查 Agent」那一行改为「由 Bugbot 承担，见 ADR-0004 §5.3」**，并说明 Cursor 无 `tools` 白名单、`readonly` 不是已证实的硬边界；
- **CD-52 §1.1 权限边界**：现在写的是「未经人类明确确认，AI 不得创建提交、推送、部署或发布内容」。按 §8 决策 4（C1）改为「不得向 `main` 或受保护分支提交/推送，不得部署或发布；允许在隔离的 agent 分支 / worktree 上提交」，并补 `beforeShellExecution` hook 作为机械化落地，注明 hook 默认 fail-open、本项目强制 `failClosed: true`；
- **CD-52 §7.3**：已经提到不要提交 `.cursor/mcp.json`，需扩展为完整的「`.cursor/` 哪些入库、哪些不入库」清单（`agents/`、`hooks.json`、`worktrees.json`、`BUGBOT.md` 入库；`mcp.json`、`permissions.json` 不入库）；
- **CD-53 §4.1 当前实现状态表**：Schema 验证、禁止 API 扫描两行随门禁上线改状态。**宪法第二十四条：门禁没进 CI 之前不得把状态改成"已启用"**。Bugbot 新增一行，且**必须标为「非门禁」**——findings 默认 `neutral`，分支保护勾上它也不会阻止合并（§5.5 限制 2）；
- **CD-53 §4.5 PR 合并规则**：补 GitHub 分支保护的具体配置项（这是 §5.4 选项 C1 的硬前置）；
- **CD-91 D.6**：追加 `multi_agent_runtime = cursor_native_worktree`；追加 `ai_autonomy` 的解释行——**「禁止的是向 `main`/受保护分支提交推送与部署发布；允许在隔离 agent 分支或 worktree 上提交」**，并注明它收窄而非推翻 `edit_test_no_commit_release`；追加 `code_review_assist = bugbot`；
- **CD-62**：「AI 高速生成导致架构漂移」一行的「当前处理」补上新增的机械门禁；新增三行风险：「多 Agent 并行放大 review 负担」、「Cursor 托管 worktree 自动清理可能丢失未提交产出」（§5.2 坑 1）、「Bugbot 需要仓库读写权限，属安全边界扩大」（§5.4 末段）；
- **README**：并行 worktree 的固定命令与端口偏移（CD-51 §4 要求固定命令写在 README，禁止 Agent 猜参数）；
- **`.gitignore`**：`.cursor/permissions.json` 加入排除（自然语言指令 + 含本机路径，且它不是安全边界，不该给人「入库即门禁」的错觉）。

### 6.4 重估触发点

以下任一条成立时，重新评估 Multica 类平台：

1. 人类协作者从 1 人增加到 2 人以上（推翻 `human_team_size = solo_owner`）；
2. 常态并行域数超过 4 个，且出现过因缺乏统一任务视图导致的重复工作或返工；
3. 需要跨机器调度，且 Cursor Cloud Agent 不能满足（例如自托管 Windows Runner 落地后，要把 Windows 平台验证任务派给指定的那台机器——Cloud Agent 不能指定物理机）；
4. Multica 或同类方案发布 1.0、有可参考的生产部署文档，**且明确支持 Cursor CLI**。

另：ADR-0003 定的「Godot 主 MCP 重估」触发点同为 M2 启动前，建议与本 ADR 阶段 B 的启动评审合并为一次工具链评审。

---

## 7. 后果

**正面**：

- 并行时机有可验证判据，不靠感觉；
- 门禁先行意味着并行度可以持续上升而不是撞上 review 天花板；
- Cursor 原生 `/worktree` 比初稿假设的更完整（IDE + CLI + Agents Window UI + 自动清理），并行工作区基建的自建量下降；
- **Bugbot 是净收益**：它直接压低 §3 不等式右边的「需要人眼判断的比例」，这正是唯一能提高并行度的杠杆；
- `beforeShellExecution` 让「Agent 不得推 `main`」第一次成为可执行的拦截而不只是文档条款，且 CODEOWNERS + 分支保护在 Agent 权限之外又加了一道 GitHub 侧的硬门禁。

**负面与代价**：

- 阶段 A 会让人觉得"慢"——M1 前半段仍是单 Agent 串行，且要额外投入几百行门禁代码。这是刻意的：宪法决策优先级里「可复现与可测试 > 迭代速度」；
- **「只读审查 Agent」这个角色被取消，改由 Bugbot 承担**（§5.3）。初稿把「只读是物理事实」列为正面后果，本版撤回这个说法：在 Cursor 里它既不是物理事实，也不再是一个 Agent 角色；
- **多 Agent「统筹」从工具保证降级为 prompt 纪律**（§5.1）。Cursor 没有 Agent Teams 那样的共享任务列表与成员间消息，orchestrator 只是一个 prompt 范式；
- subagent 上下文不共享（每个以干净上下文启动，父 agent 必须把需要的信息塞进 prompt）、嵌套限两层、token 线性叠加、简单任务上比主 agent 更慢；
- Cursor 托管 worktree 有全机 25 个上限，且自动清理会删手工建的 worktree（§5.2）；
- token 成本随并行度线性上升，另加 Bugbot 与 Cloud Agent 所需的付费套餐；
- worktree 并行会占额外磁盘：`node_modules` 39.5 MB + Godot `.godot/` 导入缓存，每个 worktree 各一份，都不能 symlink 共享。

**明确不做**：

- 不引入 Multica 或任何需要额外 stateful 服务的 Agent 平台（一期）；
- 不自建 Agent 编排框架；
- 不用 Cursor Automations（配置无法入库，§5.8）；
- 不 symlink `node_modules` 进 worktree（官方反对，且本项目依赖体积小到不值得）；
- 不为省磁盘更换包管理器（属宪法第十八条新依赖门禁）；
- 不把 Run Modes 的 `permissions.json` 或 Bugbot 的 `neutral` check 描述为门禁（宪法第二十四条）；
- 不在契约冻结前开启并行；
- 不因为"提高效率"跳过 §4.1 的四条退出条件。

---

## 8. 拍板结果

2026-08-21 由项目负责人一次性裁定全部八项。决策 1、2、5、7、8 沿自初稿；**决策 3、4、6 是本次改写因为 Cursor 事实新增的**。

- [x] **决策 1**：**接受 §4.1 四条退出条件（A1–A4）全部**作为「开始并行」的正式判据，**A4（走通第一个 PR）不可跳过**。
- [x] **决策 2**：架构选定 **Cursor 原生形态**（`/worktree` + `.cursor/agents/` + `.cursor/hooks.json`）。一期**不引入 Multica**，**不用 Automations**（配置无法入库，§5.8）。定时类需求走 GitHub Actions 的 `schedule`。
- [x] **决策 3（新增）**：选定 **R1——审查 Agent 由 Bugbot 承担**。`.cursor/agents/` 下不建审查 Agent；一期不引入 `.cursor/cli.json` 的 `permissions.deny`。R3 保留为将来升级路径。
- [x] **决策 4（新增）**：选定 **C1——收窄 `ai_autonomy` 的解释**为「禁止向 `main` 或受保护分支提交/推送，禁止部署/发布；允许在隔离 agent 分支或 worktree 上 commit/push」。**GitHub 分支保护是硬前置**，必须早于第一个 Cloud Agent 任务；hook 的判定逻辑必须配单测。
- [x] **决策 5**：初始并行度**上限 3，先跑 2 个域**，确认 review 节奏后再加第 3 个。
- [x] **决策 6（新增）**：**引入 Bugbot**，启用顺序为「本地 `/review-bugbot` 先行 → 第一个 PR 走通后再开 PR 侧」。**不启用 fail-on-unresolved-issues**，因此按宪法第二十四条，它在 CD-53 §4.1 表中必须标为「非门禁」。
- [x] **决策 7**：**批准 §4.2 三条门禁进入 M1 范围**，与 L0 契约交替进行。范围依据是 CD-61 阶段退出条件里的「AI 生成代码的自动化通过率和返工率可测量」与「人类仍能理解和接管核心模块」两项。
- [x] **决策 8**：**设立「M2 启动前工具链评审」正式检查点**，一次性处理 ADR-0003 的 Godot 主 MCP 重估与本 ADR 阶段 B 的并行度提升。

### 生效内容

1. **并行不在 M1 开头启动。** 阶段 A（单 Agent 串行 + 锁死契约 + 补三条门禁）是前置，A1–A4 全绿之前任何 Agent 不得以「提高效率」为由开启多域并行；
2. **`ai_autonomy` 的口径已收窄**：Agent 可在隔离分支/worktree 上提交，但向 `main` 与受保护分支的推送、以及部署与发布，仍是宪法第十八条的人类门禁。**这条口径变更必须先落 CD-91 D.6 与 CD-52 §1.1，落之前按原字面执行**；
3. **CD-52 §5 的「审查 Agent」角色作废**，改由 Bugbot 承担。不得在任何文档中声称 Cursor subagent 的只读是硬约束；
4. **Bugbot 与 Cloud Agent 都需要仓库读写权限**，属安全边界扩大，随本决策批准，须在 CD-62 登记；
5. **门禁状态遵守宪法第二十四条**：Schema 验证、红线扫描没进 CI、Bugbot 没启用 fail-on-unresolved-issues 之前，都不得在任何材料中描述为已生效门禁。

### 已同步

[CD-52 §1.1 / §3 / §5 / §7.3](../../Confirmed-docs/50-engineering/52-ai-workflow.md)、[CD-53 §4.1 / §4.5](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)、[CD-61](../../Confirmed-docs/60-plan/61-milestones.md)、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)、[CD-63 §2](../../Confirmed-docs/60-plan/63-open-decisions.md)、[CD-91 D.6](../../Confirmed-docs/90-reference/91-decision-log.md)、[Confirmed-docs 索引](../../Confirmed-docs/README.md)、[README.md](../../README.md)、[`.gitignore`](../../.gitignore)、[AGENTS.md](../../AGENTS.md) §2。
