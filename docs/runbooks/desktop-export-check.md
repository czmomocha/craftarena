# 导出包核查清单

本文件是[纠偏方案 2026-08](../plans/course-correction-2026-08.md) C1 产出 2 的可执行版本，服务退出条件 **E1**。

它存在的理由是：项目前 7 天从未导出过包，所有关于「包里有什么」的说法都没有证据。[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) 把「`_mcp_game_helper` 进 Headless」标为「已缓解」——第一次真导出证明那条缓解**不成立**（见 §5）。

- 这是人工可复跑的清单，**不是** CI 门禁（宪法第二十四条）。
- 命令以本文件为准；README 命令表已同步同一批。
- 「真机」在本文件里指**导出的安装包**，不是编辑器里运行源码。

---

## 1. 前置：导出模板

导出模板必须与编辑器**同一精确版本**（[CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md)）。缺模板时 `--export-release` 会直接失败。

装法二选一：

- 编辑器 GUI：**Editor → Manage Export Templates → Download and Install**；
- 命令行（下面是 2026-08-26 在 Windows 开发机实际用的那条）：

```powershell
$tpz = "$env:TEMP\Godot_v4.7.2-stable_export_templates.tpz"
curl.exe -L --retry 3 -o $tpz "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
(Get-FileHash $tpz -Algorithm SHA512).Hash.ToLower()
```

预期 SHA512（与该 Release 的 `SHA512-SUMS.txt` 同一行）：

```text
ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
```

解压后把 `templates/` 里的内容放进 `%APPDATA%\Godot\export_templates\4.7.2.stable\`（macOS 为 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`）。装好应有 35 个文件，含 `version.txt`。

**校验和对不上就停下**，不要用来导出。

---

## 2. 导出三个预设

预设在 `game/export_presets.cfg`，由 `game/tests/unit/test_export_presets.gd` 守护。路径相对 `game/`，产物落在仓库根 `export/`（已 gitignore）。

| 预设 | 命令（仓库根，Windows） |
|---|---|
| Windows Desktop | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Windows Desktop" "../export/windows/CraftArena.exe"` |
| Linux Headless | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Linux Headless" "../export/linux-headless/craftarena-server.x86_64"` |
| Web | `& $env:GODOT4_CONSOLE --headless --path game --export-release "Web" "../export/web/index.html"` |

macOS 把 `& $env:GODOT4_CONSOLE` 换成 `"$GODOT4"`。

预期：三条都退出码 0。失败时先看日志里 `Cannot export project with preset ... due to configuration errors`，那句话之后引擎不一定列出具体项，见 §5 第 2 条。

---

## 3. 包内自检（一条命令，机器判定）

```powershell
& "export\windows\CraftArena.exe" --headless -- --package-check
```

打印一行 JSON，`ok=true` 时退出码 0，否则 1。`--` 之后的参数引擎不解释，由 `res://src/client/main.gd` 交给 `PackageCheck`。

| 检查项 | 含义 | 何时必须为真 |
|---|---|---|
| `courses_readable` | 三张官方赛道 JSON 能**解码成 AuthoringWorld**（不只是文件存在） | 始终 |
| `character_visual_loadable` | 角色视觉资产能**实例化成 Node3D**。`.glb` 进包后是导入产物 `.scn`，导出过滤配错或漏了 reimport 只在这里暴露；表现层遇到失败会静默回退占位盒，那在成品包里和"美术从来没加进去"长得一模一样 | 始终（2026-08-30 加入；**尚未在真导出包上跑过**，见下） |
| `terrain_tile_visual_loadable` | 地块视觉资产能实例化**并贴合到一格**。比角色多判贴合，因为地块的缩放是从自身 AABB 算的：退化或无网格的导入会先通过 load，再让整条路静默退回石色盒 | 始终（2026-08-30 加入；**尚未在真导出包上跑过**，见下） |
| `checkpoint_pad_visual_loadable` | 检查点垫能实例化并按地块规则贴合（顶面对齐） | 始终（2026-09-02 加入；尚未在真导出包上跑过） |
| `checkpoint_gate_visual_loadable` | 检查点门能实例化并按站立物规则贴合（脚底对齐） | 始终（同上） |
| `finish_gate_visual_loadable` | 终点门同上 | 始终（同上） |
| `crate_visual_loadable` | 箱子同上 | 始终（同上） |
| `hazard_roller_visual_loadable` | 滚柱同上 | 始终（同上） |
| `locale_table_loadable` | 本地化 CSV 能被 `UiCopy` 解析，且 `zh_CN` 离线横幅不是键名本身（CSV 与官方课 JSON 一样不是引擎资源，必须写进 `include_filter`） | 始终（2026-09-02 加入；尚未在真导出包上跑过） |
| `user_draft_roundtrip` | `user://` 可写可读可删，草稿恢复的落点成立 | 始终 |
| `no_mcp_autoload` | 没有 `_mcp_game_helper` autoload | 始终 |
| `runtime_material` | 运行时 `StandardMaterial3D` 能建、能设 albedo、能读回 | 始终 |
| `compatibility_renderer` | 渲染基线仍是 `gl_compatibility`（宪法第七条） | 始终 |
| `no_godot_ai_packed` | 包里没有 `res://addons/godot_ai/` | 仅导出包 |
| `no_addons_packed` | 包里没有任何 `res://addons/` | 仅导出包 |
| `tests_excluded` | 包里没有 `res://tests/` | 仅导出包 |

后三条在源码运行时必然为假（tests 与 addons 就在磁盘上），所以只在 `template_build=true` 时计入失败。

同时报告但不判定的字段：`web`（`OS.has_feature("web")`）、`packed_addons`、`user_data_dir`、`draft_path`、`engine`、`autoloads`、`character_visual_path`、`terrain_tile_visual_path`、`checkpoint_pad_visual_path`、`checkpoint_gate_visual_path`、`finish_gate_visual_path`、`crate_visual_path`、`hazard_roller_visual_path`、`locale_table_path`。

**关于 `.glb` 为什么不在 `include_filter` 里**：三个预设都是 `export_filter="all_resources"`，`.glb` 是 Godot **导入资源**，由它覆盖；`include_filter` 里那条 `content/official/*.json,content/locale/*.csv` 之所以必须显式写，是因为 JSON 与 CSV 都不是资源类型（CSV 还用 `importer="keep"`，避免默认翻译导入生成 `.translation`）。这条推断**还没有被真导出包验证过**（2026-08-30 写入时开发机没装 4.7.2 导出模板），所以下一次谁跑导出，请把 `character_visual_loadable`、`terrain_tile_visual_loadable`、五个占用 `*_visual_loadable` 与 `locale_table_loadable` 的结果补回本节。

Linux 包在 VPS 上用同一条：

```bash
./craftarena-server.x86_64 --headless -- --package-check
```

### 2026-08-26 Windows 包实测输出

> 这份输出早于 `character_visual_loadable`（2026-08-30 加入），所以 `checks` 里没有它。重跑时应多出那一项与 `character_visual_path`。

```json
{"ok":true,"failures":[],"template_build":true,"debug_build":false,"web":false,
 "packed_addons":[],"rendering_method":"gl_compatibility","autoloads":[],
 "checks":{"courses_readable":true,"user_draft_roundtrip":true,"no_mcp_autoload":true,
 "runtime_material":true,"compatibility_renderer":true,"no_godot_ai_packed":true,
 "no_addons_packed":true,"tests_excluded":true}}
```

`user_data_dir` = `C:/Users/<user>/AppData/Roaming/Godot/app_userdata/Craft Arena`，草稿落点 `.../authoring_draft.json`。**注意**：导出包与编辑器运行共用同一个 `user://`，因为 `application/config/name` 相同。要验「干净首次启动」的草稿恢复，先把该目录挪走。

---

## 4. 人工步骤（自检覆盖不到的部分）

自检是 Headless 的，看不见画面。以下必须人来做。

### 4.1 Windows 包开窗

1. 双击 `export\windows\CraftArena.exe`（不要加 `--headless`）。
2. 预期：出现标题 **Traprush** 的窗口，状态行含 `join=idle`、`play=idle`、`tls=off`、`course=3/5/1`。失败：闪退、黑窗、或只有控制台。
3. 点 **Solo play**，点窗口内部一次，按 WASD 与空格。预期：青色本席盒会动、会跳、会落回脚下石色盒。
4. 对照编辑器里 `& $env:GODOT4 --path game` 的同一画面。预期：**颜色与明暗一致**——这是 Compatibility 下运行时创建的 `StandardMaterial3D` 的目检项，自检只能证明它能建，不能证明它长得对。

### 4.2 Web 包本地起一次

Web 包不能用 `file://` 打开。仓库根：

```powershell
python -m http.server 8060 --directory export\web
```

浏览器开 `http://127.0.0.1:8060/`。预期：Godot 加载条走完后出现同一个大厅画面。

**已知边界**：当前 Web 预设 `variant/thread_support=false`（nothreads 构建），因此不需要服务端配 `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`。改成有线程版本时这两个响应头必须一起加，否则页面白屏。

联机与远端部署属 C1 第 2 章（`docs/runbooks/server-deploy.md`）。测试开发阶段走明文 `http`/`ws`，不把域名、Let's Encrypt 或 `wss://` 当作导出核查的前提。浏览器 HTTPS 页不能混用 `ws://`、也不接受自签证书——那是公开 Web 联机 / 正式运营前的事，不是本章。

---

## 5. 第一次真导出发现了什么

这一节是 C1 的主要产出：**「跑通了」不是结论，「哪些说法被证伪」才是。**

1. **`res://addons/godot_ai/` 会被打进 release 包。** 首次导出日志里出现 `savepack | 正在保存文件：res://addons/godot_ai/handlers/_property_errors.gdc` 等 8 行。CD-62 该条风险的「已缓解」此前从未经实证，**实际不成立**。
   - 更隐蔽的是：`plugin.cfg` 不是引擎资源，不会进包，所以「检查包里有没有 `plugin.cfg`」会报告干净——第一版自检就是这么误判的。现在改为按 `res://addons/` 目录列表判定。
   - 已修：三个预设 `exclude_filter` 加 `addons/*`；`test_export_presets.gd` 守住这条；自检 `no_godot_ai_packed` / `no_addons_packed` 在包里必须为真。
   - CD-62 状态需按 C5 重新定级。

2. **Web 预设会因为 VRAM 压缩项而拒绝导出。** 报错只有一句 `Cannot export project with preset "Web" due to configuration errors:`，**后面不列具体项**。原因是 `vram_texture_compression/for_desktop` / `for_mobile` 要求工程先开对应的导入设置。当前工程零纹理，两项都设为 false。C4 引入 `.glb` 与纹理时必须与 `rendering/textures/vram_compression/import_*` 一起打开。

3. **官方赛道 JSON 与本地化 CSV 都不是引擎资源，默认不进包。** 三个预设都要 `include_filter="content/official/*.json,content/locale/*.csv"`。自检里的 `courses_readable` / `locale_table_loadable` 做的是解码而不是 `file_exists`，因为存在「文件在包里但引擎读不出来」的情况。CSV 不得走 Godot 默认翻译导入：那会生成 `.translation`，Headless 与导出包对不上同一套 remap。

4. **GUT 会静默跳过解析失败的测试脚本。** 本章两个新测试文件因类型警告解析失败时，GUT 打一行 `[GUT WARNING] Ignoring script ...` 然后照常输出 `All tests passed!`，脚本数从 95 没变。**只看 GUT 绿不足以证明测试跑了**；拦住它的是 CI 里对 `game/tests` 的逐文件 `--check-only`。本地跑 GUT 时请顺带核对 Scripts 数。

5. **4 个 `.gd` 缺 `.uid` 伴随文件**，导出时引擎打 `Missing .uid file ... re-created from cache` 警告。已补入库。

---

## 6. 2026-08-26 包体基线

用于 [CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)「网页/微信包体超限」重新定级，以及下次审视趋势对比。当前工程 **0 个 `.glb` / 0 张纹理**，所以这几乎是纯引擎运行时的地板值。

| 产物 | 大小 |
|---|---|
| Windows `CraftArena.exe` | 104.53 MB |
| Windows `CraftArena.pck` | 0.46 MB |
| Linux Headless（exe + pck） | 70.57 MB |
| Web 合计（9 个文件） | 38.46 MB |
| └ `index.wasm` 原始 | 37.68 MB |
| └ `index.wasm` gzip | 9.68 MB |
| └ `index.wasm` brotli | 6.77 MB |
| └ `index.pck` | 0.46 MB |

读法：Web 首屏下载量取决于服务端压缩，brotli 下约 **7.3 MB**（wasm + pck）。这是**还没有任何美术资源**时的数字。[CD-11 §6](../../Confirmed-docs/10-product/11-scope-and-platforms.md) 平台矩阵里的「微信小游戏，一期后跟进」需要正视这个地板：微信小游戏主包 4 MB 的限制，仅引擎 wasm 就已超出，必须靠分包或引擎裁剪，不是「导出一下」的事。
