# Godot AI 接入烟测

本文件是 [CD-51 §7](../../Confirmed-docs/50-engineering/51-dev-environment.md) 的可执行版本：在开发机上安装唯一主 MCP（Godot AI）、**先关匿名遥测**、接上 Cursor，并按 [ADR-0003](../adr/0003-godot-mcp-selection.md) 的清单做一次人工核实。

它不是 [环境烟测清单](environment-smoke-test.md) 的替代。M0 那十步仍然用命令行证明 Headless / CI 闭环；本清单证明的是「打开的编辑器 + Cursor」这条加速器。两条闭环必须同时成立，MCP 才能当加速器而不是单点。

- 适用范围：Windows 与 macOS 开发机。Linux CI **不**跑本清单。
- 预计耗时：30～45 分钟（含第一次 `uvx` 拉包）。
- 前置：已按 CD-51 §4 / §4.1 装好 Godot 4.7.2-stable Standard、Cursor，且环境烟测十步在该机器上已经签过字。
- 精确版本以 CD-51 §1 为准，本文件不另写一套数字。

> 全程在仓库根目录执行。Windows 用 PowerShell，macOS 用 bash/zsh。
> 签字表在第 10 步。未在对应机器上新增通过行之前，不得把「本机 MCP 已可用」写进任务单。

---

## 第 0 步：先关遥测，再装插件

Godot AI 的匿名遥测**默认开启**。第一次带插件启动编辑器就会尝试向外发 `startup` 事件。因此环境变量必须在启用插件之前生效，且要重启已经打开的 Cursor / Godot，否则它们继承的是旧环境。

本项目只使用专用变量 `GODOT_AI_DISABLE_TELEMETRY`，不用跨工具的 `DISABLE_TELEMETRY`（后者可能误伤别的 CLI）。

**Windows**（用户级，新开的终端和从开始菜单启动的 Godot 都能读到）：

```powershell
[Environment]::SetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "true", "User")
```

关掉本窗口，**再开一个** PowerShell，确认：

```powershell
[Environment]::GetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "User")
```

预期输出：`true`。

**macOS**（写入你实际在用的 shell 配置文件）：

```bash
echo 'export GODOT_AI_DISABLE_TELEMETRY=true' >> ~/.zshrc
source ~/.zshrc
printf '%s\n' "$GODOT_AI_DISABLE_TELEMETRY"
```

预期输出：`true`。若默认 shell 是 bash，改写 `~/.bashrc`。

然后完全退出 Cursor 与 Godot 再打开，避免子进程拿不到新变量。

---

## 第 1 步：安装 uv

Python MCP 服务由 [uv](https://docs.astral.sh/uv/) 按锁定的 `godot-ai==<CD-51 版本>` 拉起，不必单独装一套系统 Python。

**Windows**

```powershell
winget install --id astral-sh.uv -e
```

若 `winget` 不可用，再用上游脚本（会改用户 PATH）：

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

新开终端后：

```powershell
uv --version
uvx --version
```

预期：两条都打印版本号，无「找不到命令」。

**macOS**

```bash
brew install uv
uv --version
uvx --version
```

没有 Homebrew 时用 `curl -LsSf https://astral.sh/uv/install.sh | sh`，然后新开终端再查版本。

---

## 第 2 步：安装锁定版本的编辑器插件

不要从 Asset Library 点「最新」——渠道落后于 GitHub Release。按 CD-51 §1 的 tag 下载官方 `godot-ai-plugin.zip`，校验 sha256 后再解压到 `game/addons/godot_ai/`。该目录已在 `.gitignore`，**不要 git add**。

**Windows**（把 `VERSION` 换成 CD-51 §1 当前锁定的版本号，例如 `3.1.5`）：

```powershell
$version = "3.1.5"
$zip = Join-Path $env:TEMP "godot-ai-plugin-$version.zip"
Invoke-WebRequest -Uri "https://github.com/hi-godot/godot-ai/releases/download/v$version/godot-ai-plugin.zip" -OutFile $zip
Get-FileHash $zip -Algorithm SHA256
```

把打印出的 Hash 与 [该 Release 的 `godot-ai-plugin.zip.sha256`](https://github.com/hi-godot/godot-ai/releases) 对照，不一致就停。v3.1.5 的官方摘要是：

```text
20ab1053fb538b4adc00e9bfdb780d119014fd2a60c948f0c594341da1f1032b
```

版本升级时以新 Release 的 sha256 文件为准，并先改 CD-51 §1。

```powershell
New-Item -ItemType Directory -Force -Path game\addons | Out-Null
Expand-Archive -Path $zip -DestinationPath $env:TEMP\godot-ai-plugin-unpack -Force
# zip 内是 addons/godot_ai/；只把这一层拷进工程
Copy-Item -Recurse -Force $env:TEMP\godot-ai-plugin-unpack\addons\godot_ai game\addons\godot_ai
Get-Content game\addons\godot_ai\plugin.cfg | Select-String "version="
```

预期：`version="3.1.5"`（或 CD-51 当时锁定的值）。目录里应有 `plugin.gd`，没有 `.cs` / `.csproj`。

**macOS**

```bash
VERSION=3.1.5
ZIP=/tmp/godot-ai-plugin-${VERSION}.zip
curl -L "https://github.com/hi-godot/godot-ai/releases/download/v${VERSION}/godot-ai-plugin.zip" -o "$ZIP"
shasum -a 256 "$ZIP"
```

同样先对完 sha256，再：

```bash
mkdir -p /tmp/godot-ai-plugin-unpack
unzip -o "$ZIP" -d /tmp/godot-ai-plugin-unpack
mkdir -p game/addons
rm -rf game/addons/godot_ai
cp -R /tmp/godot-ai-plugin-unpack/addons/godot_ai game/addons/godot_ai
grep '^version=' game/addons/godot_ai/plugin.cfg
```

---

## 第 3 步：启用插件，并在 Dock 里再关一次遥测

**Windows**

```powershell
& $env:GODOT4 --editor --path game
```

**macOS**

```bash
"$GODOT4" --editor --path game
```

人工操作：

1. 打开工程后确认 **项目 > 项目设置 > 插件** 里 **Godot AI** 已启用。Authoring Editor 会在检测到 `game/addons/godot_ai/` 时自动启用，一般不必再勾。若提示要重启编辑器，重启后再确认 Dock 出现 **Godot AI**。
2. 点 Dock 上的 **Clients & Tools**（弹出窗口，不是主面板本身）：
   - **Tools** 页底部 **Telemetry** 关掉，再点 **Apply and Restart Server**；
   - **Settings** 页确认 **Vision Routing** 未启用（该项默认关，不会出现在主 Dock 上）；
   - 同一页里 **Remote access (advanced)** 保持折叠且 CIDR 为空（不要 `--allow-host`）。
3. 主 Dock 显示 **Server connected** 即可。Python 服务默认只绑本机 `127.0.0.1`（HTTP 8000 / WS 9500）。
4. 不要打开 **Developer mode** 来找 Vision Routing；主面板本来就不会列出它。

启用插件几乎一定会改 `game/project.godot`：加上 `res://addons/godot_ai/plugin.cfg`，并可能写入 `_mcp_game_helper` autoload。这是编辑器本地状态，**不要提交**。烟测结束后见第 9 步。

---

## 第 4 步：给 Cursor 写 attach 配置

仍在 Godot AI Dock：

1. 找到 **Cursor** 那一行，先点 **Configure**。
2. 因为第 3 步刚关了遥测，再点一次 **Configure**，让生成的 `godot-ai attach` 带上 `--disable-telemetry`。旧配置在开关变化后会显示 `configured_mismatch`。
3. **完全退出并重启 Cursor**，让 MCP 子进程用新参数启动。
4. 在 Cursor 的 MCP 面板确认 `godot-ai` 已连接。不要手改成 URL 模式，也不要把本机 `uvx` 绝对路径提交进仓库。

Windows 上 Dock 可能生成 `pythonw.exe` 包装而不是直接的 `uvx.exe`，这是上游为避免弹出控制台窗口的做法，不要简化回去。

---

## 第 5 步：功能清单（ADR-0003 第 1～3、8 条）

编辑器保持打开。在 Cursor 里让 Agent（或人手）依次做下面几件，用**临时**场景，不要改 `res://src/client/main.tscn`。

1. 读取当前场景层次（`scene_get_hierarchy` 或资源 `godot://scene/hierarchy`）。
2. 新建临时场景（例如 `res://src/client/_mcp_smoke.tscn`），在其下创建一个节点，改名，再在编辑器里 **Ctrl+Z** 逐步撤销到创建前。撤销必须走编辑器撤销栈，而不是「再发一条 MCP 把节点删掉」。
3. 保存后看 git diff：临时 `.tscn` 应可读；`project.godot` 若出现插件 / autoload 行，记下它们，第 9 步丢掉。
4. `project_run` 跑主场景或当前临时场景，再用 `logs_read` 看到启动日志或报错。
5. 故意写一个缺静态类型的临时脚本（或去掉 `: int`），确认能读到 `Warning treated as error` 一类信息，且带文件与行号。修回或删除该脚本。

遥测核实（第 8 条），编辑器仍开着、服务已因 Telemetry=关重启过一次：

**Windows**

```powershell
Test-Path (Join-Path $env:APPDATA "godot-ai\customer_uuid.txt")
```

**macOS**

```bash
test -f "$HOME/Library/Application Support/godot-ai/customer_uuid.txt" && echo exists || echo absent
```

预期：`False` / `absent`。若文件还在，说明服务启动时没吃到 opt-out：检查用户环境变量、Dock 勾选、Cursor attach 是否含 `--disable-telemetry`，然后 Apply & Restart Server 再查一次。

---

## 第 6 步：Headless 退路仍在（ADR-0003 第 4 条）

**不要关**「MCP 已连上」就当作 CI 也连上了。另开终端，**不依赖编辑器**，按环境烟测第 5、6 步跑：

**Windows**

```powershell
& $env:GODOT4_CONSOLE --headless --path game --quit
& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
echo "exit code: $LASTEXITCODE"
```

**macOS**

```bash
"$GODOT4" --headless --path game --quit
"$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
echo "exit code: $?"
```

预期：主场景 JSON 启动日志仍在；GUT 全绿。这证明 MCP 只是加速器。

---

## 第 7 步：安全边界（ADR-0003 第 5、10 条）

人工确认并勾选：

- [x] 插件目录无 `.cs` / `.csproj`（2026-08-21 Windows 与 macOS 接入烟测已核对）
- [x] MCP HTTP/WS 只听 `127.0.0.1:8000` / `9500`，未开 `--allow-host`（两台机器均已核对端口）
- [x] **Clients & Tools → Settings**：Vision Routing 保持关（主 Dock 上看不到此项，属正常；Windows 2026-08-21 人类确认；macOS 第 3 步已在 Settings 页确认，EditorSettings 无 `vision_routing/*` 键即默认关）
- [x] 没有同时启用第二套 Godot MCP（Windows 同日人类确认；macOS：Cursor 用户级 `mcp.json` 与当前会话 MCP 目录仅 `godot-ai`）
- [x] 没有把 `editor_manage(op="game_eval")` 写进任务习惯或脚本
- [x] 没有用 `test_run` / `McpTestSuite` 替代 GUT

---

## 第 8 步：删临时内容

删掉第 5 步的 `_mcp_smoke.tscn`、配套脚本和 `.uid`。不要用「再让 MCP 生成一份干净工程」的方式掩盖 diff。

---

## 第 9 步：丢掉 `project.godot` 上的 MCP 脏写入

```bash
git diff -- game/project.godot
```

若出现 `res://addons/godot_ai/plugin.cfg` 或 `_mcp_game_helper`，恢复已提交副本：

```bash
git checkout -- game/project.godot
```

本机编辑器下次打开可能提示插件未启用：那是预期。日常用 MCP 时再在本机启用即可，**仍然不要提交这两处**。Headless MatchServer 跑的是源码工程；autoload 一旦进 Git，就会进权威进程。

确认插件目录未入库：

```bash
git status --short
```

预期：没有 `game/addons/godot_ai/`。若出现，先检查 `.gitignore` 是否包含该路径。

---

## 第 10 步：记录结果

| 日期 | 执行人 | 机器 / 系统 | 插件版本 | 遥测 | UndoRedo | 运行与错误 | Headless 退路 | project.godot 已恢复 | 结果 |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-21 | 人类（安装 / Configure / Ctrl+Z）+ AI Agent（第 5–6、8–9 步） | Windows 10.0.26100 | 3.1.5 | 通过：`GODOT_AI_DISABLE_TELEMETRY=true`，无 `%APPDATA%\godot-ai\`，Cursor attach 含 `--disable-telemetry` | 通过：MCP 创建并重命名 `Marker3D`（`undoable: true`），人类 Ctrl+Z 两次后层次只剩根节点 `McpSmoke` | 通过：`project_run` 主场景 `game_status=live`，日志含 `client_boot` / `gl_compatibility`；无类型脚本诊断定位到 `_mcp_smoke_probe.gd:4` | 通过：Headless `--quit` 与 GUT `6/6`，exit 0 | 通过：已 `git checkout -- game/project.godot`；`editor_plugins` 仅 GUT；无 `_mcp_game_helper`；`game/addons/godot_ai/` 未入库 | **Windows 接入烟测通过**。第 7 步全部人工项已勾选：Vision Routing 关、无第二套 Godot MCP（人类 2026-08-21 确认） |
| 2026-08-21 | 人类（安装 / Configure / Cmd+Z）+ AI Agent（第 5–6、8–9 步） | macOS 26.5.2 (arm64) | 3.1.5 | 通过：`GODOT_AI_DISABLE_TELEMETRY=true`，无 `~/Library/Application Support/godot-ai/`，Cursor attach 含 `--disable-telemetry` | 通过：MCP 创建并重命名 `Marker3D`（`undoable: true`），人类 Cmd+Z 两次后层次只剩根节点 `McpSmoke` | 通过：`project_run` 主场景 `game_status=live`（编辑器在前台），日志含 `client_boot` / `gl_compatibility`；无类型脚本诊断定位到 `_mcp_smoke_probe.gd:4` | 通过：Headless `--quit` 与 GUT `6/6`，exit 0；还原 `project.godot` 后再跑 `--quit` 仍有 `client_boot` 且无 `_mcp_game_helper` | 通过：已 `git checkout -- game/project.godot`；`editor_plugins` 仅 GUT；无 `_mcp_game_helper`；`game/addons/godot_ai/` 未入库 | **macOS 接入烟测通过**。第 7 步：插件无 C#；HTTP/WS 仅 `127.0.0.1:8000` / `9500`；Vision Routing 默认关；仅一套 `godot-ai` MCP；未用 `game_eval` / `test_run` |

签字前不要在任务单里写「本机 MCP 已可用」。上表有对应机器的通过行之后，该开发机上允许按 [CD-52 §7](../../Confirmed-docs/50-engineering/52-ai-workflow.md) 使用 MCP。M2 生产级启用已于 2026-08-23 通过（[ADR-0003](../adr/0003-godot-mcp-selection.md) 阶段 C、[ADR-0004 §8.1](../adr/0004-multi-agent-adoption-timing-and-architecture.md)）：大型 `.tscn` 必须走 MCP / Editor API / UndoRedo；编辑器未开时仍走 README 命令行。若编辑器仍开着并把插件状态写回 `project.godot`，提交前再还原一次。
