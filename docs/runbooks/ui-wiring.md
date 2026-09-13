# Craft Arena UI 基础包 · 接线说明

> **状态（2026-09-13）：资产已落库，四项前置已清完，运行时尚未接线。**
>
> - **排期的所有者是 [CD-61 §2 M-Art](../../Confirmed-docs/60-plan/61-milestones.md#m-art表现与美术)**，本文件不复述（宪法第二十六条）。三批：S3 广场 → S1 主大厅（M6 主大厅壳章内）→ S2 / S4 / S5 / S6。
> - 第一批四项前置全部已交（均 2026-09-13）：**字体入包**（[CD-11 §8.2 第 3 条](../../Confirmed-docs/10-product/11-scope-and-platforms.md)，见 [§3.5](#36-字体已完成2026-09-13)）；**两个校验脚本进 CI**（见 [§0](#0-两个校验脚本已进-ci2026-09-13)）；**S3 + 卡片文案迁 `UiCopy`**（见 [§0.3](#03-文案迁-uicopy-的真实口径)）；**本文件按仓库实际落点重写**（本次）。
> - **本文件描述的是本仓库，不是源项目。** 2026-09-13 之前第 1–5 节还是源项目 `testUI` 的视角（`F:\study\craftarena` 路径、`godot/scenes/` 目录、写死的 Windows 引擎路径），已按 `game/` 的实际落点重写。源项目的设计管线（`design/tokens.json`、`build_theme.py`、切图脚本）**没有入库**，相关章节据此改写而不是照抄，见 [§4](#4-样式维护)。

---

## 0. 两个校验脚本（已进 CI，2026-09-13）

`game/tools/ui/validate_theme.gd` 与 `validate_scene.gd` 现在是 `ci.yml` 里 `godot` job 的一步。它们查的是 GUT 查不到的东西：`.tscn` 里 `theme_type_variation` 写成一个主题里不存在的名字，**运行时不报错**，只会静默套用默认样式——这种 bug 只有人眼在窗口里能看出来，而开发机窗口验收不是门禁（宪法第二十四条）。

本地跑：

```bash
"$GODOT4" --headless --path game --script res://tools/ui/validate_theme.gd
"$GODOT4" --headless --path game --script res://tools/ui/validate_scene.gd
```

`validate_scene.gd` 不带参数时查 `DEFAULT_SCENES`（S1 / S2 / S3），也可以在 `--` 之后传场景路径。

### 0.1 接进 CI 那天修掉的两个假绿

**这一节不是记账，是使用说明**：下次再往 CI 加这类脚本，先按同样方式注入故障，不要用 PASS 证明门禁有效。

1. **`validate_theme.gd` 的 25 项检查此前全部恒真。** 它用 `theme.get_stylebox(...) == null` 和 `get_font_size(...) <= 0` 判缺失，而 `Theme.get_stylebox()` 找不到条目时返回的是**回退空样式**、不是 `null`，`get_font_size()` 返回**默认字号**、不是 0。两个条件都永远为假。改用 `has_stylebox()` / `has_font_size()` 之后才有判定力。
2. **`--script` 在脚本自身解析失败时 exit 0。** 只在 stderr 打一行 `Failed to load script ... Parse error`，退出码是 0。于是脚本一旦写坏就变成永远绿。CI 那一步因此**额外要求输出里出现 `RESULT: PASS`**，解析失败的脚本打不出这行；同时 `game/tools` 已并入 check-only 的扫描范围，语法层面还有第二道。

这与 [desktop-export-check.md §5 第 4 条](desktop-export-check.md) 记的「GUT 静默跳过解析失败的测试脚本」是同一类陷阱：**Godot 的很多失败路径不走退出码。**

### 0.2 故障注入验证（2026-09-13 实测）

| 注入 | 期望 | 实测 |
|---|---|---|
| 主题里 `ButtonPrimary/styles/normal` 改名 | 非零 + 指名缺失项 | `exit=1`，`MISSING stylebox 'normal' on type 'ButtonPrimary'` |
| 主题里 `PageTitle/font_sizes/font_size` 改名 | 非零 + 指名缺失项 | `exit=1`，`MISSING font_size on type 'PageTitle'` |
| `s3_workshop.tscn` 的变种改成不存在的名字 | 非零 + 指名节点 | `exit=1`，`'Sort' uses undeclared variation 'NoSuchVariation'` |
| 传一个不存在的场景路径 | 非零 | `exit=1` |
| 给 `validate_theme.gd` 加一行语法错误 | 非零 | 裸退出码 **0（假绿）**；加上 `RESULT: PASS` 断言后 `exit=1` |

### 0.3 文案迁 UiCopy 的真实口径

#### 「85 处硬编码中文」这个数字同时高估和低估了工作量

它数的是四个 `.tscn` 里的 `text =` / `placeholder_text =` 行。两个方向都不准：

- **高估**：其中很大一部分不是界面文案，而是**占位假数据**——S2 的六条赛道名（`齿轮回廊`、`熔岩传送带`…）、标签、`Maker_042（我）`、`队列位次 #2 · 预计等待 00:25`，S1 的 `草稿 2` / `已发布 1`。这些将来由服务端或课程数据提供。**把它们写进本地化表是错的**：假数据一旦进表就看起来像已定稿的产品文案，接线时还得再删一遍，中间任何一次「补全翻译」还会给假数据配上英文译文。
- **低估**：它只数了 `.tscn`。`s3_workshop.gd` 里的 `ENTRIES` 数组有 8 条占位内容（标题、标签、作者、`1.2k 次游玩`），中文量比整个 `.tscn` 还多，从来没被这个口径数进去。

所以本刀采用的口径是：

| 类别 | 处理 | 落点 |
|---|---|---|
| 界面文案（标题、按钮、分区名、占位符） | 迁 `UiCopy`，按屏分前缀 | `craft_arena.s3.*`、`craft_arena.card.*` |
| 占位假数据 | **不进本地化表**，移进脚本的 `DEMO_*` 常量 | `s3_workshop.gd` 的 `DEMO_ENTRIES` |
| 数量 + 量词（`1.2k 次游玩`） | 拆开：数据给数字，表给量词 | `craft_arena.card.plays_count` = `%s 次游玩` |

`DEMO_` 这个前缀本身就是文档：它说明这段数据是要被删的，不是要被翻译的。

#### 已迁移与未迁移

**已迁移**：`s3_workshop.tscn`、`components/content_card.tscn`（第一批的实际目标）。两个文件的 `text` 已清空，运行时由 `_apply_copy()` / `_apply()` 从 `UiCopy` 填。

**未迁移**：`s1_lobby.tscn`（18 处）、`s2_matchmaking.tscn`（52 处）。它们分别属于第二批（M6）和第三批，且 `s1_lobby.tscn` 目前**没有脚本**，迁移要顺带新建 `s1_lobby.gd`。拆开是为了让第一批的接线不被两个远期屏幕挡住（宪法第九条：一次变更只解决一个主要问题）。

这份清单是**可执行的**，不只是文字：`game/tests/unit/test_ui_scene_copy.gd` 的 `PENDING_SCENES` 就是上面那两个文件，并且有一条反例断言要求它们**确实还含中文**——迁完之后那条会红，提醒把它们移进 `MIGRATED_SCENES`。

#### 为什么清空 `.tscn` 而不是留着当占位

人类 2026-09-13 拍板走「清空 + 运行时填」。好处是**漏接一个键会显示为空白**，一眼可见；留着中文当占位的话，漏接的那个会继续显示一句翻译器够不到的中文，看起来完全正常。代价是编辑器里打开场景看到的是空壳，设计评审要跑起来看。

---

> UI 基础包由独立的纯 UI 项目（`testUI`）产出，2026-09-11 落库。**那个项目不在本仓库里**，本节描述的是落库之后 `game/` 里的实际形态。
> 源项目的设计管线（`design/tokens.json`、`build_theme.py`、切图脚本、`wire_into.py`）**没有入库**，所以"改 token 重跑脚本"这条路在本仓库走不通，见 [§4](#4-样式维护)。

---

## 1. 落点

```text
game/
├── content/ui/
│   ├── theme/craft_arena.tres        主题，1003 行 / 59 类型 / 53 变种
│   ├── fonts/                        入包字体子集与字表（见 §3.5）
│   ├── shaders/                      rounded_gradient / rounded_texture / feather_left
│   └── assets/                       23 张切图（.png + .import）
├── src/client/ui/
│   ├── scenes/
│   │   ├── s1_lobby.tscn
│   │   ├── s2_matchmaking.tscn
│   │   ├── s3_workshop.tscn
│   │   └── components/content_card.tscn
│   └── scripts/
│       ├── content_card.gd           卡片组件
│       ├── press_feedback.gd         按压反馈，只能挂 BaseButton
│       ├── rounded_gradient.gd       同步 shader 的 rect_size
│       ├── spinner.gd
│       ├── s2_matchmaking.gd
│       └── s3_workshop.gd
└── tools/ui/
    ├── validate_theme.gd             CI 门禁（§0）
    ├── validate_scene.gd             CI 门禁（§0）
    └── screenshot.gd                 出预览图，不进 CI
```

注意 `scenes/` 与 `scripts/` 是**平级**的两个目录，场景和组件都在 `scenes/` 下（组件在 `scenes/components/`）。历史版本的本文件写的是 `screens/` 与 `components/` 两个顶层目录，那是源项目的形状，本仓库从来没有过。

`s1_lobby.tscn` **没有脚本**，是纯静态场景；`s2` / `s3` 有。

## 2. 当前接线状态

| 屏 | 场景 | 运行时 | 接线批次 |
|---|---|---|---|
| S1 主大厅 | `s1_lobby.tscn` | 仍是 `match_lobby_shell.gd` 自绘 `Window` | 第二批（M6） |
| S2 匹配 | `s2_matchmaking.tscn` | 同上（大厅窗口内的输入框与按钮） | 第三批 |
| S3 广场 | `s3_workshop.tscn` | **已接线**（2026-09-13）：`content_plaza_entry.gd` 的视图 | 第一批 ✅ |
| S4 / S5 / S6 | — | — | 第三批，尚无设计稿 |

### 2.1 S3 怎么接的

**只换了视图。** `content_plaza_entry.gd` 仍然持有全部状态与逻辑——tab、列表、选中、HTTP 拉取、bundle 解析、Solo 与建房两个出口，公开 API 一个字没改，所以 `match_lobby_director.gd` 不需要动。变的只是 `_ensure_window()` 里从手搓 `ItemList` 改成实例化 `s3_workshop.tscn`，以及 `_rebuild()` 改成把列表行推给视图。

视图侧（`s3_workshop.gd`）是被驱动的，自己不决定列表内容：

| 视图 API | 谁调 | 作用 |
|---|---|---|
| `set_listing(rows)` | entry | 把 `content_plaza.gd` 的列表行渲染成卡片 |
| `set_active_tab(tab)` | entry | 反映当前 tab（换主题变种） |
| `set_empty_notice(text)` | entry | 空态 |
| `tab_requested(tab)` | → entry | 点了标签页 |
| `content_selected(id)` | → entry | 点了卡片 |
| `back_requested()` | → entry | 点了左上返回 |

`demo_content` 决定是独立预览（填 `DEMO_ENTRIES`）还是被驱动（entry 在入树前置 false）。

### 2.2 设计没覆盖到的四处，以及各自怎么处理

**这四条都不是实现偷懒，是设计稿与产品契约对不上。** 接线时没有自行发明产品决策：

1. **没有 Solo / 创建房间的位置。** 设计只给了左上返回、四个标签页、卡片上一个「编辑/复用」。而广场现有两个出口（单人试玩、按内容建房）是已上线行为，删掉它们是比"换视图"大得多的改动（宪法第九条）。**处理**：原来的动作行仍由代码建出、附在屏幕下方，节点名不变（`PlazaActions/PlazaSolo` / `PlazaCreateRoom` / `PlazaClose`），代码里标了 `STOPGAP_ACTIONS`。**要把这两个动作放进设计里，需要设计稿。**
2. **排序 / 标签筛选 / 搜索没有后端。** `ContentPlaza` 只按 tab 排序，没有 tab 内排序、没有标签过滤、没有搜索。**处理**：三个控件**禁用**。留着是因为删了就是改设计；禁用是因为"能点但什么都不发生"比灰掉更糟。有测试钉住。
3. **卡片画了作者，列表行没有作者字段。** **处理**：作者名与色点一起隐藏。不拿 `content_id` 顶替——那会读作一条服务端从未做出的署名。
4. **卡片画了缩略图，UGC 永远不会有。** 玩家上传贴图是明确的不做项（[CD-11 §5](../../Confirmed-docs/10-product/11-scope-and-platforms.md)），所以一期内 UGC 不可能有预览图。**处理**：留空，不生成假图。

另外两处映射是真实的：评分 = `rating_sum / rating_count`（未评分为 0 星，那是事实不是缺值），游玩次数 = `play_count` 原样，**不缩写成 `1.2k`**——把真实计数四舍五入成设计稿的样子是在编造精度。

### 2.3 接线时挖出来的一类真 bug：`@onready` 让 setter 静默失效

`s3_workshop.gd` 与 `content_card.gd` 原本都用 `@onready` 取子节点，`_apply()` 上还有 `is_node_ready()` 守卫。后果是：**在节点入树之前给它赋值，会被静默丢弃**，不报错、不警告，只是渲染成空白。

GUT 全绿也发现不了——测试里 `add_child` 发生在一棵已经在跑的树里，`_ready` 先于 setter 执行。是驱动态渲染（[§4.1](#41-出预览图)）里一张卡都没出来才暴露的。

**修法**：两个文件都改成惰性解析（`PackedScene.instantiate()` 已经把子树建好了，`get_node_or_null` 立刻可用），并且每个公开入口先调一次幂等的 `_ensure_chrome()` / `_resolve()`。`test_content_plaza.gd` 里有一条 `test_a_card_built_outside_the_tree_still_renders` 钉住它，已做故障注入验证。

**写这类组件时记住**：凡是「属性 setter + `@onready` 子节点」的组合，都要假定 setter 可能先于 `_ready` 发生。

## 3. 接入方式

### 3.1 主题随场景走，字体是全局的

这两件事现在不一样，容易混：

- **主题不全局。** 三个屏幕场景的根 `Control` 各自带 `theme = craft_arena.tres`，所以接入一屏只影响那一屏。`project.godot` **没有** `gui/theme/custom`，因为自绘大厅还在跑，挂全局主题会当场改写它们的外观。等三批接完再统一挂。
- **字体全局。** `gui/theme/custom_font` 指向入包子集（2026-09-13），因为自绘大厅、HUD 和 `Label3D` 都不挂 theme，需要一个兜底。这一项与上面那条不冲突：它只给字体，不给样式盒。

### 3.2 实例化

```gdscript
var screen: Control = preload("res://src/client/ui/scenes/s3_workshop.tscn").instantiate()
add_child(screen)
```

### 3.3 S2 的状态由导出属性驱动

```gdscript
var s2: Control = preload("res://src/client/ui/scenes/s2_matchmaking.tscn").instantiate()
add_child(s2)
s2.set("state", 1)          # State.WAITING = 0 / State.MATCH_FOUND = 1
s2.set("player_count", 4)   # 1-8
s2.set("solo_mode", false)  # true 时显示 CD-13 离线横幅
```

跨脚本赋值走 `set()` 而不是点号，见 [§6.3](#63-严格-gdscriptcraftarena-已开启必守)。

### 3.4 S3 的卡片是数据驱动的

业务侧不改场景树，只注入数据。当前的 `DEMO_ENTRIES`（`s3_workshop.gd`）是占位，接线那一刀会换成控制面的列表响应并删掉它。字段见该常量；**`plays` 只放数字**，量词由 `craft_arena.card.plays_count` 提供（[§0.3](#03-文案迁-uicopy-的真实口径)）。

新增卡片文案必须走 `UiCopy` 键，不要写回 `.tscn`——`test_ui_scene_copy.gd` 会红。

### 3.5 窗口与缩放

`project.godot` 已经是这套值，**不需要再改**：

```ini
[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/size/window_width_override=1600
window/size/window_height_override=900
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

UI 基准是 1920×1080，开发机窗口是 1600×900 最大化——**两者不是一回事**，且基准只作用于主窗口。嵌入子窗口（Editor / Preview）另有约束，所有者是 [CD-11 §8.2 第 2 条](../../Confirmed-docs/10-product/11-scope-and-platforms.md)，本文件不复述。

### 3.6 字体（已完成，2026-09-13）

主题**此前**没有内置字体，中文全靠引擎回退渲染。现在：

- 入包文件 `game/content/ui/fonts/craftarena_sans_sc_regular.otf`（Noto Sans SC 常用 3500 字子集，SIL OFL 1.1，约 800 KB）。按 OFL 的保留字体名约束改过名，**不要再去找 "Noto Sans SC"**。
- 主题的 `default_font` 指向它。各类型变种只设 `font_sizes/font_size`，字体继承 `default_font`，不必逐个写 `fonts/font`。
- 路径的唯一所有者是 `game/src/shared/ui_font.gd`。
- 改了文案之后的重跑步骤、已知边界（只有 Regular、emoji 不在子集内、Web 上没有系统回退）都在 `tools/font-subset/README.md`，本文件不复述。
- 缺字有门禁：`test_font_covers_live_sources.gd` 现扫仓库逐字符断言，改文案导致缺字会直接红并打出 `U+XXXX(字) 首见于 res://…`。

---

## 4. 样式维护

**源项目的 token 管线没有入库**，所以本仓库改样式只能直接改 `.tres`。这是当前事实，不是推荐做法：

```bash
# 改 game/content/ui/theme/craft_arena.tres 之后，两个门禁都要过
"$GODOT4" --headless --path game --script res://tools/ui/validate_theme.gd
"$GODOT4" --headless --path game --script res://tools/ui/validate_scene.gd
```

两个脚本已进 CI（[§0](#0-两个校验脚本已进-ci2026-09-13)），本地跑只是提前发现。**新增主题变种时先加到 `validate_theme.gd` 的检查清单里**，否则它不在门禁覆盖范围内。命名沿用 `<控件><语义>`（`TrackRowSelected`、`ButtonOnGradient`）。

要把 token 管线搬进来属于新增工具与依赖（宪法第十八条），需要人类拍板，现在没有排期。

### 4.1 出预览图

```bash
"$GODOT4" --path game --rendering-driver opengl3 --resolution 1920x1080 \
    --script res://tools/ui/screenshot.gd -- \
    res://src/client/ui/scenes/s3_workshop.tscn - /tmp/s3.png
```

第三个参数是悬停节点名（`-` 表示不悬停），之后可以追加 `prop=value` 驱动导出属性（例如 `state=1`）。**不进 CI**，它需要真实渲染设备。

> 注意：S3 与卡片的文案现在由 `_ready()` 填（[§0.3](#03-文案迁-uicopy-的真实口径)），所以编辑器里打开场景看到的是空标签，**截图脚本跑出来的才有字**。

**S3 还有第二个预览，它才是有意义的那个**：

```bash
"$GODOT4" --path game --rendering-driver opengl3 --resolution 1920x1080 \
    --script res://tools/ui/plaza_preview.gd -- /tmp/plaza.png
```

`screenshot.gd` 渲染的是独立模式，看到的是 `DEMO_ENTRIES`——八张有缩略图有作者的漂亮卡片。真实列表行两样都没有（[§2.2](#22-设计没覆盖到的四处以及各自怎么处理)），所以那张图**说明不了玩家会看到什么**。`plaza_preview.gd` 喂的是 `ContentPlaza.list_tab()` 的真实形状：三行，含一条未评分、一条未验证。§2.3 那个 bug 就是靠它发现的。

---

## 5. 切图资产

23 张 `.png` 在 `game/content/ui/assets/`，已入库并生成 `.import`。**切图脚本没有入库**，所以本仓库不能重新切图；需要改图得回源项目，或者按新流程重新立项。

源 mockup 是 AI 生成概念稿，几何与规格数值不符——历史上切图坐标都是实测出来的，不是从设计稿推算的。沿用的规则：

- 只切**插画 / 缩略图 / 图标**；纯色面板、按钮、卡片一律用 Theme 代码化；
- **文字绝不切图**（无法本地化、无法缩放）——现在这条还多了一层理由：文案已走 `UiCopy`，切进图里的字既翻不了也查不出缺字。

### 5.1 换了图必须重跑导入

Godot 读的是 `.godot/imported/` 里的产物，不是 `.png` 本身。换图后直接运行看到的仍是旧纹理：

```bash
"$GODOT4" --headless --path game --import
```

这条是"改了图却没变化"类问题的第一排查项。同样适用于换字体（`.otf` 也是导入资源）。

---

## 6. 关键实现约定

路径以仓库根为准；shader 在 `content/ui/`，脚本在 `src/client/ui/`，两者不同级（[§1](#1-落点)）。

| 约定 | 原因 |
|---|---|
| 渐变用 `content/ui/shaders/rounded_gradient.gdshader` | `StyleBoxFlat` 只支持纯色 |
| 贴图圆角用 `content/ui/shaders/rounded_texture.gdshader` | `TextureRect` 无圆角属性 |
| 两个 shader 的 `rect_size` 由 `src/client/ui/scripts/rounded_gradient.gd` 同步 | 否则圆角 / 渐变在尺寸变化时错位 |
| 按钮按压反馈用 `src/client/ui/scripts/press_feedback.gd` | 主题只换样式盒，缩放 / 亮度需代码。**只能挂 `BaseButton`**，`validate_scene.gd` 会查 |
| 插画接缝用 `content/ui/shaders/feather_left.gdshader` | 切片自带烘焙渐变，与卡片渐变不匹配 |
| 可点击卡片需显式同步 `custom_minimum_size` | **Button 不是 Container，不向子节点取最小尺寸**（见 [§6.1](#61-重要button-不传播子节点最小尺寸)） |
| 文案走 `UiCopy` 键，`.tscn` 留空 | 漏接会显示为空白而不是一句翻不了的中文（[§0.3](#03-文案迁-uicopy-的真实口径)） |
| 文案语义锁定 | 见 [§6.2](#62-文案语义锁定规格约束不得改写) |

### 6.1 重要：Button 不传播子节点最小尺寸

`Button`/`Panel` 这类非 Container 节点做"可点击卡片"时，其 `custom_minimum_size` **不会**包含子节点。`content_card.gd` 的 `_sync_minimum_size()` 显式镜像了内容高度。新增同类组件时必须复制这一处理，否则卡片会塌缩、内容向外溢出。

注意：只镜像**高度**，宽度必须交给 `GridContainer` 列宽，否则卡片会宽于列导致横向溢出；同时卡片根节点需要 `size_flags_horizontal = 3` 才能让列拉伸铺满。

### 6.2 文案语义锁定（规格约束，不得改写）

锁的是**语义**，不是某个文件里的字符串。这些句子现在有的在 `UiCopy` 键表里、有的还硬编码在场景里，迁移只换存放位置，**不得顺手改措辞**：

- 「离线试玩，成绩不上传 SOLO · RESULTS NOT UPLOADED」——语义的所有者是 [CD-13 §3](../../Confirmed-docs/10-product/13-account-and-session.md)，已在 `craft_arena.ui.offline_banner`，且有专门的测试禁止它以字面量形式出现在 `src/` 里；
- 「本局名次不进入任何天梯或长期排行」（宪法第十五条）；
- 「版本不可覆盖：每次发布生成新版本 · 可随时回滚到上一签名版本」（宪法第六、十三条）；
- 「未验证内容不进入已验证筛选」——已在 `craft_arena.s3.note`；
- 标题由系统词库生成（`词库A·词库B`），**不含自由文本**；标签为白名单结构化值。

### 6.3 严格 GDScript（craftarena 已开启，必守）

`game/project.godot` 把以下告警设为 **error（会阻断脚本加载）**：
`untyped_declaration` / `unsafe_property_access` / `unsafe_method_access` / `unsafe_cast` / `unsafe_call_argument` / `unsafe_void_return` 均为 `2`。

本项目首批脚本已按此修正，后续新增必须遵守：

- 局部变量、循环变量都要带类型：`for child: Node in node.get_children():`
- **Dictionary 取值返回 Variant**，先落成带类型的局部变量再参与运算/传参：
  ```gdscript
  var score_value: float = entry["score"]   # 先转成 float
  card.set("score", score_value)
  ```
  `int(entry["x"])` / `float(entry["x"])` / `PackedStringArray(entry["x"])` 这种
  **Variant 直接进构造函数会编译失败**。
- 不要用 `x as Script` 这种 **Variant 的 `as` 强转**（`unsafe_cast`），改用带类型声明接收：
  `var script: Script = node.get_script()`
- 跨脚本设属性用 `node.set("prop", value)`，避免 `unsafe_property_access`
- 用 `roundi()` / `clampi()` 等 typed 变体，不要 `int(round(x))`

---

## 7. 已知问题 / TODO

这些是**视觉与规格层面的欠账**，都不挡接线。接线本身的欠账在 [§2](#2-当前接线状态)。

- [ ] S3 未验证卡（`card_gear_maze` / `card_wind_tower`）的缩略图里残留 mockup 烘焙的角标像素，与场景内自绘 `Badge` 叠加。需要更精细的裁剪或无角标源图——**切图脚本没入库**（[§5](#5-切图资产)），所以这一项当前无法在本仓库修。
- [ ] S2 成功态赛道 chip 已接「已锁定 LOCKED」，但仍是白底，规格未定义锁定色。注意这句中文目前**硬编码在 `s2_matchmaking.gd` 里**，属 S2 文案迁移（第三批）的范围。
- [ ] 「等待加入…」空槽用实线 1px 边框代替虚线（`StyleBoxFlat` 不支持虚线）。
- [ ] S3 卡片 hover 顶缘 2px 强调条用渐变起始色近似，规格要求渐变。
- [ ] BASTION 卡禁用罩层用了 35% alpha，规格 token 是 60%（60% 数学上达不到 mockup 明度，需设计确认）。
- [ ] 未做屏幕：S4 账号、S5 我的内容（三子 tab）、S6 局内 HUD（含结算态），均无设计稿。
- [ ] `content_card.tscn` 的根节点没挂 `press_feedback.gd`（只有卡内的 Action 按钮挂了），所以整卡点击没有按压反馈。
- [ ] S1 / S2 文案未迁 `UiCopy`，见 [§0.3](#03-文案迁-uicopy-的真实口径)。

已解决的历史问题不再列在这里，查 git 历史即可（宪法第二十六条：本文件不当变更日志用）。

---

## 8. 验证基线

下表是**跑出来的**，不是抄设计稿的。复现命令见 [§0](#0-两个校验脚本已进-ci2026-09-13)；引擎一律通过 `GODOT4` 定位，不写死路径。

| 项 | 实测（2026-09-13） |
|---|---|
| Godot | 4.7.2 stable，所有者是 [CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md) |
| 主题 | 1003 行，59 个类型 / 53 个变种，15 项 stylebox + 10 项 font_size 检查全过 |
| S1 | 90 节点 / 33 变种 / 8 处反馈脚本，PASS |
| S2 | 167 节点 / 98 变种 / 15 处反馈脚本，PASS |
| S3 | 29 节点（运行时另加 8 张卡片）/ 12 变种 / 7 处反馈脚本，PASS |
| 未声明变种 | 三屏均为 0 |

本仓库**没有** `preview/` 目录——源项目那批评审图没有跟着落库。需要看图就用 [§4.1](#41-出预览图) 现出到仓库外的临时路径；不要往仓库里塞渲染产物。
