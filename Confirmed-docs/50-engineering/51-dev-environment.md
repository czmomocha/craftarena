# CD-51 开发环境搭建

> 文档 ID：CD-51
> 单一事实源：工具选型与版本锁定策略、资产入库规则、密钥管理边界、Windows 安装步骤、Godot 项目初始设置、AI 环境烟测清单
> 加载建议：搭建或修复环境、升级依赖、调整项目设置时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第七、十八、二十三条
> 相关：[CD-41 架构](../40-technical/41-architecture.md)、[CD-52 AI 协作规范](52-ai-workflow.md)、[CD-53 测试与 CI](53-testing-and-ci.md)
> 派生自：初稿 v0.2 §39–§42

## 1. 基础工具

| 工具 | 选型 |
|---|---|
| 游戏引擎 | Godot **4.7.2-stable** Standard；编辑器与导出模板锁定同一精确版本，所有开发机与 CI 必须一致 |
| 游戏脚本 | GDScript；核心目录强制静态类型 |
| 控制面 | TypeScript + Node.js + Fastify |
| 测试期数据库 | SQLite；仅控制面直接访问 |
| 实时入口 | 独立 TypeScript TLS WebSocket 网关 |
| AI IDE | Cursor |
| Godot AI 接入 | 已拍板延期至 M2 启动前重估，见 [ADR-0003](../../docs/adr/0003-godot-mcp-selection.md)；在那之前不装 MCP，选定后也只启用一个主 MCP |
| 单元测试 | GUT **9.7.1**（MIT）；随仓库入库于 `game/addons/gut/`，升级须同步本行 |
| 版本管理 | GitHub 私有 Monorepo；受保护 `main`；Git LFS |
| 3D 工具 | Blender，统一导出 GLB/glTF |
| 服务端本地环境 | Godot Headless + Node.js 服务；Docker Compose 可选 |
| CI | 目标为 GitHub Actions Linux + 自托管 Windows Runner。**当前只有 Linux 一档在跑**，自托管 Windows Runner 尚未搭建，Windows 侧验证仍靠开发机人工执行 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) |
| 云环境 | 腾讯云香港计算与 COS；本地 + 一个长期测试环境 |

不要在同一个工程里同时启用多个功能重叠的 Godot MCP，以免 AI 选择错误工具或重复修改场景。

## 2. 资产入库与版本锁定

- 可复现所需的 `.blend`、原始音频、高分辨率源文件，以及运行时 GLB/压缩音频进入 Git LFS；`.godot/imported` 不提交；
- 引擎、插件、npm 包和导出模板锁定精确版本；
- 每月集中评估补丁升级；大版本只在里程碑边界试验，且必须可回退。

## 3. 密钥边界

- 仓库只允许提交本地或 PR 沙盒可随时销毁的**假凭据**；
- 长期测试环境的数据库、COS、JWT、内容签名等密钥必须放 GitHub Secrets 或服务器外部配置，不得进入 Git 历史或 Web 构建。

## 4. Windows 初始安装

1. 下载 Godot 4.7.2-stable Standard，不下载 .NET 版；
2. 安装 Git；
3. 安装 Cursor；
4. 安装 Blender；
5. 配置 Godot 可执行文件环境变量；
6. 新建项目时选择 Compatibility；
7. 安装 GUT；
8. 创建 `AGENTS.md` 和项目规则；
9. 建立 `game/`、`backend/`、`infra/`、`docs/` 的 Monorepo 骨架；
10. 不安装 Godot MCP——[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) 已拍板延期至 M2 启动前重估；
11. 运行最小编辑、启动、Headless、Fastify、网关和测试闭环。

第 5 步的环境变量约定：所有命令通过 `GODOT4` 定位引擎，禁止把安装路径写死在脚本里。Windows 上还需要 `GODOT4_CONSOLE` 指向同版本的 `_console.exe`，否则 PowerShell 读不到引擎 stdout。

```powershell
[Environment]::SetEnvironmentVariable("GODOT4", "<安装目录>\Godot_v4.7.2-stable_win64.exe", "User")
[Environment]::SetEnvironmentVariable("GODOT4_CONSOLE", "<安装目录>\Godot_v4.7.2-stable_win64_console.exe", "User")
```

第 6 步不经项目管理器 GUI，改由引擎 API 脚本生成 `project.godot`，理由见 [ADR-0002](../../docs/adr/0002-project-godot-generated-by-engine-api.md)。

**具体可执行的命令行不在本文件维护**，一律以仓库 [README.md](../../README.md) 的命令表为准，禁止让每个 Agent 自己猜参数。

## 5. Godot 项目初始设置

必须先配置：

- 渲染器：Compatibility；
- 物理 Tick：由每个玩法的 `SimulationCore` 自己固定推进，不直接依赖帧率；
- 数值：核心位置、速度、计时、经济和伤害使用定点整数；
- 输入动作：移动、跳跃、使用道具、交互、编辑器相机、建造、升级、出售；
- 语言：GDScript；
- 类型：`shared/`、`simulation/`、`ugc/`、`server/` 静态类型且警告视为错误；UI/工具可有限使用 `Variant`，进入核心边界前必须校验。Godot 4.7 无法按目录收紧警告，落地方式见 [ADR-0001](../../docs/adr/0001-strict-gdscript-typing-gate.md)；
- 文件命名：`snake_case`；
- 资源导入：统一 GLB；
- 自动加载：只放稳定的基础服务，不把大量玩法状态塞进 Autoload；
- 日志：开发构建输出结构化日志；
- 导出：Windows、Linux Headless、Android、iOS 占位预设；
- Web 预设在核心切片稳定后加入。

## 6. AI 环境验证烟测

环境搭好后，AI 必须完成以下闭环：

1. 读取项目版本、依赖锁和目录；
2. 若主 MCP 已拍板，通过 MCP 创建一个临时测试场景；否则使用受审查的 Editor API/文件方式；
3. 创建一个静态类型 GDScript；
4. 运行语法检查；
5. 启动游戏并读取控制台；
6. 运行一个 GUT 测试；
7. 启动一个 Headless 实例；
8. 启动 Fastify、网关与 MatchHost 的最小健康闭环；
9. 删除临时测试内容；
10. 输出实际使用的命令和结果。

**未完成这套闭环，不进入正式功能开发。**

可执行版本与历次执行记录见 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md)。上面十步是本节拥有的要求，那份 runbook 只是它的落地形式；步骤增减先改这里。
