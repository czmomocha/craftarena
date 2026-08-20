# Godot UGC 架构下的双游戏选型与简易策划案

> 文档定位：以《Godot 引擎发展现状与 AI 游戏开发生态深度调研报告》与《Godot UGC、运行时编辑与网络对战架构设计脑暴》为唯一输入，**反推**出两个最适配该架构的具体游戏，并给出简易策划案。
>
> 撰写日期：2026-08-20
>
> 结论先行：推荐 **《机关狂奔》（代号 TRAPRUSH）** 与 **《双塔要塞》（代号 BASTION）**。两者共享同一套 `SimulationCore`、同一套 15 个规则节点、同一套组件 Schema v1，构成"高动作 / 低动作"的风险对冲组合。

---

## 第一部分 · 选型方法论

### 1.1 为什么不能先想玩法再套架构

架构脑暴文档第 16 节把"先建平台后找玩法"列为失败模式之一，同时第 13 节又给了一个纵向切片建议（2~4 人俯视角占点对战）。这两点合起来说明：**玩法必须是从架构约束里"长出来"的，而不是拿一个心目中的游戏去硬塞。**

所以本文的推导顺序是：架构硬约束 → 排除性筛选 → 候选池 → 打分 → 两个选型。

### 1.2 九条硬约束（从架构文档提取）

| 编号 | 约束 | 对玩法的直接含义 |
|---|---|---|
| C1 | 服务器唯一权威，客户端不可提交结果 | 命中、得分、拾取都要服务端裁决，**不能是高速弹道类** |
| C2 | 不追求跨平台确定性物理（8.6 节） | **不能是物理沙盒建造类**（Besiege / Trailmakers 型） |
| C3 | MVP 只预测本地高频移动（8.5 节） | 手感压力只允许集中在"走位"这一件事上 |
| C4 | UGC 只能实例化白名单 Archetype + 调参 + 连规则图 | 玩法乐趣必须来自**布局 + 触发链**，不能来自自定义脚本 |
| C5 | 规则图 15 节点以内、有 gas 预算 | 内容表达空间必须能被有限节点覆盖，不能是效果发散的卡牌类 |
| C6 | 竞技局锁定内容版本、默认只允许 P0 表现热改 | 运行时改状态只能落在**沙盒/预览/导演模式**，不能是核心竞技机制 |
| C7 | 渲染基线 Compatibility（WebGL 2），轻 3D | 低面数、无后处理依赖、卡通风、俯视或斜 45° |
| C8 | 12 周产出可玩纵向切片（桌面 + Headless） | 单局 3~6 分钟、2~4 人、单地图规模、无经济系统 |
| C9 | 小游戏为减配跟进端，共享规则不共享包体 | 单局短、首包小、支持人数可降级、地图可裁剪 |

### 1.3 候选池与淘汰理由

| 候选 | 契合点 | 淘汰 / 保留理由 |
|---|---|---|
| 物理载具建造对战 | UGC 表达力极强 | **淘汰**：违反 C2，权威物理不可跨端一致 |
| 战术 FPS / 竞技射击 | 市场大 | **淘汰**：违反 C1 + C3，需要命中回溯与全量预测 |
| 自定义卡牌自走棋 | 网络最简 | **淘汰**：违反 C5（效果组合发散，预算与验证爆炸）+ 违反 C7（轻 3D 无增益） |
| 俯视角占点对战 | 架构文档自带切片 | **降级为参照**：可行但同质化重（Roblox / Fortnite Creative 已饱和），差异化弱 |
| 回合制战棋 UGC | 网络极简 | **降级**：架构里的预测、快照、安全 Tick 大半用不上，投入产出比低 |
| 双人合作机关解谜 | UGC 契合极高 | **降级为模式**：无"对战"诉求，作为 TRAPRUSH 的合作模式 |
| **多人机关竞速 + 关卡工坊** | 见 2.2 全项命中 | **选中：游戏一** |
| **塔防对垒 + 战场蓝图工坊** | 见 3.2 全项命中 | **选中：游戏二** |

### 1.4 两个选型的组合价值

不是选两个孤立游戏，而是选一个**能共用同一内核、但风险特征互补**的组合：

```text
                    共享 SharedContracts + SimulationCore + Rule VM(15 节点)
                                        │
              ┌─────────────────────────┴─────────────────────────┐
        《机关狂奔》TRAPRUSH                              《双塔要塞》BASTION
        高动作 / Tick 30Hz / 预测本地移动              低动作 / Tick 15Hz / 零预测
        验证：手感、预测校正、空间兴趣管理             验证：规则图深度、实体预算、经济规则
        风险：网络手感调优                             风险：内容平衡与创作者门槛
        小游戏减配：人数 4→2，地图裁剪                  小游戏减配：几乎无损（天生低频）
```

如果只做 TRAPRUSH，架构中的"规则图表达深度"验证不足；如果只做 BASTION，架构中的"预测 / 校正 / 回滚"整条链路完全没被压测。两个一起做，12 周切片能把架构文档第 12 节的**每一周验收项都真实触发一次**。

---

## 第二部分 · 共享内核规格（两游戏公用）

这一节是两份策划案能同时成立的技术前提，先定死，再谈玩法。

### 2.1 组件 Schema v1（14 个）

所有数值采用整数或定点量化（毫米 / 毫秒 / 千分比），符合架构文档 6.3 节要求。

| 组件 | 字段（示例） | 复制策略 | TRAPRUSH | BASTION |
|---|---|---|---|---|
| `transform` | `position_mm[3]`、`rotation_mdeg[3]` | RelevantArea | ✅ | ✅ |
| `velocity` | `linear_mm_per_tick[3]` | PredictedOwner | ✅ | — |
| `health` | `current`、`max`、`invuln_ticks` | Everyone | ✅ | ✅ |
| `team` | `team_id` | Everyone | ✅ | ✅ |
| `score` | `value`、`scope` | Everyone | ✅ | ✅ |
| `zone` | `shape`、`radius_mm`、`tag_filter` | RelevantArea | ✅ | ✅ |
| `spawner` | `archetype_id`、`interval_ticks`、`max_alive` | RelevantArea | ✅ | ✅ |
| `hazard` | `damage`、`knockback_mm`、`cooldown_ticks` | RelevantArea | ✅ | ✅ |
| `mover` | `path_points_mm[]`、`speed_mm_per_tick`、`loop_mode` | RelevantArea | ✅ | ✅ |
| `interactable` | `state`、`link_group_id`、`reset_ticks` | RelevantArea | ✅ | ✅ |
| `checkpoint` | `order_index`、`respawn_offset_mm` | Everyone | ✅ | — |
| `path_agent` | `waypoint_group`、`speed`、`bounty` | RelevantArea | — | ✅ |
| `build_slot` | `allowed_archetypes[]`、`occupied_by` | Everyone | — | ✅ |
| `replication` | `policy` 枚举 | 元数据 | ✅ | ✅ |

### 2.2 Rule VM 节点集（15 个，两游戏完全共用）

严格对齐架构文档 6.5 节的四分类与 18 节"15 个以内"的要求。

**Event（5）**

| 节点 | 说明 |
|---|---|
| `OnMatchStarted` | 开局一次 |
| `OnEveryTicks(n)` | 周期触发，n 有下限保护 |
| `OnEnteredZone(zone, tag)` | 实体进入触发区 |
| `OnEntityDied(tag)` | 实体死亡 |
| `OnVariableThreshold(var, op, value)` | 变量跨越阈值（边沿触发，防抖） |

**Query（3）**

| 节点 | 说明 |
|---|---|
| `GetVariable(scope, name)` | 读变量 |
| `GetField(entity_ref, component, field)` | 读组件字段（白名单字段） |
| `CountInZone(zone, tag)` | 区域计数，按返回数收 gas |

**Condition（2）**

| 节点 | 说明 |
|---|---|
| `Compare(a, op, b)` | 数值 / 枚举比较 |
| `Logic(op, inputs[])` | And / Or / Not，输入数有上限 |

**Action（5）**

| 节点 | 说明 |
|---|---|
| `SetVariable(scope, name, value)` | 含 Add 语义（delta 模式） |
| `Spawn(archetype, marker, count)` | 仅白名单 Archetype，受 spawns/s 预算 |
| `Despawn(entity_ref)` | 销毁 |
| `ApplyEffect(target, effect, magnitude)` | 伤害 / 治疗 / 击退 / 状态，统一收口 |
| `EmitGameEvent(name, payload)` | 发领域事件，供表现层与胜负判定消费 |

**为什么只要 15 个就够**：TRAPRUSH 的"机关联动 + 检查点 + 竞速判定"和 BASTION 的"波次 + 经济 + 胜负"本质都是"事件驱动的状态机 + 计数器"，二者的差异在 **Archetype 白名单**和**变量作用域配置**上，不在节点集上。这正是选择这两个游戏而非其他候选的最强理由——**一套 VM 撑两个品类，验证成本减半。**

### 2.3 反作弊边界（两游戏共用）

客户端**永远不能**发送这四类断言：我击中了 / 我的位置是这里 / 我通过了检查点 / 我建造成功了。客户端只发意图：

```text
TRAPRUSH: MoveIntent(dir_quantized) / JumpIntent / InteractIntent(target_hint)
BASTION : BuildIntent(slot_id, archetype_id) / UpgradeIntent(entity_id) / SendWaveIntent(wave_id)
```

服务端校验：所有权、冷却、资源、距离、目标合法性、单位时间频次、Payload 取值域。

---

## 第三部分 · 游戏一《机关狂奔》TRAPRUSH

### 3.1 一句话定位

**4 人同图机关竞速的轻 3D 关卡工坊**：玩家用平台化机关积木搭出致命跑道，其他人在同一张图上同时开跑，服务器裁决谁先冲线；创作者靠"通关率 / 完成时长"曲线获得社区排名。

参照坐标（仅定位，不抄玩法）：《Levelhead》的关卡工坊循环 + 《Stumble Guys》的同图竞速紧张感 + Mario Maker 的创作者荣誉体系，做成轻 3D 斜 45° 视角。

### 3.2 为什么它是这套架构的最优解

| 架构约束 | TRAPRUSH 的天然契合 |
|---|---|
| C1 服务器权威 | 机关触发、伤害、检查点、冲线全在服务端；玩家之间**无直接伤害**，取消了最难的 PVP 裁决 |
| C2 不依赖确定性物理 | 玩家移动是自研 kinematic 胶囊 + 简化数学查询（架构 8.6 节推荐），机关是 `mover` 路径运动，不依赖 Jolt 结果一致 |
| C3 只预测本地移动 | 竞速游戏 99% 的手感诉求就是"我自己走得顺"，远端 3 人只需插值，**MVP 预测范围与玩法诉求完全重合** |
| C4 UGC 白名单 | 机关天生是有限品类（尖刺 / 压路机 / 传送带 / 炮台 / 门 / 弹射板 / 传送门），穷举即可 |
| C5 15 节点规则图 | "踩开关 → 门开 → 3 秒后关"就是 `OnEnteredZone → SetVariable → OnVariableThreshold → SetField` 的四节点链，创作者 5 分钟能懂 |
| C6 竞技局锁版本 | 排行榜局锁 `content_hash`；创作者调参在 Preview Session 里做；**"导演模式"作为独立非竞技模式**承接 P2/P3 热改 |
| C7 Compatibility 基线 | Kenney / Quaternius 风格低面数积木，无后处理依赖，纯色 + 描边就成立 |
| C8 12 周切片 | 单局 90~180 秒、4 人、单张 UGC 地图、无经济，是架构文档 W1~W12 的等价难度 |
| C9 小游戏减配 | 4 人降 2 人、地图长度限一段、纹理 512、去粒子；**规则与内容包完全不变** |

### 3.3 核心循环

```text
【玩家侧】
挑选热门关卡 → 4 人同房同时开跑 → 服务端裁决冲线名次
   → 拿到"最快时间"与该关卡的个人段位 → 想改进 → 再来一局
                     ↓ 想造更难的
【创作者侧】
进入工坊 → 摆机关 / 调参 / 连触发链 → 30 秒进入单人预览
   → 邀 1~3 名好友试跑（Preview Session）→ 上传验证 → 发布
   → 看通关率曲线与评论 → 发新版本（version+1，旧版本回放仍可复现）
```

关键 KPI：**创作者从"改一个参数"到"双人实测"的时间 ≤ 30 秒**（这正是架构文档 18 节给的验收标准）。

### 3.4 玩法规则细节

**单局流程**

| 阶段 | 时长 | 权威行为 |
|---|---|---|
| 握手锁定 | — | 校验 `content_id + version + content_hash + ruleset_version + runtime_version` |
| 观察期 | 5 s | 镜头巡览关卡，玩家不可移动，机关静止 |
| 竞速期 | 90~180 s | 固定 Tick 30Hz 推进；机关按 `mover` / `spawner` 运行；死亡回退到最近 `checkpoint` |
| 结算期 | 10 s | 名次、各段用时、死亡次数、该关卡通关率上报 |

**死亡与惩罚**：无生命上限，死亡回退检查点 + 1.5 秒复活硬直。竞速的惩罚货币是**时间**而不是**局数**，这样单局时长可控（对小游戏端极其重要）。

**名次与得分**：冲线名次 4/2/1/0 分；同时记录"该关卡个人最佳时间"用于异步排行榜。异步榜与实时局共享同一 `SimulationBundle`，回放用命令日志 + 种子 + 关键 Tick 快照复现（架构 8.6 节）。

**玩家间交互（刻意做浅）**：不能互相攻击，只能**触发机关影响对手**——踩开关会给后面的人开门也可能关门、拉动压路机、抢用一次性弹射板。冲突全部经服务端权威判定，且都是低频离散事件，不需要回溯。

### 3.5 UGC 编辑范围

**Archetype 白名单（16 个，一期）**

| 分类 | Archetype | 关键可调参数 |
|---|---|---|
| 地形 | `block_static`、`block_slope`、`block_thin_bridge` | 尺寸（格）、材质槽位（P0 表现） |
| 起终点 | `spawn_grid`、`finish_line` | 出发朝向、宽度 |
| 检查点 | `checkpoint_gate` | `order_index`、复活偏移 |
| 移动 | `platform_mover`、`conveyor` | 路径点、速度、`loop_mode`、启动延迟 |
| 伤害 | `spike_field`、`crusher`、`turret_slow`（低速弹） | 伤害、周期、击退、预警时长 |
| 弹射 | `launch_pad`、`teleport_pair` | 力度、目标点、冷却、单次/多次 |
| 交互 | `switch_plate`、`gate_door` | `link_group_id`、`reset_ticks`、初始状态 |
| 拾取 | `pickup_boost` | 效果类型（限速度/无敌/跳跃）、时长、刷新间隔 |

`turret_slow` 特意限定为**低速可见弹丸**（≤ 8 m/s），彻底规避高速弹道回溯需求——这是"用玩法设计消解架构复杂度"的关键取舍。

**可编辑变量**

| 作用域 | 变量 | 用途 |
|---|---|---|
| Content Constant | `time_limit`、`max_players`、`checkpoint_count` | 开局锁定 |
| Match | `round_timer`、`finished_count` | 全局可靠增量 |
| Entity | `gate_state`、`platform_phase`、`switch_pressed` | 兴趣范围内同步 |
| Presentation Only | 预警闪烁强度、镜头震动 | 只发事件，不进权威状态 |

**典型规则图示例（创作者视角，4 节点）**

```text
OnEnteredZone(zone="switch_a", tag="player")
  → SetVariable(Entity, "gate_state", 1)        // 门打开
OnVariableThreshold(var="gate_state", op="==", value=1)
  → SetVariable(Match, "gate_a_close_at", round_timer + 3000)   // 3 秒后关
OnEveryTicks(15)
  → Compare(round_timer, ">=", gate_a_close_at)
  → SetVariable(Entity, "gate_state", 0)
```

进阶示例（危险但合法，靠 gas 预算兜底）：

```text
OnEveryTicks(30)
  → CountInZone(zone="arena_mid", tag="player")
  → Compare(result, ">=", 2)
  → Spawn(archetype="crusher", marker="mid_top", count=1)   // 人多就加压
```

### 3.6 权威状态与网络参数

**权威状态清单**

- 4 名玩家的 `transform`、`velocity`、`health`、当前 `checkpoint.order_index`、死亡次数
- 每个机关实体的 `mover` 相位、`interactable.state`、`spawner` 计时
- Match 变量：剩余时间、已完赛人数、各玩家分段用时
- 服务端私有：反作弊标记（`Never` 策略）、命令频次窗口

**网络参数（起始值，需由实测调整）**

| 项 | 值 |
|---|---|
| Server Tick | 30 Hz |
| 输入上行 | 30 Hz，带 `sequence` + `last_received_snapshot` |
| 状态快照 | 15 Hz 增量，基线丢失 / 重连时发全量 |
| 客户端插值缓冲 | 3 个快照 |
| 回滚缓冲 | 1 秒（30 Tick） |
| 预测范围 | 仅本地玩家移动与跳跃；弹射板与传送门**不预测**（等服务端确认，用镜头拉伸掩盖 1 帧延迟） |
| 目标网络条件 | 120 ms RTT + 30 ms 抖动 + 3% 丢包下可玩 |

**关键设计决策**：弹射与传送不预测。这类"大位移离散事件"预测错了会造成剧烈瞬移，而它们频次低，等一个 RTT 的代价远小于校正的视觉代价。这条决策直接来自架构文档 8.5 节"技能、生成和得分先由服务器确认再表现"。

### 3.7 内容预算（Manifest 片段）

```json
{
  "schema_version": 1,
  "content_id": "ugc.traprush.level",
  "version": 1,
  "entry_world": "track_main",
  "ruleset_version": 1,
  "capabilities": [
    "spawn.prefab.whitelist",
    "combat.damage.hazard_only",
    "score.race_time",
    "interact.link_group"
  ],
  "budgets": {
    "max_entities": 400,
    "max_dynamic_bodies": 60,
    "max_rule_nodes": 300,
    "max_rule_edges": 500,
    "max_rule_ops_per_tick": 8000,
    "max_spawns_per_second": 15,
    "max_zone_queries_per_tick": 40,
    "max_track_length_m": 400,
    "package_size_kb": 8192
  },
  "platform_budgets": {
    "wechat_minigame": {
      "max_entities": 200,
      "max_players": 2,
      "max_texture_px": 512,
      "package_size_kb": 3072,
      "max_track_length_m": 180
    }
  }
}
```

**超预算即拒发布**，不在线上偷偷降级（架构 10.1 节明确要求），因为服务端与客户端降级结果不一致会导致裁决分歧。小游戏端的差异只能是**平台资源变体**，不是另一套规则。

### 3.8 三种世界的落地形态

| 世界 | TRAPRUSH 中的具体样子 |
|---|---|
| `AuthoringWorld` | 网格化工坊：格子吸附摆放、机关参数面板、规则图连线板、Undo/Redo 栈（反向 EditCommand） |
| `SimulationWorld` | 纯数据 World：400 实体上限、稳定 ID、固定 Tick、种子 RNG（`pickup_boost` 刷新用） |
| `PresentationWorld` | Godot 节点树：低面数积木 + 描边材质 + 预警特效 + 名次 UI；**随时可丢弃重建** |

### 3.9 12 周切片映射

| 周次 | 架构文档验收项 | TRAPRUSH 对应产出 |
|---|---|---|
| W1~W2 | 同输入日志得同状态哈希 | 单人跑一条硬编码跑道，30Hz Tick，Transform/Health/Team/Score/Velocity 五组件 |
| W3~W4 | 不改代码只改 JSON 做两张图 | 网格工坊 + EditCommand/Undo + Bundle 编译器；两张"规则同、布局异"的跑道 |
| W5~W6 | 不可信客户端不能改血量/位置/得分 | Headless Server + ENet；四人同图；改内存血量被服务端覆盖，改位置被拒 |
| W7~W8 | 不写代码做出两个玩法变体 | 15 节点 Rule VM + gas；用规则图做出"开关门竞速"与"限时收集"两种变体 |
| W9~W10 | 目标网络条件下可玩且能复现异常 | 本地移动预测 + 校正 + 输入回放；120ms/30ms/3% 下四人竞速手感通过 |
| W11~W12 | 创作者全流程闭环 | 上传隔离区 + 验证流水线 + 签名 + Staging；3~5 名真实创作者造图并邀好友联机 |

### 3.10 首版明确不做

- 玩家上传模型 / 贴图 / 音频（一期只给平台资产 + 材质槽位）
- 玩家之间直接伤害与武器系统
- 高速弹道与命中回溯
- 实时多人协同编辑（用 Revision + 对象软锁）
- 排位、经济、抽奖
- 关卡内脚本 / 自定义公式
- 微信小游戏导出（放在桌面切片稳定之后的独立里程碑）

### 3.11 扩展模式（承接架构里的 P2/P3 热改能力）

**导演模式（Sandbox，非竞技，不计排名）**：1 名导演 + 3 名跑者。导演在对局运行中通过受权限的 `AdminCommand` 实时增删机关、改参数、改胜负条件——这正是架构文档 7.2 节 P2/P3 级热修改的唯一合法舞台。房间强制标记 `ranked=false`，所有热补丁走"安全 Tick + 事务应用 + 失败回滚 + 广播新 Revision"。

这个模式的产品价值：它把"运行时改状态"这个技术能力**直接变成了卖点玩法**，而不是仅作为开发工具。同时它不污染竞技公平性。

**合作模式（2 人）**：两人各控一个角色，部分门需双人同时踩开关（`CountInZone >= 2`）。零新增节点，纯内容配置即可实现。

### 3.12 平台差异矩阵

| 端 | 人数 | 渲染 | 差异点 |
|---|---|---|---|
| PC / Steam | 4 | Forward+ 增强 | 键鼠 + 手柄；GodotSteam 创意工坊订阅关卡；关卡编辑器完整版 |
| Android / iOS | 4 | Compatibility | 内置 VirtualJoystick（4.7 原生）；编辑器为简化版（摆放 + 调参，规则图只读） |
| 网页 / 微信小游戏 | 2 | Compatibility 减配 | 只玩不造；关卡按 `platform_budgets` 裁剪变体；WebSocket 网关接同一命令协议 |
| 鸿蒙 NEXT | 二期 | — | 官方未合入，不进一期关键路径 |

### 3.13 风险与对策

| 风险 | 等级 | 对策 |
|---|---|---|
| 弱网下竞速手感不达标 | 高 | W9~W10 专项；预测只做移动；离散大位移不预测；镜头平滑追赶而非瞬移 |
| 创作者做出"不可能通关"的垃圾关 | 高 | 上传前 Headless 机器人自动试跑（架构 10.1 节要求），通不过就拒；发布后按通关率自动降权 |
| 4 人同图视觉混乱 | 中 | 远端玩家半透明 + 描边区分；不做碰撞阻挡（只做机关交互） |
| 关卡工坊学习曲线陡 | 中 | 规则图默认折叠，提供 8 个预设触发链模板；AI 助手把自然语言转成合法规则图草稿（调研报告 4.x 生态可直接用） |
| 内容荒（发布初期没图） | 中 | 内部策划先用 Godot Editor Plugin 造 30 张官方关卡打底 |

---

## 第四部分 · 游戏二《双塔要塞》BASTION

### 4.1 一句话定位

**2v2 对垒式塔防的战场蓝图工坊**：双方在同一张 UGC 战场上互相派兵、互相布防，玩家用"路径 + 建造槽 + 波次规则"三件套设计战场蓝图；胜负由服务器权威的兵线推进结果裁决。

参照坐标（仅定位）：《Bloons TD Battles》的对垒结构 + 《要塞英雄》类的路径设计乐趣 + Warcraft3 塔防 RPG 的自定义地图文化，做成轻 3D 斜俯视。

### 4.2 为什么它是这套架构的第二优解

| 架构约束 | BASTION 的天然契合 |
|---|---|
| C1 服务器权威 | 兵线寻路、塔攻击、经济结算全在服务端；客户端**只发建造/升级/派兵意图**，作弊面天然最小 |
| C2 不依赖确定性物理 | 完全不需要刚体物理：兵沿 waypoint 移动，塔用距离查询锁敌，**架构 8.6 节的物理确定性顾虑被彻底绕开** |
| C3 只预测本地移动 | **一个都不用预测**。玩家不控制角色，UI 操作用"乐观显示 + 服务端确认"即可，是最低网络风险的选型 |
| C4 UGC 白名单 | 塔 / 兵 / 路径 / 建造槽 / 出兵口都是天然有限品类 |
| C5 15 节点规则图 | 波次表、经济公式、胜负条件全是"计数器 + 阈值 + Spawn"，规则图利用率**比 TRAPRUSH 更深**，正好压测 Rule VM |
| C6 竞技局锁版本 | 排位局锁蓝图哈希；蓝图调参在 Preview Session 做 |
| C7 Compatibility 基线 | 低面数塔 / 兵、无动态光、大量同模型实例（可用 MultiMesh 优化），是 WebGL 2 的舒适区 |
| C8 12 周切片 | 单局 5~8 分钟、2v2、单蓝图、内部经济不出局，无外部经济系统 |
| C9 小游戏减配 | **几乎无损降级**：本身低 Tick、低带宽、无高频输入，是最理想的小游戏首发形态 |

### 4.3 与游戏一的互补性（关键选型理由）

| 维度 | TRAPRUSH | BASTION |
|---|---|---|
| Tick 需求 | 30 Hz | 15 Hz |
| 预测 / 校正 | 必须（本地移动） | 不需要 |
| 实体规模 | 400（少而动） | 1200（多而慢，兵潮） |
| 兴趣管理 | 空间兴趣为主 | 队伍可见性为主（战争迷雾 `TeamOnly`） |
| 规则图深度 | 浅（4~10 节点链） | 深（30~80 节点链，波次+经济） |
| gas 预算压力 | 中（区域查询） | 高（每 Tick 上千次锁敌查询） |
| 主要风险 | 网络手感 | 内容平衡 |
| 小游戏适配难度 | 高 | 低 |

**两者叠加，把架构文档里所有"待验证项"都覆盖到了**：TRAPRUSH 压测 8.5 节（预测回滚）与 8.3 节（空间兴趣），BASTION 压测 6.5 节（规则图与 gas）与 8.3 节（`TeamOnly` 战争迷雾），二者共同压测 7.2 节（热修改分级）与 10.1 节（验证流水线）。

### 4.4 核心循环

```text
【对局侧】
选蓝图 → 2v2 匹配 → 准备期布防 → 波次开始
   → 边防守边攒钱 → 花钱建塔 / 花钱派兵打对面
   → 一方基地血量归零 → 结算
                     ↓ 想设计更平衡的战场
【创作者侧】
蓝图工坊 → 画兵线路径 → 摆建造槽 → 配波次表 → 写经济公式
   → 单人 vs AI 预览（30 秒进）→ 2v2 内测 → 上传验证 → 发布
   → 看双方胜率 / 平均局时 / 塔使用率热力图 → 调参发新版本
```

创作者的核心成就感来源：**做出一张"胜率 48~52%、平均局时 6 分钟、四种塔都有人用"的蓝图**。这是可量化的创作目标，比 TRAPRUSH 的"好玩"更容易给数据反馈，创作者留存机制更硬。

### 4.5 玩法规则细节

**单局流程**

| 阶段 | 时长 | 权威行为 |
|---|---|---|
| 握手锁定 | — | 校验蓝图 `content_hash` + `ruleset_version` + `runtime_version` |
| 准备期 | 45 s | 初始金币建塔；不可派兵；镜头可自由查看双方战场 |
| 波次期 | 每波 30 s，共 10~16 波 | 15 Hz Tick；`spawner` 按波次表出兵；塔锁敌攻击；漏兵扣基地血 |
| 突入期 | 最后 3 波 | 出兵强度阶跃、可派"精英兵"；经济收益翻倍 |
| 结算期 | 15 s | 基地剩余血量、总伤害、经济效率、MVP |

**胜负条件**：基地血量先归零者负；打满全部波次双方均存活时，剩余血量高者胜；血量相同比"总漏兵数"。全部由规则图表达，**创作者可以改**（这是 UGC 的核心表达自由）。

**经济系统（局内，不出局）**

| 来源 | 规则 |
|---|---|
| 基础收入 | 每波结束固定收入，随波次递增 |
| 击杀赏金 | 每个兵携带 `path_agent.bounty`，杀死即得 |
| 派兵投资 | 花钱给对面加兵，同时永久提升自己每波基础收入（经典对垒塔防的核心张力） |
| 漏兵损失 | 漏兵扣基地血，不扣钱 |

这套经济的技术意义：**它把"派兵"变成了一个低频、离散、可完全服务端裁决的决策**，全程不需要任何客户端预测，却制造了持续的博弈张力。

**玩家操作频次**：设计目标是每分钟 10~25 次操作。这是刻意压低的——低频操作意味着上行带宽极小、命令校验成本极低、弱网容忍度极高，是"用玩法设计换网络鲁棒性"的另一次取舍。

### 4.6 UGC 编辑范围

**Archetype 白名单（18 个，一期）**

| 分类 | Archetype | 关键可调参数 |
|---|---|---|
| 战场骨架 | `lane_waypoint`、`lane_junction`、`spawn_gate`、`core_base` | 坐标、分支权重、基地血量 |
| 建造 | `build_slot_ground`、`build_slot_high`（仅远程塔）、`build_slot_shared`（双方争夺） | `allowed_archetypes[]`、初始归属 |
| 塔 · 单体 | `tower_arrow`、`tower_cannon`、`tower_sniper` | 伤害、射速、射程、造价、升级曲线 |
| 塔 · 范围 | `tower_splash`、`tower_frost`（减速）、`tower_aura`（增益友塔） | 半径、效果强度、持续 Tick、造价 |
| 兵 · 普通 | `unit_runner`（快血少）、`unit_tank`（慢血多）、`unit_swarm`（群体） | 血量、速度、赏金、派兵价格 |
| 兵 · 特殊 | `unit_shielded`（免疫减速）、`unit_healer`（治疗友军）、`unit_boss` | 同上 + 特殊效果强度 |
| 地形装饰 | `deco_block`（纯表现，不影响寻路） | 材质槽位（P0） |

`build_slot_shared`（双方都能抢的中立建造槽）是一个刻意加入的机制：它制造了"塔防游戏里罕见的抢点冲突"，且实现上只是 `build_slot.occupied_by` 的一次服务端权威写入，**零新增技术复杂度，玩法张力显著提升**。

**可编辑变量**

| 作用域 | 变量 | 复制策略 |
|---|---|---|
| Content Constant | `wave_count`、`base_hp`、`start_gold`、`prep_time` | 开局内容包 |
| Match | `current_wave`、`wave_timer` | Everyone |
| Team | `team_gold`、`team_income_per_wave`、`base_hp_left` | **TeamOnly**（对手看不到你的准确金币，只看到模糊档位） |
| Entity | `tower_level`、`tower_cooldown`、`unit_hp` | RelevantArea |
| Presentation Only | 攻击特效强度、命中音效 | EventOnly |

`team_gold` 用 `TeamOnly` 是刻意的：它让"猜对手在憋钱还是在建塔"成为博弈的一部分，同时正好验证架构文档 8.3 节的战争迷雾复制策略与 16.8 节"客户端拿到不该知道的数据"的安全边界。

**典型规则图示例 · 波次表（创作者视角）**

```text
OnMatchStarted
  → SetVariable(Match, "current_wave", 0)
  → SetVariable(Team, "team_gold", start_gold)

OnEveryTicks(450)                                  // 15Hz × 30s = 一波
  → SetVariable(Match, "current_wave", +1)
  → Spawn(archetype="unit_runner", marker="spawn_gate_a",
          count = 3 + current_wave)
  → SetVariable(Team, "team_gold",
          + base_income + team_income_per_wave)

OnVariableThreshold(var="current_wave", op=">=", value=14)
  → Spawn(archetype="unit_boss", marker="spawn_gate_a", count=1)   // 突入期
```

**典型规则图示例 · 胜负条件（创作者可改）**

```text
OnEnteredZone(zone="core_base_a", tag="unit")
  → SetVariable(Team_A, "base_hp_left", -1)
  → Despawn(event.entity)
  → EmitGameEvent("base_leaked", {team: "A"})

OnVariableThreshold(var="base_hp_left", op="<=", value=0)
  → EmitGameEvent("match_end", {loser: event.team})
```

创作者能改胜负条件这件事，是 BASTION 相对普通塔防的最大差异化：有人做"漏 20 兵才输"的欢乐局，有人做"漏 1 兵就输"的硬核局，有人做"限时抢分不看血量"的变体。**全部用同一套 15 节点，零代码。**

### 4.7 权威状态与网络参数

**权威状态清单**

- 每个 `path_agent`（兵）的 `transform`、`health`、当前 waypoint 索引、状态效果剩余 Tick
- 每个塔的 `tower_level`、冷却、当前锁定目标 ID
- 每个 `build_slot` 的 `occupied_by`
- Team 变量：金币、每波收入、基地血量（对手侧仅可见模糊档位）
- Match 变量：当前波次、波次计时
- 服务端私有：命令频次窗口、反作弊标记

**网络参数（起始值）**

| 项 | 值 |
|---|---|
| Server Tick | 15 Hz |
| 输入上行 | 事件驱动（按操作发，非固定频率），限 5 次/秒 |
| 状态快照 | 10 Hz 增量；兵位置量化到 10 mm |
| 客户端插值缓冲 | 2 个快照 |
| 预测 | **无**。建造/升级/派兵采用"乐观 UI 灰显 + 服务端确认后落定" |
| 兵潮上限 | 单方 400 单位、双方 800、含塔与装饰共 1200 实体 |
| 目标网络条件 | 250 ms RTT + 60 ms 抖动 + 8% 丢包下可玩 |

**带宽优化关键**：兵是同构大批量对象，快照层对同 Archetype 的兵做**批量增量编码**（共享 archetype id，只发 delta 位置与血量），并用 `RelevantArea` 只发镜头附近的兵。塔攻击不发状态，只发 `EventOnly` 领域事件由客户端播特效。

### 4.8 内容预算（Manifest 片段）

```json
{
  "schema_version": 1,
  "content_id": "ugc.bastion.blueprint",
  "version": 1,
  "entry_world": "battlefield_main",
  "ruleset_version": 1,
  "capabilities": [
    "spawn.prefab.whitelist",
    "combat.damage.tower_standard",
    "score.base_hp",
    "economy.match_local",
    "visibility.team_only"
  ],
  "budgets": {
    "max_entities": 1200,
    "max_dynamic_bodies": 0,
    "max_rule_nodes": 600,
    "max_rule_edges": 1000,
    "max_rule_ops_per_tick": 20000,
    "max_spawns_per_second": 40,
    "max_target_queries_per_tick": 1500,
    "max_lane_waypoints": 200,
    "max_build_slots": 60,
    "package_size_kb": 6144
  },
  "platform_budgets": {
    "wechat_minigame": {
      "max_entities": 600,
      "max_texture_px": 512,
      "package_size_kb": 3072,
      "note": "人数与规则不变，仅裁剪同屏兵数上限与特效层级"
    }
  }
}
```

注意 `max_dynamic_bodies: 0`——BASTION **完全不使用动态物理体**。这条预算本身就是对架构文档 8.6 节确定性顾虑的正面回应，也是它作为第二个游戏最"安全"的证据。

`max_target_queries_per_tick: 1500` 是最需要压测的预算项：60 座塔在 15 Hz 下每 Tick 各做一次范围锁敌查询，是 gas 系统的真实负载来源。这正是选它来验证 Rule VM 预算体系的原因。

### 4.9 三种世界的落地形态

| 世界 | BASTION 中的具体样子 |
|---|---|
| `AuthoringWorld` | 蓝图工坊：路径画笔（拖出 waypoint 链）、建造槽刷、波次表格编辑器、经济公式面板、规则图连线板 |
| `SimulationWorld` | 纯数据 World：1200 实体、零刚体、稳定 ID、15 Hz、种子 RNG（分支权重用） |
| `PresentationWorld` | Godot 节点树：MultiMesh 批量渲染兵潮、塔攻击轨迹特效、血条/金币 UI |

### 4.10 12 周切片映射（与 TRAPRUSH 并行复用同一内核）

| 周次 | BASTION 对应产出 | 与 TRAPRUSH 的复用关系 |
|---|---|---|
| W1~W2 | 硬编码一条兵线 + 一座塔，兵走到底扣基地血 | 复用 SimulationCore、Tick、RNG、Score |
| W3~W4 | 蓝图工坊：路径 + 建造槽 + 波次表；两张"规则同、路径异"的蓝图 | 复用 EditCommand / Undo / Bundle 编译器 |
| W5~W6 | 2v2 Headless；改客户端金币被拒、伪造建造被拒 | 复用 Session / 命令校验 / 快照层 |
| W7~W8 | 用规则图做出"标准塔防"与"漏兵限时"两个变体；`TeamOnly` 迷雾 | **同一套 15 节点，深度用法压测 gas** |
| W9~W10 | 800 兵潮下 Tick P99 与带宽压测；无预测的 UI 手感调优 | 复用网络仿真工具；不复用预测链路 |
| W11~W12 | 蓝图上传验证 + 机器人 AI 自动对打平衡性检测 + 签名发布 | 复用整条内容平台流水线 |

### 4.11 首版明确不做

- 玩家上传模型 / 音频（一期只给平台资产）
- 塔的自定义攻击公式（只能调参，不能写公式）
- 局外经济、卡组、天赋、抽卡
- 排位与赛季
- 4v4 及以上、多蓝图轮换
- 实时协同编辑蓝图
- 观战与录像回看（回放数据先存起来，UI 二期做）

### 4.12 扩展模式

**天梯蓝图轮换（二期）**：官方每周从社区蓝图中选 3 张进入天梯池，创作者获得署名与曝光。这是 UGC 内容平台的核心飞轮，且完全建立在架构文档 10.2 节的版本策略之上（`ContentId + Version + ContentHash` 全程可追溯）。

**单人闯关（Preview Session 的产品化）**：玩家单人打 AI 蓝图，允许在关卡内使用受限 `AdminCommand`（回退一波、重置金币重来），标记为非竞技。这把架构里的"Preview Session 热修改能力"变成了新手教学与休闲内容。

**协作 2v2 蓝图共创（二期）**：Revision + 对象软锁即可（架构 9.1 节 MVP 策略），无需 CRDT。

### 4.13 风险与对策

| 风险 | 等级 | 对策 |
|---|---|---|
| 创作者做出严重不平衡蓝图（一塔封死） | 高 | 上传前跑机器人 AI 双方对打 N 局，胜率偏离 40~60% 直接拒发；发布后按真实胜率自动降权 |
| 800 兵潮下 Tick 超时 | 高 | 塔锁敌用空间网格加速；同 Archetype 兵批量更新；gas 预算硬上限 + 超限中止并记内容错误 |
| 塔防品类同质化严重 | 中 | 差异化押在三点：对垒派兵经济、`build_slot_shared` 抢点、创作者可改胜负条件 |
| 蓝图工坊比关卡工坊更难上手 | 中 | 波次表用表格而非节点图（表格背后自动生成规则图）；提供 5 张官方蓝图作为可 fork 模板 |
| 低操作频次导致玩家觉得"没事干" | 中 | 突入期阶跃 + 中立槽抢点 + 派兵时机博弈，把决策密度集中在波次切换的 5 秒窗口 |

---

## 第五部分 · 双游戏协同与共享资产清单

### 5.1 复用率评估

| 层 | 复用率 | 说明 |
|---|---|---|
| L0 `SharedContracts` | 100% | ID、Schema、命令、事件、快照协议、Manifest 全共享 |
| L1 `SimulationCore` | 约 85% | Tick、World、RNG、回放、状态哈希共享；差异在 System 集合（TRAPRUSH 有 Movement，BASTION 有 Pathing） |
| L2 `UGCRuntime` | 约 95% | Rule VM、gas、验证器、迁移、资源管线全共享；差异仅 Archetype 白名单表 |
| L3 `MatchServer` | 约 90% | Session、命令校验、复制、反作弊、审计共享；差异在 Tick 频率与兴趣策略配置 |
| L4 `GameClient` | 约 60% | 平台层、输入、插值、渲染映射共享；预测/校正模块 BASTION 不用 |
| L5 `CreatorTools` | 约 80% | 编辑模型、命令历史、Undo、预览链路共享；差异在编辑器 UI 面板 |
| L6 `ContentPlatform` | 100% | 上传、验证、编译、签名、CDN、灰度、下架全共享 |

**综合复用率约 85%**。第二个游戏的增量成本大致是第一个的 30~40%，这是"选两个而不是一个"在商业上成立的核心依据。

### 5.2 共享工具清单

| 工具 | 说明 |
|---|---|
| `DevLauncher` | 一键起 1 Headless + 2~4 客户端，注入测试账号，配置延迟/抖动/丢包，导出回放与性能报告（架构 11.3 节） |
| `ContentValidator` | 单一验证器二进制，按 `content_id` 前缀选 Archetype 白名单与预算表 |
| `BotRunner` | TRAPRUSH 用它自动试跑判断可通关性，BASTION 用它自动对打判断平衡性——**同一套机器人框架，两种验收用途** |
| `ReplayInspector` | 命令日志 + 种子 + 关键 Tick 快照的复现与逐 Tick 步进 |
| `RuleGraphDebugger` | 规则节点触发次数、gas 消耗、最近输入输出、错误定位 |

### 5.3 AI 在两个项目中的统一定位

依据调研报告的四层集成模型与架构文档 11.2 节，AI 的合法位置：

| 用途 | 具体做法 |
|---|---|
| 自然语言转规则图 | 创作者说"人多就加压"，AI 生成合法的 `CountInZone → Compare → Spawn` 链，走同一验证器，不获额外信任 |
| 批量生成测试内容 | 生成 200 张随机合法蓝图/跑道，跑 Golden Content 与 Soak 测试 |
| 解释验证器错误 | 把"规则节点 #47 gas 超预算"翻译成创作者能懂的话并给修改建议 |
| 驱动编辑器建表现层 | 通过 Godot MCP 生成 PresentationWorld 场景模板（非权威数据，风险低） |
| Headless 测试与定位 | 跑测试读错误、根据回放定位规则热点 |

**红线**（同时来自调研报告 2.6 节与架构文档 11.2 节）：AI 不得绕过规则图生成并发布任意 GDScript；AI 产出走完全相同的 Schema / 预算 / 沙盒仿真验证；给 Godot 引擎本体提 PR 的代码必须人写（这条只约束引擎贡献，不约束本项目游戏代码）。

### 5.4 引擎与工程约定（两项目一致）

- Godot 4 **Standard**（非 .NET），锁定 4.7 stable；工程内禁止出现 `.cs` / `.csproj`
- 全部 GDScript；仿真热点先上 GDExtension，不为性能改 .NET
- 渲染按 **Compatibility（WebGL 2）** 设计基线，PC 用 Forward+ 做增强而非前提
- 平台差异全部收在 `client/platform/`，不得泄漏进 `SimulationCore`
- 美术基座 CC0（Kenney / Quaternius）+ AI 定制补洞，统一 GLB 导入
- 项目根 `CLAUDE.md` / `AGENTS.md` 声明"Godot 4.7 语法、禁用 Godot 3 API"并附映射表；`.claude/rules/*.gd` 挂 GDScript 风格规则；GUT 单测兜底版本漂移

---

## 第六部分 · 联合排期建议

12 周内不要真的并行开两个游戏。推荐"一主一影"节奏：

```text
W1  ─ W6   ：TRAPRUSH 独立推进（主线），BASTION 只做 Archetype 白名单与波次表设计（纸面）
W7  ─ W8   ：TRAPRUSH 完成 Rule VM；BASTION 用同一 VM 搭最小可跑对局（复用红利首次兑现）
W9  ─ W10  ：TRAPRUSH 预测/校正专项；BASTION 兵潮性能与带宽专项（两条互不干扰的压测线）
W11 ─ W12  ：共用内容平台流水线；两边各邀 3~5 名真实创作者试用
W13 ─ W16  ：按数据选定一个作为一期主推产品，另一个降为"同引擎第二品类"缓推
```

**16 周决策点的判据**

| 判据 | 倾向 TRAPRUSH | 倾向 BASTION |
|---|---|---|
| 创作者次日回访 | 造图更上瘾 | 调参更上瘾 |
| 弱网可玩性达标情况 | 达标则优势大 | 天然达标 |
| Tick P99 与带宽 | 不成问题 | 若压不下来则风险高 |
| 微信小游戏首包与人数 | 减配代价大 | 减配代价小 |
| 内容生产速度 | 单张跑道产出快 | 单张蓝图需平衡验证，产出慢 |

---

## 第七部分 · 待确认问题（对齐架构文档 17 节的开放项）

架构文档 17 节留了 10 个开放问题，本策划案回答了其中一部分，剩下需要拍板：

**本文已给出答案的**

| 原问题 | 本文答案 |
|---|---|
| Q1 目标玩法品类 | 轻动作竞速（TRAPRUSH）+ 低动作对垒塔防（BASTION），均俯视/斜 45° 轻 3D |
| Q2 人数/Tick/延迟 | TRAPRUSH 4 人 / 30 Hz / 120 ms；BASTION 2v2 / 15 Hz / 250 ms |
| Q4 UGC 是否允许上传资产 | 一期仅平台资产 + 材质槽位，不开放上传 |
| Q5 是否需要协同创作 | 一期不需要，Revision + 软锁足够 |
| Q6 运行时编辑的定位 | TRAPRUSH 做成"导演模式"正式玩法；BASTION 做成"单人闯关"的受限能力；竞技局一律锁版本 |

**仍需 K 哥拍板的**

1. **是否进排名与奖励**：直接决定安全等级与反作弊投入。建议一期做"关卡内异步时间榜 / 蓝图胜率榜"，不做账号级排位，把安全等级压在中档。
2. **是否允许客户端离线玩 UGC**：若允许，离线成绩能否写回在线账户？建议一期允许离线单人试玩但成绩不回写。
3. **弹性扩容 / 跨区匹配 / 观战**：建议一期单区、固定容量、不做观战（回放数据先落库）。
4. **两个游戏是否同品牌**：建议做成同一个"创作平台"下的两个玩法频道，共享账号与创作者身份，这样内容平台投入摊薄到两条产品线。
5. **主机平台**：架构文档标注"仍未定"，本策划案未纳入，需明确是否要在美术与输入设计上预留。

---

## 附录 A · 两个策划案的一页速览

| 维度 | 《机关狂奔》TRAPRUSH | 《双塔要塞》BASTION |
|---|---|---|
| 品类 | 4 人机关竞速 + 关卡工坊 | 2v2 对垒塔防 + 蓝图工坊 |
| 视角 | 斜 45° 轻 3D | 斜俯视轻 3D |
| 单局 | 90~180 s | 5~8 min |
| Tick | 30 Hz | 15 Hz |
| 快照 | 15 Hz 增量 | 10 Hz 增量 |
| 预测 | 仅本地移动与跳跃 | 无 |
| 实体上限 | 400 | 1200 |
| 动态物理体 | 60 | 0 |
| Archetype | 16 | 18 |
| 规则节点 | 共用同一套 15 个 | 共用同一套 15 个 |
| UGC 表达核心 | 空间布局 + 机关触发链 | 兵线路径 + 波次经济 + 胜负条件 |
| 主要技术验证 | 预测/校正、空间兴趣管理 | Rule VM 深度、gas 预算、TeamOnly 迷雾 |
| 主要风险 | 弱网手感 | 内容平衡与 Tick 性能 |
| 小游戏减配 | 4→2 人、地图裁剪 | 几乎无损 |
| 差异化亮点 | 导演模式（运行时改机关变成玩法） | 创作者可改胜负条件 + 中立争夺槽 |

## 附录 B · 反向自检：这两个游戏是否踩了架构文档第 16 节的失败模式

| 失败模式 | 本方案是否规避 |
|---|---|
| 1 把 `.tscn` 当数据库 | ✅ UGC 源格式为 JSON，编译为二进制 Bundle，`.tscn` 只做表现模板 |
| 2 为热更新允许任意 GDScript | ✅ 只有白名单规则图，无脚本上传 |
| 3 客户端同步结果而非输入 | ✅ 两游戏的客户端命令均为纯意图 |
| 4 把领域事件当状态同步 | ✅ 快照负责状态，事件只驱动表现与审计 |
| 5 过早追求全量预测/回滚 | ✅ TRAPRUSH 只预测本地移动，BASTION 零预测 |
| 6 规则图没有执行预算 | ✅ 两份 Manifest 均含 gas 与查询预算，BASTION 专项压测 |
| 7 正式对局支持任意热换规则 | ✅ 竞技局锁版本；热改能力隔离在导演模式/单人闯关（非竞技） |
| 8 客户端拿到不该知道的数据 | ✅ BASTION 的 `team_gold` 用 TeamOnly，对手仅见模糊档位 |
| 9 只做编辑器不做验证器 | ✅ `BotRunner` 自动试跑/对打是发布前的强制关卡 |
| 10 先建平台后找玩法 | ✅ 本文正是"先窄玩法纵向切片"的产物 |
| 11 因 WASM 就选 .NET 版 | ✅ 锁定 Standard + GDScript，禁止 `.csproj` |
| 12 把鸿蒙 NEXT 写进一期 | ✅ 二期，不进关键路径 |
| 13 PC Forward+ 做成唯一路径 | ✅ Compatibility 为基线，Forward+ 仅增强 |

---

*本策划案为架构收敛用的产品侧输入，所有数值为起始建议值，须由 12 周切片实测调整。*