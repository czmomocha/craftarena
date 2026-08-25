# CD-13 账号、在线与离线规则

> 文档 ID：CD-13
> 单一事实源：在线模式权威规则、Guest 与正式账号生命周期、离线单人模式行为、单局排名口径
> 加载建议：改动登录注册、会话、离线流程、结算与名次时读取
> 上位约束：[CD-00 宪法](../00-constitution/CONSTITUTION.md) 第十四、十五条
> 相关：[CD-14 数据与遥测](14-data-and-telemetry.md)、[CD-21 TRAPRUSH](../20-gameplay/21-traprush.md)、[CD-22 BASTION](../20-gameplay/22-bastion.md)、[CD-44 部署与容量](../40-technical/44-deployment.md)
> 派生自：初稿 v0.2 §6.1–§6.3

## 1. 在线模式

- 服务端是唯一权威；
- 玩家只提交输入和操作意图；
- 单局结构化记录写入后端用于调试和遥测，但客户端不提供历史战绩、累计胜率或长期排名页面；
- 单局内产生名次、胜负、MVP 和统计面板；
- 不计算或展示长期段位；
- UGC 内容必须为平台验证并签名的版本；
- TRAPRUSH 在线房允许 1～8 名真人直接开始，单人在线也走 MatchServer；
- BASTION 只按蓝图声明的合法真人阵容开始；
- 在线房不自动补机器人。

## 2. Guest 与正式账号

- 匿名用户获得浏览器绑定的 Guest ID 和本地恢复密钥；
- Guest 草稿自动保存云端并保留本地缓存，云端保留期见 [CD-14](14-data-and-telemetry.md)；
- 发布和跨设备访问必须注册登录并认领草稿；
- 一期使用用户名 + 密码，任何互联网用户都可注册；
- 不提供邮箱验证、密码找回、CAPTCHA、IP 限频或设备约束；
- 忘记密码只能注册新账号，旧账号和内容不迁移；
- 注册用户名直接作为公开玩家名与作者名，不做文本过滤；
- 一期不提供文字、语音、快捷短语或 Ping。

> 上述开放注册、公开用户名和零防滥用组合风险很高，只适用于当前长期测试环境，不能表述为正式公开运营能力。见 [CD-62 风险登记册](../60-plan/62-risk-register.md)。

## 3. 离线单人模式

- 使用与线上相同的 `SimulationCore` 和内容格式；
- 通过本地内嵌权威仿真运行，不接受外部客户端结果；
- 可游玩官方内容、已缓存的签名 UGC 和本地草稿；
- 可保存本地设置、编辑草稿和个人试玩记录；
- 不回写在线成绩、奖励、战绩、排名和解锁；
- UI 必须持续显示"离线试玩，成绩不上传"；
- 恢复在线后不得补传离线结算；
- 离线试玩只保证 PC、Android 和 iOS 安装版；Web 必须联网，但断网时需保住本地草稿缓存；
- TRAPRUSH 可记录本机最佳命令轨迹并播放无碰撞幽灵，不下载他人幽灵；
- BASTION 使用模板机器人按预算布障并以规则化策略建塔。

实现落点（2026-08-25）：机关狂奔大厅 `Solo play` 启动 `MatchOfflineSession`：把默认官方 `course_01` 编进与线上相同的 `TraprushMatchSession`，命令帧 tick 为 0，快照只跟从本地最新帧。HUD 在离线进行中持续写出「离线试玩，成绩不上传」。`allows_settlement` / `allows_online_writes` 恒为 false，不发匹配 HTTP 或网关 WS。`OS.has_feature("web")` 或注入 `web_platform` 时拒绝开玩。本机最佳轨迹幽灵、已缓存签名 UGC / 本地草稿试玩、个人试玩记录落盘仍待。落点见 [CD-12 §1](12-product-structure.md#1-入口结构) 与 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点)。

## 4. 单局排名

一期的"排名"只指当前对局结算：

- TRAPRUSH 实际按本局 1～8 人结算；默认按冲线顺序，也允许受限规则组合定义结束条件；
- BASTION：先按胜负分队，再按队内贡献给出 MVP 顺序；
- 未完成玩家按检查点进度、距下一目标的合法路径距离和到达时间排序；
- 非法命令被拒绝并记日志，但一期不因作弊或异常主动踢出、封禁；
- 结算结果不生成 MMR，不影响下一局匹配权重。

TRAPRUSH 的完整排序优先级见 [CD-21 §6.1](../20-gameplay/21-traprush.md)；BASTION 的胜负与 MVP 判定见 [CD-22 §5.2](../20-gameplay/22-bastion.md)。

实现落点（2026-08-25）：大厅直播名次板从最新权威快照的 `finish_tick` / `accepted_count` 派生（`TraprushStanding` + `MatchStandingMap`），只覆盖 [CD-21 §6.1](../20-gameplay/21-traprush.md#61-排序优先级) 第 1、2 条，并以槽位作为稳定键。这是表现，不是结算写库，也不生成 MMR。合法路径距离与到达当前检查点时间仍待。落点见 [CD-42 §3.4](../40-technical/42-contracts-and-rulevm.md#34-实现落点) 与 [CD-43 §2](../40-technical/43-networking-and-replay.md#2-传输)。
