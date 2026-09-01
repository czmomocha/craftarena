# 章节真机清单

本文件是 [CD-52 §3.2](../../Confirmed-docs/50-engineering/52-ai-workflow.md) 的可执行版本：人类验收**当前完整章节 PR** 时照「本刀」逐步做。

它存在的理由是：自动化测试证明算法，不代替你在开发机窗口里看见的表现。任何人检出该 PR 分支，按本刀从头做一遍，就能自己判断这章在真机上是否成立。

- 适用范围：Windows 与 macOS 开发机；窗口化运行主场景。Headless `--quit` **不是**真机。
- 这是人工检查，**不是** CI 门禁（宪法第二十四条）。
- 命令以 [README.md](../../README.md) 为准，不要另猜参数。
- Agent 开下一章 PR 时必须**整节替换「本刀」**，不要把旧章步骤留在下面让人验错对象。无开发机可见行为的章：本刀只写「无」和一句原因。

---

## 怎么用

1. 检出待审 PR 的分支（不要用过期的 `main` 冒充本章）。
2. 先做下面「共用启动」（本刀写了「不需要三后端」则可跳过 `npm run dev`）。
3. 只做 **本刀** 的编号步骤。每步有「预期」和「失败」。全部预期满足才勾 PR 里的真机项。
4. 合入后本刀会被下一章替换；历史步骤以该章 PR 正文为准。

---

## 共用启动（大厅窗口）

机关狂奔匹配大厅是代码创建的 `Window`，标题 **Traprush**。第一行是状态 Label。按钮（从左到右）：**Quick play**、**Create room**、**Join room**、**Solo play**、**Cancel**、**Poll**。其下一行是服务器地址：输入框（placeholder `Server host`，默认填当前控制面主机）加 **Apply server** 按钮。再往下三个输入框：房间码（placeholder `Room code`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：玩家是**角色视觉资产**（一个约 1.13 m 高的角色，脚底在原点），本席覆青色薄膜（`OWN_ALBEDO`），远端覆海军蓝薄膜（`REMOTE_ALBEDO`）。橙色盒是可破坏箱；洋红盒是周期机关（固体半周期才出现；官方赛道出生点 −Z 1 个）；**始终固体铺地块视觉**（实心方块，一格一块、整格填满；官方赛道沿必经路铺立足面，`course_01` 另有出生点 −X 1 个，上层楼板在 −Z 三格）；视觉资产解析不出来时，角色与地块各自回退成原来的占位盒（青色 / 石色）。垫 / 门 / 终点仍是赛道占位盒（未开玩时垫是原绿、终点是原金；开玩后本席已验收垫是暗绿，当前目标垫是亮薄荷；全部垫完成后终点变亮金，冲线后变暗金）；条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

### 0.1 后端（本刀需要在线入场时）

仓库根目录：

```bash
npm run dev
```

预期：控制面、网关、MatchHost 三个 `/readyz` 都就绪后 DevLauncher 才放行。不要在半就绪时开游戏。停：对该终端 Ctrl+C。

Worktree 端口偏移见 README「并行工作区」；本文件不复述端口号。

### 0.2 打开窗口化主场景

**不要**用 Headless `--quit`。

| 平台 | 命令（仓库根） |
|---|---|
| Windows | `& $env:GODOT4 --path game` |
| macOS | `"$GODOT4" --path game` |

也可以先 `& $env:GODOT4 --editor --path game` / `"$GODOT4" --editor --path game`，再在编辑器里运行主场景。

预期：出现标题为 **Traprush** 的窗口；状态行含 `join=idle`、`play=idle`、`tls=off`、`server=127.0.0.1`、`course=3/5/1`（默认 `course_01` 的垫/门/终点占位；门含捷径上楼 `two_way`、安全路侧向 `two_way` 与上楼 `one_way`）。失败：没有窗口、立刻退出、或只有 Headless 日志。

操作：WASD 移动，空格跳跃（大厅按钮不抢空格），Q 或鼠标左键使用道具（打碎眼前箱；官方课出生点已拾爆破球），F 基础推击（推开邻座胶囊，无线上目标 id），Left Shift 或 **Sprint** 沿当前朝向冲刺一格（官方课出生点已拾冲刺），R 重置到最近已验收检查点。点过人数/课程/房间码/服务器框之后，再点 3D 区域或 Create room / Solo play，光标应离开输入框，WASD 才是移动。`course_01` 出生点 −Z 两格有洋红周期机关，有石色踏板可以走到它；踩上时若处于固体半周期会被击退并闪回出生点。

---

## 本刀：换掉地块视觉，修掉悬空的路面

这刀只做一件事：`TERRAIN_TILE_SCENE_PATH` 由 `floor_tile.glb`（扁板）换成 `block_static.glb`（正方块）。

**换它不是一个审美决定，是修一个实测出来的缺陷。** 贴合规则是等比缩放 + 缩放后**顶面**落在占位盒顶面，而占位盒本体早已 `layers = 0` 退出渲染，所以那一层就是玩家看到的全部：

| 资产 | 原始尺寸 | 厚宽比 | 贴合后 | 悬空 |
|---|---|---|---|---|
| `floor_tile.glb`（旧） | 1.842 × 0.338 × 1.843 m | 0.184 | 1.000 × **0.184** × 1.000 | **0.816 格** |
| `block_static.glb`（新） | 0.768 × 0.769 × 0.768 m | 1.001 | 1.000 × **0.999** × 1.000 | **0.000 格** |

平路上看不出来，一到 `course_01` 的落差处（台阶侧立面）就是一片悬空的纸。**贴合规则一个字没改**——换的是资产自己的比例，这正是它当初不写死缩放系数 0.5427 的原因。

产物 534.28 KB（源 22.67 MB 烘焙而来），1000 / 3000 静态面、贴图边 512、几何逐字不变。旧资产留着不删：回退就是改回一行字符串。

本刀需要 `npm run dev`（要看在线大厅的路面）。

1. **先看清旧的缺陷**（建立基线，别跳过）：
   ```bash
   git stash list          # 确认干净
   git checkout HEAD~1 -- game/src/shared/visual_asset_catalog.gd
   ```
   然后按「共用启动」进大厅看 `course_01`，走到有落差的地方，**从侧面看**台阶。
   - 预期：路面是一片薄板，底下明显悬空。
   - 看完 `git checkout HEAD -- game/src/shared/visual_asset_catalog.gd` 改回来。

2. **新路面是实心方块**：同样位置再看一次。
   - 预期：每格是一个填满的实心块，**侧立面是实的**，看不到底下的虚空。
   - 失败：还是扁的 ⇒ 改的常量不是 `TERRAIN_TILE_SCENE_PATH`，或 `.godot` 缓存没刷新（跑一次 `--headless --path game --import`）。

3. **路面仍然对齐，没有浮空也没有半埋**（`fit_tile_on_cell` 的顶面对齐不能被动过）：
   - 预期：角色踩在方块**顶面**上，脚底与顶面齐平；方块之间的顶面连成连续路面，不出现高低错层。
   - 失败：整条路沉下去或抬起来 ⇒ 贴合规则被改了，本刀**不该**改它。

4. **三张官方课都看一遍**，尤其：
   - `course_01`：沿路立足面、`+X` 捷径上楼、从检查点 1 向 `+Z` 的安全路（落差最多）；
   - `course_03`：步数最多（12 步），路面最长。
   - 预期：都能走通，路面连续。
   - 失败：某一段踩空或走不过去 ⇒ 是视觉遮挡或贴合问题，先看是不是只有那一格。

5. **Preview 与对局用同一块**（`MatchSolidMap` 与 `AuthoringPreviewMap` 各读同一个常量）：
   - 预期：Preview 里铺的地砖与大厅里是同一块。
   - 失败：两边不一样 ⇒ 有一处没走 `SharedVisualAssetCatalog`。

6. **自动化全绿 + 裁决不变**：
   ```bash
   npm run typecheck; npm test; npm run asset-budget; npm run redline-scan
   & $env:GODOT4_CONSOLE --headless --path game -- --package-check
   & $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：`npm test` 388/388；`--package-check` `ok=true` 且 `terrain_tile_visual_loadable=true`（这个判定**连贴合一起**判）；GUT **1153/1153**（断言 16,732，比换之前多 1 条，是新加的等比断言）；`--bot-run` 三张课 `completable`，**步数与动作序列逐项不变**（5 / 5 / 12 步）——这条是"换视觉没碰裁决"的证据。
   - 失败：bot-run 步数变了 ⇒ 视觉意外影响了仿真，停下来查，别先想着改断言。

### 本刀不测

- **新模型好不好看**：它是占位美术，配色与纹理未经美术定稿；
- **导出包内的表现**：本机无 4.7.2 导出模板；
- **macOS 导入这个新文件**：那台机器不在我手上；
- **`block_slope` / `bridge`**：本刀没生成它们，原因见 `_source_refs/traprush/MANIFEST.md` §2；
- 垫 / 门 / 终点、可破坏箱、周期机关：一点没动，仍是占位盒与 D4 危险色。

### 诚实边界

- 悬空数字是**按 AABB 算出来的**（`1 − 厚宽比`），不是截图量的。真机上你要看的是第 2 步那个"侧立面是不是实的"；
- **贴合规则没改**，所以"顶面 = 踩得到的那个平面"这条语义仍由占位盒定义，视觉不读裁决数据（ADR-0006 Q4 = A）。本刀没有把对齐改成底面对齐——那样会让路面沉到格底、玩家看起来踩在坑里；
- 新块是**等比放大**贴到一格的（系数 1.3017）。放大与缩小两条路径现在都被测试覆盖，但在换这块之前**只有缩小**被覆盖过（原用例的前提写的是"这块砖本来就不是一格宽"），那半边的覆盖缺口是这次才发现的；
- 旧资产 `floor_tile.glb` 仍在仓库，**没有代码引用它**。它不是"上一版备份"，但改一行常量就能切回去，这是故意留的回退路径；
- 本刀判断的是"路面不再悬空、仍然对齐"，**不判断美观度**。可玩性结论（E6）要等有美术之后另签。

### 仍然欠着（不因本章消失）

- **其余 6 个资产没有解析入口**：`SharedVisualAssetCatalog` 只有角色与地块两个常量，按 `asset_id` 解析那张表仍是 ADR-0006 §7 遗留项。已生成未入库的 5 个（gate / pad / finish_gate / crate / hazard_roller）都卡在这里；
- **`block_slope` 现在不能生成**：权威碰撞形状白名单只有 `box` / `sphere` / `capsule` / `platform_prefab`，**没有 slope**，Schema 层就表达不了；
- **`bridge` 既无参考图也无接线入口**；**`spawn_grid` 连数据源都没有**（出生点不在 bundle 的 7 个袋里）；
- **门比人矮**（gate 0.76–0.79 m vs 角色 1.134 m）与**滚柱超一格**（1.200 m）：两个已实测的美术问题，等解析入口那刀一起处理；
- macOS 上 `@gltf-transform/cli@4.5.0` 仍未实测；烘焙流水线（人类 2026-08-30 明确不在 C4）；按实体 diff、远端协议层 RTT 回填、字体与本地化键、动画状态契约、D7 输入抽象层、角色胶囊尚未进资产表、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,516 行（E9 要求 < 400）。

---

## 上一刀：Windows 烘焙可用 + 换掉角色视觉资产（两件独立的事）

> **本节已随上一刀合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

对应：当前完整章节 PR。两件事被放进同一刀，因为第二件依赖第一件：角色模型要能入库，先得有一台 Windows 机器能把它压到预算内。

| # | 事 | 改了什么 |
|---|---|---|
| 1 | **Windows 烘焙可用** | `@gltf-transform/cli` 4.4.2 → **4.5.0**；`_source_refs/` 加 `.gitignore`（353.8 MB 源产物不入库）；`asset-budget` 扫描跳过 `_source_refs/` 与认 `.gdignore` |
| 2 | **换掉角色视觉资产** | `CHARACTER_SCENE_PATH` 由 `robot_placeholder.glb`（0.74 × 1.03 × 0.61 m）换成 `char_runner_base.glb`（0.749 × 1.134 × 0.417 m） |

**为什么 1 不只是"补测"**：4.4.2 在 Windows 上**必失败**（`error: colourspace: parameter space not set`，exit 1，无产物）。根因是传递依赖漂移装进两份 `sharp`（0.34.5 与 0.35.4），两份 libvips 枚举对不上。`ndarray-pixels@5.2.0` 发布于 8-30 之后，所以那天在 mac 上跑通的命令后来会失败——**`npx` + `^` 区间钉不住传递依赖**。

第 1 件不需要 `npm run dev`；第 2 件需要（要在线大厅才看得到本席与远端）。

---

### 一、Windows 烘焙

1. **先确认旧的确实是坏的**（建立基线，别跳过——否则你无法区分"修好了"和"本来就好"）：
   ```bash
   npx --yes @gltf-transform/cli@4.4.2 resize <任意 .glb> %TEMP%\old.glb --width 512 --height 512
   ```
   - 预期：`GLib-GObject-CRITICAL ... property 'space' of type 'VipsInterpretation'`、`error: colourspace: parameter space not set`、**exit 1、无产物**。
   - 失败（说明本刀的前提不成立）：它居然成功了 ⇒ 依赖树又漂了，把实际版本贴回 PR 讨论，别合入。

2. **新版本能跑**（README 命令表里那条）：
   ```bash
   npx --yes @gltf-transform/cli@4.5.0 resize <同一个 .glb> %TEMP%\new.glb --width 512 --height 512
   npm run asset-budget %TEMP%\new.glb
   ```
   - 预期：打印 `info: x.glb (N MB) → new.glb (N KB)`；`asset-budget` 输出 `ok`，贴图 `largest edge 512`，exit 0。
   - 失败：仍报 `colourspace` ⇒ 依赖树里出现了第二份 `sharp`，见第 3 步。

3. **看是不是又装成两份 sharp**（根因自检）：
   ```bash
   cd %TEMP% && mkdir sharpprobe && cd sharpprobe && npm init -y
   npm install @gltf-transform/cli@4.5.0
   npm ls sharp --all
   ```
   - 预期：`sharp@0.35.4` 只出现一次，且子依赖那一行带 `deduped`。
   - 失败：出现两个不同版本 ⇒ 复现了 4.4.2 的病，需要再钉一次版本。

4. **批量**：对 `_source_refs/traprush3D/` 下 7 个 glb 逐个跑第 2 步那条命令。
   - 预期：7/7 成功，合计约 16 秒（首次含下载 173 个包）。`asset-budget` 对 7 个产物 **7/7 `ok`**，最大 801.1 KB / 2 MB、贴图边 512、面数 1000–1056 / 3000。
   - 失败：任何一个 FAIL ⇒ 别入库那一个，先看它超的是哪一项。

5. **门禁在"有源产物的开发机"上也绿**（这刀真正要修的缺口）：
   ```bash
   npm run asset-budget
   ```
   - 预期：只列出 `game/content/assets/` 下的 3 个已入库资产，全 `ok`，exit 0。**一条 `_source_refs` 的 FAIL 都不该出现**。
   - 失败：又出现 `_source_refs/.../xxx.glb` 的 FAIL ⇒ 扫描跳过没生效。这处的危害是"本地红、CI 绿"，两种红都不是好的那个。

6. **353.8 MB 不会进 LFS**：
   ```bash
   git add -An --dry-run game/content/assets/_source_refs
   ```
   - 预期：只有 3 行——`.gdignore`、`.gitignore`、`traprush/MANIFEST.md`。**没有任何 `.png` / `.glb`**。
   - 失败：出现源产物 ⇒ `.gitignore` 没生效。用 `git check-ignore -v <那个文件>` 看是谁放行了他。

---

### 二、换掉角色视觉资产

7. **大厅里玩家换成了新模型**。按「共用启动」打开窗口，`Solo play` 或 `Quick play`（2 人）。
   - 预期：玩家不再是原来那个约 1.03 m 的机器人，而是高约 **1.13 m**、更瘦长的一个角色。本席仍覆青色薄膜、远端仍覆海军蓝薄膜，且薄膜是半透明的（模型细节还看得见）。
   - 失败：还是旧机器人 ⇒ 改的是 `SharedVisualAssetCatalog.CHARACTER_SCENE_PATH`，确认 `res://` 能解析到新文件。

8. **脚底踩在地板上，不浮空也不半埋**（这是 `CHARACTER_FOOT_LIFT` 那条约定还成不成立）：
   - 预期：角色站在铺了地块（黄黑警示条地砖）的格子上，脚底与地砖表面齐平。
   - 失败：整体浮空约半米 ⇒ 新模型的原点不在脚底（`minY` 不是 0）；半埋 ⇒ 反过来了。用 `gltf-transform inspect` 看 POSITION 的 min，别去调 `CHARACTER_FOOT_LIFT`。

9. **比一格高是预期的，不是 bug**：新模型 1.134 m > 1 格，所以头会穿出占位盒顶一点。旧模型（1.03 m）也会，只是少一点。**只要第 8 步的脚底是对的，这一步就算过。**

10. **Preview / 对局两条路径用同一个模型**：
    ```bash
    & $env:GODOT4_CONSOLE --headless --path game -- --package-check
    ```
    - 预期：`ok=true`、`character_visual_loadable=true`、`character_visual_path` 以 `char_runner_base.glb` 结尾。
    - 失败：`character_visual_loadable=false` ⇒ 资产在包里读不到，通常落在 `.import` 配置或导出过滤上。

11. **入库形态是每个资产两个文件**：
    ```bash
    ls game/content/assets/characters/
    ```
    - 预期：`char_runner_base.glb` + `char_runner_base.glb.import`；`robot_placeholder.glb`(+ `.import`) **仍在**（故意留着，它是这条链路上第一个跑通的样本）。
    - 失败：出现 `char_runner_base_0.png` 之类解包贴图 ⇒ `.import` 的 `gltf/embedded_image_handling` 又退回 `1` 了，同一份像素会入库两遍。

12. **自动化全绿**（换视觉不该动任何裁决）：
    ```bash
    npm run typecheck; npm test; npm run asset-budget; npm run redline-scan
    & $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
    ```
    - 预期：388 npm 用例全绿；GUT **1153/1153 全绿**（16,731 断言，约 5.6 分钟）。其中 `test_character_visual_asset.gd` 那组断言的是**关系**（视觉尺寸 ≠ 权威胶囊 ≠ 占位盒），换模型后一条都没改就仍然通过——这正是本刀想要的。
    - 失败：任何一条红 ⇒ 换视觉意外影响了裁决，停下来看，别先想着改断言。

### 本刀不测

- **macOS 上 4.5.0 的烘焙**：那台机器不在我手上，实测矩阵里那一格是空的。请你在 mac 上第一次烘焙时补进 `docs/runbooks/asset-bake.md` 的矩阵表；
- **烘焙是否改变几何**：已由脚本逐项对比 AABB / 顶点数 / primitive 数 / 材质数 / skin 数（`GEOM_DIFF_COUNT=0`），那不是人眼能验的，不列进真机；
- **新模型好不好看**：它是**占位美术**，比例、朝向轴与配色都未经美术定稿，只用来跑通链路；
- **动画**：新模型无 `skin`、无动画，与旧模型一致。动画状态契约仍欠着；
- **垫 / 门 / 终点的视觉**：本刀一点没动；
- **导出包内的表现**：本机没有 4.7.2 导出模板，未实测。

### 诚实边界

- **Windows 烘焙已实测；macOS 上 4.5.0 一次都没跑过**。"它是纯 Node 所以跨平台"正是本刀证伪过的那句推断，不要再写一遍；
- **这次修复依赖当下这份 sharp/libvips 组合**。换一台机器、或者再过一段时间，`^` 区间下的传递依赖仍可能漂走，症状会一模一样。第 3 步那个自检就是为了下次快速确认；
- 4.4.2 与 4.5.0 烘焙同一文件**产物字节相同**（801.1 KB / 497.6 KB 各测过一次）。这不是"必须相同"的承诺，只是本次观察；
- **烘焙只降贴图、不减面**，所以贴图边 512 意味着近景会糊。那是 CD-11 §8.1 的预算决定的，不是烘焙的锅；
- 新模型高 1.134 m，**视觉上会穿出占位盒顶**（见第 9 步），这是预期；
- 两个角色模型都在仓库里：旧的留着但**没有任何代码引用它**。它不是"上一版备份"，只是这条链路的第一个样本，别因为看到它就去猜还有个开关能切回去；
- 本刀的真机步骤判断的是"看得见、脚底对"，**不判断美观度**。可玩性结论（E6）要等有美术之后另签。

### 仍然欠着（不因本章消失）

- **烘焙流水线**（CI 内烘焙、按用途分档、产物自动入库）：人类 2026-08-30 明确不在 C4。**批量本身不是流水线**——逐个跑同一条命令不引入新工具、不进 CI、不分档；
- **P0 地形块**：`block_static` 已经由紧邻的下一刀（换地块视觉）入库；`block_slope` **现在不能生成**——权威碰撞形状白名单只有 `box` / `sphere` / `capsule` / `platform_prefab`，没有 slope，Schema 层就表达不了；
- **已生成的 5 个资产没有解析入口**（gate / pad / finish_gate / crate / hazard_roller）：`SharedVisualAssetCatalog` 只有角色与地块两个常量，按 `asset_id` 解析那张表仍是 ADR-0006 §7 的遗留项；
- **门比人矮**（gate 0.76–0.79 m vs 角色 1.134 m）与**滚柱超一格**（1.200 m）：两个已实测的美术问题，等解析入口那刀一起处理；
- 按实体 diff（Preview 一次编辑仍全量重建）、远端协议层 RTT 回填、C3 网络参数锁定、字体与本地化键、动画状态契约、D7 输入抽象层、角色胶囊尚未进资产表、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,516 行（E9 要求 < 400）。

> **再早一刀**（Godot AI 脏写入不再进提交）的步骤已随 #195 合入并归档，不再留在本文件——本文件只保留「本刀」与紧邻的「上一刀」，三份历史堆在一起会让人验错对象。

---

## 归档：Godot AI 脏写入不再进提交（freeze-exception，单项）

这刀不属于任何 C 批次，还的是 C4 第 7 章记的第二笔账：**Godot AI 插件每次运行都把 `autoload/_mcp_game_helper` 与 `res://addons/godot_ai/plugin.cfg` 写回 `game/project.godot`**。它让守卫测试反复变红，并已经漏进过一个 commit。第一笔（Preview 每帧全量重建）已由 C4 第 8 章合入，与本刀无依赖。

**先看清这刀能做什么、不能做什么。** 插件在 `.gitignore` 里、不是本仓库代码，所以**没有办法阻止它写**。这刀做的是另外两件：一条命令把工作树还原、以及让那次写入进不了提交。因此本刀的验收不是「工作树永远干净」，而是「脏了能一键还原，且脏着提交会被拦」。

本刀**不需要**跑 `npm run dev`，也不改 `game/` 下任何玩法代码。

1. **在干净仓库上是空转**（先建立基线）：
   ```bash
   npm run godot-settings:check
   ```
   - 预期：一行 JSON，`"ok":true`、`entries` 为空，退出码 0。
   - 失败：`ok:false` —— 那说明你的工作树现在就是脏的，先做第 3 步再回来。
2. **插件真的会写**（这一步是让你亲眼看见问题存在，不是本刀的产出）：本机已装 `game/addons/godot_ai/` 时，打开一次编辑器：
   ```bash
   & $env:GODOT4 --editor --path game      # macOS: "$GODOT4" --editor --path game
   ```
   关掉编辑器，然后 `git diff -- game/project.godot`。
   - 预期：出现 `+[autoload]` / `+_mcp_game_helper=...`，`editor_plugins/enabled` 里多出 `res://addons/godot_ai/plugin.cfg`。
   - 本机没装该插件：跳过本步，直接手工造一次同样的两行再做第 3、4 步。
3. **一条命令精确还原**：
   ```bash
   npm run godot-settings:scrub
   git diff -- game/project.godot
   ```
   - 预期：scrub 打印被摘掉的条目；`git diff` 之后**完全没有输出**（回到字节一致，不是「差不多」）。再跑一次 scrub 是空转（幂等）。
   - 失败：`git diff` 仍有内容（说明还原不完整，比如空的 `[autoload]` 段没删掉）。
4. **别的改动不会被顺手丢掉**（这是它比 `git checkout --` 好的唯一理由）：先手工在 `game/project.godot` 里随便改一个无关值（例如把 `window/size/window_width_override` 改成 `1601`），再让它同时带上第 2 步那两行，然后 `npm run godot-settings:scrub`。
   - 预期：两行 MCP 条目被摘掉，`1601` **还在**。
   - 失败：`1601` 被一起还原了（那就是 `git checkout --` 的行为，不是本刀要的）。
   - 做完记得把 `1601` 改回去。
5. **脏着提交会被拦**（Agent 路径。人手敲的 git 不经过这个 hook，所以这条只对 IDE Agent 生效）：把第 2 步那两行弄回去，然后
   ```bash
   '{"command":"git add .","cwd":"<仓库绝对路径>"}' | node tools/shell-guard/src/main.ts
   ```
   - 预期：`"permission":"deny"`，消息里含 `game/project.godot` 与 `npm run godot-settings:scrub`。
   - 再试 `git add README.md`：应为 `"permission":"allow"`（守卫只拦会把该文件塞进索引的形式）。
   - 收尾：`npm run godot-settings:scrub`，确认 `git status --short` 里没有 `game/project.godot`，也没有 `game/addons/godot_ai/`。
6. **自动化仍然全绿**：
   ```bash
   npm run typecheck; npm test
   ```
   - 预期：`npm test` 全绿，其中含新工具用例与 shell-guard 新增用例。

### 本刀不测

- **让插件不写**。做不到，见上面那段；
- **人手 git 的拦截**。`.cursor/hooks.json` 只在 IDE Agent 发命令时生效，本仓库没有安装 git 原生 `pre-commit` 钩子（那要改 `core.hooksPath`，属人类门禁）；
- 任何玩法、协议、Preview / 对局表现。这刀一行 `game/` 代码都没改。

### 诚实边界

- **这不是「工作树永远干净」**。插件照旧写，只是现在有一条命令能精确撤销、并且脏着提交会被拦。任何写成「已经不会污染工作树了」的说法都是虚报；
- **拦截只覆盖 Agent 发出的 git**，靠 `.cursor/hooks.json` 的 `beforeShellExecution`（`failClosed: true`）。人手在终端敲 `git commit` 不经过它。CI 拦的是最后一道：磁盘副本脏就让 `npm test` 变红；
- **检测按插件目录名而不是固定 autoload 名**：`addons/godot_ai` 下的任何 autoload 都算本机条目，插件换版本改名也拦得住。反过来，**其他** autoload 一个不碰 —— 将来真要加基础服务 autoload（CD-51 §5）不会被误删，有用例钉着；
- **`enabled` 数组被摘空时保留 `enabled=PackedStringArray()`**，不删这个键。删键与留空键在 Godot 里语义相同，但留空键的 diff 更小；
- 纯文本编辑，不解析完整 ini 语义。不认识的 `enabled=` 写法（例如手工换行过的）会被**原样留下**而不是猜着改，这是故意的：宁可漏报一次让 CI 变红，也不要改坏 `project.godot`。

### 仍然欠着（不因本章消失）

- **git 原生钩子**：装 `pre-commit` 能覆盖人手 git，但需要改本机 `core.hooksPath`，属宪法第十八条的人类门禁项，本刀没做；
- **按实体 diff**：C4 第 8 章已修掉 Preview 的**每帧**重建，但一次编辑仍然全量重建 49 个节点。它不在每帧路径上，优先级低于下面这些；
- 远端协议层 RTT 回填、C3 网络参数锁定、E6 有美术后的可玩性签署、字体与本地化键、动画状态契约、D7 输入抽象层、角色胶囊尚未进资产表、垫 / 门 / 终点仍无独立视觉、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,516 行（E9 要求 < 400）。
