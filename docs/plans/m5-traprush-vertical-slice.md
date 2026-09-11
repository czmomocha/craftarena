# M5 章节计划：TRAPRUSH 纵向切片验收 + 音频系统

> 类型：实现级章节计划（`docs/plans/`），**不是所有者文档**。
> 里程碑产出与退出条件的所有者是 [CD-61 §2 M5](../../Confirmed-docs/60-plan/61-milestones.md)；本文件只把 M5 拆成可审查的章。两者冲突以 CD-61 为准。
> 日期：2026-09-10。状态：章节划分与音频模块基建已由人类拍板（§5.1）；**A1 / A2 / A3 / B1 已交**；**C1 第 4 张官方课（垂直塔）本刀**。
> 上位约束：[CD-00 宪法](../../Confirmed-docs/00-constitution/CONSTITUTION.md) 第一、三、四、五、九、十七、十八、十九、二十三条。

## 1. 能不能开工

能。判据不是感觉，是 CD-61 的顺序值：

| 前置 | 状态 |
|---|---|
| 可玩性深化 | 已收口（2026-09-09） |
| M4a（Rule VM 第 1–5 章） | 已收口（2026-09-09） |
| M4b（内容平台 + 账号第 1–5 章） | 已收口（2026-09-10） |
| CD-61 明写的下一动 | **M5** |

两处仓库规则文件仍停在旧口径，开工第一章时须一并改到 M5，否则 Agent 每次加载都会被指向已收口的段：

- `.cursor/rules/course-correction-freeze.mdc` §1「现在可以开工：可玩性深化」；
- `.cursor/rules/complete-chapter-prs.mdc`「下一刀 = 可玩性深化」与其任务单末四行。

## 2. M5 范围

CD-61 §2 的五项产出，加人类 2026-09-10 拍板挂入本号的第六项：

| # | 产出 | 现状 | 落在本文件哪几章 |
|---|---|---|---|
| 1 | 3～5 张官方赛道（第 4 张及以后） | 01–04 已入库；匹配 HTTP 白名单认这四张；05 仍待 C2 | C1、C2 |
| 2 | BotRunner 可达性测试 | 能力已在引擎内（`bot_run_cli.gd` + `course_completion_probe`）；`tools/bot-runner/` 未建但 CD-41 §5 列了它 | C5 |
| 3 | 按需人工网络故障检查 | 清单在 [CD-53 §2.5](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)，无可执行 runbook | C6 |
| 4 | 项目负责人可玩性清单 | 纠偏 E6 已签「好玩」，但那不是 M5 的签署物；无独立清单文件 | C6 |
| 5 | 编辑—预览—邀请—发布—游玩—单局结算闭环 | 见 §2.1 断点 | C3、C4 |
| 6 | **TRAPRUSH 音频系统**（人类 2026-09-10 拍板挂入 M5） | 只有 F 线 FB 的 `PlaySfx`：8 个内部临时 WAV、静态类、一次性 `AudioStreamPlayer`、无池化 / 无节流 / 无 BGM / 无音量设置 | A1–A3、B1、B2 |

### 2.1 闭环目前断在哪

编辑、预览、官方课联机、结算写库都已通。断的是三处：

1. **创作 → 发布**：Godot 编辑外壳没有发布按钮，客户端从不调 `POST /content/publish`。后端与 `ContentCatalog` 只有单测覆盖。
2. **发布 → 广场**：`ContentPlazaEntry` 不拉 `GET /content/plaza`，真机打开是空列表；现有测试靠 `apply_list` 注入。
3. **已签名 UGC → 联机**：匹配 HTTP 只认 `course_01/02/03/04` 四个 enum，自制课只能 Solo。

「邀请」不算断——房间码建房 / 按码加入已通，缺的是可分享的邀请串与产品化提示。

## 3. 音频系统初步设计

### 3.1 硬约束

人类要求：独立模块、游戏无关、业务层与底层解耦，BASTION 直接复用。落成可检查的形式：

1. **模块内零玩法词汇**。`game/src/audio/**` 不得出现 `traprush` / `bastion` / `jump` / `hazard` / `crate` / `finish` 等玩法名词，连字符串字面量也不行。由 `tools/redline-scanner/` 加一条规则机械保证，进 CI。这是本设计唯一能防止"音频模块慢慢长成 TRAPRUSH 音频模块"的东西。
2. **业务层只说 cue id**。玩法代码不碰文件路径、总线名、音量、衰减距离、并发数。它只调 `AudioService.post(cue_id, ctx)`。
3. **只有一个文件碰引擎**。`audio_backend.gd` 是唯一引用 `AudioServer` / `AudioStreamPlayer` / `AudioStreamPlayer3D` 的文件；其余全部通过它。换引擎 API 或做 Web 空实现时只改这一个文件。
4. **音频永不进权威**。不进 `SimulationWorld`、不进 `hash_state`、不进协议帧。Headless MatchServer 与 GUT 全静默。这是宪法第五条，不是风格偏好。
5. **可丢失**。音频事件允许漏播；任何"没播出来"的路径都不能影响玩法判定。

### 3.2 分层

```text
业务层（认识玩法，可替换，不在 audio 模块内）
  game/src/games/traprush/traprush_audio_router.gd   TRAPRUSH 事件 → cue id 的唯一映射表
  game/src/client/match_audio_source.gd              从权威快照 diff 派生事件
  （BASTION 日后加自己的 router，不改下面任何一层）
        │  只调 AudioService.post(cue_id, ctx) / MusicDirector.request(state_key)
        ▼
服务层（游戏无关，game/src/audio/）
  audio_service.gd      门面：post / stop / set_bus_db / set_muted / shutdown
  audio_cue.gd          cue 定义（数据）
  audio_bank.gd         cue 集合 + 加载校验
  audio_voice_pool.gd   声部池、优先级抢占、per-cue 并发上限与冷却节流
  music_director.gd     BGM 状态机、交叉淡入淡出、同曲不重启
  audio_settings.gd     五条总线音量持久化（user://）
        ▼
底层（引擎适配，game/src/audio/）
  audio_backend.gd      唯一碰 AudioServer / AudioStreamPlayer(3D) 的文件
                        headless / Dummy 音频驱动 / 显式静默开关走空实现
```

依赖方向单向向下，禁止服务层反向引用业务层。目录落点 `game/src/audio/` 需要写进 [CD-41 §5](../../Confirmed-docs/40-technical/41-architecture.md)（目录所有者），并声明它自愿等同宪法第二十三条的严格类型强度（不改宪法条文，已拍板，见 §5.1）。

### 3.3 Cue 契约

cue 是数据，定义在 `game/content/audio/banks/*.json`，字段初稿：

| 字段 | 含义 |
|---|---|
| `id` | 稳定 cue id，业务层唯一可见的键 |
| `streams[]` | 变体文件列表，多个则随机轮播（避免脚步声机关枪） |
| `bus` | `music` / `sfx` / `ui` / `ambience` 之一，不能自由填 |
| `gain_db` / `pitch_min` / `pitch_max` | 增益与音高随机区间 |
| `spatial` | `false` = 2D，`true` = 3D 定位（需 `max_distance`） |
| `loop` | 循环（机关环境音） |
| `priority` | 声部不足时的抢占顺序 |
| `max_voices` | 同 cue 并发上限 |
| `cooldown_ms` | 同 cue 最小触发间隔（节流） |

平台内置 cue id 清单落 `game/src/shared/schema/audio_cue_catalog.gd`，形状类比已有的 `gameplay_asset_catalog.gd`。UGC 只能引用已登记 id（宪法第三、四条，[CD-31 §5](../../Confirmed-docs/30-ugc/31-ugc-principles.md)「只能引用平台内置音效」）。bank 校验进 CI，未登记 id / 缺文件 / 非法枚举 / 未知键一律判失败而不是静默跳过。

人类 2026-09-10 拍板素材格式为 **OGG**（音效与背景音乐都是），并会持续补充。因此：bank 与 catalog 必须支持增量登记，加一条 cue 不得改动服务层与底层任何文件；`.gitattributes` 把 `*.ogg` 纳入 LFS。

### 3.4 你提供的素材 → cue 映射草案

你列的类别里有两项在 TRAPRUSH 现有玩法中**没有对应概念**。有音效不等于有玩法——不得为了用上素材而发明机制（宪法第一条）。处理办法如下，接线前请确认：

| 你说的 | TRAPRUSH 现状 | 本计划怎么接 |
|---|---|---|
| 击毁障碍 | 已有：可破坏箱 / 碎石 / 障碍核心 / 能量墙，走 UseItem | 直接接，按被打碎的袋类型分 cue |
| 获胜冲线 | 已有：`finish_tick` + 单局名次 | 直接接，冲线与"第一名"分两个 cue |
| 选择角色 | **界面已立项但未开工**（`character_select_screen`，排在主大厅壳之后） | 先登记为通用 UI cue（`ui.select` / `ui.confirm`），接到现有大厅按钮；角色选择界面落地时直接复用，不改音频层 |
| 击杀 | **不存在**。TRAPRUSH 是竞速，没有击杀，只有推击（Shove）与环境失败（hazard / out_of_range / crushed） | 拆成两个诚实的 cue：`player.shove_hit`（推击命中）与 `player.rival_failed`（他人环境失败）。**不叫击杀，也不为此加击杀机制**。真正的击杀属 BASTION（M6 / M7），届时新 router 复用同一模块 |
| gameover | **不存在**。单局按名次结束，未冲线也不是失败态 | 拆成 `player.env_fail`（环境失败复位，已有三种原因）与 `match.settled`（结算面板出现）。若你要的是"本局结束"的收束音，用后者 |
| 背景音乐 | 无 | A3 的 `music_director`：大厅 / 对局 / 结算 / 编辑四态，交叉淡入淡出 |

### 3.5 诚实边界（写进每章交付说明，不得省略）

- v1 快照帧没有 `vy` / `stun` / 事件字段。**联机对局的跳跃、落地、硬直音只能靠相邻快照位姿近似**，会漏播也会误播。修它要改协议帧（宪法第十八条），本 M 不改。
- 机关环境音靠客户端按快照 tick 重算半周期，与服务端权威开合可能差一两拍。
- Web 导出的音频延迟与桌面不同，不做数值承诺，只做"能听见"验收。
- 音量设置是本机 `user://`，不上云、不跟账号。
- 短音效用 OGG 而不是 WAV，每次播放都要解码。Godot 4 支持 `AudioStreamOggVorbis`，但高频音效（脚步）在 8 人对局下的开销**未实测**。B2 交付时给一次实测数字；若确有问题，改为导入期转 WAV，业务层与 cue id 不受影响（这正是分层要挡住的那类变更）。

## 4. 章节清单

11 章。每章都是一条链路的闭合，符合 D9 的 5× 粒度；交章时整节替换 [开发机窗口验收](../runbooks/dev-window-check.md) 的「本刀」。

顺序：**A1 → A2 → A3 → B1 → C1 → C2 → B2 → C3 → C4 → C5 → C6**。B2 依赖人类交付正式素材，素材一到即可插队。

### A1 音频内核与总线（`PlaySfx` 退场）

- **交付**：新目录 `game/src/audio/`；`audio_service` 门面 + `audio_backend` + `audio_voice_pool` + `audio_settings`；总线布局从 Master/Sfx 扩到 Master/Music/Sfx/Ui/Ambience（改 `game/default_bus_layout.tres`）；redline 规则「audio 模块零玩法词汇」进 CI；现有 8 个 F 线临时 WAV 改走新内核，`game/src/client/play_sfx.gd` 删除。
- **测试**：声部池抢占 / 并发上限 / 冷却节流正反例；headless 与 `--audio-driver Dummy` 下静默（CI 用哪个由本章实测确定，不凭记忆猜参数）；设置文件缺失与损坏时回退默认；redline 规则自测（故意放一个 `jump` 字面量应判失败）。
- **审查**：常审。 **窗口**：跳 / 落地 / 打箱 / 冲线仍有声，且按住 W 连续跑动不再爆音。
- **不做**：BGM、设置 UI、新素材、任何玩法音效增删。

### A2 Cue Bank 契约与内置目录

- **交付**：`audio_cue` / `audio_bank` / `audio_bank_loader`；`game/src/shared/schema/audio_cue_catalog.gd` 内置 cue 清单；`game/content/audio/banks/core.json` + `traprush.json` 装入现有 8 个音；bank 校验进 CI（并入 `tools/content-validator/` 或新建 `tools/audio-bank/`，二选一见 §5.2 问题 5）。
- **测试**：未知 cue id / 重复 id / 缺文件 / 非法 bus / 未知键 / 超预算全部拒绝；catalog 与 bank 一致性；已有 8 个音行为逐字节不变。
- **审查**：**深审**（落在 `game/src/shared/schema/`，是契约）。 **窗口**：8 个音走 bank 播放，音色与时机与 A1 一致。
- **不做**：让创作者自定义 cue 参数；UGC 引用未登记 id。

### A3 音乐总监与音量设置面板

- **交付**：`music_director`（状态机 + 交叉淡入淡出 + 同曲不重启 + 单实例）；游戏无关的状态键（`lobby` / `play` / `result` / `edit` 由业务层传入，不硬编码在模块里）；大厅「设置」按钮（[CD-12 §1](../../Confirmed-docs/10-product/12-product-structure.md) 大厅结构已列「设置」）打开独立 Window，五条音量滑条 + 静音，全部走 `UiCopy` 本地化键；关窗即生效并落 `user://`。
- **测试**：状态转换与淡入淡出不重叠；同曲重复 request 不重启；音量夹取与持久化；重启后仍生效。
- **审查**：常审。 **窗口**：编号步骤走「大厅听到曲 → 拉低音乐滑条 → 进 Solo 换曲 → 冲线换结算曲 → 重启仍记住音量」。
- **不做**：locale 热切换设置页（明确的不做项）；画质 / 按键重映射；音量跟账号上云。

### B1 TRAPRUSH 玩法音效路由（离线路径）

- **交付**：`traprush_audio_router.gd`——**唯一**知道"跳 = 哪个 cue"的文件，一张常量映射表；Solo / Preview 全事件接线：脚步（按步长节流）、跳、落地、冲刺、推击、使用道具、拾取、打碎（箱 / 碎石 / 核心 / 能量墙）、检查点验收、复位、环境失败（hazard / out_of_range / crushed 三种不同音）、冲线、结算；机关 3D 循环环境音（传送带 / 电梯 / 喷火 / 滚柱 / 压板 / 摆锤 / 传送门 / 开关门 / 冰面）；`AudioListener3D` 挂到跟随相机。
- **测试**：路由表每个 cue id 在 catalog 中存在（防止改名后静默失声）；节流；`hash_state` 不因音频改变；headless 静默。
- **审查**：常审。 **窗口**：Solo 跑一遍 `course_f_playable`，逐个机关听。
- **不做**：联机路径（B2）；新素材；改任何玩法数值。

### B2 联机对局音频与正式素材入库

- **交付**：`match_audio_source.gd` 从相邻两份权威快照 diff 派生事件（耐久归零 → 碎；`accepted_count` 上升 → 检查点；`finish_tick` 出现 → 冲线；位姿 y 上升沿 → 跳的近似），远端玩家走 3D 定位；人类提供的正式素材替换临时 WAV，落 `game/content/audio/sfx/` 与 `music/`，走 Git LFS（[CD-51 §2](../../Confirmed-docs/50-engineering/51-dev-environment.md) 已规定原始音频与运行时压缩音频进 LFS）；音频资产预算门禁（格式 / 采样率 / 声道 / 时长 / 单文件体积 / 总体积）进 CI，数值落 CD-11 §8.3。
- **测试**：快照 diff 派生事件的正反例（坏帧 / 乱序 / 重复 tick 不重复播）；预算门禁正反例（超限判失败、0 个音频文件时明确输出"什么都没查"）。
- **审查**：常审；素材许可由人类事前确认（宪法第十八条）。 **窗口**：两个客户端进同一房，听得见远端玩家动作。
- **诚实边界**：§3.5 全部适用，尤其"跳跃与硬直是位姿近似，会漏播"与"OGG 短音效解码开销未实测"。

### C1 第 4 张官方赛道 + 课表落点收敛

- **交付**：`course_04.json`，须满足 [CD-61 §4.1](../../Confirmed-docs/60-plan/61-milestones.md) 夹具全部条目（起终点、3 个顺序检查点、上层传送、区块传送、周期障碍、可破坏障碍、爆破道具、安全路线 + 危险捷径）；加进 `backend/contracts/src/official_courses.ts` 与 `game/src/shared/official_traprush_courses.gd`；`bot_run_cli.gd` 默认覆盖；GUT slow 与 nightly 覆盖；顺带把散落的课表引用收敛到这两处单一事实源。
- **测试**：编译零问题码；可达性可完成；HTTP 白名单正反例；`res://` 路径注入仍被拒。
- **审查**：常审。 **窗口**：大厅选 `course_04` 联机跑完一局并出结算。

### C2 第 5 张官方赛道

同 C1，主题与 01–04 差异化。做完 M5 的官方课数量落在 CD-61 要求的 3～5 张上限。

### C3 创作者发布闭环客户端接线

- **交付**：编辑外壳「发布」按钮——验证器全绿才允许 → 编译 bundle → 取得签名 → `POST /content/publish` → 回显 version / latest，失败码可读；`ContentPlazaEntry` 改走真 `GET /content/plaza`，四标签排序生效，列表项能直接 Solo 试玩。
- **审查**：**深审**（安全边界）。
- **必须先解决的安全问题**：M4b 的 `POST /content/publish` 校验 HMAC 平台签名，意味着调用方持密钥。**平台 HMAC 密钥绝不能进玩家包**，否则任何人都能伪造平台签名。所以客户端不能自己签，必须由控制面在鉴权后代签。这是安全边界变化，属宪法第十八条，见 §5.2 问题 3。**该问题拍板前 C3 不开工。**

### C4 邀请与已签名 UGC 联机

- **交付**：可分享邀请（Web `?room=`、桌面显示 `host:port` + 房间码 + 一键复制）；匹配 HTTP 从"只认官方 enum"扩到"官方 enum ∪ 已签名 `content_id@version`"；MatchHost 传内容引用；MatchServer 取 bundle 并按 M4b 已有机制开局锁 `content_hash`；结算 payload 带上该哈希。
- **审查**：**深审**。这是**协议不兼容变更**（匹配 HTTP 请求体），属宪法第十八条，须人类事前批准，见 §5.2 问题 4。
- **窗口**：A 发布自制课 → 复制邀请 → B 加入 → 两人跑完 → 结算写库带 `content_hash`。

### C5 BotRunner 可达性正式化

- **交付**：五张官方课全覆盖；可达性报告产物（每课可否完成、步数、搜索预算用量、退出码）；nightly 扩展；`tools/bot-runner/` 建薄壳或从 CD-41 §5 删除该目录（二选一，§5.2 问题 5）。
- **审查**：常审。 **窗口**：本章无开发机可见行为（命令行工具），按 CD-52 §3.2 写明原因。

### C6 M5 退出验收

- **交付**：`docs/runbooks/network-fault-check.md`（延迟 / 抖动 / 丢包 / 乱序 / 重复包 / 短时断线重连 / 恶意高频 / 篡改帧的编号步骤，只写"怎么执行"，清单本身仍归 [CD-53 §2.5](../../Confirmed-docs/50-engineering/53-testing-and-ci.md)）；`docs/runbooks/playability-signoff-traprush.md`（项目负责人逐项签署：操作手感、机关可读性、路线选择、失败反馈、**音频反馈**、结算清晰度、创作流畅度、外人 5 分钟上手）；全闭环走查一次；CD-61 M5 退出回写 + CD-53 变更记录 + 两份 `.cursor/rules` 指向下一动。
- **审查**：轻审 + 人类签署。
- **待拍板**：网络故障注入工具选型（§5.2 问题 6）。

## 5. 拍板状态

### 5.1 已拍板（2026-09-10）

| 项 | 结论 |
|---|---|
| 章节划分与顺序 | 照 §4 的 11 章执行，从 A1 音频内核开工 |
| 素材格式 | **OGG**（音效与背景音乐都是），人类持续补充；bank 与 catalog 必须支持增量登记 |
| 模块目录 | `game/src/audio/`，自愿等同宪法第二十三条严格类型强度（**不改宪法条文**，只在 CD-41 §5 声明） |
| Autoload | **不加**。显式实例 + 宿主节点挂载，测试与 headless 可控 |
| 总线与默认音量 | Master / Music / Sfx / Ui / Ambience 五条；Master 0 dB、Music −6 dB、其余 0 dB |
| 音频资产预算 | 已落 [CD-11 §8.3](../../Confirmed-docs/10-product/11-scope-and-platforms.md)（该节是所有者，本文件不复述数值） |
| §3.4 素材映射 | 照办：击杀拆成推击命中 + 他人环境失败；gameover 拆成环境失败复位 + 结算收束；选择角色先登记为通用 UI cue。**不发明击杀与失败态** |

### 5.2 仍待拍板（AI 不得自选，宪法第五节与 [CD-63](../../Confirmed-docs/60-plan/63-open-decisions.md) 使用规则）

| # | 问题 | 卡住哪章 | AI 推荐 |
|---|---|---|---|
| 1 | 素材**来源与授权**（宪法第十八条：许可证需人类确认） | B2 | 给出来源与许可证文本；自制或 CC0 最省事 |
| 2 | 第 4 / 第 5 张官方课的主题与机关组合 | C1（**04 已拍**）、C2 | 04 = 垂直塔（电梯 + 弹射 + 压板，考验上下层）**已拍**（2026-09-11）；05 = 双路线竞速（安全长路 vs 需打碎能量墙的短路）仍待 |
| 3 | 发布签名密钥去向（**阻断项**） | C3 | 客户端不持密钥；控制面在账号鉴权后代签。安全边界变化，须明确批准 |
| 4 | 匹配 HTTP 扩到已签名 UGC（**阻断项**） | C4 | 批准后再开工；协议不兼容变更 |
| 5 | 两个小目录：`tools/audio-bank/` 建不建、`tools/bot-runner/` 建还是从 CD-41 删 | A2（**已执行推荐项**）、C5 | A2 已把 bank 校验并入 `tools/content-validator/`，不新建 `tools/audio-bank/`。`tools/bot-runner/` 仍属 C5 |
| 6 | 网络故障注入工具 | C6 | Windows 用 clumsy、Linux 用 `tc netem`；外部工具不入库，仍需点头 |

**C1 本刀：04 已拍。** 05 仍待 C2。下一刀 C2 或 B2（素材一到可插队）。B2 的第 1 项（素材来源与授权）在正式 OGG 入库前必须有答案。

## 6. M5 退出条件

CD-61 §2 M5 的验收句不变：完整完成"编辑—预览—邀请—发布—游玩—单局结算"闭环。本文件补充可核对的形式：

1. 官方课 5 张全部可选、可联机、可完成，bot-run 与 GUT slow 全绿；
2. 自制课能从编辑器发布 → 广场可见 → 邀请他人 → 联机跑完 → 结算写库带 `content_hash`；
3. 音频系统在 Solo / Preview / 联机三条路径都有声，headless 与 CI 静默，`game/src/audio/**` 通过零玩法词汇的红线扫描；
4. 网络故障 runbook 与可玩性清单各走一遍并由人类签署；
5. 导出、Android / iOS 烟测、公开 TLS **不是** 本号退出条件（CD-61 已明确）。

## 7. 本文件不做的事

- 不定 Rule VM 的后续章（M4a 已收口，其余属未来）；
- 不碰 BASTION（M6 / M7）；
- 不改推击力度、爆破半径、道具重生（D-F4 / D-F5 / D-F6 保持现值）；
- 不改 Tick / 快照 / 心跳 / 插值数字（E3 已锁）；
- 不做字体入包、Android / iOS 烟测、触控 UI（一期收尾）；
- 不发明 M8。
