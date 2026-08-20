# ADR-0001 GDScript 静态类型门禁采用全局 Error + 局部豁免

- 状态：已实施，待人类复核
- 日期：2026-08-20
- 相关：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第二十三条、[CD-51 §5](../../Confirmed-docs/50-engineering/51-dev-environment.md)、[CD-53 §4.1](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)

## 背景

宪法第二十三条要求 `game/src/shared/`、`simulation/`、`ugc/`、`server/` 四个目录**静态类型且警告视为错误**，同时允许 UI 与工具层有限使用 `Variant`。这是一条按目录分区的约束。

Godot 4.7 提供了 `debug/gdscript/warnings/directory_rules`，看起来正好能表达按目录的差异。但查证官方 `ProjectSettings` 文档后确认，它的取值只有 `0 = Exclude` 与 `1 = Include` 两档：Exclude 表示该目录完全不产生警告，Include 表示套用全局配置。**它只能让某个目录更宽松，不能让它更严格。**

因此"只对四个核心目录报错"无法由引擎原生表达，必须在两条路线里选一条。

## 决策

采用全局最严档 + 局部豁免：

1. 以下警告在 `project.godot` 中全局设为 `2`（Error）：
   `untyped_declaration`、`inference_on_variant`、`unsafe_call_argument`、`unsafe_cast`、`unsafe_method_access`、`unsafe_property_access`、`unsafe_void_return`；
2. `directory_rules` 保留引擎默认的 `{"res://addons": 0}`，第三方插件（GUT 等）不受本项目警告配置约束——这也是 Godot 官方明确建议的做法；
3. UI 与工具层确实需要 `Variant` 时，用 `@warning_ignore` / `@warning_ignore_start` 就地豁免，豁免点在 code review 中可见。

## 理由

- 引擎在解析阶段就阻断违规脚本，`--check-only` 与 GUT 运行都会失败，宪法红线由工具强制而不是靠自觉；
- 不需要自建按目录扫描的 CI 工具，M0 阶段少一个要维护的东西；
- 把"宽松"变成需要显式书写的例外。核心目录写不出豁免注解不会被察觉，而 UI 层写了豁免注解会留在 diff 里，符合宪法第二十条的可解释性要求。

## 后果

正面：

- 四个核心目录事实上得到了比宪法要求更强的保证；
- 新人或 AI 写出未标注类型的代码时立刻失败，不会积累技术债。

负面：

- UI 与工具层的书写成本上升，某些 Godot API 返回 `Variant` 时必须显式接住。已知的安全写法是先用带类型的变量接收，例如 `var name: String = ProjectSettings.get_setting(...)`，而不是 `String(...)` 这类构造函数调用——后者会触发 `unsafe_call_argument`；
- 豁免注解可能被滥用。缓解方式是后续在 CI 中统计 `@warning_ignore` 出现位置，一旦出现在四个核心目录里就直接失败。该检查尚未实现，属于 CI 任务的待办。

## 备选方案

**全局 Warn + CI 按目录判定 Error**：保留引擎默认宽松度，由自建脚本解析 `--check-only` 输出并按路径决定是否失败。分区更精确，但需要自己维护一个解析器，且本地开发时不会即时反馈。M0 阶段不值得这个复杂度，若将来 UI 层豁免注解泛滥可以再切换。

## 验证

实际执行过的证据：

- 故意写一个未标注类型的脚本，`--check-only` 返回退出码 1，报 `Parse Error: Variable "untyped_value" has no static type. (Warning treated as error.)`；
- 合规脚本 `res://src/client/main.gd` 同一命令返回 0；
- 第一版 `test_project_contract.gd` 里用了 `int(ProjectSettings.get_setting(...))`，被门禁拦下并要求改写，说明规则对测试代码同样生效；
- GUT 加载 `res://addons/gut` 下 259 个文件未受影响，确认 `directory_rules` 的排除规则起作用。

设置本身由 `game/tests/unit/test_project_contract.gd` 的 `test_strict_typing_warnings_are_errors` 持续守护。
