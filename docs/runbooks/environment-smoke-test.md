# 环境烟测清单（Windows）

本文件是 [CD-51 §6](../../Confirmed-docs/50-engineering/51-dev-environment.md) 那套十步闭环的可执行版本，同时充当**人类运行验证**清单。

它存在的理由是宪法第十条与第二十四条：没有执行结果的测试等于没有测试，而"AI 说跑通了"不是证据。任何人换一台机器，照本文件从头跑一遍，就能自己判断这套环境是不是真的成立。

- 适用范围：Windows 开发机。macOS/Linux 尚未验证，首次执行后请补充对应列。
- 预计耗时：10 分钟。
- 前置条件：已按 CD-51 §4 装好 Godot 4.7.2-stable **Standard**（非 .NET）、Node 24+、Git，并设好 `GODOT4` 与 `GODOT4_CONSOLE`。

> 全程在仓库根目录（`craftarena/`）执行，用 PowerShell。

---

## 第 0 步：前置检查

```powershell
node --version
$env:GODOT4
$env:GODOT4_CONSOLE
& $env:GODOT4_CONSOLE --version
```

预期：Node 为 `v24.x` 或更高；两个路径都指向**同一版本**的引擎；最后一条输出 `4.7.2.stable.official.ed1daf0bf`。

三个变量任一为空，说明 CD-51 §4 第 5 步没做完，先回去补，不要继续往下跑。

---

## 第 1 步：读取版本、依赖锁与目录

```powershell
git log --oneline -5
npm ci
```

预期：`npm ci` 结束时报告安装了约 66 个包且没有 `ERR!`。它读的是 `package-lock.json`，因此这一步同时验证了依赖锁是完整的。

---

## 第 2–3 步：新建一个静态类型 GDScript 与临时场景

MCP 未选定（[ADR-0003](../adr/0003-godot-mcp-selection.md)），所以按 CD-51 §6 第 2 步的规定走文件方式。

新建 `game/src/client/_smoke_probe.gd`，内容如下：

```gdscript
extends Node

func _ready() -> void:
	var answer: int = 6 * 7
	print("smoke probe says ", answer)
	get_tree().quit()
```

这个脚本刻意把每个变量和返回值都标注了类型。**这不是风格偏好**：ADR-0001 把类型相关警告全局设成了 Error，漏标一处就会在下一步被引擎直接判错。

---

## 第 4 步：语法与类型检查

```powershell
& $env:GODOT4_CONSOLE --headless --path game --check-only -s res://src/client/_smoke_probe.gd
echo "exit code: $LASTEXITCODE"
```

预期：无输出，`exit code: 0`。

**顺便验证门禁真的在工作**：把 `var answer: int = 6 * 7` 临时改成 `var answer = 6 * 7`（去掉 `: int`），重跑上面的命令。应当看到

```
Parse Error: Variable "answer" has no static type. (Warning treated as error.)
exit code: 1
```

确认之后把类型标注改回去。这一步比前一步更重要——它证明的是"错误代码会被拦下"，而不只是"正确代码能通过"。

---

## 第 5 步：启动游戏并读取控制台

```powershell
& $env:GODOT4_CONSOLE --headless --path game --quit
```

预期：输出一行 JSON 启动日志，含 `"event":"client_boot"`、`"rendering_method":"gl_compatibility"`、`"project":"Craft Arena"`。

渲染基线必须是 `gl_compatibility`（宪法第七条）。如果看到 `forward_plus`，说明 `project.godot` 被改坏了，去跑第 6 步的 GUT 测试会得到更明确的失败信息。

---

## 第 6 步：运行 GUT 单元测试

```powershell
& $env:GODOT4_CONSOLE --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
echo "exit code: $LASTEXITCODE"
```

预期：`6/6 passed.`、`---- All tests passed! ----`、`exit code: 0`。

这 6 个断言守护的是工程契约本身：项目名、三个平台的渲染基线、严格类型开关、17 个输入动作、以及"工程里不存在任何 `.cs` / `.csproj`"（宪法第七条）。

---

## 第 7 步：启动 Headless 实例

第 5 步跑的是客户端主场景，这一步跑的是对局服务端场景：

```powershell
& $env:GODOT4_CONSOLE --headless --path game --scene res://src/server/match_server.tscn -- --match-id=manual-check --port=42999
```

预期：输出 `{"event":"match_server_boot", ..., "match_id":"manual-check", "port":"42999"}` 后**保持运行**。按 Ctrl+C 停止。

它不自己退出是对的：真实对局进程要活到 MatchHost 回收它为止。

---

## 第 8 步：后端最小健康闭环

先跑自动化测试：

```powershell
npm run typecheck
npm test
```

预期：typecheck 无输出；测试报告 `pass 46`、`fail 0`。

再拉起三个服务：

```powershell
npm run dev
```

预期依次出现（大约 6 秒内）：

```
[dev-launcher] control-plane ready at http://127.0.0.1:8080
[dev-launcher] gateway ready at http://127.0.0.1:8090
[dev-launcher] match-host ready at http://127.0.0.1:8100
[dev-launcher] all services ready; press Ctrl+C to stop
```

**保持这个窗口开着**，另开一个 PowerShell 窗口做下面的检查。

### 8.1 三个服务的就绪探针

```powershell
foreach ($port in 8080,8090,8100) { Invoke-RestMethod "http://127.0.0.1:$port/readyz" }
```

预期：三条都是 `status = ready`。控制面那条会带一次真实的 SQLite 读写往返结果，网关那条的就绪取决于它能否探到控制面——所以这一条同时验证了两个服务之间的依赖关系是活的。

### 8.2 真实开一局

```powershell
$m = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8100/matches"
$m
Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Select-Object ProcessId,ParentProcessId,Name
```

预期：返回一条 `state = running` 的记录，带 `matchId`、`port`（42000 起）、`pid`，以及 30 分钟后的 `leaseExpiresAt`（CD-44 §3）。进程列表里会出现**两个** Godot 进程——外层 `_console.exe` 和它派生的引擎本体。这是 Windows 特有现象，MatchHost 记录的 `pid` 是外层那个。

### 8.3 关掉它

```powershell
Invoke-RestMethod -Method Delete -Uri "http://127.0.0.1:8100/matches/$($m.matchId)"
Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'"
```

预期：返回 `state = stopped`、`stopReason = requested`；第二条命令**无输出**，即两个 Godot 进程都被回收。

回到 `npm run dev` 那个窗口，应该能看到一行 `match stopped` 日志，`recentOutput` 字段里带着刚才那个对局进程的引擎版本行和 `match_server_boot` 日志。这就是 CD-44 §3 要求的"进程异常时尽力保留最后日志"。

### 8.4 停止服务

在 `npm run dev` 窗口按 Ctrl+C。预期三个进程一起退出，8080/8090/8100 全部释放。

---

## 第 9 步：删除临时测试内容

```powershell
Remove-Item game/src/client/_smoke_probe.gd, game/src/client/_smoke_probe.gd.uid -ErrorAction SilentlyContinue
git status --short
```

预期：`git status` 干净（或只剩你自己有意的改动）。CD-51 §6 第 9 步要求验证内容不留在仓库里。

---

## 第 10 步：记录结果

CD-51 §6 第 10 步要求输出实际使用的命令与结果。命令即本文件，结果记在下面这张表里。**新增一行，不要覆盖旧行**——需要的是历史，不是快照。

| 日期 | 执行人 | 机器 / 系统 | 引擎 | 结果 | 备注 |
|---|---|---|---|---|---|
| 2026-08-20 | AI Agent | Windows 10.0.26100 | 4.7.2-stable | 全部通过 | 第 2/3/9 步以受审查的文件方式完成；第 8.2 步实测两级进程与端口回收；此次执行发现 MatchHost 在 Windows 上用非 console 引擎会丢失子进程日志，已修 |
| 2026-08-20 | 人类 | Windows 10.0.26100 | 4.7.2-stable | 全部通过 | 按本清单逐步复跑，无偏差。另按下方「编辑器 GUI」独立打开工程：渲染基线 Compatibility、输入映射 17 个动作齐全、项目能正常打开 |

---

## 编辑器 GUI（人类独立检查，不在 CD-51 §6 十步内）

本清单其余步骤全程 headless。首次在一台 Windows 开发机上完成十步之后，额外打开一次编辑器：

```powershell
& $env:GODOT4 --editor --path game
```

人工确认三件事后关闭编辑器：

1. 工程能正常打开，无导入失败弹窗；
2. 项目设置里三个平台的渲染方法都是 Compatibility（`gl_compatibility`）；
3. 输入映射里有 CD-51 §5 要求的 17 个动作。

| 日期 | 执行人 | 结果 |
|---|---|---|
| 2026-08-20 | 人类 | 通过：工程可开、Compatibility、17 个输入动作 |

---

## 已知不在本清单覆盖范围内

按宪法第二十四条明确列出，避免把本清单的通过当成比它实际更强的保证：

- **编辑器 GUI 不进自动回归**。上面那一节只是人类独立检查，CI 不打开编辑器。
- **Windows 无自动回归**。CI 只有 Linux runner（[CD-53 §4.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)），Windows 侧的引擎行为完全依赖本清单被人手动执行。
- **不覆盖网络故障与性能**。这两类按 CD-53 §1.1 是明确接受的风险，没有门禁。
- **不验证对局玩法**。M0 的对局进程只打印一行启动日志就挂着，没有仿真、没有网络协议。真正的对局验收从 M1 开始。
