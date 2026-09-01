# 资产烘焙与预算（runbook）

生成工具（TRELLIS、混元 3D 等）的产物贴图通常是 4096，单文件动辄几十 MB，**过不了 [CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 的准入线**。本文是把它压到预算内、再确认它真的合格的两条命令。

- 预算数值的所有者是 **CD-11 §8.1**，本文不复述，只调用；
- 观察数据见 [烘焙试验记录](../plans/asset-bake-trial-2026-08.md)（一次本机试验，不是规范）；
- 烘焙是**入库前的一次性预处理**。入库物是烘焙后的 `.glb`，不是脚本的输出流水线。

---

## 1. 校验：`npm run asset-budget`

```bash
npm run asset-budget                 # 扫 game/ 下所有 .glb
npm run asset-budget path/to/a.glb   # 只查指定文件（可以在仓库外）
```

超预算退出码 1，并逐项说出原因（哪张贴图、多大、超了什么）。这条命令**已进 CI**（`backend` job 的 Single-asset budget step），所以超限资产进不了 `main`。

**扫描范围**（2026-09-01 起）：跳过 `addons/`（第三方插件）与 `_source_refs/`（生成源产物落点），并认 `.gdignore` 目录标记（**递归**，与 Godot 4.7.2 实测一致）。跳过 `_source_refs/` 是必需的——源产物被 `.gitignore` 排除，CI checkout 不到，若不跳过就是「本地红、CI 绿」，而门禁只在其中一处成立等于不成立。**显式指定路径不受影响**：`npm run asset-budget <file>` 不走遍历，想单独查一个源产物照样查得到（它会如实报 FAIL，那是对的）。

它判四件事：

| 判定 | 依据 |
|---|---|
| 三角面 | 有 glTF `skin` 就按角色档，否则静态档。**看 skin 不看文件名** |
| 贴图边长 | 每张贴图的长边，从图像 header 读，**不解码像素** |
| 文件体积 | 磁盘字节 |
| 能不能判定 | 认不出的贴图格式、非三角 primitive、LFS 指针一律**拒绝而不是放过** |

零 native 依赖（只 `@gltf-transform/core`），所以 `sharp` 装不上的机器仍有门禁。

## 2. 烘焙：`npx @gltf-transform/cli`

```bash
npx --yes @gltf-transform/cli@4.5.0 resize in.glb out.glb --width 512 --height 512
npm run asset-budget out.glb
```

实测（本机 Windows 11，Node 24.19.0 / npm 11.17.0，2026-09-01）：对 `_source_refs/traprush3D` 下 7 个混元 3D 产物逐个跑上面那条命令，**7/7 成功，合计 16.3 秒**（含 `npx` 首次拉取 173 个包）。

| 资产 | 源体积 | 产物 | 面数 | 最大贴图边 |
|---|---|---|---|---|
| char_runner_base | 22.76 MB | 509.59 KB | 1000 | 512 |
| traprush_checkpoint_gate | 17.52 MB | 434.86 KB | 1000 | 512 |
| traprush_checkpoint_pad | 18.29 MB | 595.96 KB | 1012 | 512 |
| traprush_crate | 26.77 MB | 820.29 KB | 1056 | 512 |
| traprush_finish_gate | 21.52 MB | 676.38 KB | 1000 | 512 |
| traprush_hazard_roller | 20.66 MB | 675.29 KB | 1000 | 512 |
| traprush_spawn_grid | 23.08 MB | 575.99 KB | 1010 | 512 |
| **合计** | **150.60 MB** | **4.19 MB** | | |

三条复验，全部通过：

- `npm run asset-budget` 对 7 个产物逐个判定 **7/7 `ok`**（面数 1000–1056 / 3000 静态档、贴图边 512、最大 801.1 KB / 2 MB），退出码 0 ⇒ 这批资产**已经具备入库资格**；
- 几何**逐字不变**：AABB、顶点数、primitive 数、材质数、skin 数烘焙前后两两相同，`GEOM_DIFF_COUNT=0`；
- 三张 4096 贴图（2× PNG + 1× JPEG）全部降到 512。注意第三张是 **JPEG**（621 KB → 22.9 KB），`resize` 会重新编码它 —— 本项目 `asset-budget` 不卡编码格式（[CD-11 §8.1](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 只卡分辨率），所以这一项不构成门禁问题。

### 版本为什么必须是 4.5.0（4.4.2 在 Windows 上失败，已证伪）

本文此前写「两条命令都是纯 Node，Windows / Linux 同样可用」，并钉 `@4.4.2`。**那条声明从未在 Windows 上验证过，2026-09-01 实测失败**：

```text
(process:NNN): GLib-GObject-CRITICAL **: value "32" of type 'gint' is invalid
              or out of range for property 'space' of type 'VipsInterpretation'
error: colourspace: parameter space not set
EXIT=1，无产物
```

不是这批资产的问题：对**已入库的** `robot_placeholder.glb` 跑同一条命令同样失败；内嵌贴图是标准 8-bit RGB PNG + JPEG，不是 16-bit 或异色彩空间。

根因是**传递依赖漂移**，不是引擎或资产：

| 包 | 版本 | 拖进来的 `sharp` |
|---|---|---|
| `@gltf-transform/cli@4.4.2` 自己 | 4.4.2 | `~0.34.5` |
| 它的 `@gltf-transform/functions@^4.4.2` → 解析到 4.5.0 | 4.5.0 | `ndarray-pixels@5.2.0` → `sharp@0.35.4` |

一份依赖树里装进**两份 `sharp`**（各带一份 libvips），`ndarray-pixels` 用 0.35.4 产出、`cli` 用 0.34.5 消费，枚举值对不上。`ndarray-pixels@5.2.0` 是 2026-08-30 之后发布的，所以那天在 macOS 上跑通的命令今天会失败——**`^` 区间 + `npx` 的组合不具可复现性**，这正是本 runbook §2 原本的隐患。

`4.5.0` 把 cli 自己的 sharp 也提到 `0.35.4`，两处 `deduped` 成一份，冲突消失。副作用是依赖树从 205 包降到 **173 包**，且 `npm audit` **0 漏洞**——4.4.2 那 4 个 libvips CVE（`GHSA-f88m-g3jw-g9cj`）随 `sharp` 0.34.5 → 0.35.4 一并消失。

**别再用 4.4.2**。如果因为某种原因必须留在 4.4.2，唯一实测可行的补救是本地 `npm install` + `package.json` 里 `overrides: { "ndarray-pixels": "5.0.1" }`，把两处 sharp 压回同一份 0.34.5。以下是 2026-09-01 逐项实测**失败**的替代方案，不要重试：

| 试过的方案 | 结果 |
|---|---|
| `npx --prefix <带 overrides 的目录>` | 失败。`npx` 装进 `~/.npm/_npx`，**不读 prefix 的 `overrides`** |
| `npm exec --prefix <同上>` | 失败，同上 |
| `npm_config_prefix=<目录> npx ...` | 失败，同上 |
| 顶层 `overrides: { "sharp": "0.35.4" }` + `npx` | 失败，`_npx` 目录同样不应用它 |

只在**当前目录已有 `node_modules`** 且它由带 overrides 的本地 `npm install` 生成时，`npx` 才会复用它从而间接生效——删掉 `node_modules` 就立刻复现失败。所以「`npx` 单命令 + overrides」这个组合不成立，升级版本是唯一能保住单命令形态的路。

### 为什么烘焙工具不进 package.json

`@gltf-transform/cli@4.5.0` 拖 **173 个包**，`npm audit` 0 漏洞。不进 `package.json` 的理由不是体积也不是 CVE（4.5.0 两项都比校验层更干净），而是**它不该成为每次 `npm install` 与 CI 都要付的成本**：烘焙只在开发机、偶尔跑、且只在你明确决定要入库新资产时跑。把它写进 lock 等于让 173 个包进入整个团队的依赖可复现面，而产物 `.glb` 本身才是有版本价值的那个东西。

所以分两层：

- **校验**（门禁，每次 PR 跑）依赖 `@gltf-transform/core` **4.4.2** —— 2 个包，`npm audit` 0 漏洞，无 native 依赖；
- **烘焙**（开发机，偶尔跑）用 `npx` 临时拉起，**版本写死 `@4.5.0`**，不进 lock。

代价与边界，别外推：

- 烘焙工具**不在 lock 里**，所以它的传递依赖不保证逐字节可复现 —— 这正是 4.4.2 在 Windows 上失败的根因（见上一节）。可接受，因为入库物是产物 `.glb`，且产物由第 1 节的门禁把关；**但"写死版本"只钉住了直接依赖，钉不住 `^` 区间下的传递依赖**，所以换机器后第一次烘焙请照第 2 节先跑一个文件确认，不要默认它会成功；
- 4.5.0 的 `sharp@0.35.4` 仍带 libvips，攻击面是"用 libvips 解码不可信图像"，而这里解码的是**你自己生成的资产**，在开发机上，不在服务端、不在玩家包、不在 CI；
- `npx` 首次运行要下载 173 个包（约十几秒）；离线机器跑不了烘焙，但**跑得了校验**；
- 4.4.2 在 macOS 上会打印 `libvips-cpp` 两个版本冲突的 `objc[...]` 警告。4.5.0 把 sharp 去重了，那个警告应当消失 —— 但**这一条没在 macOS 上复测**（见下）。

### 换机器与 Windows

引入它替掉旧脚本的原因仍然成立：那份试验脚本硬编码 `/usr/bin/sips`，**只在 macOS 成立**，而且不入库。

但「两条命令都是纯 Node，Windows / Linux 同样可用」这句是 2026-08-30 从"两条命令都是 Node 写的"**推断**出来的，当时没有 Windows 实测。2026-09-01 补测后它才第一次成为事实 —— 代价是把版本从 4.4.2 提到 4.5.0。

**当前实测矩阵（只填测过的格子）**：

| | 烘焙（`npx @gltf-transform/cli@4.5.0`） | 校验（`npm run asset-budget`） |
|---|---|---|
| Windows 11 / Node 24.19.0 / npm 11.17.0 | **已测通过**（2026-09-01，25.53 MB → 801.1 KB） | 已测通过 |
| macOS arm64 | **未测**（4.5.0 尚未在这台 Mac 上跑过） | 已测通过（2026-08-30） |
| Linux CI | 不跑（烘焙刻意不进 CI） | 已测通过 |

在 Mac 上第一次用 4.5.0 烘焙时，请把结果补进这张表 —— 不要因为"它是纯 Node"就跳过。

## 3. 入库：内嵌贴图，别让像素进两遍

把烘焙好的 `.glb` 放进 `game/content/assets/<类别>/`，然后**必须**改一次导入设置：

```bash
"$GODOT4" --headless --path game --import          # 先导一次，生成 .glb.import
# 编辑 game/content/assets/<类别>/<name>.glb.import：
#   gltf/embedded_image_handling=1   →   gltf/embedded_image_handling=3
rm -f game/content/assets/<类别>/<name>_*.png game/content/assets/<类别>/<name>_*.jpg  # 删掉刚解包出来的
rm -f game/.godot/uid_cache.bin                    # 否则会残留已删文件的 UID
"$GODOT4" --headless --path game --import
```

为什么：Godot 的 glTF 导入器默认是 `1`（**Extract Textures**），会把内嵌贴图解包成外部图片文件。那些文件也走 LFS，于是**同一份像素入库两遍**（本机实测 803 KB 的 `.glb` 额外带出 683 KB 贴图），而且"一个资产一个文件"变成"一组文件各自漂移"，正是 [CD-51 §5.1](../../Confirmed-docs/50-engineering/51-dev-environment.md) 要避免的形态。`3` 是 **Embed as Uncompressed**（枚举由引擎的 `GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED` 自证）。

改完之后，`game/content/assets/<类别>/` 下应该**只有两个文件**：`.glb` 与 `.glb.import`。

代价要说清：内嵌未压缩只解决**磁盘与入库形态**，运行时显存不省——512² 三张未压缩仍是约 3 MB VRAM。这与[烘焙试验 §5.2](../plans/asset-bake-trial-2026-08.md)"编码格式只省磁盘，不省显存"是同一件事。想省显存只能降分辨率或上 KTX2 / Basis，后者仍未测。

最后确认包内真的读得到（**实例化**判定，不是 `file_exists`）：

```bash
"$GODOT4" --headless --path game -- --package-check
```

## 4. 还没做的事

- **自动化烘焙流水线**（CI 内烘焙、按用途分档的独立参数、产物自动入库）**不在 C4**，人类 2026-08-30 明确。第 2 节是一条手动命令，不是流水线。**批量本身不需要流水线**：对一批文件逐个跑同一条命令不引入新工具、不进 CI、不分档，与"流水线"是两件事（判断依据见 `docs/plans/course-correction-2026-08.md` 的 C4 边界）；
- 按用途分档（baseColor / ORM / normal 各自不同上限）没有实现。CD-11 §8.1 是全用途同一档 512，`resize` 也就一刀切。烘焙试验 §5.1、§5.3 记录了分档的收益与"ORM / normal 不能转 JPEG"的坑，等流水线立项时再用；
- KTX2 / Basis 未测（`--width/--height` 之外的压缩路径）；
- 场景总量、Draw call、材质数、骨骼上限**不判**，仍属 [CD-63 §1.7](../../Confirmed-docs/60-plan/63-open-decisions.md) 延期。
