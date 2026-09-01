# TRAPRUSH 3D 生成优先级清单

> 初版：2026-08-31。最后更新：**2026-09-01**（本文件是每次生成/入库后要回头改的活清单，不是快照）。
> 来源：`F:/AI/AIGC/genGameImage`（多视角参考图：three_quarter / front / side / top）
> 用途：img-to-3D 生成排队依据。产物 GLB 落点约定为 `game/content/assets/<类别>/<名称>.glb`。
> 本目录含 `.gdignore`（**递归**，Godot 4.7.2 实测）与本目录自己的 `.gitignore`。前者让本机编辑器不导入这些 PNG，后者让它们不进 git / LFS。两层都在，缺一层就漏。
> 依据：CD-61（M1/M2 已退出、M3 进行中）、CD-21 §5/§7 白名单。
> 本文件的相对链接**从仓库根起算**，不是从本文件所在目录起算。

---

## 0. 先读这一节：生成的硬约束

### 0.1 落点与后续处理

生成到 `_source_refs/traprush3D/<图集>_glb/`，**不要**直接放 `assets/<类别>/`。源产物 4K 贴图 + 十几 MB，过不了 [CD-11 §8.1](Confirmed-docs/10-product/11-scope-and-platforms.md)（贴图边 512、单文件 2 MB），必须先烘焙。烘焙与入库流程见 [资产烘焙 runbook](docs/runbooks/asset-bake.md)：

```bash
npx --yes @gltf-transform/cli@4.5.0 resize in.glb out.glb --width 512 --height 512   # 不要用 4.4.2
```

本目录已被 `.gitignore` 覆盖，源产物不会进 LFS（当前 99 个文件 / 353.8 MB）。

### 0.2 形状约束：厚宽比要接近 1，别生成薄板

这不是审美要求，是贴合规则的必然结果。地块贴合是**等比**缩放、系数由水平最长边推出，并让缩放后的**顶面**落在占位盒顶面（`SharedVisualAssetCatalog.fit_tile_on_cell`）：

```text
悬空格数 = max(0, 1 − 厚宽比)
```

| 资产 | 原始尺寸 | 厚宽比 | 贴合后 | 悬空 |
|---|---|---|---|---|
| `floor_tile.glb`（旧） | 1.842 × 0.338 × 1.843 | 0.184 | 1.000 × **0.184** × 1.000 | **0.816 格** |
| `block_static.glb`（新） | 0.768 × 0.769 × 0.768 | 1.001 | 1.000 × **0.999** × 1.000 | **0.000 格** |

占位盒本体现已 `layers = 0` 退出渲染，所以那片板就是玩家看到的全部。扁板在平路上看不出来，一到有落差的地方（台阶侧立面）就是一片悬空的纸——这就是 2026-09-01 换掉它的唯一理由。

⇒ **后续地形类资产一律按接近 1:1:1 生成**，顶面做完整踩踏面、底面收口。别再做薄板。

### 0.3 有些东西现在生成了也用不上

生成之前先看「有没有接线入口」，否则就是囤资产。

---

## 1. 状态总表（按图集）

| 图集 | 参考图 | 3D 产物 | 入库 | 接线 | 下一步 |
|---|---|---|---|---|---|
| char_runner_base | 有（4） | 有 | ✅ `characters/char_runner_base.glb` | ✅ 角色 | — |
| traprush_block_static | 有（4） | 有 | ✅ `terrain/block_static.glb` | ✅ 地块（solids 袋） | — |
| traprush_checkpoint_gate | 有（4） | 有 | ❌ | ❌ | 待「按 asset_id 解析」 |
| traprush_checkpoint_pad | 有（4） | 有 | ❌ | ❌ | 同上 |
| traprush_finish_gate | 有（4） | 有 | ❌ | ❌ | 同上 |
| traprush_crate | 有（3） | 有 | ❌ | ❌ | 同上（且 D4 危险色取舍未定） |
| traprush_hazard_roller | 有（4） | 有 | ❌ | ❌ | 同上（且 D4 危险色取舍未定） |
| traprush_spawn_grid | 有（4） | 有 | ❌ | ❌ | **连数据源都没有**，见 §2.2 |
| traprush_block_slope | 有（4） | 无 | — | — | **先别生成**，见 §2.1 |
| traprush_portal_two_way | 有（4） | 无 | — | — | 待接线入口 |
| traprush_portal_one_way | 有（4） | 无 | — | — | 待接线入口 |
| traprush_hazard_spike | 有（4） | 无 | — | — | 待接线入口 |
| traprush_hazard_flame | 有（4） | 无 | — | — | 待接线入口 |
| traprush_hazard_crusher | 有（4） | 无 | — | — | 待接线入口 |
| traprush_pickup_bomb | 有（3） | 无 | — | — | 待接线入口 |
| traprush_pickup_dash | 有（3） | 无 | — | — | 待接线入口 |
| traprush_bridge | **无** | 无 | — | — | 无参考图，需先补图 |

### 已生成但没能入库的 5 个（`traprush3D/` 下）

`checkpoint_gate` / `checkpoint_pad` / `finish_gate` / `crate` / `hazard_roller` 都已烘焙并通过预算门禁（7/7 ok），**卡在接线而不是资产**。`SharedVisualAssetCatalog` 只有角色与地块两个常量、按**袋类型**解析，按 `asset_id` 解析那张表是 ADR-0006 §7 的遗留项，未实装。其中 `crate`（橙）与 `hazard_roller`（洋红）还多一个待拍板项：换真模型后是否保留 D4 的危险色染色。

---

## 2. 先别生成的（生成了也是囤着）

### 2.1 `traprush_block_slope` — 权威碰撞表达不了斜坡

原清单把它列为 P0-3，理由是"坡道，路线核心地形变体"。**这个前提是错的**：

- 权威碰撞形状白名单只有 `box` / `sphere` / `capsule` / `platform_prefab`（`game/src/shared/schema/collision_shape_kinds.gd`），**没有 slope / ramp**；
- ADR-0006 §7：只有 `box` 有权威实现，`sphere` / `capsule` / `platform_prefab` 在加载层直接拒。

也就是说斜坡在 **Schema 层就无法表达**：生成了斜坡视觉，玩家踩的仍是整格 box（台阶）。视觉说"这是斜面"、碰撞说"这是台阶"，比没有斜坡更糟。等权威碰撞支持斜坡形状（破坏性 Schema 变更，M4 之后，宪法第十八条人类门禁）再补。

**如果确实想要"能爬升"的观感**，可行的替代品是**阶梯状模型**（`block_stair`）：视觉是一级级台阶，碰撞是几个整格 box，两者对得上——但需要**先补参考图**（当前 16 个图集里没有它）。

### 2.2 `traprush_spawn_grid` — 连数据源都没有

产物已生成。但出生点**不在 SimulationBundle 的 7 个袋里**：它来自 `graybox_course` 的 `start_x` 或最低 `order` 的 pad。表现层没有它的位置来源，接线要先解决数据源，不只是加一个常量。

### 2.3 `traprush_bridge` — 无参考图，且没有接线入口

CD-21 §7 白名单里有它，但（a）本目录没有它的参考图；（b）即使生成了也没有接线入口：现在按袋类型解析，一个 `solids` 袋只能给一个模型，而"这里是平路、那里是窄桥"需要按 `asset_id` 解析。

---

## 3. 原来的优先级（保留作历史，已过时，别照它排队）

初版把 P0 写成"替换现有占位"，其中两条当天就已过时：

- **P0-2 `block_static` 在写下那天已经交付**：`floor_tile.glb` 就是它（PR #190，2026-08-30 入库，人类提供，667 KB → 64 KB）。本文件 2026-08-31 才生成，晚了一天。
- **P0-3 `block_slope` 的 blocked 原因当初没查**：见 §2.1。

| 初版序 | 图集 | 初版理由 | 现状 |
|---|---|---|---|
| 1 | char_runner_base | 当前用 robot_placeholder.glb | ✅ 已换（2026-09-01） |
| 2 | traprush_block_static | 当前用 floor_tile.glb | ✅ 已换（2026-09-01，修薄板悬空） |
| 3 | traprush_block_slope | 坡道，路线核心地形变体 | ⛔ blocked，见 §2.1 |
| 4–9 | finish_gate / checkpoint_pad / checkpoint_gate / portal_two_way / portal_one_way / crate | 验收核心物件 | 3 个已生成未入库；portal 未生成。全卡接线入口 |
| 10–16 | hazard_* / pickup_* / spawn_grid | 当前为洋红占位盒 | 1 个已生成未入库；spawn_grid 见 §2.2 |

### 未入选（机制尚未实现）

- 可破坏家族扩展：traprush_rubble / traprush_energy_wall / traprush_obstacle_core
- 移动类（sim 未实现移动平台）：traprush_platform_mover / traprush_conveyor / traprush_lift / traprush_launch_pad
- 触发类（sim 未实现触发链）：traprush_gate / traprush_switch / traprush_portal_switch
