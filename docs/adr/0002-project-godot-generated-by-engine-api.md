# ADR-0002 project.godot 由引擎 API 脚本生成，不经项目管理器 GUI

- 状态：已实施，待人类复核
- 日期：2026-08-20
- 相关：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第九、十一、十二条、[CD-51 §4–§5](../../Confirmed-docs/50-engineering/51-dev-environment.md)

## 背景

`README.md` 原先规定 `project.godot` 必须由 Godot 项目管理器 GUI 创建，"不要手写"。这条约束的真实目的是避免手写 ConfigFile 时写错 4.7 的键名、枚举值或序列化格式——尤其是输入映射，它序列化后是一大段 `Object(InputEventKey, ...)` 文本，手写几乎必错。

但 GUI 创建方式有两个问题：它无法复现（下次换机器又要点一遍，且没人记得点了哪些选项），也无法覆盖 CD-51 §5 列出的十几项设置，那些仍然要在项目设置面板里手动点。

## 决策

用一次性 GDScript 通过引擎自身的 API 生成工程，而不是走 GUI：

1. 先放一个空的 `game/project.godot`，让引擎把该目录识别为项目根；
2. 用 `--headless -s` 运行一次性脚本，调用 `ProjectSettings.set_setting()` 写入 CD-51 §5 要求的全部设置，用 `PackedScene.pack()` + `ResourceSaver.save()` 生成启动场景，最后 `ProjectSettings.save()`；
3. 脚本执行成功后**立即删除**，`project.godot` 本身才是入库的事实源；
4. 键名与枚举值不靠记忆，先用探测脚本读 `ProjectSettings.get_property_list()` 的 `hint_string` 确认（宪法第十一条：不猜 API）。

相应地改写 README 中"Godot 工程首次创建"一节。

## 理由

- 序列化由引擎完成，格式一定正确，同时避免了 GUI 的不可复现；
- 探测 `hint_string` 拿到的是这台机器上这个引擎版本的事实，比查文档更可靠。实测中它纠正了两个凭直觉会写错的地方：`script_name_casing` 的 snake_case 是 `2` 而非 `1`，`directory_rules` 的值域是 Exclude/Include 而不是警告级别；
- 生成脚本用完即删，不留下第二个可能与 `project.godot` 冲突的事实源。若将来需要重建工程，从这份 ADR 与 `project.godot` 的 diff 就能还原做了什么。

## 后果

正面：

- 工程设置的每一项都有明确出处，人类审查 `project.godot` 的 diff 即可；
- 后续增删输入动作等设置可以用同样方式做，不必依赖任何人的 GUI 操作记忆。

负面：

- `ResourceSaver.save()` 生成的 `main.tscn` 没有 `uid=` 字段，也没有用 uid 引用脚本，与编辑器保存的产物略有差异。功能上无影响（路径引用完全有效），引擎在编辑器中第一次保存该场景时会自动补齐；
- 这套做法只适用于 `project.godot` 与结构极简的占位场景。**真正的玩法场景不适用**——宪法第十二条要求大型 `.tscn` 通过编辑器 / MCP / UndoRedo 修改，本 ADR 不构成对那条红线的豁免。

## 验证

- `--headless --path game --import` 退出码 0，无错误无警告；
- `--headless --path game --quit` 启动主场景，输出结构化启动日志，其中 `rendering_method` 字段实测为 `gl_compatibility`；
- 生成的 `project.godot` 内容经人工通读确认，17 个输入动作、渲染基线、警告级别均符合 CD-51 §5；
- `game/tests/unit/test_project_contract.gd` 6 个用例 30 条断言全绿。
