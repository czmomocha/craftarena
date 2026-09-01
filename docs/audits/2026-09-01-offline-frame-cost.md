# 离线 Solo 每帧成本：从 33.7 ms 到 1.7 ms

> 日期：2026-09-01
> 触发：人类在开发机上观察到「未进对局约 120 FPS，点 Solo play 后掉到 20–30 FPS」
> 落点：`game/src/shared/fixed/fixed.gd`、`game/src/client/match_lobby_shell.gd` 与三个表现 map
> 性质：**观察值，不是门禁**。[CD-53 §1.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md) 明确不建自动性能回归门禁

## 1. 一句话结论

掉帧与渲染无关，**根因是 `Fixed.try_mul` 单次要 176 微秒**：它走的是纯 GDScript 的软件 128 位大整数长除法，而每次碰撞查询要对 49 个静态盒各做 4 次。加一条「中间积不溢出 int64 就用原生乘除」的快路径后，整帧从 **33.73 ms 降到 1.664 ms（20×）**，且仿真结果逐字节不变。

## 2. 为什么能断定不是渲染

点 Solo play **之前**，36 块地砖、5 条传送连线、4 个检查点顺序标、终点盒就已经画在屏幕上了，那时是 120 FPS。点下去只多了一个角色和每帧的 `_process` 工作。所以增量 100% 在 CPU 侧。

这条推断后来被数字证实：headless（**完全没有渲染**）下同一条路径也是 33.7 ms。

## 3. 测法

`game/tests/support/frame_cost_bench.gd`，可复跑：

```powershell
& $env:GODOT4_CONSOLE --headless --path game -s res://tests/support/frame_cost_bench.gd
```

开发机 Windows + Godot 4.7.2 debug 解释器，300 帧均值，预热 10 帧。**诚实边界**：headless 不付 GPU 上传、着色器与 draw call 提交，所以它**低估**「每帧 free 再 new 一个 Label3D / MeshInstance3D」的真实代价；真机收益只会比这里大。真机 FPS 由人类按[章节真机清单](../runbooks/chapter-device-check.md)走查确认，本文件不能替代那一步（宪法第二十四条）。

## 4. 分摊表

| 段 | 改前 ms/帧 | 改后 ms/帧 |
|---|---:|---:|
| 整帧（physics + render） | **33.730** | **1.664** |
| └ `offline.try_advance` | 31.607 | 1.351 |
| 　└ `session.commit_tick` | 33.191 | 1.313 |
| 　　└ `apply_player_falls` | 25.655 | 1.020 |
| 　　　└ `Gravity.integrate` | 25.035 | 0.980 |
| 　　　└ `_resolve_player_hazards` | 0.629 | 0.030 |
| 　　└ `advance_sim_tick` | 7.541 | 0.316 |
| 　└ `_publish`（编解码） | 0.011 | 0.010 |
| └ `_apply_snapshot_map` | 0.170 | 0.125 |
| 　└ `standings.apply_players` | 0.018 | 0.016 |
| 　└ `crates.apply_follow` | 0.019 | 0.006 |
| 　└ `hazards.apply_follow` | 0.017 | 0.006 |
| 　└ `map.apply_players` | 0.009 | 0.009 |
| 占 60 FPS 预算（16.667 ms） | 202% | **10%** |

碰撞数学探针（同一次运行）：

| | 改前 | 改后 |
|---|---:|---:|
| 静态盒数 / 实体数 | 49 / 1 | 49 / 1 |
| `is_pose_blocked` 一次 | 25.183 ms | 0.971 ms |
| `Fixed.try_mul` 一次 | **0.1756 ms** | **0.0014 ms** |
| `Fixed.try_add` 一次 | 0.0011 ms | 0.0010 ms |

## 5. 根因

`Fixed.try_mul(a, b)` 就是 `try_mul_div(a, b, SCALE)`，而 `try_mul_div` 无条件走软件大整数：

- `_mul_mags` 做 4×4 限位乘法；
- `_div_mags` 做 **128 轮逐位长除**，每轮 `_shl1` / `_sub_limbs` / `_with_bit` 各新建一个 `PackedInt32Array`。

一次 `StaticAabb.overlaps_capsule` 要 4 次 `try_mul`（dx²、dz²、dy²、radius²）。一次 `is_pose_blocked` 遍历全部静态盒。于是 49 × 4 × 0.176 ms ≈ 34 ms —— **整帧就是它**。

128 位中间积在 `a * b / SCALE` 里是**正确性**需要的（两个 Q48.16 相乘会先冲出 int64 再被除回来），但它不该是常见路径：碰撞检测里的间隙都是格子尺度，中间积根本不溢出。

> 玩家当时**静止**在出生点下方的地砖上（`vy = 0`、竖直扫掠 0 步），成本恒定不随 tick 增长。也就是说这不是「扫掠步数发散」那个已知缺口（[2026-08-28 审计](2026-08-28-ci-gate-timeout.md)），那条仍然欠着。

## 6. 改了什么

1. **`Fixed.try_mul_div` 加 64 位快路径**：`|left * right| ≤ INT64_MAX` 时直接用原生整数乘除，溢出才回退到限位长除法。两条路径都向零截断、符号都由三个操作数异或决定，**结果逐位相同**。
2. **对局壳一帧只重映射一次**：离线权威推进与输入采样搬到 `_physics_process`（固定 60 Hz，与 `match_server.gd` 同一节拍），`_process` 只留插值 + 一次 `_apply_snapshot_map`。原来一帧三次重映射、四次状态行重排。
3. **三个表现 map 复用节点**：`MatchStandingMap` / `MatchCrateMap` / `MatchHazardMap` 从「全清全建」改为按稳定键复用，与 `MatchSnapshotMap._sync_players`（C4 第 6 章）同一种修法。

第 2 项同时修掉一个**正确性**缺陷：离线仿真节拍原本等于帧率。33 ms/帧时是三分之一速慢放，帧成本修好之后会变成 120 tick/s 的两倍速；按住 W 的位移同理（离线意图立即应用、不按 tick 排队）。

## 7. 凭什么说行为没变

| 证据 | 结果 |
|---|---|
| `test_fixed_mul_div_paths.gd` 差分用例 | 快路径与限位路径在边界值、碰撞形状输入与 4000 组定种子伪随机上给出同一个值，22,318 条断言 |
| `--bot-run` 三张官方课 | 动作序列、`expansions`、`search_ticks`、`steps`、`ticks` **逐字段与改前相同**；墙钟 108.6 s → 5.7 s |
| `tests/replay/` 官方磁带回放 | 同磁带同 `hash_state` 与同快照字节 |
| GUT 全量 | 见本刀 PR 的 Test plan |

## 8. 顺带的效果

`Fixed.try_mul` 是全项目热点，不只服务对局：

- `--bot-run` 三张课 108.6 s → **5.7 s**（19×）；
- GUT 全量 354.6 s → **24.4 s**。同日的测试分层（探针记忆化 + `tests/slow`）自己只能把它压到 285 s 量级，剩下的一个数量级是这条快路径给的。也正因为如此，slow 层最初「移出 PR 门禁」的决定被同日收回——它现在只要 7 秒；
- 服务端 `match_server.gd` 的 `commit_tick` 走同一条 `SimulationWorld`，单场 CPU 占用同比例下降（未在 Linux 上实测，[CD-44](../../Confirmed-docs/40-technical/44-deployment.md) 的容量核算可在有样本后复核）。

## 9. 仍然欠着

- **扫掠取样代价无上限**（宪法第十七条缺口）：步数正比于 `|dy| / radius`，玩家长时间自由下落时仍会线性增长。本刀只把每步的常数压下去了，没有给步数封顶，也没有引入空间划分。
- **无空间划分**：`is_pose_blocked` 仍是 O(静态盒数) 全量扫描。49 个盒子现在只要 0.97 ms，但 UGC 赛道的盒数没有上限。
- **真机 FPS 未由本文件证明**：headless 只量 CPU。人类走查见[章节真机清单](../runbooks/chapter-device-check.md)。
- **未在导出包或 Linux 上量过**：以上全部是 Windows 开发机 debug 解释器的数字。
