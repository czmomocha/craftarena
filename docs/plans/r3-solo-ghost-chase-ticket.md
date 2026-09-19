# R3 任务单：Solo 追赶本机最高纪录（幽灵）

主管派给 **client**。先读 `.cursor/agents/client.md` 与 `AGENTS.md`，再干。不能再往下派子 Agent。未经人类说「提交」不得 commit / push / 开 PR / 部署。

## 任务单

目标：机关狂奔 **Solo** 开局追赶本机最高纪录的无碰撞幽灵。进入单人试玩默认开启；设置窗可关；破纪录后该次磁带成为同课下次幽灵。

背景：人类 2026-09-19 点名这一刀，插在 **R2 之后、M6 F2 之前**，不发明新里程碑号（章号 **R3**）。产品已锁：[CD-13 §3](../../Confirmed-docs/10-product/13-account-and-session.md)「TRAPRUSH 可记录本机最佳命令轨迹并播放无碰撞幽灵，不下载他人幽灵」；CD-91 `traprush_offline_opponents = local_ghost`；实现落点仍写「本机最佳轨迹幽灵…仍待」。R2 已交命令磁带（`TraprushReplayTape` / `TraprushReplayStore` / `MatchOfflineReplay`），本章在它上面加「每课最快一条 + 并行表现会话」。工作树里 R2 可能还没 commit，**不要 revert R2**，在现状上继续。

允许修改：

- `game/src/client/`（Solo 幽灵跑者、库、设置开关、幽灵表现映射、大厅接线）
- `game/src/shared/ui_copy*.gd` 与 `game/content/locale/craft_arena.csv`（设置复选框文案；禁止 emoji）
- `game/tests/unit/` 本章测试
- 所有者文档（同一任务必须更，宪法第十九、二十六条）：CD-13 §3、CD-12 设置/离线、CD-21 单局流程、CD-14 若新增 persist 路径、CD-61 插入段、CD-91 追一行、CD-53 里「不锁幽灵」那句、`docs/runbooks/dev-window-check.md` 本刀整节替换

禁止修改：

- `game/src/simulation/`、`game/src/server/`、`backend/`、协议帧、Component Schema / Bundle 袋、`placeholder_spec.gd` 散落新 const、`play_stubs.gd` 玩法数值、`sky_catalog.gd`、`character_catalog.gd` 目录
- 不要把幽灵当成直播会话第二席（会碰撞 / Shove / 上名次）
- 不要改 D-F4 / D-F5 / D-F6；不要开 M6 F2、BASTION 幽灵、双人/联机幽灵、从服务端拉他人磁带、回放里再套幽灵、暂停/倍速
- 不要为占位表现写色彩/材质强断言
- 不要 commit

隔离方式：无（当前 checkout）

输入文件：

- `game/src/client/match_offline_session.gd`、`match_offline_replay.gd`、`traprush_replay_store.gd`
- `game/src/games/traprush/replay_tape.gd`
- `game/src/client/audio_settings_entry.gd`、`hud_settings.gd`
- `game/src/client/match_snapshot_map.gd`、`match_snapshot_map_players.gd`
- `game/src/shared/visual_asset_catalog_fit.gd`（`tint` 已经 `TRANSPARENCY_ALPHA` + `SEAT_TINT_ALPHA=0.42`，幽灵不要改这个数；用节点 `transparency`）
- `game/src/client/match_course_map_fx.gd` 里 `_set_geometry_fade` 是现成的 `geometry.transparency` 写法
- `game/src/client/match_lobby_director.gd`、`match_lobby_runtime.gd`、`match_lobby_shell.gd`
- `game/tests/unit/test_traprush_replay.gd`、`test_match_play_session.gd`
- 所有者文档见上

验收标准：

1. Solo 开局时若设置开且本课 `course_id` + `content_hash` 有最佳磁带，三维里出现一个虚拟角色；无纪录或开关关则不出现。
2. 幽灵是**第二个本地 `TraprushMatchSession` / `MatchOfflineSession`**，按磁带重仿真，与直播会话同 tick 推进；直播快照 `player_count` 仍是 1，幽灵不占席、不碰撞、不上单局名次、不发 HTTP。
3. 幽灵角色网格 = 本席当前选中（磁带不存网格，CD-12）；整个幽灵节点树 `GeometryInstance3D.transparency = 0.5`（正常本席是 0，一半不透明）。不要改 `SEAT_TINT_ALPHA`。
4. 最佳纪录**不走 R2 环 50**。独立 `user://traprush_solo_ghosts.json`，按 `course_id` 保一条最快磁带；开局还要 `content_hash` 对上才播。冲线且 `finish_ticks[0]` **严格小于** 已存才替换；平局保旧。Cancel / 未冲线不写。R2 环仍照旧存次局。
5. 设置窗（现有 `AudioSettingsEntry` SettingsWindow）加 CheckBox，默认 **开**；缺文件 = 开。关窗落 `user://traprush_ghost_settings.json`。只读中的回放局（`replay_active`）不再套幽灵。
6. 离线横幅仍在。不回写在线。

必须运行的测试：

- 先写测试再实现。新脚本建议 `game/tests/unit/test_traprush_ghost.gd`（库 / 开关 / 并行会话强断言；表现只烟测：节点能造出来、不崩、有一个幽灵节点且 `transparency` 约 0.5，不断言色板）
- 覆盖：默认开；开关关不出幽灵；无磁带不出幽灵；hash 不对不出；更快替换、更慢/平局不替；直播 `player_count==1`；幽灵会话随 tick 走位姿；`replay_active` 不套幽灵
- 跑 `npm run test:gut:affected`；若 affected 漏了新测试就直接 `"$GODOT4" --headless --path game -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_traprush_ghost.gd -gexit` 再加上受影响的旧脚本（至少 `test_traprush_replay.gd`、`test_match_play_session.gd`、`test_ui_copy.gd`）
- 改了 locale / ui_copy 就跑对应 GUT
- 没有执行结果的测试等于没有测试

性能或安全预算：第二个会话只多 1 个胶囊。不要把性能观察写进 CI。离线不写控制面。

输出物：

- `game/src/client/traprush_ghost_settings.gd`（默认 enabled=true）
- `game/src/client/traprush_ghost_store.gd`（每课最佳磁带，不环被踩）
- `game/src/client/match_offline_ghost.gd`（E9：从 `match_offline_session.gd` 拆出幽灵并行会话，守文件长度）
- 幽灵表现映射（新小文件或挂在现有 map 侧路；不要把幽灵塞进直播玩家列表）
- SettingsWindow CheckBox + locale 键（例如 `craft_arena.ui.ghost_chase`，中文「追赶本机最高纪录」 / 英文 `Race my best time`）
- GUT 正反例
- 所有者文档与 `docs/runbooks/dev-window-check.md` 本刀

开发机窗口步骤：整节替换 `docs/runbooks/dev-window-check.md`「本刀」为编号步骤（启动、进机关狂奔、单人试玩跑完一次、再跑看到半透明幽灵、设置关掉后不再出、破纪录后下次幽灵变快）。本刀不需要三后端。

里程碑归属：M6（插入 R3，R2 之后 / F2 之前；不发明 M8）

是否绕过 placeholder_spec 散落几何/色板常量：否。幽灵 `transparency=0.5` 只写在幽灵映射一处。

审查级别：常审

## 已锁设计（不要再问人类）

- **只 Solo 离线**（`MatchOfflineSession` 真实试玩）。不做在线 1 人房、双人、BASTION。「本账号」在 Solo = 本机 `user://`，与 R2 本机环同一台机边界。
- 幽灵用与 R2 同型的命令磁带重仿真，不是录像、不是位姿采样点。
- 并行会话的 seed / go_tick / play stubs 从磁带与主会话拷贝，所以周期机关相位一致。
- 幽灵跑完停在终点姿。主角跑完不影响幽灵已停的位置。
- HUD 可加一个现有口径的小 token（例如 `ghost=on` 或追赶文案），**不要**新做排行榜。
- 幽灵不进协议帧、不进 SimulationBundle、不改 ContentHash。
- Godot 4：`GeometryInstance3D.transparency` 0=不透明、1=全透。不要猜 Godot 3 API。
- 文案走 `UiCopy` + CSV，不要把中文写进场景或脚本字面量。

## 实现提示

`MatchOfflineSession.try_advance` 在直播推进后调幽灵 `try_advance`。`try_stop` 一并清幽灵。`try_begin` 里若 `ghost_settings.enabled` 且不是 `replay_active`，从 ghost store 取最佳并 `hash_ok` 后 `try_begin_replay` 到并行会话。`maybe_save` 成功后 `ghost_store.put_if_faster`。

大厅表现：跟幽灵 follow 的 slot 0 姿再造一个不跟相机的节点；别把它当 `follow_slot`。

测试用临时 `user://` 路径，`after_each` 删掉，照 `test_traprush_replay.gd`。

E9：不要把 `match_offline_session.gd` 再撑胖。

文档：文首「当前生效值」是覆盖而非追加。别处只链接不复述参数。CD-91 追一键，注明覆盖 `traprush_offline_opponents = local_ghost` 的实现落点。CD-61 把 R3 写进 R2 之后、F2 之前，且 F2 重签须一并覆盖幽灵。

回报必须包含：改了哪些文件、测试命令与结果、开发机窗口本刀是否已替换、未做什么、失败模式一句话。
