# TRAPRUSH 3D 生成优先级清单

> 生成日期：2026-08-31
> 来源：`F:/AI/AIGC/genGameImage`（多视角参考图：three_quarter / front / side / top）
> 用途：img-to-3D 生成排队依据。产物 GLB 落点约定为 `game/content/assets/<类别>/<名称>.glb`。
> 本目录含 `.gdignore`，Godot 不会导入这些 PNG，不会进入包体。
> 依据：CD-61（M1/M2 已退出、M3 进行中）、CD-21 §5/§7 白名单、现有占位资产（`characters/robot_placeholder.glb`、`terrain/floor_tile.glb`）。

## P0 — 立即生成（替换现有占位，全程可见/用量最大）

| 序 | 图集 | 产物建议落点 | 理由 |
|---|---|---|---|
| 1 | char_runner_base | assets/characters/runner_base.glb | 玩家角色，对局全程可见，当前用 robot_placeholder.glb |
| 2 | traprush_block_static | assets/terrain/block_static.glb | 地形块用量最大，当前用 floor_tile.glb |
| 3 | traprush_block_slope | assets/terrain/block_slope.glb | 坡道，路线核心地形变体 |

## P1 — 尽快生成（M3 表现映射直接受益，验收核心物件）

| 序 | 图集 | 产物建议落点 | 理由 |
|---|---|---|---|
| 4 | traprush_finish_gate | assets/flow/finish_gate.glb | 终点冲线是每局验收核心 |
| 5 | traprush_checkpoint_pad | assets/flow/checkpoint_pad.glb | 检查点垫已实现占用验收 |
| 6 | traprush_checkpoint_gate | assets/flow/checkpoint_gate.glb | 检查点门，与垫配套 |
| 7 | traprush_portal_two_way | assets/portal/portal_two_way.glb | 验收要求上层传送 |
| 8 | traprush_portal_one_way | assets/portal/portal_one_way.glb | 验收要求左右区块单向传送 |
| 9 | traprush_crate | assets/obstacle/crate.glb | 可破坏箱已在 M3 表现映射（橙色占位盒） |

## P2 — 排队生成（周期机关与道具刚落地，当前为洋红占位盒）

| 序 | 图集 | 产物建议落点 | 理由 |
|---|---|---|---|
| 10 | traprush_hazard_spike | assets/hazard/hazard_spike.glb | 周期机关代表（sim 目前为通用 hazard 固体切换） |
| 11 | traprush_hazard_roller | assets/hazard/hazard_roller.glb | 周期机关变体 |
| 12 | traprush_hazard_flame | assets/hazard/hazard_flame.glb | 周期机关变体 |
| 13 | traprush_hazard_crusher | assets/hazard/hazard_crusher.glb | 周期机关变体 |
| 14 | traprush_pickup_bomb | assets/pickup/pickup_bomb.glb | 爆破道具（UseItemIntent 打箱已实现） |
| 15 | traprush_pickup_dash | assets/pickup/pickup_dash.glb | 冲刺道具（白名单原型候选） |
| 16 | traprush_spawn_grid | assets/flow/spawn_grid.glb | 出生点，简单且每局必现 |

## 未入选（机制尚未实现，图集保留在 F:/AI/AIGC/genGameImage 待后续批次）

- 可破坏家族扩展：traprush_rubble / traprush_energy_wall / traprush_obstacle_core
- 地形变体：traprush_bridge
- 移动类（sim 未实现移动平台）：traprush_platform_mover / traprush_conveyor / traprush_lift / traprush_launch_pad
- 触发类（sim 未实现触发链）：traprush_gate / traprush_switch / traprush_portal_switch
