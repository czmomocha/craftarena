# 网络故障人工检查

本文件是 [CD-53 §2.5](../../Confirmed-docs/50-engineering/53-testing-and-ci.md#25-网络仿真人工清单非门禁) 的**可执行版本**。

- **清单本身归 CD-53 §2.5**（九项：延迟 / 抖动 / 丢包 / 乱序 / 重复包 / 短时断线 / 基线丢失 / 恶意高频命令 / 篡改序号、Tick、目标 ID 和 Payload）。本文件只写"怎么执行"，**不在这里增删清单项**。
- 这是**按需人工检查，不是 CI 门禁**（宪法第二十四条）。跑过一次不等于有回归覆盖；没跑的项在 §5 写"未执行"，**不得**写"已覆盖"。
- 注入工具选型见 [CD-91 D.9](../../Confirmed-docs/90-reference/91-decision-log.md) `net_fault_tooling = clumsy_netem_external`：Windows 用 clumsy、Linux 用 `tc netem`、macOS 用 `dnctl` + `pfctl`。三者都是**外部工具，不入库、不进 CI、不写成 npm script**，本文件只引用它们的命令行。
- 命令以 [README.md](../../README.md) 为准，端口默认值：控制面 8080、网关 8090、MatchHost 8100。

---

## 0. 先读这条，否则会得出错误结论

一期传输是 **WebSocket over TCP**（[CD-43 §2](../../Confirmed-docs/40-technical/43-networking-and-replay.md#2-传输)）。所以：

| 你在链路上注入的 | 应用层真正看到的 |
|---|---|
| 丢包 | TCP 重传 ⇒ **延迟与卡顿**，不是丢帧 |
| 乱序 | TCP 重组 ⇒ 顺序不变，只多了延迟 |
| 重复包 | TCP 去重 ⇒ 应用层收不到重复帧 |

因此清单分两段执行，**不要**用链路整形去证明"应用层能扛住乱序/重复/篡改"：

- **§2 链路整形**：延迟、抖动、丢包、乱序、重复包、短时断线、基线丢失。验的是"链路变差时这一局还能不能玩、能不能自己恢复"。
- **§3 应用层帧注入**：恶意高频命令、篡改帧。验的是"服务端对畸形与刷帧的拒绝"。这段必须直连网关发原始字节，链路整形做不到。

清单里的**基线丢失**在 v1 没有增量基线可丢：快照帧是**全量**帧（[CD-43 §1](../../Confirmed-docs/40-technical/43-networking-and-replay.md#1-序列化分工)），断线期间错过的快照不需要补。所以这一项验的是"重连后直接贴最新权威帧，而不是回放或卡在旧位姿"。

---

## 1. 准备

1. 仓库根 `npm run dev`，等三个 `/readyz` 都就绪（[开发机窗口验收 0.1](dev-window-check.md)）。
2. 按 [开发机窗口验收 0.2](dev-window-check.md) 开两个窗口化主场景（客户端 A / B），A **创建房间**、B 按码 **加入房间**，人数 `2`，课程 `course_01`。
3. 读数只看这四处：
   - 客户端状态行：`join=` / `play=` / `seat=` / `tick=` / `pads=` / `rtt=` / `rtt_n=`；
   - 客户端 `user://protocol_rtt.jsonl`（统计脚本见 [server-deploy.md §13](server-deploy.md#13-协议层-rttc3)）。**不要提交这个文件**；
   - `curl -fsS http://127.0.0.1:8100/matches`（MatchHost：`state` / `leaseExpiresAt`，用来看续租有没有被刷帧带偏）；
   - 跑 `npm run dev` 的那个终端（网关与控制面日志）。
4. 远端双机做同一套时按 [server-deploy.md](server-deploy.md) §5–§7 连测试机；整形加在**测试机**或本机任一端都可以，记在 §5 的备注里。

> 这里量出来的毫秒数**不能**用来改 [CD-43 §4](../../Confirmed-docs/40-technical/43-networking-and-replay.md#4-已锁定的网络参数) 的锁定值（Tick / 快照 / 心跳 / 插值步）。改那些数字要另立项并由人类拍板。

---

## 2. 链路整形

三套工具只按你当前开发机选一套。**加完立刻记下怎么撤**——忘记撤销会让后面所有测试都在一条坏链路上跑。

### 2.1 macOS（`dnctl` + `pfctl`，需要 sudo）

```bash
# 1) 建一条管道：120ms 延迟 ± 30ms 抖动、5% 丢包
sudo dnctl pipe 1 config delay 120 plr 0.05

# 2) 只把网关端口打进这条管道（8090 是网关；控制面 8080 不整形，避免入场 HTTP 一起超时）
echo 'dummynet out proto tcp from any to any port 8090 pipe 1' | sudo pfctl -f - -E

# 3) 撤销（必须做）
sudo pfctl -F all -f /etc/pf.conf
sudo pfctl -d
sudo dnctl -q flush
```

`dnctl` 的 `plr` 是丢包率，`delay` 是单向毫秒。抖动用两条管道 + `prob` 分流实现（`sudo dnctl pipe 2 config delay 150`，再按概率把流量分到 1 / 2）。

**诚实边界：本节命令未在本仓库的开发机上实测过**（它改系统级 pf 规则，AI 不代跑）。人类首次执行后把实际可用的写法直接改进本节，不要在别处另起一份。

### 2.2 Linux（`tc netem`，通常加在测试机上）

```bash
# 查网卡名
ip -o link show

# 加：120ms 延迟 ± 30ms 抖动、5% 丢包、1% 重复、25% 重排（reorder 必须配 delay 才生效）
sudo tc qdisc add dev eth0 root netem delay 120ms 30ms loss 5% duplicate 1% reorder 25% 50%

# 改（不要重复 add）
sudo tc qdisc change dev eth0 root netem delay 200ms 50ms loss 10%

# 看
tc -s qdisc show dev eth0

# 撤销（必须做）
sudo tc qdisc del dev eth0 root
```

`netem` 作用于**出方向**。要双向变差就在两台机器上各加一条。加在测试机上会影响该机上所有对局，别在别人正在用的时候加。

### 2.3 Windows（clumsy，管理员运行）

1. 下载 clumsy（WinDivert 驱动，需要管理员）。**不要把它拷进仓库**。
2. Filter 填：`tcp and (tcp.DstPort == 8090 or tcp.SrcPort == 8090)`
3. 勾选并设值：**Lag** 120ms（抖动靠手动改数值或勾 **Throttle**）、**Drop** 5%、**Duplicate** 1%、**Out of order** 25%。
4. 点 Start 开始注入，点 Stop 撤销。关窗即失效。

### 2.4 编号步骤

每步做完把结论填进 §5。**预期**是这一步成立的样子，**失败**是需要停下来查的样子。

1. **基线（不加整形）**：A / B 各走两步、A 冲线。
   - 预期：状态行出现 `rtt=` 与 `rtt_n=`；两边都能看见对方移动；`pads=` 正常推进。
   - 失败：本机零整形就已经卡顿或对方不动 ⇒ 不是网络问题，先修这个再继续。
2. **延迟**：只开延迟（macOS `delay 120` / netem `delay 120ms` / clumsy Lag 120）。
   - 预期：`rtt=` 明显上升到注入量级；本席 WASD 仍即时响应（本席走预测 overlay），**远端**玩家延迟可见；下一份快照到达时本席被硬贴回权威位姿。
   - 失败：本席自己也卡住不动 ⇒ 预测没在本席生效；或两边位姿越走越远不收敛。
3. **抖动**：延迟加上抖动（netem `delay 120ms 30ms` / 两条 dnctl 管道 / clumsy 手动上下调 Lag）。
   - 预期：远端玩家动作不匀但**不回跳穿墙**；`rtt=` 波动，`rtt_n=` 持续增长。
   - 失败：远端玩家反复瞬移回旧位置（插值取了旧帧）；或客户端断开。
4. **丢包**：延迟 + 5% 丢包，再试 10%。
   - 预期：卡顿变明显（TCP 重传），但这一局仍能继续，`tick=` 继续前进；不出现伪造位置。
   - 失败：客户端崩溃、`join=` 变成 `FAILED` 而无重连、或 `tick=` 长期停住不恢复。
5. **乱序与重复包**：netem `reorder 25% 50%` + `duplicate 1%`（macOS 用 clumsy / netem 的等价项；dnctl 无直接重排开关，这一步可在 Linux 测试机做并记在备注里）。
   - 预期：**表现与第 4 步同量级**——TCP 已经重排并去重，应用层看不到乱序或重复帧。这正是本步要确认的结论。
   - 失败：出现重复的过垫、重复的破箱、或名次抖动 ⇒ 应用层真的吃到了重复语义，停下来查。
6. **短时断线**：整形先撤掉。断网 5 秒再恢复（macOS/Linux：临时 `pfctl` / `tc` 全丢包或关 Wi-Fi；Windows：clumsy Drop 100%）。
   - 预期：客户端 `play=` 掉出 `IN_MATCH` 后**自动补票重连**（[CD-43 §2](../../Confirmed-docs/40-technical/43-networking-and-replay.md#2-传输)），回来后 `seat=` 与断线前**同一席位**，能继续玩；对局仿真在断线期间没有停。
   - 失败：回不来、换了席位、或必须手工重新建房。
7. **基线丢失**：在第 6 步基础上把断网拉长到 15 秒。
   - 预期：恢复后本席**直接贴最新权威位姿**（不回放断线期间的过程）；`tick=` 是当前值而不是断线那一刻的值。
   - 失败：客户端停在旧位姿、或试图重放中间过程。

---

## 3. 应用层帧注入

这一段用 Node 原生 `WebSocket` 直连网关发原始字节。**脚本存到系统临时目录，不要放进仓库、不要写成 npm script**（CD-53 §2.5）。帧布局见 [CD-43 §1](../../Confirmed-docs/40-technical/43-networking-and-replay.md#1-序列化分工)：命令帧定长 35 字节 `[version:u8=1][type:u8=1][tick:s64][intent_id:u8][dx:s64][dz:s64][yaw_bam:s64]`，小端。

保存为 `/tmp/craftarena-inject.mjs`（Windows 用 `$env:TEMP\craftarena-inject.mjs`）：

```js
// 网络故障人工检查 §3。只在开发机对自备后端使用。不入库。
const mode = process.argv[2] ?? "flood";
const cp = process.argv[3] ?? "127.0.0.1:8080";
const gw = process.argv[4] ?? "127.0.0.1:8090";

const room = await fetch(`http://${cp}/matchmaking/rooms`, {
	method: "POST",
	headers: { "content-type": "application/json" },
	body: JSON.stringify({ course: "course_01", seats: 1 }),
}).then((r) => r.json());
console.log("room", room.roomCode, "match", room.matchId, "seat", room.seat);

const SCALE = 65536; // Fixed.SCALE，一格
function command({ tick = 0, intent = 1, dx = 0, dz = 0, yaw = -1 }) {
	const view = new DataView(new ArrayBuffer(35));
	view.setUint8(0, 1);
	view.setUint8(1, 1);
	view.setBigInt64(2, BigInt(tick), true);
	view.setUint8(10, intent);
	view.setBigInt64(11, BigInt(dx), true);
	view.setBigInt64(19, BigInt(dz), true);
	view.setBigInt64(27, BigInt(yaw), true);
	return new Uint8Array(view.buffer);
}

const ws = new WebSocket(`ws://${gw}/ws?ticket=${encodeURIComponent(room.ticket)}`);
ws.binaryType = "arraybuffer";
let frames = 0;
let lastX = null;
ws.addEventListener("message", (event) => {
	const bytes = new Uint8Array(event.data);
	if (bytes.length < 12 || bytes[1] !== 2) return; // 只读快照帧
	frames += 1;
	const view = new DataView(bytes.buffer);
	const tick = view.getBigInt64(2, true);
	const x = view.getBigInt64(11, true); // 席位 0 的 x
	if (x !== lastX) {
		console.log("snapshot tick", tick.toString(), "x", x.toString());
		lastX = x;
	}
});
ws.addEventListener("open", () => {
	if (mode === "flood") {
		// 恶意高频：同一席位每毫秒一条 Move（服务端每 commit_tick 只该吃一条）
		setInterval(() => ws.send(command({ dx: SCALE })), 1);
	} else if (mode === "tamper") {
		const bad = [
			["version=2", (f) => { f[0] = 2; return f; }],
			["type=9", (f) => { f[1] = 9; return f; }],
			["unknown intent=99", (f) => { f[10] = 99; return f; }],
			["truncated", (f) => f.slice(0, 34)],
			["trailing byte", (f) => new Uint8Array([...f, 0])],
			["reserved nonzero on Jump", () => {
				const f = command({ intent: 2, yaw: 0 });
				new DataView(f.buffer).setBigInt64(11, 1n, true);
				return f;
			}],
			["tick=2^40 (服务端不信任 tick)", (f) => {
				new DataView(f.buffer).setBigInt64(2, 1n << 40n, true);
				return f;
			}],
			["dx=SCALE+1（超一格）", () => command({ dx: SCALE + 1 })],
			["snapshot frame as command", (f) => { f[1] = 2; return f; }],
		];
		for (const [name, mutate] of bad) {
			ws.send(mutate(command({ dx: SCALE })));
			console.log("sent", name);
		}
		// 最后发一条合法帧：连接还活着就该动
		setTimeout(() => ws.send(command({ dx: SCALE })), 500);
	}
});
setTimeout(() => { console.log("snapshot frames:", frames); process.exit(0); }, 8000);
```

运行（Node ≥ 24，见 README「依赖」）：

```bash
node /tmp/craftarena-inject.mjs flood
node /tmp/craftarena-inject.mjs tamper
```

`8080` 被别的进程（常见是 Python `http.server`）占用时 `npm run dev` 会**拒绝启动**并告诉你那不是控制面。不要去杀别人的进程，改用偏移端口起一套：

```bash
CONTROL_PLANE_PORT=8180 GATEWAY_PORT=8190 MATCH_HOST_PORT=8200 \
CONTROL_PLANE_URL=http://127.0.0.1:8180 MATCH_HOST_URL=http://127.0.0.1:8200 \
MATCH_HOST_PORT_RANGE_MIN=42200 MATCH_HOST_PORT_RANGE_MAX=42229 npm run dev
# 脚本第 2、3 个参数就是这两个地址
node /tmp/craftarena-inject.mjs flood 127.0.0.1:8180 127.0.0.1:8190
```

> **脚本可用性冒烟（AI 执行，2026-09-12，macOS 开发机，偏移端口 8180 / 8190，`course_01` 1 席）**：`flood` 每毫秒发一条 Move，快照每 2 tick 一帧，`x` **每帧恰好 +65536（一格）**，从 `65536` 走到 `524288` 后被 ±8 格出界桩弹回出生点并静默约 60 tick（1.0 s 硬直），随后重复——刷帧没有叠成瞬移。`tamper` 九条畸形帧发完 `x` 仍是 `65536`，500 ms 后那条合法帧把 `x` 推到 `131072`，连接仍可用。
>
> 这只证明**脚本能跑、结论方向对**，**不代替** §5 的人类执行记录，也不覆盖 §2 的链路整形（那部分 AI 没跑）。

### 编号步骤（续 §2.4）

8. **恶意高频命令**：`node /tmp/craftarena-inject.mjs flood`，同时 `curl -fsS http://127.0.0.1:8100/matches`。
   - 预期：`x` **每个 commit_tick 至多前进一格**（每席位每 tick 至多一条命令入队，后到的拒绝，见 `game/src/server/match_realtime.gd`）；不出现按发送速率叠加的瞬移；进程不崩、连接不被动断开；MatchHost 的 `leaseExpiresAt` 只跟真实生效的命令走。
   - 失败：`x` 一拍前进多格（位置伪造门禁失效）、对局进程退出、或 MatchHost 把这条刷帧连接当成高价值输入无限续租。
   - **诚实边界**：一期**没有**速率限制、封禁与作弊处置（宪法第二十五条、[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md)）。本步验的是"刷帧改不了裁决结果"，**不是**"刷帧会被挡住"。
9. **篡改帧**：`node /tmp/craftarena-inject.mjs tamper`。
   - 预期：九种畸形帧**一条都不生效**（`x` 不变），解码在 `decode_command` 就被拒（版本不符 / 未知类型 / 未知 intent / 截断 / 尾随字节 / 保留字段非零）；`dx=SCALE+1` 通过解码但被 `MOVE_STEP_MAX` 整条拒绝、位姿不变；`tick=2^40` 不影响服务端 tick（命令帧 tick 只解码不信任）；快照帧当命令被拒。最后那条合法帧让 `x` 前进一格，证明连接仍然可用。
   - 失败：任何一条畸形帧改变了 `x`、对局进程崩溃、或合法帧之后连接已经死了。

---

## 4. 已由自动化覆盖，本文件不重复

这几条有 CI 用例，不必用人工注入再证一遍（但**它们也不覆盖** §2 / §3 的链路与端到端行为）：

- 帧编解码拒绝（版本 / 类型 / 截断 / 尾随 / 保留字段）：`game/tests/unit/test_match_frame_codec.gd`；
- 每席每 tick 一条命令、断开丢排队、超限 Move 拒绝：`game/tests/unit/test_match_realtime.gd`；
- 旧 tick / 坏帧不重建、只跟最新快照：`game/tests/unit/test_match_snapshot_follow.gd`；
- 票据一次性消费、补票回同一席位：`backend/control-plane/tests/reconnect.test.ts`；
- 网关票据裁决与逐字节转发：`backend/realtime-gateway/tests/`。

---

## 5. 执行记录

一次检查填一行块。**AI 不得代填**；没执行就留"未执行"。

| 清单项（CD-53 §2.5） | 执行方式 | 结论 | 日期 / 机器 |
|---|---|---|---|
| 延迟 | §2.4 第 2 步 | 未执行 | |
| 抖动 | §2.4 第 3 步 | 未执行 | |
| 丢包 | §2.4 第 4 步 | 未执行 | |
| 乱序 | §2.4 第 5 步 | 未执行 | |
| 重复包 | §2.4 第 5 步 | 未执行 | |
| 短时断线 | §2.4 第 6 步 | 未执行 | |
| 基线丢失 | §2.4 第 7 步 | 未执行 | |
| 恶意高频命令 | §3 第 8 步 | 未执行 | |
| 篡改序号 / Tick / 目标 ID / Payload | §3 第 9 步 | 未执行 | |

备注（整形加在哪一端、用了哪套工具、远端还是本机）：

```text
（人类填）
```
