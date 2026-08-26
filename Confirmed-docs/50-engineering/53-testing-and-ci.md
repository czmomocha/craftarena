# CD-53 测试、性能观察与 CI 门禁

> 文档 ID：CD-53
> 单一事实源：测试优先级与强度策略、七类测试层级、性能观察参考值、CI 门禁分级、Definition of Done、首批测试用例
> 加载建议：写测试、改 CI、判断任务是否完成时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第十、十七、二十四条
> 相关：[CD-52 AI 协作规范](52-ai-workflow.md)、[CD-43 网络与回放](../40-technical/43-networking-and-replay.md)、[CD-61 里程碑路线](../60-plan/61-milestones.md)、[CD-62 风险登记册](../60-plan/62-risk-register.md)
> 派生自：初稿 v0.2 §48–§52、附录 B

## 1. 测试原则

优先级：

```text
权威正确性
> UGC 安全
> 可回放与可复现
> Edit / Hot Publish 可靠性
> 网络鲁棒性
> 性能
> 表现质量
```

AI 生成代码必须比普通手写代码有**更强的自动化证据**，因为其产出速度更快，也更容易快速放大错误。

### 1.1 不对称强度策略

- 仿真、命令、Schema、Rule VM、内容编译和热发布坚持**测试先行**；
- 纯表现与 UI 可先实现，再补烟测和视觉检查；
- 网络故障场景只做临时人工测试，不设固定频率；
- 不建立自动性能回归门禁，出现明显问题后再分析优化；
- 纵向切片期间不组织外部真人试玩，由项目负责人按清单签署玩法结论。

> 后四项是明确接受的项目风险，**不能**在对外材料中描述为"已充分验证"。

## 2. 测试层级

### 2.1 静态与 Schema 测试

- GDScript 语法和类型错误；
- 禁止 API 扫描；
- Schema 正反例；
- 字段范围和默认值；
- 引用完整性；
- 稳定 ID 重复；
- 规则图类型；
- 无界循环、递归和超预算检测；
- 内容版本兼容性。

### 2.2 单元测试

- 固定 Tick；
- RNG；
- 移动和检查点；
- 传送可达性与循环检测；
- 障碍耐久和重生；
- 道具效果；
- 塔锁敌优先级；
- 伤害、减速和增益；
- 金币和波次；
- 单局排名；
- 命令权限与频率限制；
- EditCommand 反向命令。

### 2.3 集成测试

- AuthoringWorld 编译为 SimulationBundle；
- Preview 安全 Tick 应用；
- Headless 服务端与多个客户端；
- 断线重连；
- 内容下载和哈希校验；
- P2/P3 新版本只影响新房，P0/P1 按补丁规则进入运行房；
- 回滚后新房恢复旧版本；
- 离线模式不产生在线写请求。

### 2.4 回放测试

- 相同版本、种子和输入得到相同关键状态哈希；
- 定点位置、计时、经济与伤害在客户端和服务器测试夹具中一致；
- TRAPRUSH 传送、破坏和冲线可复现；
- BASTION 障碍布置、建塔、镜像波次和胜负可复现；
- 版本不匹配时拒绝播放；
- 周期关键快照可以恢复并继续执行；
- P0/P1 PatchHash 按原顺序重放。

### 2.5 网络仿真（人工清单，非门禁）

网络故障测试**不进入自动 CI 门禁**，也不设固定执行节奏。有需要时使用统一人工清单覆盖：

- 延迟；
- 抖动；
- 丢包；
- 乱序；
- 重复包；
- 短时断线；
- 基线丢失；
- 恶意高频命令；
- 篡改序号、Tick、目标 ID 和 Payload。

香港真实环境形成样本后，再根据 P90/P95 数据决定是否建立自动门禁，以及是否为 TRAPRUSH 引入 ENet/WebRTC。当前选择只保证"有检查清单"，**不保证稳定回归覆盖**。

### 2.6 UGC 安全测试

- 超大实体数；
- 无限生成；
- 传送循环；
- 不可达终点；
- 塔防路径彻底封死；
- 深层嵌套；
- 引用环；
- 压缩炸弹；
- 非法资源类型；
- 越权组件和字段；
- 规则 gas 耗尽；
- 恶意字符串和异常 Unicode；
- 旧 Schema 内容迁移。

### 2.7 Edit 与热发布测试

- 连续 Undo/Redo 100 次；
- BatchCommand 原子性；
- Preview Patch 成功与失败回滚；
- AuthoringDocument 桌面/Web 往返与非法快照拒绝；
- Preview 窗口打开/关闭不结算且编辑会话保持；
- Preview 带 `transform` 的实体映射为 1 米占位盒，失败补丁不留幽灵节点；
- Preview `portal_link` gizmos：`two_way` / `one_way` 连线、`dangling` 只标源点、失败补丁不留幽灵线；
- Preview 检查点 `order` 标记与唯一顺序连线；重复 order 不进顺序链；失败补丁不留幽灵标记；
- Preview 可达性叠加：问题码标到有 `transform` 的实体；跨楼层不可达画断段；无实体问题只进状态；失败补丁不留幽灵且不作为写入门禁；
- 编辑外壳：格子上 place 检查点、Undo/Redo、已连接 Preview 跟随写入、关闭只隐藏、未知表面拒绝、不结算；
- 编辑窗口 3D 映射：place 后出现 1 米占位盒；失败/Undo 不留幽灵；编辑 map 与已连接的 Preview map 都跟随写入；
- TRAPRUSH 工具面板：检查点与传送门走格子；两次 Place portal 成 `two_way`；Floor 只改下一次 `cell_y`；Remove last 不留幽灵盒；不结算；
- 验证器详情：空世界列出 `missing_mandatory_path` 且 Focus 失败；悬空传送可定位有 `transform` 的实体；列表跟随编辑、不是写入门禁；已打开的 Preview 叠加同步跟随；不结算；
- 第一张官方赛道：decode 成功且 `reach_ok`；缺通路 / 悬空反例；编辑导入不是写入门禁；不结算；
- 第二张官方赛道：侧向跨层 `two_way` 与第一张布局不同；decode 成功且 `reach_ok`；缺通路 / 悬空反例；编辑导入不是写入门禁；不结算；
- 第三张官方赛道：地面走道可破坏箱 + `one_way` 上楼 + 上层 `two_way` 对，与前两张布局不同，是首张带 `one_way` 连线的官方赛道；decode 成功且 `reach_ok`；编译加载出 4 垫 / 3 传送 / 1 终点 / 1 固体箱；Preview 全程试玩（破箱 → 走垫 → `one_way` 落地 → 上层两垫 → 冲线）；删 `one_way` 传送则跨层不可达；编辑导入不是写入门禁；不结算；
- 对局进程多人仿真循环：1/8 人边界与 0/9 拒绝；两玩家同图独立进度与独立冲线 tick；箱破坏全员共享；重置只动本人；意图不进 tick、`commit_tick` 才推进；同磁带同哈希序列、不同磁带不同尾哈希；无网络、无结算；
- 对局二进制协议 v1：四种意图命令帧与快照帧编解码回环（含 s64 极值）；未接线意图（Shove/Interact）拒绝编码；保留字段非零、版本不符、未知类型、截断、尾随字节均拒绝解码；同帧编码字节恒等；
- 对局进程仿真入口：参数只认 `--key=value`；坏配置（缺课程/人数越界/负 max-ticks）拒绝启动；课程编成 bundle 启动 1~8 人会话；心跳 JSON 含 tick/人数/状态哈希；同参数两次启动同哈希；MatchHost 启动参数含 `--course`/`--players`（纯函数断言，不 spawn 进程）；
- 对局进程实时回路：槽位按需占用/满员拒绝/断开释放复用；坏帧（不可解码/版本错/槽位未占用）拒绝；命令 FIFO 排队、commit_tick 边界才应用、服务端 tick 权威（命令 tick 不信任）；快照帧编解码回环（含箱耐久）；UseItem 经线上帧破箱；全程线上命令走完 course_01 冲线 tick 正确；同命令流两核心同快照字节序列；socket 层为薄层，网络正确性保持手动测试（CD-91 D.8）；
- 实时网关代理：票据缺失/空白/被拒 401；裁决无上游或上游不可达 502；二进制帧双向逐字节转发、文本帧保文本；客户端关闭即关上游；假上游零接触（无票据不建联）；端到端手动冒烟（真客户端→网关→真对局进程，Move 命令位移出现在快照）；
- 控制面真票据：登记 `ws`/`wss` 上游正例与 `http`/带凭据反例；签发后校验返回同一上游；同场可发多张独立票；缺票/未知/过期/已消费 401；签发接口拒绝多余字段；网关 `ControlPlaneTicketVerifier` 走控制面后代理，同一票据第二次升级 401；`GATEWAY_DEV_UPSTREAM` 空白视为未设置；不锁账号绑定与重连补票；
- MatchHost 自动登记上游：拉起后登记同一 `matchId` 与 `ws` 上游正例；spawn 失败不登记；控制面 5xx / 错 `matchId` 杀进程并 502；并发登记占容量；真控制面签发后校验回到该上游；不查库、不锁账号绑定与重连补票；
- MatchHost 等待 listen 后登记：listen 可连后再登记正例；超时或进程先退出不登记、杀进程并 502；等待期间占容量；TCP 探针连上即成功、无监听则超时、abort 即停；探测连 `127.0.0.1`，不查库、不锁真匹配/房间码；
- MatchHost 停止后注销会话：停止/回收/进程退出/关机后注销正例；listen 或登记失败不注销；未用票据校验 401、再签发 404；同 `matchId` 可再登记；邻场不受影响；注销 404 视为成功、5xx 本地已停且显式 DELETE 回 502；不查库、不锁真匹配/房间码/账号绑定/重连补票；
- 真匹配与房间码：建房发码并签发首票正例；按码加入（大小写不敏感）；满员 409；未知码 404、非法码 400；快速游戏加入最旧未满房，无空位则拉起；运维登记不进快速游戏；邻房不受影响；注销后余票 401、再加入 404；拉起失败 502；席位上限拒绝超额签发；不查库、不锁账号绑定/重连补票；
- FIFO 等待队列与预计等待：容量满时建房/快速游戏回 202 与位次、预计等待；轮询直到注销出队后签发票据；两位等待按 FIFO 出队；后续快速游戏可进新房余席，建房不占邻房余席；有空位时快速游戏仍立即加入；按码加入满员仍 409；取消后后位升为 1；已就绪不可取消；过期/未知 404；过期头名跳过；邻票隔离；取消拒绝多余字段；无 MatchHost 仍 503、非容量拉起失败仍 502；出队拉起失败只标记队头；对局注销后未领取就绪票失败；不查库、不锁账号绑定/重连补票；
- 客户端匹配入场与权威快照跟从：201 持票就绪；202 后轮询就绪；位次更新；房间码大小写归一与非法拒绝；满员 409 不入队；队列 DELETE 取消回 idle、就绪不可走队列取消；已就绪取消码仍可轮询；大厅 Cancel 对 connecting / in_match / closed 本地离开、清玩家盒、后续快照不跟、不补票；队列失败/未知/无 MatchHost/拉起失败；多余或缺字段拒绝；邻会话隔离；JSON 整浮点数；快照跟从最新、旧 tick 与坏帧保留上一份；持票后网关 URL、命令 tick=0、Shove 编码且无线上 id、Interact 不编码；大厅窗口快速游戏自动开玩、排队状态、隐藏不采样；不插值、不预测、不结算；
- 权威快照表现映射：玩家位姿映射为 1 米盒；后一快照直接跳到新位姿；人数减少不留幽灵盒；空玩家列表清空；畸形列表与无快照跟从保留上一份；旧 tick / 坏帧不重建；箱子无 3D 节点；大厅 `own_world_3d`；不插值、不预测、不结算；
- 对局大厅赛道几何表现映射：官方 course_01 画出 3 垫 / 2 门 / 1 终点且箱子无 3D 节点；course_02 布局不同且不留上一张门幽灵；空 bundle 清空；缺课 / 空路径 / 坏袋保留上一份；大厅打开即映射默认 course_01，快照更新不改赛道盒；不插值、不预测、不结算；
- 对局大厅可破坏箱表现映射：官方 course_01 画出箱子 40 于拓扑位姿；course_03 布局不同；空 bundle 清空；缺课 / 空路径 / 坏袋保留上一份；快照耐久 0 或未列入撤盒、耐久 >0 在原位恢复；坏快照不重建；大厅打开即映射默认 course_01 箱子，MatchCourseMap / MatchSnapshotMap 仍无箱节点；不插值、不预测、不结算；
- 对局大厅传送连线可视化：官方 course_01 画出 2 条 two_way 条且无方向点；course_02 布局不同且不留上一张连线幽灵；course_03 画出 3 条且 one_way 10 有方向点；空 bundle 清空；缺课 / 空路径 / 坏 dest 袋保留上一份；大厅打开即映射默认 course_01 连线，快照更新不改连线；MatchCourseMap / MatchCrateMap / MatchSnapshotMap 仍无连线节点；不插值、不预测、不结算；
- 对局大厅检查点顺序可视化：官方 course_01 画出 3 个 order 标与 2 条顺序条；course_02 布局不同且不留上一张顺序幽灵；course_03 画出 4 标 / 3 条；空 bundle 清空；缺课 / 空路径 / 坏 order 袋保留上一份；重复 order 只打标不进顺序链；大厅打开即映射默认 course_01 顺序，快照更新不改顺序 gizmos；MatchCourseMap / MatchCrateMap / MatchPortalLinkMap / MatchSnapshotMap 仍无顺序节点；不插值、不预测、不结算；
- 对局大厅进度与单局名次：已冲线按 `finish_tick` 再按槽位；未冲线排在其后按 `accepted_count` 再按槽位；无人冲线无 MVP；缺字段 / 负进度 / 坏快照拒绝并保留上一份；空名单清空；后一快照标签直接跳到新位姿；人数减少不留幽灵标；官方 course_01 未冲线显示 `n/3`；2 人会话一人冲线后 slot 0 为 `#1` 且为 MVP；大厅 HUD 写出 `standings=` / `mvp=`；MatchCourseMap / MatchCrateMap / MatchPortalLinkMap / MatchCheckpointOrderMap / MatchSnapshotMap 仍无名次节点；不插值、不预测、不结算、不锁路径距离；
- 机关狂奔离线单人试玩：官方 course_01 开玩即 1 人快照且 HUD 持续「离线试玩，成绩不上传」；Web / 缺课拒绝；二次开玩须先停；Move 改本地位姿且 `try_advance` 推进 tick；Solo 仅一枚胶囊故 Shove 无目标不编码；Interact 不编码；course_01 五步冲线后本地 `finish_tick=0` 且 `allows_online_writes=false`；大厅 Solo 开玩不发 HTTP，在线进行中不能开离线，离线进行中不能开匹配，Cancel 停离线并清玩家盒；Solo 复用官方赛道选择器；不插值、不预测、不结算、不锁幽灵；
- 对局命令门禁与双人 Headless 冲线：同槽同 tick 第二条命令拒绝且位姿只 +1 格；断开丢弃排队，重入后 commit 不继承旧 Move；快照帧不能当命令；两槽各一条 FIFO；官方 course_01 两槽经 MatchRealtime 各 5 步后 `finish_tick=4` 且 MVP 为 slot 0；同磁带同快照字节与状态哈希；冲线后 `allows_settlement` 为 true；`allows_online_writes` 为 false；不插值、不预测、不锁墙钟速率；
- 机关狂奔单局结算写库：未全员冲线拒绝生成；course_01 两槽冲线后 payload 含 `finish_tick=4` / `pad_total=3` / `mvp_slot=0`；同磁带同哈希；心跳未完成无 settlement、完成后带上；离线冲线后 `allows_settlement` 仍为 false；控制面 POST 一次 201、第二次 409；注销会话后 GET 仍在；未知场 / `mmr` 多余字段 / 未完成 `finishTick` 拒绝；MatchHost 活场心跳或停止前从心跳 POST，无记录则不写，写失败不注销；不生成 MMR、不锁限时未全员结算；
- 断线重连补票：入场票绑定席位，校验返回 `seat`；网关上游 URL 带 `slot=`；`occupy_slot` 占用指定席，非法/已占拒绝；断开丢排队、同槽再占恢复位姿；已消费票补发同席位新票且不占额外席；未消费/已作废/错场/未知票/多余字段拒绝；注销后不能补票；客户端 READY 补票换票，大厅 `IN_MATCH` 关闭后自动补票并跟从新快照；大厅 Cancel 本地离开不补票；不锁账号绑定、插值/预测、离开对局 HTTP；
- 官方赛道选择：HTTP JSON 只用 `course_01` / `course_02` / `course_03`；空 body 默认 `course_01`；快速游戏只进同一赛道未满房；队列记住 `course` 且不占邻课余席；按码加入拒绝 body 并回该房课程；未知课 / `res://` 路径 / 多余字段 400；MatchHost 按 id 映射 `--course=` 并登记；大厅跟从响应编译同一赛道，Solo 复用选择器；不锁账号绑定、插值/预测；
- 人数按场下发：HTTP JSON `seats` 为 1～8；空 body 默认 2；快速游戏只进同课同人数未满房；队列记住 `seats` 且不占邻人数余席；按码加入拒绝 body 并回该房人数；0 / 9 / `players` 别名 400；MatchHost 按场 `--players=` 并登记；大厅选人数；Solo 仍为 1 人；不锁账号绑定、插值/预测；
- 对局快照插值：tick 前进保留上一份玩家位姿；无上一份贴最新；`t=0` 亚格子显示上一份且进度取最新、`t=SCALE/2` 中点、`t=SCALE` 显示最新；yaw 最短弧；≥1 格立即贴最新；畸形最新拒绝；新槽贴最新；大厅亚格子两步到最新且隐藏不推进；箱子耐久跟最新权威；1 格跳仍贴最新；大厅 Cancel 停 in_match（清盒、后续快照不跟、不补票）；不预测、不锁插值窗口；
- 对局本席移动预测：入场就绪 JSON 带 `seat`（0 起，须 < `seats`）；补票回同一席且错席拒绝；`MatchLocalPredict` 把 Move/Jump overlay 叠在最新权威本席位姿上，本席不插值、远端仍插值；更新 tick 硬贴并清 overlay；同 tick 不清；溢出贴最新；未绑定/越界席位不叠；畸形最新拒绝；大厅 WASD 立即移动本席盒，下份快照硬贴；Solo 不叠 overlay；箱子/赛道不预测；大厅 Cancel 停 in_match；不锁远端外推碰撞、平滑对账、插值窗口；
- 对局大厅本席预测避开最新权威固体：空地 overlay 仍生效；预测胶囊与活箱重叠则本席停在最新权威且 overlay 仍累积；耐久 0 / 省略 / 畸形箱不挡；远端最新位姿重叠不叠、远离仍叠；大厅线上向 +Z 活箱走青盒不穿橙箱，打碎后可过；注入 2 人快照撞远端最新位姿则停；Solo 不叠 overlay；
- 真人命令才续租：空 tick / 快照当命令 / 未占用槽 / 零位移 Move / 官方赛道 Jump 不更新 `last_valid_input_tick`；合法 Move 与打碎箱子更新为该次 `commit_tick` 后的权威 tick 且后续空 tick 保持；心跳 JSON 含 `valid_input_tick`（默认 -1）；MatchHost 解析最后一条 `match_tick` 的 ≥0 整数才续租，缺字段 / 负数 / 非整数 / 垃圾行不续；同一 tick 不重复续、前进后推迟 idle；带 settlement 且 `valid_input_tick=-1` 仍 flush、不续租；不改 30 分钟租约与 10 分钟 idle 数字；
- 网关进程内 TLS：未设置证书仍明文 `ws`；成对 PEM 路径进入 `config.tls`；只设 CERT 或只设 KEY 抛错；`readTlsCredentials` 读夹具 PEM；`wss` 二进制往返仍通且上游仍 `ws`；同一 TLS 端口 `/healthz` 200；未信任自签的客户端拒绝握手；大厅默认 HUD `tls=off`，`gateway_base` 为 `wss` 时 `tls=on`；`wss` URL 才返回 `TLSOptions`；
- 权威 Move 位移门禁：`MOVE_STEP_MAX` 等于 `Fixed.SCALE`；一格正/负/对角 Move 应用；`SCALE+1` 拒绝且位姿不变；线上超限帧可入队但 apply 失败、不续租；
- 对局基础推击：命令 id 5=`ShoveIntent` 编解码且保留字段须为零；Interact 仍拒绝；两席出生点 Shove 把较低邻座沿 -Z 推开 `SCALE/4`；无目标 / 超限 step / 邻域外拒绝且位姿不变；三席选最近席；同 tick 冷却不位移、commit 后可再推；线上帧可入队并续租；大厅可见窗口 F 上升沿编码、隐藏不采样；Solo 无目标；
- 出界复位：`STUB_HALF` 为 8 格；闭区间边界上不算越界；超 `max_x` / 低于 `min_y` 写回起点落点且不 tick；空区间拒绝；会话默认关闭时两格 Move 停在 `2*CELL`；开启 `half=CELL` 后两格 Move 弹回出生且不验收下一垫；验收第二垫后再出界进度不回退；`enable_play_range(0)` 关闭；boot / Solo / Preview 壳打开 ±8 格桩；
- 周期机关进拓扑：v1 bundle 必含 `hazards`（可空）；袋为 `entity_id` / `x` / `y` / `z` / `cooldown_ticks`；缺键 / 缺 cooldown / 重复 id 拒绝；编译自带 `hazard`+`transform` 的实体；与检查点/传送/终点/可破坏同实体整份拒绝；官方三张赛道 `hazards.size()==0`；`((tick_index / cooldown_ticks) % 2) == 0` 为固体、`cooldown_ticks < 1` 始终固体；对局 `commit_tick` 挡→开→挡；Preview 意图不切换、`try_advance_play` 才切；壳按钮 `AdvanceTick` 调用同一 API；不读 damage/knockback、不挤出、不伤害；
- 对局大厅周期机关表现映射：官方三张赛道 0 个盒；编译袋画出洋红 1 米盒；tick 固体半周期显示、开放半周期撤盒且 `live_solid_boxes` 变空；缺课 / 坏袋保留上一份；大厅 HUD `hazards=n/m`；本席 overlay 撞固体机关停在权威、开放后可过；Preview `hazard` 占位同一色，开玩后非固体隐藏；不改协议、不发明 `period`、不读 damage/knockback；GUT 906；npm test 319；人类真机步骤见 [章节真机清单](../../docs/runbooks/chapter-device-check.md) 本刀（人工检查，非 CI 门禁）；
- 对局进程动作数值占位桩：boot 后 `jump_dy`/`support_dy`/`use_item_reach_dz` = `Fixed.SCALE`、伤害 1、reach dx/dy = 0（与 Preview 对齐，不是产品数值）；官方 `course_01` 出生点 UseItem 打碎 +Z 箱且快照耐久 0；Solo 出生点 UseItem 撤橙盒；官方赛道 Jump 仍为空操作；
- 对局大厅本席摄像机跟随：`follow_slot` 把 SnapshotCamera 对准该席表现位姿（偏移与 Preview 相同）；缺席/空名单看原点；Solo 跟本地盒、线上跟本席不跟远端；Cancel 回到原点；
- 对局大厅本席移动朝向：大厅 WASD 把 8 向离散水平 `yaw_bam` 写入已有 Move（W=0 为 -Z；省略哨兵仍是 `-1`）；`MatchLocalPredict` overlay 朝向，更新 tick 硬贴；Solo 走本地权威；玩家盒带 local -Z 面向标记；显式 `try_encode_intent(..., -1)` 仍省略朝向；不发明 atan2、不锁产品转向、不改 Preview WASD；
- 对局大厅本席分色：`follow_slot` 把本席盒涂成 `OWN_ALBEDO`（青）、远端仍 `REMOTE_ALBEDO`（海军蓝）；名次标本席前缀 `*`；`follow_slot < 0` 全员远端色；Solo / 线上 seat 0 与 seat 1 对调；Cancel 清 `follow_slot`；不是产品皮肤；
- 对局大厅本席检查点占用高亮：本席 `accepted_count` 把垫涂成已验收 / 当前目标 / 未到；`accepted_count < 0` 全员原垫色；Solo 出生点已验收第一垫；走到第二垫后当前目标前移；线上跟本席进度不跟远端；Cancel 恢复原垫色；不是走路可达；
- 对局大厅本席冲线闭环表现：本席 `finish_tick` 把终点涂成未到 / 当前目标 / 已冲线；HUD `pads=n/m` / `finish=n`；Solo 走完 course_01 后 `result=`；线上仅本席垫齐时终点变当前、仅全员冲线才 `result=`；Cancel 恢复原金色且去掉 `pads=` / `result=`；不是结算写库或走路可达；
- 对局大厅本席复位与楼层/箱子 HUD：开玩 HUD 写 `floor=n`（本席权威 `y / Fixed.SCALE` 向零，不用插值采样）与 `crates=n/m`（活着的箱 / 编译袋总数）；Solo 出生 `floor=0` `crates=1/1`；UseItem 打碎后 `crates=0/1` 且总数不变；进传送门后 `floor=1`；R 回到最近已验收垫且进度不回退、`floor` 回 0；线上楼层跟权威 y；Cancel 去掉 `floor=` / `crates=n/m`；不是长按时长或结算写库；
- 大厅只读结算面板：MatchHost 对 running 场心跳一旦带 settlement 就 POST（409 已写入），停止前再 POST；大厅线上全员冲线后 GET，200 写 HUD `settled=`；404 不把 join 打成 FAILED；畸形 200 不写面板；Solo 冲线只有 `result=`、不 GET；Cancel 清掉 `settled=`；客户端 `allows_settlement` 仍为 false；
- 内部开发 EditorPlugin：`plugin.cfg` 入库；`project.godot` 启用 GUT + authoring_editor、不含 `godot_ai` / `_mcp_game_helper`；host 打开已有外壳，关闭只隐藏并保持会话，`detach` 释放，不结算；
- 本地草稿恢复：成功写入落 `latest` 且文件非空；空会话打开恢复；恢复后工具条下一个 Place 使用新 id；编辑器 `plugin.gd` `@tool` 落盘；`world_committed`；失败写入不改草稿；损坏 / 多余键拒绝；拒绝写入 `res://`；检查点最多 30；不结算；
- 编辑写入自动进 Preview：place / remove / Undo / Redo 都到达已连接 Preview 且两个世界 revision 同步；`set_component` 等级按 Preview 世界算（按编辑世界算会低报被拒）；失败写入不转发且仍跟随；越界补丁与整份 `import_document` 脱同步且不回滚编辑；无 Preview 时不谎报跟随；窗口隐藏仍跟随；状态栏 `follow` 可见；不结算；
- TRAPRUSH 拓扑编译：空世界编成空 bundle；两张官方赛道编出检查点垫、`two_way` 传送、一份终点占用与一份侧向可破坏箱且布局不同；传送袋含源点 `x/y/z`；`finish` 为 0 或 1 个袋；`destructibles` 为 0 或多份袋（含 `durability`）；`hazards` 为 0 或多份袋（含 `cooldown_ticks`）；官方三张赛道 `hazards` 为空；`dangling` 省略、`one_way` 保留；检查点或缺源点/`finish`/可破坏/机关 `transform` 整份拒绝；两份终点拒绝；可破坏或机关与检查点同实体拒绝；缺 `destructibles` / `hazards` 键拒绝；多余键拒绝；加载后垫盒、传送源点盒与终点盒非固体且可占用查询；可破坏箱固体（`durability` 0 已打开）；机关盒固体（tick 0 为固体半周期）；`one_way` 可落地；`two_way` 走 `try_land_exit` 而非 `follow`；不 tick 进加载器、不结算；
- Preview 试玩：两张官方赛道能开玩且玩家占用最小 `order` 垫；空垫 / 缺 `transform` 拒绝；开玩进入 tick 后补丁拒绝，Stop 后可再补丁；`try_advance_play` 推进 tick 且不结算；Play 画出玩家表现桩，Stop 清掉；开玩期间编辑写入脱同步且不回滚编辑；开玩后 `MoveIntent` 改 XZ 且不推进 tick；WASD 按世界方向编码；未开玩 / 缺字段拒绝；窗口隐藏不采样键盘但仍接受直接意图；开玩占用第一垫即验收；走到同层次一垫验收下一 id；跳点 / 未重叠 / 未开玩拒绝；状态 `pads=n/m`；走进传送源点盒经 `try_land_exit` 单跳落地；`two_way` 落点门闩不往返弹跳；出口占用则等待且本帧不位移；传送不代验收检查点；状态 `floor=n`；官方赛道能走到上层检查点；全部垫完成后走进终点盒经 `try_cross` 记 `finish_tick`；缺垫或缺重叠拒绝；传送不代冲线；状态 `finish=n`（未冲线为 -1）；开玩后 `ResetToCheckpointIntent` 回到最近已验收检查点落点且不回退进度；未验收则回起点偏移；客户端坐标忽略；传送后门闩清掉；已冲线后重置仍保留 `finish_tick`；窗口可见时 Reset / R 上升沿采样，隐藏不采样；开玩后 `UseItemIntent` 在调用方 reach 姿态与固体箱盒相交时才扣耐久；零 reach / 零伤害 / 未开玩拒绝；摧毁后箱盒非固体且 MoveIntent 可穿过；客户端命中字段忽略；状态 `crates=n/m`；窗口可见时 Use item / `use_item` 上升沿采样，隐藏不采样；开玩后 `JumpIntent` 经接地检查（调用方 support 探测固体支撑）才按调用方 jump_dy 上移直到阻挡；未接地不位移仍回 ok；零 jump_dy 不位移；未开玩拒绝；客户端高度字段忽略；窗口可见时 Jump / `jump` 上升沿采样，隐藏不采样；Interact / Shove 仍拒绝；出界复位默认关闭，开启紧区间后两格 Move 弹回起点且不验收下一垫；壳打开 ±8 格桩；周期机关经 `TraprushHazardCycle` 在 `try_advance_play` 于 `world.tick()` 之后按 `cooldown_ticks` 切换固体，意图不切换；壳 **Advance tick** 调用同一 API；不接重力、不计数 N、不写硬直、不结算、不锁爆破表或跳跃数值；
- 发布中途进程退出；
- 签名失败；
- `latest` 指针原子切换；
- 新旧对局并存；
- 一键回滚；
- 被下架内容不能创建新房；
- 已开始对局仍能按锁定版本完成。

### 2.8 平台测试

- Windows 键鼠；
- Android 触控、切后台、恢复；
- iOS 触控、切后台、恢复；
- 分辨率和安全区；
- Compatibility 渲染一致性；
- Windows/macOS Chrome、Edge 最新两个大版本的 Web 单线程和资源加载；
- 微信包体、文件系统和 API 适配；
- 中端基线设备的帧率与内存，设备与帧率目标见 [CD-11 §8](../10-product/11-scope-and-platforms.md)。

## 3. 性能观察参考

一期**不建立固定性能基准或自动阻断门禁**。以下值只用于埋点和问题定位，不能作为当前已保证的发布指标；出现明显卡顿、服务器超载或用户反馈后再做专项分析。

### 3.1 TRAPRUSH

| 指标 | 目标 |
|---|---|
| 服务端 Tick | 待纵向切片实测决定 |
| 8 人与典型 UGC 实体量的 Tick P99 | 持续记录，不设当前门禁 |
| 客户端观察帧率 | 见 [CD-11 §8](../10-product/11-scope-and-platforms.md) |
| 单客户端快照带宽 | 以压测确定，必须持续记录 P95/P99 |
| 弱网 | 香港真实样本形成后定义 |
| Edit 到双人预览 | ≤ 30 秒 |

### 3.2 BASTION

| 指标 | 目标 |
|---|---|
| 服务端 Tick | 待纵向切片实测决定 |
| 典型高兵潮 Tick P99 | 持续记录，不设当前门禁 |
| 塔锁敌 | 使用空间网格，不允许全量 O(N×M) 扫描 |
| 弱网 | 香港真实样本形成后定义 |
| 同 Archetype 单位 | 批量更新与批量增量编码 |
| Edit 到双人预览 | ≤ 30 秒 |

## 4. CI 门禁

### 4.1 每次变更

- 语法与类型检查；
- `shared/`、`simulation/`、`ugc/`、`server/` 警告视为错误；
- 受影响单元测试；
- Schema 验证；
- 禁止 API 和依赖检查；
- 编辑文件的 linter 诊断；
- 功能 PR 自动生成独立公开 Web 预览。

#### 当前实现状态

上面是本项目的目标门禁清单，不是已经生效的清单。`.github/workflows/ci.yml` 在 M0 只启用了其中一个子集，已于 2026-08-20 在 GitHub Actions 的 Linux runner 上首次跑绿：

| 门禁项 | 状态 | 实现方式 |
|---|---|---|
| 语法与类型检查 | 已启用 | 逐个 `.gd` 文件跑 `--check-only`（`game/src`、`game/tests`、`game/addons/authoring_editor`；不含 GUT）；`backend/`、`tools/` 跑 `tsc --noEmit` |
| 核心目录警告视为错误 | 已启用 | GDScript 由 `project.godot` 全局配置（[ADR-0001](../../docs/adr/0001-strict-gdscript-typing-gate.md)）并由 GUT 断言守护；TypeScript 由 `tsconfig.json` 的 strict 系列保证 |
| 单元测试 | 已启用（全量，非"受影响"） | GUT 跑 `res://tests/unit`；后端跑 `node --test` |
| Schema 验证 | 已启用（L0 信封 + Component Schema v1 + AuthoringDocument + SimulationBundle） | `tools/content-validator/` 对 `backend/contracts/schemas/` 做正反例（含 `component_record`、`authoring_document` 与 `simulation_bundle`），并由根目录 `npm test` 收集。未覆盖 Rule VM 图。未引入 Ajv（新依赖属宪法第十八条人类门禁）。字段名单见 [CD-42 §1.2](../40-technical/42-contracts-and-rulevm.md#12-字段标识符v1)、[CD-32 §1.4](../30-ugc/32-editor-and-preview.md#14-共同数据模型) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点) |
| 禁止 API 和依赖检查 | 已启用（宪法红线子集） | `tools/redline-scanner/` + CI step `npm run redline-scan`：`simulation/` 禁 SceneTree/`float`、共享核心禁 `.gdextension`、`game/src` 禁 Godot 3 高信号符号、`game/` 禁 `.cs`/`.csproj`/`.sln`（GUT 仍保留同一条）。Godot 3 黑名单是[官方更名表](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html)的高信号子集，不是穷尽。第二十三条仍由 ADR-0001 覆盖 |
| 编辑文件的 linter 诊断 | 未实现 | 依赖开发机 IDE，未进 CI |
| PR Web 预览 | 未实现 | 等 Web 导出与沙盒环境落地 |
| Godot AI MCP | **不进 CI** | 阶段 C 生产级启用已通过（2026-08-23），仍只服务本机打开的编辑器；Headless / GUT / `npm test` 仍是门禁。不得把 `test_run` / `McpTestSuite` 写成自动回归。见 [CD-51 §7](51-dev-environment.md)、[ADR-0003](../../docs/adr/0003-godot-mcp-selection.md) |
| Bugbot | **非门禁** | 已拍板引入（[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 6）。本地 `/review-bugbot` 已于 2026-08-21 跑过。`.cursor/BUGBOT.md` 已入库。**GitHub PR 侧已跳过**（Cursor SCM 安装对不上）；合入继续靠本表已启用的 CI + [§4.5](#45-pr-合并规则) 人类批准。不得描述为已覆盖的合并门禁。配置见 [CD-52 §5.2](52-ai-workflow.md) |

按宪法第二十四条，**未在本表标为"已启用"的项目不得在任何材料中描述为已覆盖**。新增门禁时同时改本表和 workflow。

另有一条平台缺口：CI 目前只跑 Linux runner。CD-51 §1 规划的自托管 Windows Runner 尚未搭建，因此 **Windows 与 macOS 上的引擎行为都没有任何自动回归**，只能靠开发机按 [环境烟测清单](../../docs/runbooks/environment-smoke-test.md) 人工执行。macOS 上 `--check-only` 在类型错误时退出码仍为 0，本地门禁看日志；Linux CI 仍按退出码收集失败，这条失败路径未在桌面开发机上按 Linux 复测。

### 4.2 每日

- 全量 GUT；
- Headless 多客户端集成；
- 固定回放；
- UGC Golden Content。

### 4.3 每周

- 依赖与许可证变化检查；
- Windows/Android 导出烟测；
- 内容发布和回滚演练。

### 4.4 发布候选

- 全量平台烟测；
- 零阻断级错误；
- 回放一致；
- 新旧内容版本并存；
- 回滚演练通过；
- 项目负责人完成玩法清单签署；
- 人类完成安全与发布确认。

### 4.5 PR 合并规则

PR 合并必须 CI 全绿并至少获得一次人类批准；AI 审查不能替代人类。GitHub PR 侧 Bugbot 已跳过，不构成本条的「一次人类批准」。若日后恢复，其 check 默认仍为 `neutral`，勾选该 check **不会**因为发现问题而阻止合并。

[ADR-0004](../../docs/adr/0004-multi-agent-adoption-timing-and-architecture.md) 决策 4 把 GitHub 分支保护定为隔离分支提交的硬前置。目标配置：

- `main` 禁止直推，必须走 PR；
- 要求 CI 通过；
- 要求一次人类批准；
- `CODEOWNERS` 覆盖 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/`。

**当前（2026-08-21）：`main` 分支保护已由 GitHub API 复核。** 已启用：要求 1 次批准、过期 review 作废、Require review from Code Owners、禁止 force push、禁止删除 `main`、要求状态检查通过且分支与 `main` 同步。必过检查：`Backend typecheck and tests`、`Godot check-only and GUT`。未启用：`enforce_admins`（仓库管理员仍可绕过）。`.github/CODEOWNERS` 覆盖 `game/src/shared/`、`backend/contracts/`、`Confirmed-docs/`、`.github/`。A4 回路已走通一次： [PR #1](https://github.com/czmomocha/craftarena/pull/1)。此后 Agent 可在隔离分支上创建提交，仍不得向 `main` 提交或推送（[CD-52 §1.1](52-ai-workflow.md)）。

每个 PR 的 Web 预览公开访问，但必须使用独立临时沙盒命名空间、测试数据和可销毁凭据，关闭 PR 后清理。合入 `main` 后更新稳定测试链接。

## 5. Definition of Done

任务只有同时满足以下条件才算完成：

1. 功能行为符合任务单；
2. 有自动化测试或明确说明为何无法自动化；
3. 测试实际运行通过；
4. 无新增错误级日志；
5. 网络和权威边界没有被绕过；
6. UGC 输入经过验证；
7. 性能未明显回退；
8. 文档或 Schema 已同步；
9. AI 能解释关键实现和失败模式；
10. 人类完成必要审查；若本章有开发机可见行为，按 [章节真机清单](../../docs/runbooks/chapter-device-check.md) 本刀的编号步骤执行，不得用「AI 说看起来对」代替。未勾选真机不等于自动门禁已覆盖（宪法第二十四条）；义务口径见 [CD-52 §3.2](52-ai-workflow.md)；
11. 未把人工临时网络测试或性能观察伪报成自动门禁；
12. AI 没有违反 [CD-52 §1.1](52-ai-workflow.md) 的提交边界，也没有未经许可部署或发布。

## 6. 首批测试用例

1. 传送门 A→B 后不能跳过强制检查点；
2. A→B→A 循环在发布前被发现；
3. 爆破球只能伤害 `destructible`；
4. 障碍重生不会把玩家卡入模型；
5. 客户端伪造冲线被拒绝；
6. 离线冲线结果没有网络写请求；
7. BASTION 路障不能封死唯一路径；
8. 对称阵容障碍预算一致；非对称阵容只能应用平台补偿预设；
9. 客户端伪造金币被拒绝；
10. 同一建造槽并发建塔只有一个成功；
11. P2/P3 新内容版本不改变运行中的旧房，P0/P1 补丁按安全边界生效；
12. `latest` 回滚后新房加载旧签名版本；
13. Rule VM 超 gas 时只中止问题规则；
14. 断线重连后客户端恢复权威快照；
15. 相同回放得到相同关键状态哈希。
