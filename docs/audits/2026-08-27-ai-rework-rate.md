# AI 返工率 — 第一份数据（2026-08-27）

> 类型：纠偏 C2 度量快照（[CD-61 §3](../../Confirmed-docs/60-plan/61-milestones.md) 阶段退出条件第 6 条：自动化通过率和返工率可测量）
> 基准日：2026-08-27
> 仓库范围：`origin/main` @ `ce95ff6`（C2 第一章 `--bot-run` 合入后，本文件所在章尚未合入）
> 窗口：2026-08-20 17:49 +0800 起，至 2026-08-27 17:12 +0800，共 7 天 / 312 commits / 106 次 `Merge pull request`

纠偏方案 C2 建议的两个口径在这里落地，并补一条「为什么这个数字不能单独当成绩」的限制。数字全部由下面「怎么复跑」的命令从 git 历史算出，不是估的。

---

## 1. 口径

| # | 名称 | 定义 | 为什么选它 |
|---|---|---|---|
| R1 | 被后续提交删掉的行占累计新增的比例 | `git log --numstat` 的 deletions / insertions，按路径过滤到产品代码 | 纠偏方案原文「被后续章修改或推翻的行数占比」。改一行在 git 里通常是 −1/+1，所以 deletions 是「后来被换掉的行」的下限 |
| R2 | 被回滚的章数占比 | 标题含 `revert`（不区分大小写）的 commit 数 / `Merge pull request` 次数 | 纠偏方案原文「被回滚的章数占比」。本仓用完整章节 PR，一次 merge ≈ 一章 |
| R3 | 后续修复章占比 | 非 merge、且 Conventional Commit 类型为 `fix` 的 commit 数 / 类型为 `feat` 的 commit 数 | R2 为零时仍能看见「合入后再补刀」的密度 |
| R4 | 单文件章触达 | 某文件被多少次 commit 改过 | 行级返工低、但同一文件被几十章追加，正是审视里「上帝对象 / 追加式文档」那类问题 |

**自动化通过率**不另造口径：每次变更的 GUT + `npm test` 以 [CD-53 §4.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md) 的「已启用」列为准。合入 `main` 要求 CI 全绿，所以「合入的章」的自动门禁通过率是 100%；这不包含被打回、未开 PR、或合入后才发现的人工真机失败。

不把下列东西算进返工：纯 `docs` / `chore` 提交、测试文件的断言增补（测的是新行为，不是推翻产品代码）、格式化。

---

## 2. 结果

### R1 行级推翻

| 范围 | 当前文件 | 当前行数 | 累计 insertions | 累计 deletions | R1 |
|---|---|---|---|---|---|
| `game/src` `*.gd` | 100 | 18,578 | 19,515 | 937 | **4.8%** |
| `game/tests` `*.gd` | 99 | 21,841 | 22,320 | 479 | 2.1% |
| `backend` `*.ts` | 42 | 9,596 | 10,063 | 467 | 4.6% |
| `tools` `*.ts` | 38 | 3,218 | 3,305 | 47 | 1.4% |

产品 GDScript 被后来删掉的行，大约二十行里有一行。累计新增 19,515、当前 18,578，差额正好等于 deletions（19,515 − 937 = 18,578），说明这段历史几乎没有「整文件扔掉」，主要是追加。

行级推翻最集中的产品文件（`game/src`，按 deletions）：

| deletions | insertions | commits | 文件 |
|---|---|---|---|
| 130 | 1,519 | 33 | `game/src/client/match_lobby_shell.gd` |
| 99 | 912 | 18 | `game/src/games/traprush/graybox_course.gd` |
| 79 | 370 | 15 | `game/src/server/match_server.gd` |
| 66 | 611 | 22 | `game/src/creator/authoring_preview_shell.gd` |
| 55 | 724 | 17 | `game/src/simulation/simulation_world.gd` |

大厅壳当前 1,389 行（审视基线 2026-08-26 是 1,140 行），7 天被 34 次 commit 改过。它的 R1 是 130/1519 = 8.6%，高于仓均值，但仍然不是「写了推倒重来」，而是「每一章往同一个文件再贴一段」。

### R2 章回滚

**0 / 106 = 0%。** `git log origin/main --grep=revert -i --oneline` 为空。没有一章被整章 Revert。

### R3 后续修复

非 merge 主题：`feat` 140，`fix` 8，`docs` 51，`chore` 3，其它 4。

**fix / feat = 8 / 140 = 5.7%。** 合入后再用 `fix` 补刀的章很少。失败模式不是「写错了再改」，是「写对了，但写的不是现在该写的」。

### R4 章触达（产品代码 commit 次数最多）

| commits | 文件 |
|---|---|
| 33 | `match_lobby_shell.gd` |
| 22 | `authoring_preview_shell.gd` |
| 18 | `graybox_course.gd` |
| 17 | `simulation_world.gd` |
| 15 | `match_server.gd`、`authoring_preview.gd` |

---

## 3. 怎么读（限制）

R1 / R2 低**不能**读成「AI 产出质量已经够好，可以加速」。审视基线的偏差是：核心玩法未成形、表现层先于玩法、从未离开开发机。那些错的章多数是**一次写成、再也没人推翻**——R1 把它们算成 0% 返工，因为它们还在。

所以这份快照的用途是：

1. CD-61 §3 第 6 条从「零数据」变成「有可复跑的口径和第一组数」；
2. 下次审视用同一组命令对比，而不是再猜；
3. 提醒不要用行级返工当唯一 KPI。C5 拆大厅壳、C3 引入重力导致既有测试变红，那时 R1 预期会上升，那是纠偏方案 §8 写过的预期结果，不是回归事故。

自动化通过率（合入章的 §4.1 已启用项）是 100%，同样不能外推成「产品已验证」：网络故障、性能、外部真人测试仍是临时人工 / 未开始（宪法第二十四条）。

---

## 4. 怎么复跑

在仓库根、已 `git fetch origin main`：

```powershell
git log origin/main --pretty=tformat: --numstat -- game/src
git log origin/main --pretty=tformat: --numstat -- game/tests
git log origin/main --grep=revert -i --oneline
git log origin/main --format=%s
```

对 `numstat` 只计第三列以 `.gd` 或 `.ts` 结尾、且增删不是 `-` 的行，按路径汇总 insertions / deletions。当前行数用 `git ls-files` 后按文件读盘计数。主题类型看 Conventional Commits 前缀，忽略 `Merge ` 行。

下次快照换文件名日期，不要改这份的历史数字。
