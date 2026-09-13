# 平台资产来源与许可证归档

本文件登记 `game/content/assets/` 下**每一个入库资产**的来源与许可条款。

存在的理由：[CD-11 §8](../../../Confirmed-docs/10-product/11-scope-and-platforms.md) 允许 AI 生成产物作为正式资产，但没有回答"第三方资产怎么入库"。宪法第十八条把**新依赖和许可证**列为人类门禁，而在 `animal-cat.glb` 之前，本仓库所有资产都是自生成的，没有第三方条款需要归档，所以也就没有这份清单。第一个第三方资产进来时必须补上，否则"AI 资产来源、投诉和下架流程"（[CD-63 §4](../../../Confirmed-docs/60-plan/63-open-decisions.md) 阻断清单第 6 项）连基础事实都没有。

**本文件是事实登记，不是授权。** 第三方资产入库仍须人类逐项确认。

## 1. 第三方资产

| 资产 | 来源 | 许可 | 署名要求 | 入库日期 |
|---|---|---|---|---|
| `characters/animal-cat.glb` | Kenney，Cube Pets 2.0（`kenney.nl`） | **CC0 1.0 Universal**（公有领域奉献） | 无强制要求；Kenney 建议但不要求署名 | 2026-09-05 |
| `../../ui/fonts/craftarena_sans_sc_regular.otf` | Noto Sans SC（Google / Adobe，[notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)），常用 3500 字子集 | **SIL OFL 1.1** | 必须随附许可全文；**子集产物不得沿用保留字体名**（RFN） | 2026-09-13 |

CC0 允许个人、教育与**商业**用途，无署名义务。原始包内 `License.txt` 原文：

> License: (Creative Commons Zero, CC0)
> http://creativecommons.org/publicdomain/zero/1.0/
> You can use this content for personal, educational, and commercial purposes.
> Support by crediting 'Kenney' or 'www.kenney.nl' (this is not a requirement)

我们仍然署名（本表即署名），因为"不要求"不等于"不应该"。

### 1.1 字体：Noto Sans SC 子集（2026-09-13）

**许可条款原文位置**：`game/content/ui/fonts/OFL-1.1.txt`（随字体分发，OFL 要求再分发时必须带上），上游同一份在 `tools/font-subset/licenses/OFL-1.1.txt`。

上游源文件与 SHA-256 记录在 `tools/font-subset/build_font_subset.py`；子集的构建、改名与重跑步骤在 `tools/font-subset/README.md`。

**OFL 的保留字体名（RFN）约束**是这一项的具体义务，不是又一次门禁：上游声明了 "Noto Sans SC"（Google）与 "Source"（Adobe）两个 RFN，子集是修改产物，**不得沿用**。所以入库文件叫 `CraftArena Sans SC`，`--check` 与 GUT 都断言保留名没残留。改名只动 name 表的命名项；版权（ID 0）与许可全文（ID 13/14）按要求保留。

**已知边界**：上游不含 emoji，S1 大厅的 🔒 仍走引擎系统回退；只有 Regular 一个字重，加字重约 +800 KB 一份，需人类拍板。

### 待人类确认

1. **入库范围**：当前只取了 24 只动物里的 1 只（cat）。是否把整包（或其中 8 只，对应 8 个席位）纳入，属产品决策，未拍板；
2. **原始包的去留**：`test-res/kenney_cube-pets_1.0/` 是人类本地下载的素材暂存，**不在 Git 跟踪范围内**，也不应入库。若日后需要复现，从 kenney.nl 重新下载即可；
3. **是否把 CC0 素材当作长期方案**：当前它解决的是"契约需要一个有 clip 的角色"，不是"角色美术定稿"。

## 2. 自生成资产（AI 生成工具产出）

按 [CD-11 §8](../../../Confirmed-docs/10-product/11-scope-and-platforms.md)（2026-08-30 拍板），TRELLIS / 混元 3D 等工具的产物可作为正式资产。生成参数与烘焙记录见 `_source_refs/traprush/MANIFEST.md`（该目录不入 Git）。

| 资产 | 生成工具 | 备注 |
|---|---|---|
| `characters/char_runner_base.glb` | 混元 3D | 前任角色视觉，2026-09-05 起未被引用；留作回退 |
| `characters/robot_placeholder.glb` | TRELLIS | 首个跑通 DCC → GLB → 导入链路的样本；留作回退 |
| `terrain/block_static.glb` | 混元 3D | 当前地块视觉 |
| `terrain/floor_tile.glb` | 混元 3D | 前任地块视觉（扁板，贴合后悬空）；留作回退 |
| `checkpoints/checkpoint_pad.glb` | 混元 3D | 检查点垫 |
| `checkpoints/checkpoint_gate.glb` | 混元 3D | 检查点门（已知：比角色矮） |
| `finish/finish_gate.glb` | 混元 3D | 终点拱门 |
| `crates/crate.glb` | 混元 3D | 可破坏箱 |
| `hazards/hazard_roller.glb` | 混元 3D | 周期机关滚柱（已知：略超一格） |
| `portals/portal_gate.tscn` | 内部 Mesh 占位 | F 线 FC 传送门视觉 |
| `pickups/pickup_bomb.tscn` | 内部 Mesh 占位 | F 线 FC 爆破球 |
| `pickups/pickup_dash.tscn` | 内部 Mesh 占位 | F 线 FC 冲刺 |
| `spawns/spawn_marker.tscn` | 内部 Mesh 占位 | F 线 FC 出生点标记 |

## 2.1 平台运行时音频（B2，2026-09-11）

人类 2026-09-11 确认本地音频授权可用于正式入库。运行时只收 **OGG Vorbis**（[CD-11 §8.3](../../../Confirmed-docs/10-product/11-scope-and-platforms.md)）。F 线临时 WAV 已转码后删除；授权源目录 `game/content/assets/_source_refs/audio_temp/` **不入库**。`choose_your_character` 超 2 s 未收；`you_lose` / `ready` 没有对应玩法，不发明机制。

| 资产 | 来源 | 许可 | 入库日期 |
|---|---|---|---|
| `../../audio/sfx/step.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |
| `../../audio/sfx/hazard_warn.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |
| `../../audio/sfx/jump.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/land.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/pickup.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/crate.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/portal.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/loop_mover.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/sprint.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/finish.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/settled.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/fail_hazard.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/click1.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/click2.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/click3.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/click4.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/switch1.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/switch2.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/sfx/switch3.ogg` | 人类确认授权的本地素材转码 | 人类 2026-09-11 确认 | 2026-09-11 |
| `../../audio/music/theme_idle.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |
| `../../audio/music/theme_run.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |
| `../../audio/music/theme_end.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |
| `../../audio/music/theme_edit.ogg` | F 线内部 WAV 转码 | 无第三方许可 | 2026-09-11 |

## 3. 维护规则

1. **入库即登记**。新增任何 `.glb` / 贴图 / 音频都要在本文件加一行，无论来源；
2. **第三方资产必须记许可条款原文位置**，不能只写"CC0"；
3. 所有 `.glb` 仍须过 [CD-11 §8.1](../../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的单资产预算（`npm run asset-budget`）；音频过 [CD-11 §8.3](../../../Confirmed-docs/10-product/11-scope-and-platforms.md)（随 `npm test`）；
4. 玩家上传模型、音频与贴图仍是 [CD-11 §5](../../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的不做项，本文件不适用于 UGC。
