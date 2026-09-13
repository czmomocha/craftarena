# 字体子集工具

把 Noto Sans SC（SIL OFL 1.1）切成项目要用的那部分，改名，写进 `game/content/ui/fonts/`。

**这个工具不进 CI。** 它需要 Python 3 与 fontTools，CI 里没有，也不打算装——往 CI 加依赖属宪法第十八条的人类门禁。CI 只验证**已经生成好的那份字体文件**（`game/tests/unit/test_font_packaging.gd`：覆盖、改名、体积）。本工具是"怎么把它重新生成出来"的记录。

## 1. 为什么是子集

完整 Noto Sans SC 单字重约 8 MB。Windows 安装包还好，Web 包会直接撞上 [CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) 已登记的「网页包体超限」风险，而 Web 游玩分发第一刀已经交了。人类拍板的范围是**常用 3500 字**，切完约 800 KB。

## 2. 子集范围

三层的并集，顺序不代表优先级：

| 层 | 来源 | 落点 |
|---|---|---|
| 常用 3500 字 | 《现代汉语常用字表》语料库在线版，经 [jinghu-moon/Simplified-Chinese-Characters](https://github.com/jinghu-moon/Simplified-Chinese-Characters)（MIT）转录 | `game/content/ui/fonts/charsets/common_3500.txt` |
| 项目补集 | 扫 `game/src/`、`game/content/locale/`、`game/content/official/` 里 `.gd` / `.tscn` / `.tres` / `.csv` / `.json` 的全部非 ASCII 字符 | `game/content/ui/fonts/charsets/project_supplement.txt` |
| 兜底 | 可打印 ASCII（U+0020–U+007E）+ 常用符号（× ÷ ° … — 「」《》等） | 写在 `build_font_subset.py` 里 |

字表文件与字体同处 `content/ui/fonts/charsets/`，**不在本工具目录**：它是"这个子集包含什么"的规格，属于内容而不是工具，而且必须能被 `res://` 读到，GUT 才能拿它做覆盖断言。

### 2.1 两张 3500 字表

上游仓库同时给了两版，都是 3500 个汉字，收字略有差异：

- **语料库在线版**（本刀采用）：笔画序，开头是「一乙二十丁厂七卜八人入儿匕几九刁了刀力乃又三干于亏工土士」，与《现代汉语常用字表》一致；
- **邢红兵版**：按语料频率排序，开头是「一丁七万丈三上下不与丐丑专且世丘丙业丛东丝丢两严丧个中丰」。

选前者，因为"常用 3500 字"作为标准名词指的就是《现代汉语常用字表》。**两版都不完整覆盖项目 UI 文案**，差的那部分由第 2 层补集兜住——所以换另一版也不会缺字，代价只是文件里多几十个字形。

### 2.2 补集为什么按全量扫，而不是人工挑

人工挑会漏，而且漏了不会有任何报错：字体回退会画出一个看起来差不多的字。全量扫多带进来的是注释里的字，代价只有几十 KB。

**但这不是一个被门禁保住的性质。** 这个脚本不进 CI（见第 5 节），GUT 断言的是"字体覆盖了**已入库的**补集"，没有任何东西断言"补集是新的"。所以改一句文案之后仍然可能悄悄缺字——挡住它的是第 4 节那个**人工**重跑步骤，不是流水线。要把这条链闭上，得用 GDScript 在 GUT 里重做一遍扫描（不需要 Python），那是另一刀，需要人类拍板。

## 3. 为什么改名

SIL OFL 1.1 有保留字体名（RFN）约束。上游文件声明了两个 RFN：Google 的 **"Noto Sans SC"** 与 Adobe 的 **"Source"**（思源黑体那一脉）。子集是修改产物，**不得沿用**；所以输出改名为 `CraftArena Sans SC`。

改名只动 name 表里的**命名项**（ID 1/2/3/4/6/16/17）。ID 0（版权）与 13/14（许可全文与 URL）**必须保留**——OFL 反过来要求这些跟着走。ID 7（商标声明）删掉：它不是版权声明，留着只会让"这字体改没改过"变模糊。

`--check` 与 GUT 都断言保留名没有残留。这不是洁癖，是许可证义务。

## 4. 怎么重跑

改了文案、加了按钮、或者上游字体更新之后：

```bash
python3 tools/font-subset/collect_project_chars.py     # 重写补集
python3 tools/font-subset/build_font_subset.py         # 下载源字体 → 子集 → 改名 → 落盘
python3 tools/font-subset/build_font_subset.py --check # 校验改名与体积预算

"$GODOT4" --headless --path game --import              # 字体是导入资源，必须重跑导入
npm run test:gut:fast                                  # 覆盖断言
```

只想知道补集是不是过期了（比如 CI 里不想跑 Python）：

```bash
python3 tools/font-subset/collect_project_chars.py --check
```

## 5. 源字体不入库

上游 8 MB 的 `NotoSansSC-Regular.otf` 落在 `tools/font-subset/.cache/`（已 gitignore）。脚本按 URL + SHA-256 取，校验不过就**报错退出**，不会静默换个新文件——上游挪动文件时，正确反应是人类确认后更新 `SOURCE_SHA256`，不是照单全收。

## 6. 已知边界

- **🔒 没有字形。** 上游 Noto Sans SC 不含 emoji，S1 大厅那把锁仍走引擎系统回退。这是"子集没买 emoji"的直接后果，不是待修缺陷。要它就得换一份含 emoji 的字体，那是一次新的许可证确认。
- **只有 Regular 一个字重。** 产品 UI 的标题（56 / 96 px）目前靠字号分层，没有粗体。加字重约 +800 KB 一份，需要人类拍板。
- **繁体不在范围内。** 一期 locale 是 `zh_CN` + `en`；`zh*` 一律归一到 `zh_CN`。
