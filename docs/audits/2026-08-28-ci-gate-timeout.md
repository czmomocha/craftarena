# CI Godot 门禁连续五刀未通过（2026-08-28）

> 类型：门禁失守事故记录（宪法[第十条](../../AGENTS.md#第十条测试是完成条件)测试是完成条件、[第二十四条](../../AGENTS.md#第二十四条测试声明必须真实)测试声明必须真实）
> 发现日：2026-08-28，在排查「本地某个 GUT 用例挂死」时顺带发现
> 影响范围：`origin/main` 上 `afe850c`（PR #175 合入）之后到 `99504c6`（PR #180 合入）之间的五次合并
> 处置：本文件所在章（`fix/ci-gut-timeout`，`[freeze-exception]`）

---

## 1. 发生了什么

`.github/workflows/ci.yml` 的 `godot` job 设了 `timeout-minutes: 15`。从 2026-08-28 02:18 起，`GUT unit, integration, and replay tests` 这一 step 每次都在 15 分钟处被 GitHub 终止。

**被终止的 job 结论是 `cancelled`，不是 `failure`。** PR 页面上它既不是红叉也不是绿勾，`gh pr checks` 在合并前那一刻显示的还是 `pending`。人类与 AI 都把它读成了「还在跑」，五个 PR 的正文里都写了「CI 绿」。

| 时间（UTC） | run | Godot job | 耗时 | 结论 |
|---|---|---|---|---|
| 08-27 09:58 | 33061013596 | PR #170 头 | 5.0 min | success |
| 08-27 11:54 | 33069466223 | PR #172 头（C3 ch.1 重力） | 4.8 min | success |
| 08-27 13:08 | 33075324602 | PR #173 头（C3 ch.2 官方路面） | 10.2 min | success |
| 08-27 16:31 | 33093638911 | PR #174 头（C3 ch.3 道具） | 11.4 min | success |
| 08-28 01:13 | 33132181771 | PR #175 头（C3 ch.4 机关碾压） | 11.7 min | success |
| 08-28 01:16 | 33132348316 | PR #175 合并 | 12.5 min | **最后一次 success** |
| 08-28 02:18 | 33135534433 | PR #176 头（C3 ch.5 安全路线） | 15.3 min | **cancelled** |
| 08-28 03:35 | 33139332626 | PR #176 合并 | 15.3 min | cancelled |
| 08-28 04:59 | 33143409370 | PR #177 头（C3 ch.6 协议 RTT） | 15.3 min | cancelled |
| 08-28 05:04 | 33143679824 | PR #177 合并 | 15.3 min | cancelled |
| 08-28 06:59 | 33149831764 | PR #178 头（C3 ch.7 双路线） | 15.3 min | cancelled |
| 08-28 07:23 | 33151304071 | PR #178 合并 | 15.3 min | cancelled |
| 08-28 08:11 | 33154361764 | PR #179 头（C1 一键更新测试机） | 15.4 min | cancelled |
| 08-28 08:12 | 33154421088 | PR #179 合并 | 15.4 min | cancelled |
| 08-28 09:10 | 33158243459 | PR #180 头（C3 ch.8 复活硬直） | 15.3 min | cancelled |
| 08-28 09:15 | 33158618544 | PR #180 合并 | 15.3 min | cancelled |

同一 run 里的 `backend` job 每次都在 0.3 分钟内 success，所以 `npm test`、`typecheck` 与红线扫描不受影响。失守的只有 Godot 这一侧：GUT 单元、集成、回放三个目录，以及它们之前已经跑完的 `--check-only` 逐文件类型检查（那几步都是 success，被切的是最后一步）。

## 2. 为什么会变慢

`game/tests/unit/test_authoring_preview_play.gd` 里有四处、`game/tests/integration/test_traprush_authoring_to_match.gd` 里有一处，把胶囊尺寸写成了字面量 `1`：

```gdscript
assert_true(_preview_shell.try_start_play(1, 1, 1))
```

后两个 `1` 是 `radius` 与 `cylinder_height`，单位是 Q48.16 原始整数，也就是 **1/65536 格**。真实角色是 `TraprushPlayStubs.CAPSULE_RADIUS = Fixed.SCALE / 8 = 8192`。这行是 [PR #104](https://github.com/czmomocha/craftarena/pull/104) 写的，当时只是要一个「非零胶囊」，重力还不存在，所以无害。

`SimulationWorld` 的竖直扫掠按 `_sweep_step_count(|dy|, radius) = ceil(|dy| / radius)` 决定取样次数——半径是安全步长，写小 8192 倍，取样就细 8192 倍。Preview 壳的 `_copy_fall_stub()` 让一次 Advance 下落一整格（`PlayStubs.PREVIEW_FALL_DY = -Fixed.SCALE = -65536`），于是：

| 传入的 radius | 取样次数 | 一次 `try_advance_play` 实测耗时 |
|---|---|---|
| 8192（= 真实角色） | 8 | 80 ms |
| 1024 | 64 | 760 ms |
| 64 | 1024 | 12.3 s |
| 8 | 8192 | 100 s |
| 1（**测试实际传的值**） | 65536 | 外推约 800 s |

每次取样约 12.2 ms，完全线性——每次取样都要对整份编译拓扑做一次占用判定，所以赛道里的静态盒越多，单次取样越贵。这解释了为什么耗时是**逐章爬上去**的而不是一次跳变：C3 ch.2 给三张官方课铺了沿路地板（5.0 → 10.2 分钟），ch.3 / ch.4 继续加，ch.5 的安全路线把它推过了 15 分钟。

所以这**不是死循环**。第一次排查时记的「进程 CPU 停住、是阻塞」是错的：进程一直在满核跑。它也**不是 Windows 特有**，Linux CI 上同样慢，只是 CI 会在 15 分钟处被切掉，本地不会，于是本地表现成「永远跑不完」。

## 3. 为什么没被发现

三件事同时成立才会漏掉：

1. **`cancelled` 不是 `failure`。** 超时终止在 GitHub 上是灰色圆点，视觉上更接近「排队中」而不是「失败」。
2. **合并前看的是 `gh pr checks`，那时它还是 `pending`。** 没有人在合并后回头看 run 的最终 `conclusion`。
3. **耗时没有任何可见性。** GUT 只在结尾打一个总时长，单个脚本从 0.3 秒涨到 13 分钟的过程，在 PR 里看不到任何信号，直到它一次吃光整个预算。

分支保护要求的两个 status check 里，`cancelled` 显然不该算通过。为什么这五次仍能合并，本文件不下结论——需要人类核对 `main` 的保护规则实际配置（是否 `enforce_admins` 关闭、是否用了管理员绕过），结论另记。

[2026-08-27 的 AI 返工率快照](2026-08-27-ai-rework-rate.md) §1 写过「合入 `main` 要求 CI 全绿，所以合入章的自动门禁通过率是 100%」。那句话在写下时（基准 `ce95ff6`，PR #169）成立，从 PR #176 起不再成立。该文件的历史数字不改，本节即为更正。

## 4. 处置

本章做四件事：

1. 把五处 `1, 1` 改成 `TraprushPlayStubs.CAPSULE_RADIUS / CAPSULE_HEIGHT`，并在原处写清为什么不能随手写 1。断言全部不变、全部仍通过。
2. CI 的 GUT step 自己掐 12 分钟（`timeout -k 30 720`）。超预算由 `timeout` 结束进程，step 变红并打印一行明确错误，不再是灰色的 `cancelled`。job 级 `timeout-minutes: 15` 保留为兜底。预算数字按 §5 的 CI 实测定，不是拍的。
3. 新增 `Report slowest test scripts` step：用 GUT 的 `-gjunit_xml_file` 导出结果，打印最慢的 10 个测试脚本与总时长。不判定，只让下一次变慢在 PR 里看得见。
4. 在当前 `main` 上补跑一次完整 GUT，结果记在下一节。

**不做**：给 `SimulationWorld._sweep_step_count` 加取样上限。取样密度直接决定权威碰撞落点，改它会动状态哈希与回放基线，属于 `simulation/` 深审，另立一章。它本身是宪法第十七条「性能有预算」的缺口——单次扫掠的代价与 `1/radius` 成正比且无上限——这一条记在待办里，不在本章解决。

## 5. 补验结果

在 `fix/ci-gut-timeout`（= `main` @ `99504c6` + 本章修改）上跑：

```powershell
& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
```

**111 个脚本 / 1080 个用例全通过，总耗时 354.6 秒（Windows 开发机）**，退出码 0。这是 PR #176 以来第一次有人真的看到这套测试跑完，也说明那五刀的产品代码本身没有被这次门禁失守掩盖掉的失败。

耗时最长的脚本（同一次运行的 JUnit 导出）：

| 秒 | 测试脚本 |
|---|---|
| 121.8 | `tests/unit/test_traprush_official_path_floors.gd` |
| 58.2 | `tests/unit/test_traprush_course_completion_probe.gd` |
| 41.7 | `tests/unit/test_traprush_semantic_course.gd` |
| 21.0 | `tests/replay/test_traprush_official_tape_replay.gd` |
| 16.2 | `tests/unit/test_match_lobby_shell.gd` |

前三名都是在权威仿真上做搜索或整段走课，代价本来就高，不是本次的异常。

本章 PR 在 CI 上跑出的第一组数（run `33168145521`，两个 job 最终 `conclusion` 都是 `success`）：

| | 开发机（Windows） | CI（ubuntu-latest） |
|---|---|---|
| GUT 111 个脚本合计 | 354.1 s | 533.1 s |
| GUT step 墙钟 | — | 9.0 min |
| 最慢单个脚本 | 121.8 s | 186.4 s（`test_traprush_official_path_floors.gd`） |
| GUT 之前的步骤合计 | — | 1.4 min |

CI 比开发机慢约 1.5 倍，所以预算必须按 CI 这一列定。最初按开发机数字设的 10 分钟只剩 67 秒余量，会误报；改为 **12 分钟**：比实测多约 35%，同时 1.4 + 12 = 13.4 分钟仍在 job 的 15 分钟上限之内——预算比 job 上限晚触发就等于没加。

作为对比，最后一次绿的 CI（PR #175）里 GUT 单独花了 10.9 分钟，其中约 7 分钟是本次修掉的那一个用例。

**后续观察点**：`test_traprush_official_path_floors.gd` 一个脚本占了 CI 侧 GUT 总时长的三分之一。它在权威仿真上把三张官方课整段走完，代价是真实的，但再加课就会重新逼近预算。下次赛道扩容时先看这一行。

## 7. 后续（2026-09-02，C5 第 15 章）

当时「不做」的取样上限已另立深审章落地：`SimulationWorldMove.MAX_SWEEP_STEPS = 256`，超限拒绝整段位移，不粗化取样。`radius=1` 下落一整格不再跑 65536 次，会立刻失败。本节历史数字与处置不改。口径见 [CD-42 §1.1](../../Confirmed-docs/40-technical/42-contracts-and-rulevm.md)。

## 6. 怎么复跑本文件的结论

```powershell
# 各次 run 的 Godot job 结论与耗时
$runs = (gh run list --workflow=ci.yml --limit 30 --json databaseId,conclusion,displayTitle | Out-String) | ConvertFrom-Json
foreach ($r in $runs) {
  $j = (gh run view $r.databaseId --json jobs | Out-String) | ConvertFrom-Json
  $g = $j.jobs | Where-Object { $_.name -like "*GUT*" }
  "{0,-11} {1,-10} {2,5:N1}m  {3}" -f $r.databaseId, $g.conclusion, ((([datetime]$g.completedAt)-([datetime]$g.startedAt)).TotalMinutes), $r.displayTitle
}
```

耗时与 radius 的关系用一个临时 GUT 脚本量的：对同一张 `course_01` 连续 `try_start_play(1, r, r)` 并设 `play_fall_dy = PlayStubs.PREVIEW_FALL_DY`，用 `Time.get_ticks_msec()` 夹住一次 `try_advance_play()`，`r` 取 8192 / 1024 / 64 / 8 / 1。该脚本是一次性排查工具，不入库。
