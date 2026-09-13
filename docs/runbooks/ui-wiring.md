# Craft Arena UI 基础包 · 接线说明

> **状态（2026-09-12）：资产已落库，运行时尚未接线，且本文件部分内容已失真。**
>
> - **排期已定，见 [CD-61 §2 M-Art](../../Confirmed-docs/60-plan/61-milestones.md#m-art表现与美术)**（所有者）。三批：S3 广场（M5 退出后）→ S1 主大厅（M6 主大厅壳章内）→ S2 / S4 / S5 / S6。**M5 C6 期间不得接任何一屏。**
> - 第一批四项前置：**字体入包 ✅ 已于 2026-09-13 交**（[CD-11 §8.2 第 3 条](../../Confirmed-docs/10-product/11-scope-and-platforms.md)，见 [§3.5](#35-字体已完成2026-09-13)）；文案迁 `UiCopy`（三个场景现有 106 处硬编码中文，零处走键）；`validate_theme.gd` / `validate_scene.gd` 进 CI；本文件按仓库实际落点重写。
> - **下面第 1–5 节仍是源项目 `testUI` 的视角**：`F:\study\craftarena` 路径、`godot/scenes/...` 目录、`C:\Tools\Godot_v4.7.2-stable_win64_console.exe` 命令都与本仓库实际不符。实际落点是 `game/src/client/ui/scenes/`、`game/src/client/ui/scripts/`、`game/content/ui/`；命令以 [README.md](../../README.md) 为准。重写排在第一批接线那一刀（宪法第十九条）。
> - 第 6 节（关键实现约定）与 7.2 文案语义锁定**现在就有效**，不受上述失真影响。

---

> 本项目（`testUI`）是 **纯 UI 项目**，产出将合入 UGC 游戏项目 **Craft Arena**（`F:\study\craftarena`），作为游戏 UI 基础。
> 本文档描述交付物、接入步骤、维护流程与已知问题。

---

## 1. 交付物概览

```
testUI/
├── UI_WIRING.md                    本文档
├── craft_arena_ui_spec.md          设计规格（唯一事实来源，六屏）
├── design/
│   └── tokens.json                 设计 Token（色板/字号/圆角/尺寸），主题生成的输入
├── slice_config.json               切图配置（实测源图坐标）
├── preview/                        渲染预览图（评审用，可不入库）
├── tools/                          Python 工具链
│   ├── build_theme.py              tokens.json → craft_arena.tres
│   ├── slice_assets.py             按 slice_config.json 切图
│   ├── find_regions.py             按颜色定位元素，量取坐标
│   └── preview_assets.py           切图结果对比图
└── godot/                          ★ 需要合入的部分
    ├── project.godot               最小宿主工程（仅用于验证）
    ├── theme/craft_arena.tres      主题（53 个类型变种）
    ├── scenes/                     屏幕场景 + components/ 可复用组件
    ├── scripts/                    场景脚本与通用组件
    ├── shaders/                    渐变 / 圆角 / 羽化
    ├── assets/ui/                  切图资产
    └── tools/                      无头校验与截图脚本
```

**合入时只搬 `godot/` 下的内容**（`project.godot` 除外，见下节）。根目录的 `tools/`、`design/`、`slice_config.json` 是设计资产管线，建议一并放入独立工具目录，便于后续改样式。

---

## 2. 目标工程结构（craftarena）

Craft Arena 的 Godot 工程根是 `game/`：

```
F:\study\craftarena\game\
├── project.godot
├── addons/
├── content/          美术与内容资产
├── src/
│   ├── client/
│   ├── creator/
│   ├── games/
│   ├── server/
│   ├── shared/
│   ├── simulation/
│   └── ugc/
└── tests/
```

建议合入位置：

| 本项目 | 目标位置 | 说明 |
|---|---|---|
| `godot/theme/craft_arena.tres` | `game/content/ui/theme/craft_arena.tres` | 全局主题 |
| `godot/scenes/*.tscn` | `game/src/client/ui/screens/` | 屏幕场景 |
| `godot/scenes/components/*.tscn` | `game/src/client/ui/components/` | 可复用组件 |
| `godot/scripts/*.gd` | `game/src/client/ui/scripts/` | 组件脚本 |
| `godot/shaders/*.gdshader` | `game/content/ui/shaders/` | UI shader |
| `godot/assets/ui/*.png` | `game/content/ui/assets/` | 切图资产 |
| `design/tokens.json` + `tools/` | `game/tools/ui/` | 设计管线（可选） |

> 路径按团队规范可调整，**关键是保持 `theme/`、`scenes/`、`scripts/` 三者相对关系与 shader 引用路径一致**（场景内用 `res://` 绝对路径引用 shader 与脚本，移动后需全局替换）。

---

## 3. 接入步骤

> **接线已执行完毕**（2026-09-11）。使用 `tools/wire_into.py`，它负责拷贝文件并重映射 `res://` 前缀。
> 重跑即可同步最新改动：`python tools/wire_into.py`（加 `--dry-run` 先预览）。
> **不要手改 craftarena 里的 UI 文件**——下次重跑会被覆盖；改动应回到本项目，再重跑脚本同步。
>
> 接线后必须重跑一次 `godot --headless --path <game> --import`（见 5.1）。

### 3.1 主题挂载策略：随场景走，不设全局

**当前刻意没有**设置 `gui/theme/custom`。原因：craftarena 已有 `match_lobby_*`、
`content_plaza_entry` 等自绘 UI，挂全局主题会立刻改写它们的外观。

每个屏幕场景的根 Control 已自带 `theme = craft_arena.tres`，主题随场景生效，
**接入一个屏只影响那一屏**。等旧 UI 全部迁移完，再统一挂全局主题即可：

```ini
[gui]
theme/custom="res://content/ui/theme/craft_arena.tres"
```

### 3.2 接入屏幕场景

每个屏幕是独立的 `Control` 场景，根节点即入口：

| 屏 | 场景 | 状态 |
|---|---|---|
| S1 主大厅 | `scenes/s1_lobby.tscn` | 完成 |
| S2 TRAPRUSH 匹配 | `scenes/s2_matchmaking.tscn` | 完成（两态） |
| S3 公共内容广场 | `scenes/s3_workshop.tscn` | 完成 |
| S4 账号 | — | 未开始 |
| S5 我的内容 | — | 未开始 |
| S6 局内 HUD | — | 未开始 |

接入方式：

```gdscript
var screen := preload("res://src/client/ui/screens/s1_lobby.tscn").instantiate()
add_child(screen)
```

### 3.3 屏幕状态切换

S2 通过根节点导出属性切换，供业务侧驱动：

```gdscript
var s2 := preload(".../s2_matchmaking.tscn").instantiate()
add_child(s2)
s2.state = s2.State.MATCH_FOUND   # WAITING(0) / MATCH_FOUND(1)
s2.player_count = 4               # 1-8
s2.solo_mode = false              # true 时顶部显示 SOLO 橙色横幅
```

S3 的内容卡是**数据驱动**，业务侧不应改场景树，而是注入数据（结构见 `scripts/s3_workshop.gd` 的 `ENTRIES` 数组）。

### 3.4 窗口与缩放

本包按 1920×1080 设计基准制作，建议目标工程采用：

```ini
[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

### 3.5 字体（★ **已完成**，2026-09-13）

主题**此前**没有内置字体，中文全靠引擎回退字体渲染。现在：

- 入包文件：`game/content/ui/fonts/craftarena_sans_sc_regular.otf`（Noto Sans SC 常用 3500 字子集，SIL OFL 1.1，约 800 KB）。按 OFL 的保留字体名约束改了名，**不要再去找 "Noto Sans SC"**。
- 主题的 `default_font` 已指向它（`craft_arena.tres` 的 `[resource]` 第一行）。各类型变种只设 `font_sizes/font_size`，字体继承 `default_font`，不需要逐个写 `fonts/font`。
- 全局兜底 `gui/theme/custom_font` 指向同一份，让不挂 theme 的自绘大厅 / HUD / `Label3D` 也用上它。路径唯一所有者是 `game/src/shared/ui_font.gd`。
- 字表随字体入库在 `game/content/ui/fonts/charsets/`（`common_3500.txt` + `project_supplement.txt`）。改了文案或加了按钮，先跑 `python3 tools/font-subset/collect_project_chars.py` 重写补集，再跑 `build_font_subset.py`，然后 `"$GODOT4" --headless --path game --import`。重跑步骤与已知边界（只有一个字重、emoji 不在子集内）见 `tools/font-subset/README.md`。
- GUT `test_font_packaging.gd` 断言本地化表与两张字表**零缺字**；改文案导致缺字会直接红。

本节不再依赖源项目的 `design/tokens.json` / `build_theme.py`——那套管线没有入库。

---

## 4. 样式维护流程

**改样式 = 改 `design/tokens.json` → 重跑脚本 → 重新校验**，不要手改 `.tres`。

```bash
# 1. 改 design/tokens.json（变种定义在 build_theme.py）
python tools/build_theme.py        # 产出 godot/theme/craft_arena.tres

# 2. 无头校验主题与场景
Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
    --script res://tools/validate_theme.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
    --script res://tools/validate_scene.gd -- res://scenes/s1_lobby.tscn res://scenes/s2_matchmaking.tscn res://scenes/s3_workshop.tscn

# 3. 出预览图
Godot_v4.7.2-stable_win64_console.exe --path godot --rendering-driver opengl3 \
    --resolution 1920x1080 --script res://tools/screenshot.gd -- \
    res://scenes/s1_lobby.tscn - res://../preview/s1_lobby.png
```

`validate_scene.gd` 检查：场景可加载、所有 `theme_type_variation` 已在主题中声明、`press_feedback.gd` 只挂在 BaseButton 上。**建议接入 CI**，任何主题/场景改动都跑一遍。

### 4.1 新增主题变种

变种定义集中在 `tools/build_theme.py` 的 `build()` 里（按屏幕分段注释）。新增步骤：在对应分段加 `b.variation(...)` + `b.set(...)` → 重跑脚本。命名遵循 `<控件><语义>`（如 `TrackRowSelected`、`ButtonOnGradient`）。

---

## 5. 资产（切图）管线

源 mockup 是 **AI 生成概念稿**，几何与规格数值不符，因此切图坐标必须实测，不能从 `craft_arena_ui_spec.md` 推算。

```bash
# 定位元素（量坐标）
python tools/find_regions.py <mockup.png> --saturated 55 --min-area 4000 --box x0 y0 x1 y1
python tools/find_regions.py <mockup.png> --palette 20            # 看实际渲染色

# 写进 slice_config.json 后切图
python tools/slice_assets.py --only S3_workshop

# 目视检查
python tools/preview_assets.py
```

**规则：**
- 只切 **插画 / 缩略图 / 图标**；纯色面板、按钮、卡片一律用 Theme 代码化
- **文字绝对不能切图**（无法本地化、无法缩放）
- `keyOut` 用于深色底上的图标抠透明
- `specZones` 标注画板上的标注条，切图越界会告警

### 5.1 重要：切图后必须重跑 Godot 导入

`slice_assets.py` 只改写 `assets/ui/*.png`，**Godot 读的是 `.godot/imported/` 里的导入产物**。
切图后如果直接渲染/运行，看到的仍是旧纹理。必须先执行：

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import
```

再渲染或运行。这条排在"改了图却没变化"类问题的第一位排查项。

---

## 6. 关键实现约定

| 约定 | 原因 |
|---|---|
| 渐变用 `shaders/rounded_gradient.gdshader` | `StyleBoxFlat` 只支持纯色 |
| 贴图圆角用 `shaders/rounded_texture.gdshader` | `TextureRect` 无圆角属性 |
| 两个 shader 的 `rect_size` 由 `scripts/rounded_gradient.gd` 同步 | 否则圆角/渐变在尺寸变化时错位 |
| 按钮按压反馈用 `scripts/press_feedback.gd` | 主题只换样式盒，缩放/亮度需代码 |
| 插画接缝用 `shaders/feather_left.gdshader` | 切片自带烘焙渐变，与卡片渐变不匹配 |
| 可点击卡片需显式同步 `custom_minimum_size` | **Button 不是 Container，不向子节点取最小尺寸**（见 6.1） |
| 文案语义锁定 | 见 6.2 |

### 6.1 重要：Button 不传播子节点最小尺寸

`Button`/`Panel` 这类非 Container 节点做"可点击卡片"时，其 `custom_minimum_size` **不会**包含子节点。`content_card.gd` 的 `_sync_minimum_size()` 显式镜像了内容高度。新增同类组件时必须复制这一处理，否则卡片会塌缩、内容向外溢出。

注意：只镜像**高度**，宽度必须交给 `GridContainer` 列宽，否则卡片会宽于列导致横向溢出；同时卡片根节点需要 `size_flags_horizontal = 3` 才能让列拉伸铺满。

### 6.2 文案语义锁定（规格约束，不得改写）

- 「离线试玩，成绩不上传 SOLO · RESULTS NOT UPLOADED」
- 「本局名次不进入任何天梯或长期排行」
- 「版本不可覆盖：每次发布生成新版本 · 可随时回滚到上一签名版本」
- 「未验证内容不进入已验证筛选」
- 标题由系统词库生成（`词库A·词库B`），**不含自由文本**；标签为白名单结构化值

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

- [x] ~~S3 内容卡标题显示两次~~ **已解决**（2026-09-11）。根因有两层：
  1. 切图高度按 16:9 推算（291px），实际 mockup 缩略图是 `517×203`，多出的部分把 mockup 里烘焙的标题一起切进了图里；
  2. 重新切图后**没有重跑 Godot 导入**，渲染用的仍是 `.godot/imported/` 里的旧纹理，导致"改了 PNG 不生效"的假象。
  修正：`slice_config.json` 改为实测 `517×203`，`content_card.tscn` 的 `ThumbWrap` 高度改为 153 以匹配 2.55:1 素材。
- [ ] S3 未验证卡（齿轮迷城 / 风蚀高塔）的缩略图里仍残留 mockup 烘焙的角标像素，与场景内自绘 `Badge` 叠加。需更精细的裁剪或改用无角标源图。
- [ ] S2 成功态赛道 chip 文案已接「已锁定 LOCKED」，但仍是白底，规格未定义锁定色。
- [ ] 「等待加入…」空槽用实线 1px 边框代替虚线（`StyleBoxFlat` 不支持虚线）。
- [ ] S3 卡片 hover 顶缘 2px 强调条用渐变起始色近似，规格要求渐变。
- [ ] BASTION 卡禁用罩层用了 35% alpha，规格 token 是 60%（60% 数学上无法达到 mockup 明度，需设计确认）。
- [ ] 未做屏幕：S4 账号、S5 我的内容（三子 tab）、S6 局内 HUD（含结算态）。
- [ ] 交互状态仅 S1/S2 接入，S3 卡片 hover 样式已有但未挂 `press_feedback.gd`。

---

## 8. 验证基线

| 项 | 结果 |
|---|---|
| Godot 版本 | 4.7.2 stable（`C:\Tools\Godot_v4.7.2-stable_win64_console.exe`） |
| 主题 | 1000 行 / 53 类型变种，`validate_theme.gd` PASS |
| S1 | 90 节点 / 33 变种 / 8 处反馈脚本，PASS |
| S2 | 167 节点 / 98 变种 / 15 处反馈脚本，PASS |
| S3 | 29 节点（+8 运行时实例化卡片）/ 12 变种，PASS |
| 渲染 | 1920×1080，OpenGL 3.3 |

预览图见 `preview/`。
