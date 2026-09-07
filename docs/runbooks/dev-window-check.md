# 开发机窗口验收

本文件是 [CD-52 §3.2](../../Confirmed-docs/50-engineering/52-ai-workflow.md) 的可执行版本：人类验收**当前完整章节 PR** 时照「本刀」逐步做。

它存在的理由是：自动化测试证明算法，不代替你在开发机窗口里看见的表现。任何人检出该 PR 分支，按本刀从头做一遍，就能自己判断这章在开发机窗口上是否成立。

- 适用范围：Windows 与 macOS 开发机；窗口化运行主场景。Headless `--quit` **不是**开发机窗口验收。
- **「真机」留给导出安装包**（见 [导出包核查清单](desktop-export-check.md)）。本文件验的是编辑器 / `--path game` 开出来的窗口，不是包。
- 这是人工检查，**不是** CI 门禁（宪法第二十四条）。
- 命令以 [README.md](../../README.md) 为准，不要另猜参数。
- Agent 开下一章 PR 时必须**整节替换「本刀」**，不要把旧章步骤留在下面让人验错对象。无开发机可见行为的章：本刀只写「无」和一句原因。

---

## 怎么用

1. 检出待审 PR 的分支（不要用过期的 `main` 冒充本章）。
2. 先做下面「共用启动」（本刀写了「不需要三后端」则可跳过 `npm run dev`）。
3. 只做 **本刀** 的编号步骤。每步有「预期」和「失败」。全部预期满足才勾 PR 里的开发机窗口项。
4. 合入后本刀会被下一章替换；历史步骤以该章 PR 正文为准。

---

## 共用启动（大厅窗口）

机关狂奔匹配大厅是代码创建的 `Window`。窗题与按钮走本地化键（`UiCopy`）：本机 Godot locale 为 `zh*` 时窗题是 **机关狂奔**，按钮从左到右是 **快速游戏**、**创建房间**、**加入房间**、**单人试玩**、**取消**、**查询队列**；其余 locale 仍是 **Traprush** / **Quick play** / **Create room** / **Join room** / **Solo play** / **Cancel** / **Poll**。节点名仍是英文。第一行是帧率读数（`FPS 60`，首窗之前 `FPS --`），第二行是状态 Label（`join=` / `pads=` / `FPS` **不翻译**）。其下一行是服务器地址：输入框（placeholder 随 locale：`Server host` / `服务器地址`，默认填当前控制面主机）加 **Apply server** / **应用服务器**。再往下三个输入框：房间码（placeholder `Room code` / `房间码`）、课程 id（默认 `course_01`）、人数（默认 `2`）。窗口里的 3D：玩家是**角色视觉资产**（2026-09-05 起是 Kenney Cube Pets 的猫；2026-09-07 加上角色贴合后是 **0.48 × 0.62 × 0.70 m**，不再超出一格，脚底落在权威胶囊底面），本席覆青色薄膜（`OWN_ALBEDO`），远端覆海军蓝薄膜（`REMOTE_ALBEDO`）。可破坏箱是箱子模型，覆橙色薄膜（`CRATE_ALBEDO`）；周期机关是滚柱模型，覆洋红薄膜（`HAZARD_ALBEDO`；固体半周期才出现；官方赛道出生点 −Z 1 个）；**始终固体铺地块视觉**（实心方块，一格一块、整格填满；官方赛道沿必经路铺立足面，`course_01` 另有出生点 −X 1 个，上层楼板在 −Z 三格）；检查点占用是垫（顶面对齐）+ 门（脚底对齐），覆进度色薄膜（未开玩原绿；开玩后已验收暗绿、当前目标亮薄荷）；终点是金色拱门，覆进度薄膜（未完成原金，全部垫完成后亮金，冲线后暗金）；传送门仍是色块（专用模型未生成）。视觉资产解析不出来时，对应占用回退成原来的占位盒。条是传送连线与检查点顺序 gizmos。玩家盒上方有名次 Label；本席名次标以 `*` 开头。开玩时状态行含 `pads=n/m`、`floor=n`、`finish=n`、`crates=n/m`、`hazards=n/m` 与 `solids=n/m`。

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

预期：出现大厅窗口（窗题 **Traprush** 或 **机关狂奔**，随本机 locale）；状态行含 `join=idle`、`play=idle`、`tls=off`、`server=127.0.0.1`、`course=3/5/1`（默认 `course_01` 的垫/门/终点占位；门含捷径上楼 `two_way`、安全路侧向 `two_way` 与上楼 `one_way`）。失败：没有窗口、立刻退出、或只有 Headless 日志。窗题变成键名 `craft_arena.ui.window_traprush` ⇒ CSV 没进 `res://` 或没解析到。

操作：WASD 移动，空格跳跃（大厅按钮不抢空格），Q 或鼠标左键使用道具（打碎眼前箱；官方课出生点已拾爆破球），F 基础推击（推开邻座胶囊，无线上目标 id），Left Shift 或冲刺按钮沿当前朝向冲刺一格（官方课出生点已拾冲刺），R 重置到最近已验收检查点。点过人数/课程/房间码/服务器框之后，再点 3D 区域或创建房间 / 单人试玩，光标应离开输入框，WASD 才是移动。`course_01` 出生点 −Z 两格有覆洋红薄膜的滚柱周期机关，有石色踏板可以走到它；踩上时若处于固体半周期会被击退并闪回出生点。

---

## 本刀：无待审章

F 线可读性已收口。下一刀按 [CD-61](../../Confirmed-docs/60-plan/61-milestones.md)：**Web 游玩分发**（浏览器能跑、测试期 Solo、链接+端口打 VPS）。开新章 PR 时**整节替换**本节。

本章无开发机可见行为：当前没有待审实现章。

---

> **本节随 CD-61 顺序回写；验当前 PR 只看上面的「本刀」。**

## 上一刀（已合入）：F 线可读性 —— 拉开示范课、缩 HUD、斜视距调节

**不需要三后端**（Solo 即可）。

这刀验的是窗口里能不能看清、走得开：示范课不再挤成一团；头顶字缩小；结算表不挡 3D；滚轮拉远仍是斜 45°。课程 id 填 `course_f_playable`。主路沿 +X 约 8 格可走完（不必等平台；整课落在出界桩 ±8 格内）；跳台在 −Z 五格，平台在 +Z 五格。

1. **打开窗口化主场景**（共用启动 0.2）。课程 id 框**整段替换**成 `course_f_playable`（不要接在 `course_01` 后面），点第四个按钮 **单人试玩**（不要点最左边 **快速游戏**）。
   - 预期：大厅画出拉开后的课（2 垫间距约 3 格 / 金色终点约在 +X 7 格 / −Z 侧廊可见 bomb 与 dash，不再堆在出生点周围）；状态行 `course_id=course_f_playable`、`offline=playing`；局时字明显小于参考图里的巨字；名次 / `idle` 标签不再盖住角色。失败：仍是挤成一团的短课、走到 +X 8 格外被弹回、或状态行 `offline_error=` / `error=http_official_only`。
2. **滚轮拉远，中键拖一下**。
   - 预期：画面走近 / 拉远，斜视角不变（仍从 +X/+Z 上看下来）；中键平移后角色可偏到画面一侧。失败：视角变成顶视或自由旋转、或滚轮没反应。
3. **沿 +X 走到第二垫再进终点**（地面石色路，不必跳、不必等平台）。
   - 预期：过垫有分段；冲线后钟停、结算表出现在**右上**，不挡赛道中央。失败：掉进虚空、或结算表仍盖在 3D 正中。
4. **（可读性）走到 −Z 看 1 格高台，走到 +Z 看往返石色平台，走到 +X 侧向看洋红机关。**
   - 预期：高台能跳上去；平台在动；机关固体半周期前有洋红闪。失败：高台跳不上去、平台冻住、机关无预警。
5. **点取消**。
   - 预期：钟、分段、结算表消失。失败：表还在。

### 本刀不测

- 匹配 HTTP 发 `course_f_playable`（控制面仍只接受 01–03）；
- 改默认相机距离 / FOV 产品值、自由旋转镜头、字体入包；
- 改爆破半径、推击力度、道具重生。

### 诚实边界

- 分段不是权威量，刷新窗口或重连会丢；
- 字体未入包，大字中文可能缺字；数字与 `:` `.` 应仍可读；
- 开发期 `join=` 状态行仍在，本刀没有删 token；
- 默认相机距离仍是 D4 未答的 √136，只是允许滚轮调节。

---

> **本节随 F 线可读性补刀合入；验当前 PR 只看上面的「本刀」。**

## 上一刀（已合入）：角色动起来（C4 动画状态 → clip 与姿态；含角色贴合）

**不需要三后端。** 全程走 **单人试玩**（Solo）与 **Preview**，因为在线快照没有接地 / 硬直字段，远端席位**本来就不接线**（见「诚实边界」）。

这刀做的事：C4 锁了八个动画状态名（`idle` / `run` / `jump` / `land` / `shove` / `hit` / `break` / `portal`），此前它们只写进 metadata 和一个 Label3D，**角色一动不动**。现在 `PlayAnimVisual` 把它们接到视觉上——四个状态播 GLB 自带 clip，另四个用程序化姿态偏移补。同时把角色资产换成 `animal-cat.glb`：换它不是审美决定，是前两个模型都是静态网格、**连 `AnimationPlayer` 都没有**，接线无处落地。

**2026-09-07 追加：角色贴合。** 人类看真机后判定「动物有点大」。根因是**角色此前根本没有贴合规则**——地块走 `fit_tile_on_cell`、门 / 箱 / 滚柱走 `fit_prop_on_cell`，都按自身 AABB 等比缩到一格，只有角色是把资产原始尺寸直接摆上去。前两个角色水平最长边 0.75 m 本来就小于一格，所以缺陷一直没暴露；猫是 1.806 m（尾巴 + 四足），一眼可见。新增 `fit_character_on_cell` 补上这条规则。

0. **先看清缺陷**（建立基线，可跳过但建议做一次）：
   ```bash
   git stash list          # 确认干净
   git checkout HEAD -- game/src/shared/visual_asset_catalog_fit.gd
   ```
   —— 本刀尚未合入时无从 checkout，改用另一条路：把 `placeholder_spec.gd` 的 `CHARACTER_VISUAL_CELL_SPAN` 临时改成 `1.806`（等于不缩放），跑一次大厅，看猫压在相邻格上的样子；看完改回 `0.7`。

1. **角色不再超格，且站在方块顶面上**：按「共用启动」开大厅，点 **单人试玩** / **Solo play**。
   - 预期：猫明显比上一版小（约 **0.48 宽 × 0.62 高 × 0.70 深**），**水平方向不越过所在格的边界**；脚底与所踩方块的顶面齐平，不悬空、不半埋。
   - 失败：仍然超格 ⇒ `fit_character_on_cell` 没接到 attach。整只沉进方块或浮在上方 ⇒ 脚底对齐算错了（应对齐**权威胶囊底面**，不是 1 米占位盒底面）。

2. **站着有待机动作**：松开所有键。
   - 预期：角色**持续播 idle 动作**（猫会有细微的呼吸 / 摆动，不是完全静止的一坨）。头顶 Label 是 `idle`。
   - 失败：完全不动 ⇒ clip 没播，看是不是资产解析回退成占位盒了（占位盒是纯色方块，不是猫）。Label 是 `idle` 但模型静止 ⇒ `PlayAnimVisual.apply` 没接到 `set_anim_state`。

3. **走起来切 run**：按住 W / A / S / D 移动。
   - 预期：动作**从 idle 切成 run**（四条腿动起来），Label 变 `run`。松开键回到 `idle` 与待机动作。
   - 失败：Label 变了但动作没变 ⇒ clip 映射没生效。按住 **Left Shift** 冲刺时**仍是 run**（sprint 并进 run，不单开状态），这是预期不是缺陷。

4. **跳起来是姿态，且大小不变**：站在地上按**空格**。
   - 预期：离地瞬间 Label 变 `jump`，角色**明显前倾**（约 20°）且**动作停住**（不再播 idle / run 的循环）；落地那一拍 Label 闪 `land`，角色**后仰并下压**一下，随即回到 `idle` / `run`。**全过程角色大小不变。**
   - 失败：**一起跳角色突然变大** ⇒ 姿态态用常量重建了基准，把贴合缩放抹掉了（这是本刀最容易回归的一条，单测 `test_pose_keeps_the_fitted_scale` 钉的就是它）。跳起来还在播 idle 循环 ⇒ 姿态态没停 clip。落地没有任何变化 ⇒ `land` 只出现一拍，眨眼会错过，**多跳几次**再判。前倾角度残留（落地后一直歪着）⇒ clip 态没有把 transform 归零回基准。

5. **姿态不会把角色顶飞或埋进地里**：重复第 4 步，盯着**脚底**。
   - 预期：前倾 / 下压是绕脚附近旋转 + 小幅升降，角色始终**站在方块顶面上**，不悬空、不陷进地里。
   - 失败：一跳就整个人沉下去半格或飘起来 ⇒ 姿态偏移替换了基准而不是叠加在基准上。

6. **推击与打箱各有姿态**：走到官方课出生点 −X 那个石色方块旁按 **F** 推击（大厅里得有第二个人才推得动，Solo 里只看姿态）；再走到箱子前按 **Q** 打箱。
   - 预期：推击那一拍 Label 闪 `shove` 且角色**前倾更多**（约 30°）；打碎箱子那一拍 Label 闪 `break` 且角色**前俯**（约 25°）。两者都只出现一拍。
   - 失败：Label 出现但姿态没有区别 ⇒ 两个姿态的数值撞了（测试里有一条断言专门钉「四个姿态互不相同」）。

7. **受击与传送播的是 clip，不是姿态**：走到出生点 −Z 两格那个洋红滚柱上（固体半周期时会被击退并闪回出生点）；再走进传送门。
   - 预期：硬直期间（1.0 s）Label 是 `hit`，角色播**摇头晃脑**的动作（`gesture-negative`）；踩进传送门那几拍 Label 是 `portal`，角色播**手舞足蹈**（`dance`）。
   - 失败：`hit` 期间角色前倾不动 ⇒ 这两个状态被错接成姿态态。**语义近似是路线 A 已接受的折衷**：猫没有"受击"和"传送"动作，用摇头和跳舞代替，不是接错了。

8. **Preview 里是同一套**：F6 跑 `res://src/creator/editor_sandbox.tscn`（或 Project > Tools > Authoring Editor），点 **预览**，在 Preview 窗里点 **开始**，按 WASD 与空格。
   - 预期：Preview 里的角色与大厅**是同一只猫、同样大小**，idle / run / jump 表现一致。
   - 失败：Preview 里还是方块或还是旧模型 ⇒ 有一处没走 `SharedVisualAssetCatalog`。**两边大小不一样** ⇒ 只有一条壳调了 `fit_character_on_cell`。

9. **在线远端不会动，这是预期**：`npm run dev` 后开两个客户端进同一局。
   - 预期：**本席**（Solo 之外的在线本席也不接线）与远端席位的角色都**保持 idle 静止**，头顶没有动画 Label；但**大小与 Solo 一致**（贴合与是否接动画无关）。
   - 失败：远端角色动起来了 ⇒ 有人从快照里猜了接地 / 硬直，那是改协议（宪法第十八条），打回。

10. **自动化全绿 + 裁决逐字不变**：
   ```bash
   npm run typecheck; npm test; npm run redline-scan; npm run asset-budget; npm run godot-settings:check
   "$GODOT4" --headless --path game -- --package-check
   "$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://tests/replay -gexit
   "$GODOT4" --headless --path game -- --bot-run
   ```
   - 预期：`typecheck` 无输出；`npm test` **423/423**；`redline-scan` `no findings`；`asset-budget` 全 `ok`（cat 是 **684/3000** 面、512 贴图、171.9 KB）；`godot-settings:check` `ok=true`（**不能**有 `_mcp_game_helper`）；`--package-check` `ok=true` 且 `character_visual_path` 已是 `animal-cat.glb`、`character_visual_loadable=true`；GUT **1307/1307**（137 个脚本）；`--bot-run` 三张课 `completable`，**步数仍是 5 / 5 / 12**，`expansions` 5 / 5 / 18、`search_ticks` 112 / 112 / 922 逐字段不变。
   - 失败：bot-run 有**任何**字段变了 ⇒ 视觉意外影响了裁决，停下来查，**别先改断言**。这条是「换了角色资产、改了视觉缩放、没碰权威」的唯一硬证据。

### 本刀不测

- **0.7 这个占格比例对不对**：它是人类说「有点大」之后给的**占位值，未定稿**，D4 从没问过这一项。觉得还是偏大或偏小，改 `PlaceholderSpec.CHARACTER_VISUAL_CELL_SPAN` 一个数字即可，不动任何结构；
- **动作好不好看 / 猫合不合适**：这是占位美术，比例与题材都没有经过美术定稿；
- **动画时长与过渡**：`PlayAnimVisual` 不引入时间轴，姿态跟着本拍事实出现和消失。clip 之间没有 blend。秒数仍属 CD-63 延期项；
- **`walk` / `eat` / `static` / `gesture-positive`**：cat 自带但**未映射**，八态契约不需要它们；
- 大厅联机的动画（第 9 步验的正是"不该动"）、导出包、Android / iOS、触控。

### 诚实边界

- **在线远端接不了线，不是遗漏**：v1 快照帧没有 `vy`、没有 `stun_remaining`、没有库存，`airborne` 与 `hit` 在客户端算不出来。补上它要改协议帧，属宪法第十八条。所以本刀的动画只在 **Solo 与 Preview** 成立，那两条壳读的是本地权威；**贴合缩放不受此限**，三条壳一致；
- **`hit` 用摇头、`portal` 用跳舞是语义近似**。Cube Pets 是一套通用动物动作集，没有受击与传送动作。这是路线 A 拍板时就接受的折衷，不是接错；
- **四个姿态的角度（−20° / 10° / −30° / 25°）与升降（−0.12）是占位数值，未定稿**。测试断言的是「四者互不相同」「clip 态回得到基准」「姿态保留缩放」，不是任何具体角度——换数值不改结构；
- **视觉与权威仍然不等，而且差得更多了**：贴合后视觉 0.48 × 0.62 × 0.70 m，权威胶囊直径 0.25 m、总高 0.375 m。视觉仍比胶囊大，这是 ADR-0006 Q4 = A 明确允许的（视觉从不参与裁决），不是待修缺陷。缩放**只改表现**，`--bot-run` 逐字段不变即为证据；
- **贴合按 AABB 算，不写死系数**，理由与地块那条相同：Cube Pets 24 只动物尺寸各异（长颈鹿高、螃蟹扁），写死系数等于每换一只都要重算。代价是不同动物贴合后高矮不一——那是保留动物本身比例的结果，不是 bug；
- **它不走共享 Mesh 快路径**：7 个网格节点，只有单网格资产才扁平化。这是必须的——快路径只保留 `Mesh`，会把 `AnimationPlayer` 和部件层级一起丢掉。每帧成本不受影响，因为 `_sync_players` 复用席位节点，只有席位数变化才实例化；
- **cat 是仓库里第一个第三方资产**（Kenney，CC0）。来源与条款已归档到 `game/content/assets/ATTRIBUTION.md`，但**入库范围仍需人类拍板**（当前只取了 24 只里的 1 只），见该文件「待人类确认」。

### 仍然欠着（不因本章消失）

- 按 `asset_id` 解析视觉（ADR-0006 §7 遗留项）；传送门仍无模型；**拾取物客户端仍不绘制**；
- 角色胶囊仍不是资产；`match_lobby_shell.gd` 仍远超 E9 的 400 行；
- 触控 UI（D7）、字体入包（一期收尾）、动画秒数与过渡（CD-63）。

---

## 上一刀：创作者可测（XYZ / Place pickup / Preview 并排 / 点选拖拽）

> **本节随 [#224](https://github.com/czmomocha/craftarena/pull/224) 合入；验当前 PR 只看上面的「本刀」。**

**不需要三后端。** F6 跑 `res://src/creator/editor_sandbox.tscn`，或主场景里 Project > Tools > Authoring Editor。

1. 打开 Authoring Editor。
   - 预期：编辑窗口在主窗**左半**，`MODE_WINDOWED`，不是铺满。3D 里看得见深色地板网格。状态行含 `cursor=`。
   - 失败：编辑窗最大化盖住一切 ⇒ `AuthoringWindowLayout.apply_editor` 没接到。没有地板 ⇒ `AuthoringPreviewMapFloor.sync` 没接到。
2. 把 Z 旋到 `2`，点 **放置固体**。
   - 预期：石色盒出现在当前 XYZ（z=2 格），不在 z=0。
   - 失败：盒仍在 z=0 ⇒ 光标没进 `place`。
3. 再连续点两次 **放置固体**（Y 仍为 0），然后把 Y 旋到 `1`（或点 **上一层**）。
   - 预期：Y=0 的石色盒仍在 3D 里看得见；当前层有半透明网格和黄色光标。状态行 `floor=1`、`entities=` 没变。
   - 失败：下层盒整片消失，只剩光标 ⇒ 地板填色仍不透明或写了深度。点放置之后才重新出现也算失败。
4. 点编辑窗 3D **空地**（工具条下方，不要点按钮）。
   - 预期：X/Z 旋钮变成点击落点的格；再 Place 落在那里。
   - 失败：光标不动 ⇒ `window_input` 被 HUD 吃掉，或射线没打到楼层平面。
5. 点 3D 里刚放的石色盒，拖到旁边一格后松开。
   - 预期：盒子跟着鼠标走，松开后停在新格；状态行 `selected=` 为该实体；Undo 能撤回收。
   - 失败：只能拧 SpinBox、拖了没写入 ⇒ 没走 `set_component`。拖完位置变成非整格 ⇒ 静默取整，打回。
6. 再点另一个已有组件，按住 **Shift** 拖。
   - 预期：盒子沿竖直方向改 Y（楼层），松开后写入。
   - 失败：Shift 仍只改 XZ ⇒ 竖直平面没接到。
7. 点 **放置检查点**，把 X 旋回与检查点同一格，点 **放置冲刺**，再点 **预览**。
   - 预期：Preview 在主窗**右半**，**不盖住** Editor 右缘；两窗能同时看见全部按钮。
   - 失败：Preview 压在 Editor 上 ⇒ 仍按 1600 override 写死，或 `wrap_controls` 把子窗撑宽。Preview 最大化挡住 Editor ⇒ 仍是旧的 `MODE_MAXIMIZED`。
8. Preview 里点 **开始**，按 Left Shift（或冲刺按钮）。
   - 预期：角色沿朝向冲一格；无冲刺拾取时 Shift 无效。
   - 失败：有 dash 仍不动 ⇒ 拾取没编进 `pickups` 或开玩没授予。有 dash 却白给（没放拾取也能冲）⇒ 产品规则被改掉，打回。

### 该刀不测

- 大厅联机、官方课 JSON、TLS、导出包、系统原生可拖窗口（`gui_embed_subwindows` 仍为 true）、手机触控拖拽。

---

## 更早：解除纠偏冻结令

> **本节随解除记录合入；验当前 PR 只看上面的「本刀」。**

**无。** 该章只回写人类拍板（E10 选项 A、字体入包推迟、§1 解除），不改仿真、壳、协议或导出。

---

## 上一刀：C5 批次收口（第 17 章）

> **本节随 [#221](https://github.com/czmomocha/craftarena/pull/221) 合入；验当前 PR 只看上面的「本刀」。**

**无。** 该章不改仿真、壳、协议或导出。

---

## 上一刀：静态盒均匀格阔相（C5 第 16 章）

> **本节随 [#220](https://github.com/czmomocha/craftarena/pull/220) 合入；验当前 PR 只看上面的「本刀」。**

静态盒占用改走均匀格阔相。窄相与 ID 顺序不变。

---

## 上上刀：扫掠取样预算（C5 第 15 章）

> **本节随 [#219](https://github.com/czmomocha/craftarena/pull/219) 合入；验当前 PR 只看上面的「本刀」。**

权威扫掠加了 `MAX_SWEEP_STEPS = 256`。超限拒绝整段，不粗化取样。

---

## 上上刀：E1 真导出（C5 第 14 章）

> **本节随 [#218](https://github.com/czmomocha/craftarena/pull/218) 合入；验当前 PR 只看上面的「本刀」。**

按 [导出包核查清单](desktop-export-check.md) 打出 Windows 包，并修到 `--package-check` 全绿。真机是导出的 `CraftArena.exe`。

---

## 上上刀：E9 剩余 + E3/E6 回写（C5 第 13 章）

> **本节随 [#217](https://github.com/czmomocha/craftarena/pull/217) 合入；验当前 PR 只看上面的「本刀」。**

把控制面 `server.ts` / `database.ts`、MatchHost `registry.ts`、`visual_asset_catalog.gd`、`match_snapshot_map.gd` 拆到 400 行以下。公开 API 与 `--bot-run` 步数不变。人类把现有网络桩升为 E3 锁定值（**不改数字**），并签署 E6 = 好玩。**没有新的窗口外观**。

---

## 上上刀：编辑壳 + 拓扑编译器（C5 第 11–12 章）

> **本节已随上一章 PR 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

第 11 章把 `AuthoringEditorShell` 拆成 chrome / place / follow。第 12 章把 `TraprushTopologyCompiler` 拆成 bags / fields。全部压到 400 行以下。公开 API 与 `--bot-run` 步数不变。**没有新的窗口外观**。不需要 `npm run dev`。

1. 仓库根目录跑 GUT fast 层（或至少 `test_authoring_editor_e9_split.gd`、`test_traprush_topology_e9_split.gd`、`test_authoring_editor_shell.gd`、`test_traprush_topology_compiler.gd`）：
   ```bash
   npm run test:gut:fast
   ```
   - 预期：全绿；新拆分用例断言编辑壳 / 编译器各文件均 < 400 行。
   - 失败：place / undo / Preview 跟随 / 官方课编译红 ⇒ 门面把公开方法转丢了。

2. 官方课步数：
   ```powershell
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：三张课仍是 `completable`，步数 **5 / 5 / 12**。
   - 失败：步数变了或 `not_completable` ⇒ 拓扑编译袋语义变了。

3. 编辑器打开 `res://src/creator/editor_sandbox.tscn`，**F6**（不要 F5）。
   - 预期：出现编辑窗口；状态行含 `entities=`、`reach_ok=`、`follow=`；已有一个检查点与一个 dangling 传送；点 **Preview** 后 `follow=true`，再 Place 一个占用，Preview 仍跟着。
   - 失败：窗口不出现、工具条没了、Preview 不再跟随 ⇒ chrome / follow 委托坏了。

### 本刀不测

- 控制面 / MatchHost registry 拆分（下一章）；
- 解冻令、协议帧、Schema、官方课 JSON、Tick / 快照 / 插值锁定。

### 诚实边界

- E9 仍欠：控制面 `server.ts` / `database.ts`、MatchHost `registry.ts`、`visual_asset_catalog.gd`、`match_snapshot_map.gd`；
- 扫掠步数仍无上限（宪法第十七条缺口）。

---

## 上一刀：仿真世界 + bundle；灰盒 + 探针（C5 第 9–10 章）

> **本节随 [#213](https://github.com/czmomocha/craftarena/pull/213) 提交；验当前 PR 只看上面的「本刀」。**

第 9 章把 `SimulationWorld` 拆成 query / move、把 `SimulationBundle` 拆成 decode / bags。第 10 章把灰盒拆成 layout / assemble / play、把完成探针拆成 heuristic / search。全部压到 400 行以下。公开 API 与 `--bot-run` 步数不变。**没有新的窗口外观**。不需要 `npm run dev`。

1. 仓库根目录跑 GUT fast 层（或至少 `test_simulation_e9_split.gd`、`test_traprush_e9_split.gd`、`test_traprush_graybox_course.gd`、`test_traprush_course_completion_probe.gd`）：
   ```bash
   npm run test:gut:fast
   ```
   - 预期：全绿；新拆分用例断言仿真世界 / bundle / 灰盒 / 探针各文件均 < 400 行。
   - 失败：占用 / 扫掠 / v1→v2 解码 / 灰盒 `try_*` / 探针 `run_path` 红 ⇒ 门面把公开方法转丢了。

2. 官方课步数：
   ```powershell
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：三张课仍是 `completable`，步数 **5 / 5 / 12**。
   - 失败：步数变了或 `not_completable` ⇒ 扫掠、bundle 解码或探针搜索语义变了。

3. （抽查）`& $env:GODOT4 --path game`，点 **单人试玩**，WASD 走两步、空格跳一下。
   - 预期：角色仍落在出生点固体上，能走、能跳；状态行仍有 `join=` / `solids=`。
   - 失败：一开玩掉出世界或走不动 ⇒ 占用查询或扫掠委托坏了。

### 本刀不测

- 控制面 / 编辑壳 / 拓扑编译器拆分（下一章）；
- 解冻令、协议帧、Schema、官方课 JSON、Tick / 快照 / 插值锁定。

### 诚实边界

- E9 仍欠：控制面 `server.ts` / `database.ts`、MatchHost `registry.ts`、`authoring_editor_shell.gd`、`traprush_topology_compiler.gd`；
- 扫掠步数仍无上限（宪法第十七条缺口）。

---

## 上一刀：CD-61 回写（C5 第 8 章）

> **本节随 CD-61 回写提交；验当前 PR 只看上面的「本刀」。**

本章只把已批准的重排写进里程碑正文，**没有开发机可见行为**。不需要 `npm run dev`，不必开 Godot 窗口。

1. 打开 [CD-61](../../Confirmed-docs/60-plan/61-milestones.md) 文首「当前生效值」与 §1。
   - 预期：写 **本文件是现行口径**；开发顺序含 M-Export → M-Art → M4a → M4b → M5；纠偏冻结令仍优先于进度压力。
   - 失败：仍写「待人类逐条批准后才回写」，或正文还只有旧的「M4：规则字节码与热发布」 ⇒ 回写没落地。

2. 打开同一文件的 M3 / M5 / §5。
   - 预期：M3 验收后有诚实边界（爆破球 + 冲刺；表现增强不是 M3 退出条件）；M5 不再把 Windows / Android/iOS 导出当退出条件；§5 给 CD-11 §4 每条和「表现 / 美术」「平台导出与 Web」「账号 + 草稿云」写了所有者；没有 M8。
   - 失败：导出仍挂在 M5，或 §5 缺失 ⇒ E12 仍不成立。

3. 打开 [重排草案](../plans/cd-61-rearrangement-draft.md) 与 [CD-91 D.10](../../Confirmed-docs/90-reference/91-decision-log.md)。
   - 预期：草案状态是 **已批准并回写**，§8 全勾；CD-91 有 `cd61_rearrangement = approved_writeback` 覆盖 `draft_pending_human`。
   - 失败：草案仍待批，或决策日志没覆盖 ⇒ 批准记录与正文脱节。

4. 自动化：
   ```bash
   npm test
   ```
   - 预期：`tools/dev-launcher/tests/cd61_writeback.test.ts` 与 `doc_governance.test.ts` 全绿。
   - 失败：里程碑标题、M3/M5 字符串或 §5 对不上。

### 本刀不测

- 大厅 / Preview / 导出包窗口；
- 解冻令、协议、官方课、`--bot-run` 步数。

### 诚实边界

- 回写 **不解除** 纠偏冻结令；M4a / M4b / M6 / M7 / 表现增强仍不得开工；
- M0–M2 已退出记录与 §3 / §4 验收场景编号未改。

---

## 上一刀：文档治理（C5 第 7 章）

> **本节随 [#211](https://github.com/czmomocha/craftarena/pull/211) 提交；验当前 PR 只看上面的「本刀」。**

本章只改所有者文档、runbook 文件名和 CD-61 草案，**没有开发机可见行为**。

1. 打开 [开发机窗口验收](dev-window-check.md) 本文档标题。
   - 预期：标题是 **开发机窗口验收**，不是「章节真机清单」。引言把「真机」留给导出包。
   - 失败：标题仍是旧名 ⇒ 更名没落地。

2. 打开 [CD-21 文首当前生效值](../../Confirmed-docs/20-gameplay/21-traprush.md) 与 [CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)。
   - 预期：CD-21 一期最小道具是爆破球 + 冲刺；CD-62「网页/微信包体超限」是未开始，「传送迷路」是已缓解，「单人审查带宽超载」与「零延迟锁定网络参数」两行存在。
   - 失败：仍写「已治理」的包体/传送，或道具表仍自称未锁 ⇒ 文档与事实又不一致。

3. 打开 [CD-61 重排草案](../plans/cd-61-rearrangement-draft.md)。
   - 预期（第 7 章当时）：标明待人类逐条批准；CD-61 仍写现行口径且尚未回写新编号。
   - 失败：当时就把新编号写进 CD-61 ⇒ 违反 D6（草案先批）。

4. 自动化：`npm test`，预期 `doc_governance.test.ts` 全绿。

### 诚实边界（第 7 章）

- 第 7 章合入不等于重排已拍板；回写是第 8 章。

---

## 上一刀：拆 Preview 壳（C5 第 6 章，chrome / sampler / hud / play / view）

> **本节已随 [#210](https://github.com/czmomocha/craftarena/pull/210) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `AuthoringPreviewShell` 拆成 chrome / sampler / hud / play / view，压到 400 行以下。公开 API 与 `--bot-run` 步数不变。

---

## 上一刀：拆 Preview 映射（C5 第 5 章，convert / occupancy / gizmos / overlay / player）

> **本节已随 [#209](https://github.com/czmomocha/craftarena/pull/209) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `AuthoringPreviewMap` 拆成 convert / occupancy / gizmos / overlay / player，压到 400 行以下。公开 API 与 `--bot-run` 步数不变。

---

## 上一刀：拆 Preview 会话（C5 第 4 章，bootstrap / intents / scan / view）

> **本节已随 [#208](https://github.com/czmomocha/craftarena/pull/208) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `AuthoringPreview` 拆成 bootstrap / intents / scan / view，压到 400 行以下。公开 API 与 `--bot-run` 步数不变。

---

## 上一刀：拆对局会话（C5 第 3 章，bootstrap / intents / scan / view）

> **本节已随 [#207](https://github.com/czmomocha/craftarena/pull/207) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `TraprushMatchSession` 拆成 bootstrap / intents / scan / view，压到 400 行以下。公开 API 与 `--bot-run` 步数不变。

---

## 上一刀：角色脚底对齐胶囊底面（freeze-exception）

> **本节已随 [#206](https://github.com/czmomocha/craftarena/pull/206) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把角色视觉从 1 米占位盒底改到权威胶囊底面。窗口里脚贴方块顶，权威命令不变。

---

## 上一刀：拆匹配会话（C5 第 2 章，codec / accept / 门面）

> **本节已随 [#205](https://github.com/czmomocha/craftarena/pull/205) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `MatchJoinSession` 拆成 codec / accept / 门面，压到 400 行以下。窗口外观不变。

---

## 上一刀：拆大厅壳（C5 产出 1，L4 协作者）

> **本节已随 [#204](https://github.com/czmomocha/craftarena/pull/204) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把 `MatchLobbyShell` 按 CD-41 L4 拆成 chrome / net / sampler / stage / hud / director，门面压到 400 行以下。窗口外观不变。当时**不拆** `match_join_session.gd`。

---

## 上一刀：本地化键（`craft_arena.ui.*`，en + zh_CN，不入字体）

> **本节已随 [#203](https://github.com/czmomocha/craftarena/pull/203) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

该刀把大厅 / Editor / Preview 的窗题、按钮、占位符和 CD-13 离线横幅改成走 `UiCopy` 键。**不入字体**。locale 在建窗时采样。

---

## 再上一刀：表现动画状态契约（idle / run / jump / land / shove / hit / break / portal）

> **本节已随 [#202](https://github.com/czmomocha/craftarena/pull/202) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

上一刀（[#201](https://github.com/czmomocha/craftarena/pull/201)）把玩法采样改成 `PlayInput`。该刀锁表现动画状态名与优先级，Solo 与 Preview 从局部权威派生，写到角色头顶 Label3D `anim`。不播 clip。在线远端不接线。

该刀**不需要** `npm run dev`（Solo 就能看完前 4 步；Preview 用 F6 沙箱；第 5 步才需要后端）。

1. **Solo 出生是 `idle`**：按「共用启动」打开大厅，点 **Solo play**。看本席角色上方的 `anim` 字（在名次标附近，不是状态行 HUD）。
   - 预期：字是 `idle`。
   - 失败：没有 `anim` 字 ⇒ Solo 没把状态写到 Label3D。一出生就是 `land` ⇒ 开局被误判成落地，应打回。

2. **走路是 `run`，松手回 `idle`**：按住 W，再松开。
   - 预期：按住时 `run`；松开后回到 `idle`。冲刺（Left Shift）也是 `run`，没有 `sprint` 字。
   - 失败：走路仍是 `idle` ⇒ `_play_moving` 没接到。出现 `sprint` ⇒ 状态集被加戏了。

3. **空格是 `jump`，落地闪一下 `land`**：站在出生点按空格。
   - 预期：跳起后立刻是 `jump`（整段空中都是，包括弧顶）；落地那一拍变成 `land`，下一拍回到 `idle`。
   - 失败：跳起来仍是 `idle`/`run` ⇒ 又用了 Jump 的 1 格 `support_dy` 当接地，官方 hop 只有 1/4 格。空中闪过 `land` 再回到 `jump` ⇒ 弧顶 `vy==0` 被当成落地。一出生就是 `jump` ⇒ 接触探针短于半格、探不到占用盒顶。

4. **Preview 同一套字**：编辑器打开 `res://src/creator/course_sandbox.tscn`，**F6**（不要 F5），点 **Play**。走一步、跳一下。
   - 预期：出生 `idle`；WASD → `run`；空格 → `jump`，Advance / 落地后闪 `land`。Preview 仍不写 `yaw_bam`。
   - 失败：大厅有字、Preview 没有 ⇒ Preview 没调 `_apply_play_anim`。

5. **在线没有 `anim` 字**：`npm run dev` 就绪后点 **Quick play**（一人房即可）。
   - 预期：本席角色上方**没有** `anim` 字。名次标还在。
   - 失败：在线也出现 `idle`/`run` ⇒ 用快照里没有的字段猜远端状态了，应打回（改协议属宪法第十八条）。

6. **自动化全绿 + 裁决不变**：
   ```bash
   npm run typecheck; npm test; npm run redline-scan
   npm run test:gut:full
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：`npm run typecheck` 无输出；`redline-scan` `no findings`；GUT 全绿；`--bot-run` 三张课 `completable`，**动作序列与步数逐项不变**（5 / 5 / 12 步）。
   - 失败：bot-run 步数变了 ⇒ 表现状态意外改了命令，停下来查，别先改断言。

### 该刀不测

- **clip / 绑定动画**：角色网格没有 `skin`，该章不播；
- **在线远端动画**：v1 快照没有 vy / stun；
- **动画秒数**：CD-63 仍延期；
- **Solo 1 人推击字**：没有邻座胶囊，`shove` 不会出现。

### 诚实边界

- `anim` 是契约读出，不是 HUD 字段，也不进快照；
- `hit` 跟环境失败硬直（出界 / 踩实心机关），不是受击闪白；
- Preview 没有基础推击，所以 Preview 不会出现 `shove`。

---

## 再上一刀：D7 输入抽象（方向向量 + 动作事件）

> **本节已随 [#201](https://github.com/czmomocha/craftarena/pull/201) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

上一刀（[#200](https://github.com/czmomocha/craftarena/pull/200)）按袋类型接上 5 个占用视觉。本刀把玩法采样从四个 WASD 布尔 / 物理键改成 `PlayInput`：方向向量 + 上升沿动作。键盘仍是现在这套键，只是走 Input Map。触控 UI 不做。

本刀**不需要** `npm run dev`（Solo 就能看完前 3 步；Preview 用 F6 沙箱）。

1. **Solo 移动仍是 8 向**：按「共用启动」打开大厅，点 **Solo play**，按 W / D / W+D。
   - 预期：W 朝世界 −Z 走；D 朝 +X；W+D 走对角。角色面向跟着 8 向走，不是自由 atan2。
   - 失败：WASD 没反应 ⇒ Input Map 的 `move_*` 没接到 `PlayInput`。走成任意角度 ⇒ 量化被改成 atan2 了，应打回。

2. **动作键仍是原来那套**：空格跳、Q 或鼠标左键用道具、F 推击、Left Shift 冲刺、R 复位。
   - 预期：与上一刀同一套键，按一下触发一次（按住不连发）。
   - 失败：F / Shift / R 没反应 ⇒ 新动作名 `shove` / `sprint` / `reset_checkpoint` 没进 Input Map，或绑定的 physical keycode 不对。

3. **Preview 同一套采样**：编辑器打开 `res://src/creator/course_sandbox.tscn`，**F6**（不要 F5），点 **Play**。
   - 预期：WASD / 空格 / Q / Shift / R 与大厅同一套键。Preview 角色移动仍不写 `yaw_bam`（面向标记可以不转）。
   - 失败：大厅能动、Preview 不能 ⇒ Preview `_process` 没走 `PlayInput`。

4. **自动化全绿 + 裁决不变**：
   ```bash
   npm run typecheck; npm test; npm run redline-scan
   npm run test:gut:full
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：`npm run typecheck` 无输出；`redline-scan` `no findings`；GUT 全绿；`--bot-run` 三张课 `completable`，**动作序列与步数逐项不变**（5 / 5 / 12 步）。
   - 失败：bot-run 步数变了 ⇒ 输入抽象意外改了命令幅度，停下来查，别先改断言。

### 本刀不测

- **触控 / 虚拟摇杆**：本章只做抽象层；
- **按键重映射界面**：原型期不做；
- **模拟摇杆手感**：幅度不进 MoveIntent，接上摇杆也仍是 8 向整步；
- **导出包内按键**：本机无 4.7.2 导出模板。

### 诚实边界

- 看起来「什么都没变」是成功判据：D7 要的是以后触控能插进来，不是新手感；
- 复位仍是上升沿，不是 CD-21 §3.2 写的「长按」——时长未锁；
- Preview 仍不把 8 向写入 Move `yaw_bam`（大厅才写）。

### 仍然欠着（不因本章消失）

- 触控 UI；动画状态契约；字体与本地化键；
- 按 `asset_id` 解析视觉；传送门没有专用模型；
- 扫掠步数无上限；`match_lobby_shell.gd` 仍超 E9 行数上限。

---

## 再上一刀：按袋类型把 5 个占用视觉接到大厅与 Preview（箱 / 滚柱保留 overlay）

> **本节已随 [#200](https://github.com/czmomocha/craftarena/pull/200) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

上一刀（[#199](https://github.com/czmomocha/craftarena/pull/199)）修掉 Solo 掉帧。该刀把已经烘焙过预算的 5 个占用 `.glb` 接到表现层：检查点垫 + 检查点门、终点门、箱子、滚柱。接线按**袋类型**，不按 `asset_id`。箱与滚柱保留 D4 危险色薄膜（人类 2026-09-02 拍板）。传送门仍是色块。

本刀**不需要** `npm run dev`（Solo 就能看完前 4 步；Preview 用 F6 沙箱）。

1. **Solo 默认课能看见垫 / 门 / 终点 / 箱 / 滚柱**：按「共用启动」打开大厅，点 **Solo play**。
   - 预期：检查点是薄垫 + 拱门（不是绿盒子）；终点是金色拱门；箱子是木箱覆橙色薄膜；出生点 −Z 方向周期出现的是覆洋红薄膜的滚柱，不是洋红盒子。地块仍是实心方块。传送门仍是彩色盒。
   - 失败：仍是纯色 1 米盒 ⇒ 路径常量没接到对应 Map，或 `.glb` 没导入（跑一次 `--headless --path game --import`）。整个人看不见 ⇒ 占位盒 `layers = 0` 之后视觉没挂上。

2. **垫的进度色还在**：走上去验收第一个垫（或开玩后看当前目标垫）。
   - 预期：当前目标垫是亮薄荷薄膜，走过的是暗绿，未到的是原绿。盒子本体看不见，颜色在模型薄膜上。
   - 失败：模型不变色、或整个人变成纯色块 ⇒ overlay 没套上。

3. **箱仍是橙、滚柱仍是洋红**（这是拍板项，不是审美）：盯着箱子和滚柱看。
   - 预期：能看出是模型，同时能一眼认出「会打你的」——橙 / 洋红薄膜还在。
   - 失败：箱子和地板一个色 ⇒ overlay 被拿掉了。

4. **换课之后箱子在新位置**：把课程 id 改成 `course_03`，点 **Apply**（或重开大厅），再点 **Solo play**。
   - 预期：箱子在 `course_03` 的位置，不是 `course_01` 的位置；仍是覆橙薄膜的箱子模型。
   - 失败：箱子留在上一张课的坐标 ⇒ 复用节点时没有重写位姿。

5. **Preview 同一套**：编辑器打开 `res://src/creator/course_sandbox.tscn`，**F6**（不要 F5）。
   - 预期：Editor 3D 里垫 / 门 / 终点 / 箱 / 滚柱与大厅同一套模型；点 **Preview**，独立窗口一致。固体地块没有危险色 overlay。
   - 失败：Preview 仍是色块、大厅是模型 ⇒ 有一处没走 `SharedVisualAssetCatalog`。

6. **门比人矮、滚柱可能超格——这不是本刀要修的**：把角色走到门旁边，再看滚柱。
   - 预期：门明显矮于角色（约 0.76 m vs 约 1.13 m）；滚柱可能略高出一格。本刀**不**靠拉伸修。
   - 失败：门被拉成跟人格一样高、滚柱被压扁进格子 ⇒ 贴合规则被改成按高度缩放了，应打回。

7. **自动化全绿 + 裁决不变**：
   ```bash
   npm run typecheck; npm test; npm run redline-scan; npm run asset-budget
   & $env:GODOT4_CONSOLE --headless --path game -- --package-check
   npm run test:gut:full
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：`npm run typecheck` 无输出；`redline-scan` `no findings`；`npm test` **401/401**；`--package-check` `ok=true` 且五个占用 `*_visual_loadable` 均为 `true`；GUT **1194/1194**（121 个脚本）；`--bot-run` 三张课 `completable`，**动作序列与步数逐项不变**（5 / 5 / 12 步）。
   - 失败：bot-run 步数变了 ⇒ 视觉意外影响了仿真，停下来查，别先改断言。

### 本刀不测

- **新模型好不好看**：占位美术，配色与比例未经美术定稿；
- **按 `asset_id` 换模型**：本刀按袋类型接线，7 类袋仍共用同一个内置玩法资产；
- **传送门 / spawn_grid / slope / bridge**：没生成或没数据源，见 `_source_refs/traprush/MANIFEST.md`；
- **导出包内表现**：本机无 4.7.2 导出模板。

### 诚实边界

- 贴合系数从模型自己的 AABB 算，测试不写死尺寸。门矮、滚柱超格是资产比例，不是贴合公式算错；
- 箱 / 滚柱的橙 / 洋红是 `material_overlay`，不改共享 Mesh。拿掉 overlay 会让「会打你的」和地板看起来一样；
- `apply_own_progress` 每帧都会被对局壳调用；盒子 albedo 没变就不重套 overlay，避免每帧 `StandardMaterial3D.new()`；
- 官方课 JSON 一个字节没动。占用半长仍来自 bundle 的 `assets` 袋。

### 仍然欠着（不因本章消失）

- **按 `asset_id` 解析视觉**仍未做：一期唯一内置玩法资产被 7 类袋共用；
- **传送门没有专用模型**；`spawn_grid` 没有数据源；`block_slope` 在 Schema 层无法表达；
- 扫掠步数无上限（宪法第十七条缺口）；`is_pose_blocked` 仍是全量扫描；
- 字体与本地化键、D7 输入抽象、C5 拆 `match_lobby_shell.gd`。

---

## 上一刀：找出并修掉 Solo 掉帧的真因，顺带把 GUT 从 355 秒压到 24 秒

> **本节已随 [#199](https://github.com/czmomocha/craftarena/pull/199) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

上一刀（[#198](https://github.com/czmomocha/craftarena/pull/198)）把帧率读数放上了 HUD，本刀用它量出了掉帧的真因并修掉。

现象是：大厅空闲约 120 FPS，点 **Solo play** 后掉到 20–30。分摊之后根因只有一个——`Fixed.try_mul` 单次要 **176 微秒**（它走纯 GDScript 的软件 128 位长除法），而一次碰撞查询要对 49 个静态盒各做 4 次。加一条「中间积不溢出 int64 就用原生乘除」的快路径后，整帧 **33.73 ms → 1.656 ms**。完整分摊表与诚实边界在 [2026-09-01 帧成本审计](../audits/2026-09-01-offline-frame-cost.md)。

同刀还修了一个**正确性**缺陷：离线仿真节拍原本等于帧率（`_process` 里推 tick）。33 ms/帧时是三分之一速慢放，帧成本修好之后会变成两倍速。现在推进搬到 `_physics_process`，固定 60 Hz，与 `match_server.gd` 同一节拍。

本刀**不需要** `npm run dev`（Solo 就能看完前 5 步）。

1. **先建立基线**：按「共用启动」打开大厅，读最上面一行的 `FPS`（上一刀加的读数，头半秒是 `FPS --`）。
   - 预期：约半秒后出现一个数字；状态行在它下面一行，`join=idle`、`play=idle`、`tls=off`、`server=127.0.0.1`、`course=3/5/1` 一个不少。**把这个数字记下来**，第 3 步要和它比。
   - 失败：一直是 `FPS --` ⇒ `_process` 没喂到它（这属于上一刀的回归，本刀改过 `_process` 的结构，值得一并查）。

2. **数字约每半秒跳一次，不是每帧抖**：盯着看两秒。
   - 预期：数字**跳变**约每秒 2 次（刷新间隔 0.5 s），中间那几十帧它不动，读得清。
   - 失败：数字每帧都在变 ⇒ 刷新被改成了每帧写 `text`。

3. **这刀的主证据：点 Solo play 之后帧率不掉**。点 **Solo play**，再看两秒，和第 1 步记下的数字比。
   - 预期：开玩后的数字与开玩前**在同一量级**（掉一点正常，掉到 20–30 不正常）。
   - 失败：仍掉到 30 以下 ⇒ 还有一处没量到的每帧开销。别猜，跑
     `& $env:GODOT4_CONSOLE --headless --path game -s res://tests/support/frame_cost_bench.gd`，
     它会把整帧摊到各段上；改前改后用的是同一把尺子。

4. **不再慢放，也没有变成两倍速**（tick 从渲染帧解耦的证据）。开 Solo，按住 **W** 从出生点走到第二个检查点垫，用手机掐一下秒。
   - 预期：走同样的距离，**墙钟时间与帧率无关**。想更硬的证据就对比状态行的 `pads=n/3` 推进快慢——它跟的是权威 tick。
   - 失败：明显比以前快一倍 ⇒ 采样或推进又回到了 `_process`；明显慢 ⇒ `_physics_process` 在追帧，说明单 tick 仍超预算。

5. **表现还是对的**（复用节点最容易走反的一侧）。开 Solo，按住 W 走几步，然后按 **F**（推击，Solo 无目标）与 **空格**。
   - 预期：本席青色角色跟着走；头顶名次标 `*#1 P0 n/3` 跟着移动且数字跟着变；橙色箱在原位；洋红机关按周期显隐；状态行 `pads` / `floor` / `crates` / `hazards` / `solids` 都在。按 F 什么都不该发生（Solo 只有一枚胶囊）。
   - 失败：名次标不动或不跟着走 ⇒ 复用时漏写了位姿；箱子或机关消失不再回来 ⇒ 撤盒那一侧写反了。

6. **换课之后箱子在新位置**（复用节点最容易漏的那个坑）。把课程 id 改成 `course_03`，点 **Apply**（或重开大厅），看橙色箱。
   - 预期：箱子在 `course_03` 的位置，不是 `course_01` 的位置。
   - 失败：箱子留在上一张课的坐标 ⇒ 复用节点时没有重写位姿。

7. **自动化全绿 + 裁决逐字不变**：
   ```bash
   npm run typecheck; npm test; npm run redline-scan; npm run asset-budget
   & $env:GODOT4_CONSOLE --headless --path game -- --package-check
   npm run test:gut:full
   & $env:GODOT4_CONSOLE --headless --path game -- --bot-run
   ```
   - 预期：`npm run typecheck` 无输出；`redline-scan` `no findings`；`npm test` **401/401**；`--package-check` `ok=true`；GUT **1178/1178**（120 个脚本，约 24 秒）；`--bot-run` 三张课 `completable`，**动作序列、`expansions`、`search_ticks`、`steps`、`ticks` 逐字段与改前相同**（5 / 5 / 12 步）。
   - 失败：bot-run 有**任何**字段变了 ⇒ 定点数快路径与限位路径分叉了，停下来看 `test_fixed_mul_div_paths.gd`，**别先改断言**。这条是整刀「只变快、没变对错」的唯一硬证据。

### 本刀不测

- **帧率数字要达到多少**：CD-53 §1.1 明确不建自动性能回归门禁，本刀也不锁目标值。第 3 步比的是「开玩前 vs 开玩后」，不是某个绝对数；
- **Preview 与编辑器窗口的帧率**：只接了大厅壳 `MatchLobbyShell`，两条 creator 壳一行没动（但它们共用 `Fixed`，所以也会一起变快，只是没量）；
- **在线对局的帧率**：第 3–6 步走的是 Solo。在线要 `npm run dev` 且引入网络抖动，不适合当帧率步骤；
- **导出包内表现**：本机无 4.7.2 导出模板。

### 诚实边界

- 审计里那张分摊表是 **headless** 量的，完全没有渲染。它**低估**「每帧 free 再 new 一个 Label3D / MeshInstance3D」的真实代价——真机收益只会更大，但真机 FPS 只有第 3 步能证明；
- 全部数字来自 **Windows 开发机 debug 解释器**，不是产品性能指标，也没在导出包或 Linux 上量过；
- 快路径**不改数值合同**：Q48.16、向零截断、溢出拒绝一个字没动（ADR-0005 / CD-42 §1.1）。它只是在中间积不溢出时少绕一圈；差分用例 22,318 条断言钉住两条路径同值；
- 测试从 354.6 s 到 24.4 s 里，探针记忆化与分层只贡献到 285 s 量级，**剩下一个数量级是定点数快路径给的**。分层本身不减覆盖：fast 与 slow 两层都在每次 PR 跑；
- `test:gut:affected` 是本地工具，**永远不是门禁**。它算错的上限是「某个失败晚几分钟被发现」。

### 仍然欠着（不因本章消失）

- **扫掠步数无上限**（宪法第十七条缺口）：步数正比于 `|dy| / radius`，长时间自由下落仍会线性增长。本刀只把每步的常数压下去了；
- **`is_pose_blocked` 仍是 O(静态盒数) 全量扫描**，没有空间划分。49 个盒子现在只要 0.97 ms，但 UGC 赛道的盒数没有上限；
- Preview 壳与编辑器壳没有帧率读数；macOS / Linux 桌面与 Web 都没实测；
- `match_lobby_shell.gd` 仍远超 E9 的 400 行上限（本刀在原文件内收敛了调用关系，没有拆它——拆分属 C5）。

---

## 更早：大厅 HUD 顶行显示运行时帧率（FPS）

> **本节已随 [#198](https://github.com/czmomocha/craftarena/pull/198) 合入，保留只为追溯。验当前 PR 只看上面的「本刀」。**

这刀只做一件事：在大厅窗口 HUD 的**第一行**加一个 `FPS 60` 读数。

**它是观察工具，不是性能门禁。** 纠偏期那几刀每帧优化（Preview 重建脏检查、共享 Mesh）当时只能靠 `print` 出来的毫秒数判断，量一次就得改一次代码。这刀把这个数放到屏幕上，好让「改之前 / 改之后」能在同一个窗口里连着看。它不进裁决、不进快照、不写日志、不发网络，也不锁帧率目标（CD-53 §1.1 明确不建自动性能回归门禁）。

它加完的第二天就派上了用场：当前这刀的第 1、3 步读的就是它。

1. **开窗口就有，而且头半秒不是 0**：按「共用启动」打开大厅。
   - 预期：最上面一行先是 `FPS --`，**约半秒后**变成 `FPS 60` 上下的数字。
   - 失败：一直是 `FPS --` ⇒ `_process` 没喂到它；一上来是 `FPS 0` ⇒ 首窗占位被改成了 0，那会被读成「卡死了」。

2. **数字约每半秒跳一次，不是每帧抖**：刷新间隔 0.5 s，中间那几十帧它不动。

3. **帧率行不抢输入**：它是 `Label`（默认 `FOCUS_NONE`），放在按钮行**上面**，不盖任何控件。

### 诚实边界（当时写下的，仍然成立）

- 单元测试里的 `FPS 100` 来自**注入的固定 delta**（`sample(0.01)` 喂 60 次），不是真机测出来的。测试钉的是「帧数 ÷ 累计秒数」这个**数法**，不是任何性能阈值；
- 0.5 s 刷新是「看得清 + 不抖」的折中，**不是产品规格**。真要做逐帧剖面，要的是毫秒——当前这刀用的就是 `frame_cost_bench.gd`，不是这个数；
- 窗口隐藏时**丢弃半窗**（`reset()`），所以隐藏期间有多卡都不会体现在下一窗；
- 帧率行**常驻，没有开关**；用的是引擎默认字体（字体入包仍是 C4 遗留的人类门禁）。

---

## 更早的一刀：换掉地块视觉，修掉悬空的路面

> **本节已随 [#197](https://github.com/czmomocha/craftarena/pull/197) 合入，保留只为追溯。**

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
- macOS 上 `@gltf-transform/cli@4.5.0` 仍未实测；烘焙流水线（人类 2026-08-30 明确不在 C4）；按实体 diff、字体与本地化键、动画状态契约、D7 输入抽象层、角色胶囊尚未进资产表、扫掠取样代价无上限（宪法第十七条缺口）、`match_lobby_shell.gd` 已 1,516 行（E9 要求 < 400）。

---
