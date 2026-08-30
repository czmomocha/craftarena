# AI 生成 GLB 烘焙试验记录（2026-08-29）

> 文档类型：实现级试验记录（`docs/plans/`，见 [CD-41 §5](../../Confirmed-docs/40-technical/41-architecture.md#5-monorepo-目录)）
> 状态：**试验记录**。本文所有数字都是一次本机试验的观察值，**不是规范、不是门禁、不是预算**。视觉结论已由人类于 2026-08-29 在编辑器内目测确认（§8）。§7 第 1 项已于 **2026-08-30 拍板并迁出**（数值的所有者是 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md)，本文不复述）；§7 第 2、3 项仍未拍板
> 日期：2026-08-29（§6/§7 于 2026-08-30 按拍板结果更新）
> 上位约束：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第九、十、十七、十八、二十四、二十六条
> 关系：本文是 [纠偏方案 C4 资产契约与美术规格](course-correction-2026-08.md) 的**输入材料**。本期预算数字曾属 [CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 未决事项，已拍板迁出

---

## 1. 背景

用混元 3D 生成了一个测试模型，选的是 3000 面，产物却 29.7 MB。问题是：这个量级能不能用、怎么处理、后续能否继续用生成方法。

本文记录的是一次**不入库**的烘焙试验：用一次性脚本按预设参数批量后处理，量化各档位的体积收益，并验证产物能被引擎正确导入。

## 2. 试验环境

| 项 | 值 |
|---|---|
| 机器 | macOS（Darwin），本机开发机 |
| 引擎 | Godot **4.7.2.stable.official.ed1daf0bf**（与 [CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md) 锁定版本一致） |
| 缩放/转码 | macOS 自带 `/usr/bin/sips` |
| npm 依赖 | **0 个**（脚本为零依赖一次性脚本） |
| 脚本 | `test-res/test-glb/_bake_test/bake_once.mjs`（未跟踪，不入库） |
| 跨平台 | **不成立**。`sips` 是 macOS 专有；Windows 上需换成 Blender headless 或 ImageMagick |

## 3. 样本与体积拆解

样本：`test-res/test-glb/kofizhou_lightai_1787938054928__AIGC_TEMP.glb`，混元 3D 生成，29,740,928 字节。

| 部分 | 体积 | 占比 |
|---|---|---|
| 几何（2562 顶点 / 3000 面，POSITION + NORMAL + TEXCOORD_0） | ~118 KB | 0.4% |
| 内嵌贴图（3 张，全部 **4096×4096**） | 29.62 MB | **99.6%** |

| 用途 | 格式 | 分辨率 | 体积 |
|---|---|---|---|
| baseColor | PNG (RGB, 8bit) | 4096² | 16.96 MB |
| metallicRoughness（ORM） | PNG (RGB, 8bit) | 4096² | 11.84 MB |
| normal | **JPEG** | 4096² | 0.82 MB |

**结论：面数不是问题，贴图分辨率和编码方式才是。** 3000 面的几何只占 0.4%。

## 4. 烘焙结果

脚本按「贴图用途分档」处理：baseColor / ORM / normal 各自独立的分辨率与编码上限，重排 GLB 的 bufferView 后重写文件。

| 预设 | baseColor | ORM | normal | GLB 体积 | 降幅 | Godot 导入后<br>(scn + 3×ctex) |
|---|---|---|---|---|---|---|
| 原始产物 | 4096 PNG 16.96 MB | 4096 PNG 11.84 MB | 4096 JPEG 0.82 MB | **29,740,928** | — | 未测 |
| 一刀切 1024 PNG | 1024 PNG 1.17 MB | 1024 PNG 0.97 MB | 1024 PNG 0.77 MB | 3,022,160 | −89.8% | 未测（超 2 MB 参考线） |
| 一刀切 512 PNG | 512 0.32 MB | 512 0.26 MB | 512 0.23 MB | 928,068 | −96.9% | 840,632 |
| **分级 1024 / 512 / 512 PNG** | 1024 PNG 1.17 MB | 512 PNG 0.26 MB | 512 PNG 0.23 MB | **1,776,592** | −94.0% | 1,594,400 |
| **分级 + baseColor JPEG** | 1024 JPEG 0.16 MB | 512 PNG 0.26 MB | 512 PNG 0.23 MB | **769,572** | **−97.4%** | 1,340,020 |
| **全 512 + baseColor JPEG**（人眼验证后补测） | 512 JPEG 0.05 MB | 512 PNG 0.26 MB | 512 PNG 0.23 MB | **658,004** | **−97.8%** | 未测 |

几何在四组产物中逐字节不变（3000 面 / 2562 顶点 / 117,984 字节 accessor）。

## 5. 三个发现

### 5.1 一刀切没用，按用途分档才有效

法线贴图最反直觉：4096 的 JPEG 源只有 0.82 MB，缩到 1024 后存 PNG 仍要 0.77 MB——**只省了 7.1%**。PNG 压法线噪声几乎压不动，必须单独给它降档（512 → 0.23 MB，−72.2%）。

### 5.2 编码格式只省磁盘，不省显存

JPEG 版 GLB 从 1.78 MB 降到 0.77 MB（−57%），但 Godot 导入后的 `.ctex` 只从 1.59 MB 降到 1.34 MB（−16%）——1024 贴图在引擎里仍然约 1 MB。

**真正要卡的是贴图分辨率，不是 PNG 还是 JPEG。** 想继续降运行时开销，只能降分辨率或上 KTX2/Basis——后者本次未测（需要额外工具链）。

### 5.3 ORM 不能跟着转 JPEG

试验中途脚本把 metallicRoughness 也转成了 JPEG（55 KB，看着很诱人），但金属度/粗糙度的有损压缩会产生带状伪影。已改回固定走 PNG，法线同理。

## 6. 推荐预设（建议，已被 §7 拍板覆盖）

依据 §8.1 的人眼结论（各档看不出区别），本文当时推荐**全 512 档**：

```json
{
  "max_triangles": 3000,
  "base_color": { "max_size": 512, "format": "jpeg" },
  "orm":        { "max_size": 512, "format": "png"  },
  "normal":     { "max_size": 512, "format": "png"  },
  "max_total_bytes": 1048576
}
```

→ 实测 658,004 字节（−97.8%）。

保守档（base_color 1024 / orm 512 / normal 512，全 PNG，1,776,592 字节）作为**备选**，用于占屏更大或贴图含高频细节的资产。

`max_total_bytes` 只是本次试验用的参考线，**不是预算**。

> 2026-08-30：预算已由人类拍板，落在 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md)。与本节的差异有两处：面数按"是否带动画绑定"分两档（静态 3,000 / 角色 6,000），单个文件上限放宽到 2 MB。贴图 512 与本节推荐一致。**以 CD-11 为准，本节只留作当时的推理过程。**

## 7. 拍板项与仍未拍板项

| # | 事项 | 状态 |
|---|---|---|
| 1 | 具体预算数值（面数 / 贴图分辨率 / 总体积） | **已拍板（2026-08-30）**：静态无绑定 3,000 三角面 / 带动画绑定角色 6,000 三角面 / 贴图边长 512 / 单个文件 2 MB。数值落 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md)，来源 [CD-91 D.1](../../Confirmed-docs/90-reference/91-decision-log.md)，[CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 已迁出该段 |
| — | 生成产物能否作为正式资产 | **已拍板（2026-08-30）**：TRELLIS / 混元 3D 产物过预算即可作正式平台资产，不必人手重做。落 [CD-11 §8](../../Confirmed-docs/10-product/11-scope-and-platforms.md) |
| 2 | 是否引入烘焙工具与依赖（如 MIT 的 `@gltf-transform/cli`） | **仍未拍板**。宪法第十八条「新依赖和许可证」人类门禁；引入后须写进 [CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md) 版本表。注意：512 上限已经拍了，但**没有任何跨平台工具能把 4096 的生成产物压到 512**——本文 §2 的脚本硬编码 macOS `sips` 且不入库。这一项不拍，第 1 项就只是一条无法在 Windows / CI 上执行的准入线 |
| 3 | 是否把烘焙流水线立为 C4 的一章 | **仍未拍板**。[纠偏冻结](course-correction-2026-08.md) 期间不进行新的功能开发；本期属 C4 范围，需人类排期 |

AI 不得自行选定第 2、3 项，也不得把第 1 项的数值当成"已有工具链保障"。

## 8. 人工真机查看步骤（已完成，2026-08-29）

### 8.1 目测结论

执行人：人类。环境：Godot 4.7.2 编辑器 3D 视口，原始 4096 与三个烘焙产物并排对比。

| 检查项 | 结论 |
|---|---|
| normal 512 | 凹凸感保留，与原始 4096 无可辨差异 |
| 各档整体（4096 / 1024 / 512、PNG / JPEG） | **完全看不出区别** |

即：在本样本上，前四档之间的体积差异（29.7 MB → 0.77 MB）**没有换来任何可观察的画质差异**，贴图可以继续降档，故 §6 推荐档位下调为全 512。

边界见 §9 第 2、3 条——该结论不能跨样本、跨观察距离外推。

### 8.2 复现步骤

> 以下步骤依赖本机 `test-res/` 下的原始样本与烘焙脚本，两者均**未入库**（见 §2 与 `.gitignore`）。换机器复现需要先自行生成样本，并重写脚本的缩放 / 转码层（macOS `sips` → Blender headless 或 ImageMagick）。**本文不提供可复现的工具链。**

1. 拷样本到工程内临时目录（看完即删）：

   ```bash
   cd <仓库根>
   mkdir -p game/content/test_fixtures/_bake_preview
   cp test-res/test-glb/kofizhou_lightai_1787938054928__AIGC_TEMP.glb \
      test-res/test-glb/_bake_test/baked_mix_jpg.glb \
      test-res/test-glb/_bake_test/baked_mix_png.glb \
      test-res/test-glb/_bake_test/baked_512_png.glb \
      game/content/test_fixtures/_bake_preview/
   ```

2. 打开编辑器：

   ```bash
   "$GODOT4" --editor --path game
   ```

3. **不要拖进主场景**——主场景是匹配大厅，只把实体渲染成 1 米占位盒，拖进去看不到模型。

4. 新建 3D 场景：`Scene → New Scene → 3D Scene`（自带 `DirectionalLight3D` + `WorldEnvironment`），临时保存到 `_bake_preview/preview.tscn`。

5. 从 FileSystem 面板把四个 glb 依次拖进 3D 视口，沿 X 轴摆开；生成模型的尺度不定，先按 Inspector 里的 bounds 调整 `scale` 与间距。

6. 环绕查看（鼠标中键平移 / 右键旋转 / 滚轮缩放），逐项对比：

   | 检查项 | 看什么 |
   |---|---|
   | baseColor 1024 vs 4096 | 近处细节损失是否可接受 |
   | baseColor 512 | 是否已糊 |
   | baseColor JPEG | 锐利边缘、高对比处有无振铃/块状伪影 |
   | normal 512 | 凹凸感是否还在，有无色带 |
   | normal 原始 4096 JPEG | 与 512 对比，验证 §5.1 的判断是否成立 |
   | ORM 512 | 金属/粗糙度过渡有无 banding |
   | Inspector 材质 | Godot 是否正确把三张图识别为 BaseColor / ORM / Normal Map |

7. 选中 glb → `Import` dock，看纹理压缩模式与 mipmap 设置；改完 `Reimport` 再比对。

8. 看完清理：

   ```bash
   rm -rf game/content/test_fixtures/_bake_preview
   rm -f game/.godot/imported/baked_* game/.godot/imported/kofizhou*
   git status --short   # 应只剩 ?? test-res/
   ```

> 工程渲染基线是 `gl_compatibility`（Compatibility），所以编辑器里看到的画面就是 Web/移动端的共同基线表现。

## 9. 诚实边界

- 所有体积数字来自 **2026-08-29 macOS 本机**这一次运行，不是产品指标，也不是回归门禁；
- §8.1 的「看不出区别」是在**编辑器 3D 视口的观察距离**下成立的。模型在屏幕上的占比越小，分辨率损失越不可见；游戏内若有近距离展示（拾取预览、特写、大模型占满屏幕），512 会暴露，**该结论不能外推**；
- 本样本的贴图内容未做复杂度评估（是否有文字、锐利图案、高频细节）。高频内容的降采样损失远大于平滑内容，**换样本必须重新目测**；
- Godot 导入后的 `.ctex` 是**桌面** VRAM 压缩格式。Web / 移动端导出会重新导入，本文数字**不能**直接当作包体结论；
- 视觉质量（512、1024、JPEG 各自够不够看）**未做验证**，只能人眼判断；
- KTX2 / Basis、Draco / meshopt、WebP 均未测：WebP 在本机 `sips` 上不支持（exit 13），其余需要额外工具链；
- 烘焙脚本硬编码 `/usr/bin/sips`，**只在 macOS 成立**；
- 样本只有 1 个。不同生成器、不同材质复杂度的产物收益会有差异，不能拿这一组数据外推。

## 10. 清理状态

`game/` 已恢复干净（`git status --short` 只剩 `?? test-res/`）。`test-res/` 仍是未跟踪目录，其中 62 MB 原始文件**不要** `git add`。
