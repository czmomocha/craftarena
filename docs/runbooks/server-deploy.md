# 远端测试机部署手册

本文件是[纠偏方案 2026-08](../plans/course-correction-2026-08.md) C1 产出 3–7 的可执行版本，服务退出条件 **E2** 与 **E3**。

它存在的理由是：项目前 7 天从未离开开发机，所有网络参数都是在 `127.0.0.1` 零延迟下调出来的。**本手册的产出不是「跑通了」，是「哪些参数在真条件下不成立」**（§12）。

- 这是**给人操作的**清单。部署属宪法第十八条人类门禁，AI 只写步骤，不执行。
- 传输是明文 `http` / `ws`。人类 2026-08-27 拍板（D11），[CD-43 §2](../../Confirmed-docs/40-technical/43-networking-and-replay.md#2-传输) 已落点，[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) 已登记为「已接受」。**这是测试期风险接受，不是产品已具备 TLS。** 公开运营前必须回到宪法第二十二条。
- 本文件**不写死**任何 IP、域名、VPS 规格、发行版或 SSH 落点。真实值由你在执行时代入。
- 云主机上的额外差异（安全组、数据盘）见 [`infra/tencent-cloud/README.md`](../../infra/tencent-cloud/README.md)。

> **状态：人类已于 2026-08-27 在自备测试机构建 compose，完成远端双机对局，并按 §8–§9 回填了 §12。** 仓库仍不写 IP / 域名。§12 的结论是：本条链路的 ICMP 近端样本**没有**证伪快照 / 心跳 / 插值占位桩；7 局空转**证实** CPU 先于内存。C3 不得把这张表当成锁定 [CD-43 §4](../../Confirmed-docs/40-technical/43-networking-and-replay.md#4-未锁定项) 的依据。

## 占位符

| 占位符 | 含义 |
|---|---|
| `<SERVER_HOST>` | 测试机的 IP 或主机名，**客户端**要能路由到 |
| `<SSH_USER>` | 你登录测试机用的账号 |
| `<REPO_DIR>` | 测试机上仓库的路径 |

---

## 1. 前置

测试机上需要：

1. Docker Engine 与 Compose v2（`docker compose version` 能打印版本）；
2. 本仓库的一份 checkout（`git clone` 或 `scp`），进入 `<REPO_DIR>`；
3. 出站网络能到 `github.com`（构建时要下载 Godot 引擎）。

本机（你的开发机）上需要：`curl`、`ping`，以及 C1 第 1 章导出的 Windows 包（见[导出包核查清单](desktop-export-check.md)）。

**不需要**：域名、证书、反向代理、Node、Godot。三个服务全在容器里。

---

## 2. 取 Godot 引擎校验和

`match-host` 镜像里要装 Godot Linux 引擎。仓库**不写死**它的 SHA512：装一个没人核对过的引擎去跑权威仿真，比构建失败贵得多，所以缺校验和时构建直接失败。

版本必须与 [CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md) 锁定的开发机版本一致（当前 `4.7.2-stable`）。两边不是同一个引擎时，回放哈希对不上会被误读成仿真 bug。

在测试机上：

```bash
GODOT_VERSION=4.7.2-stable
curl -fsSL -o /tmp/SHA512-SUMS.txt \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/SHA512-SUMS.txt"
grep "_linux.x86_64.zip" /tmp/SHA512-SUMS.txt
```

预期：打印一行，形如 `<128 位十六进制>  Godot_v4.7.2-stable_linux.x86_64.zip`。把前面那串十六进制记下来。

失败：404 说明该 Release 没有这个文件名或版本号写错了。**不要**改成别的版本继续，先确认 CD-51 §1 锁的是哪一个。

---

## 3. 配置并构建

```bash
cd <REPO_DIR>/infra/compose
cp .env.example .env
```

编辑 `.env`，把 §2 拿到的值填进 `GODOT_SHA512=`。其余项默认即可。`.env` 已被 gitignore，不会进仓库。

```bash
docker compose build
```

预期：三个服务构建成功；`match-host` 那层能看到 `Godot_v4.7.2-stable_linux.x86_64.zip: OK`（`sha512sum -c` 的输出），随后是一次 Godot `--import`。

常见失败：

| 现象 | 原因 |
|---|---|
| `set GODOT_SHA512 in infra/compose/.env` | `.env` 里那行还是空的 |
| `sha512sum: WARNING: 1 computed checksum did NOT match` | 校验和抄错，或下到了别的版本。**停下**，不要跳过校验 |
| `npm ci` 报 lockfile 不匹配 | checkout 不完整，或 `package-lock.json` 没同步 |

---

## 4. 拉起并确认就绪

```bash
docker compose up -d
docker compose ps
```

预期：`control-plane`、`gateway`、`match-host` 三个都是 `running (healthy)`。健康检查打的是各自的 `/readyz`，所以 healthy 意味着控制面数据库读写往返成功，不只是端口开着。

在测试机上自测一次：

```bash
curl -fsS http://127.0.0.1:8080/readyz
curl -fsS http://127.0.0.1:8090/readyz
```

预期：两条都返回 `"status":"ready"`。

失败：`docker compose logs control-plane`（或 `gateway` / `match-host`）看最后几十行。容器反复重启多半是配置项写错，日志里会有该变量名。

---

## 5. 开放端口

只需要两个：

| 端口 | 服务 |
|---|---|
| 8080 | 控制面 HTTP |
| 8090 | 实时网关 WebSocket |

**不要开放 42000–42099。** 那是对局进程端口段，只在 compose 内网被网关拨到；开放它等于让公网直连 Godot MatchServer，违反宪法第二十二条。`docker-compose.yml` 里 `match-host` 没有 `ports:`，防火墙也不开，两层都关才算成立。

云主机还要在安全组放行同样两个端口，别只改机器内的防火墙。

从**本机**验证一次（换成真实地址）：

```powershell
curl.exe -fsS http://<SERVER_HOST>:8080/readyz
```

预期：和 §4 一样的 JSON。失败：连接超时 = 防火墙或安全组没放行；连接被拒 = 端口没发布或服务没起。

---

## 6. 把客户端指向测试机

客户端默认连本机 `npm run dev`。指向远端有三条入口，优先级从低到高：

| 方式 | 写法 | 适合 |
|---|---|---|
| 环境变量 | `CRAFTARENA_SERVER=<SERVER_HOST>` | 一台机器长期连同一个服务器 |
| 命令行 | `CraftArena.exe -- --server=<SERVER_HOST>` | 临时切换 |
| 大厅输入框 | 填主机后点 **Apply server** | 不想重启，或想当场换机器 |

端口非默认时用 `--control-plane=http://HOST:PORT` 与 `--gateway=ws://HOST:PORT` 分别指定。`--server=` **只接受主机名或 IP，不接受端口**——从控制面端口猜网关端口会是一条凭空发明的规则，所以它宁可拒绝并在 HUD 上说明。

启动后看状态行的 `server=`：

- `server=<SERVER_HOST>` → 指过去了；
- `server=127.0.0.1` → 参数没生效（多半是漏了 `--`，引擎会把它当自己的参数吃掉）；
- `server_error=...` → 地址被拒，后面那句写了原因。**这时连的仍是上一个地址，不是你刚填的那个。**

`tls=off` 是预期的：测试期就是明文。

---

## 7. 两台真机打完一局并确认写库

至少一台走真实公网，不要两台都在同一个局域网里——那样测不出这一批要测的东西。

1. A 机：启动客户端并指向 `<SERVER_HOST>`，赛道填 `course_01`，人数填 `2`，点 **Create room**。记下状态行里的 `room=` 六位码。
2. B 机：同样指向 `<SERVER_HOST>`，把房间码填进 **Room code**，点 **Join room**。
3. 预期：两边 `play=in_match`，各自看得到对方的海军蓝盒子在动。失败：`join=FAILED` 看 `error=`；连上又立刻掉看 `docker compose logs gateway`。
4. 两边 WASD + 空格走完全部检查点直到冲线。预期：全员冲线后状态行出现 `result=`，随后出现 `settled=`（那是只读 GET，客户端从不写结算）。
5. 在测试机上确认结算真的落库了：

```bash
docker compose exec -T control-plane node -e "
const {DatabaseSync}=require('node:sqlite');
const db=new DatabaseSync('/data/control-plane.sqlite');
console.log(db.prepare('SELECT match_id, tick, pad_total, mvp_slot, created_at FROM match_settlements ORDER BY created_at DESC LIMIT 5').all());
"
```

预期：至少一行，`created_at` 是刚才那一局的时间。

失败：没有行 = 结算没写进去。先看 `docker compose logs match-host` 里有没有 settlement POST 的错误。**这一步不能跳**：客户端上显示 `settled=` 只证明 GET 到了东西，落库要在服务器这侧看。

留证据：两台机器各截一张 `play=in_match` 的图和一张冲线后的图，连同上面这条查询的输出，一起贴进 PR。

---

## 8. 网络基线

在**本机**（不是测试机）采。目标是 [CD-43 §4](../../Confirmed-docs/40-technical/43-networking-and-replay.md) 那些参数的决策依据，所以要在真实链路上采，且要采够长。

先跑长采样（`-n` 是次数，约等于秒数；86400 ≈ 24 小时。先用 600 跑通流程，再放长）：

```powershell
$target = "<SERVER_HOST>"
$sent   = 600
ping -n $sent $target | Tee-Object -FilePath "rtt-raw.txt" | Out-Null
```

再统计：

```powershell
$samples = @(Select-String -Path "rtt-raw.txt" -Pattern '=(\d+)ms' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { [int]$_.Groups[1].Value })
if ($samples.Count -eq 0) { throw "没解析出样本，先打开 rtt-raw.txt 看 ping 是不是全超时了" }
$sorted = $samples | Sort-Object
function Get-Pct([int[]]$values, [int]$p) {
    $i = [math]::Ceiling($values.Count * $p / 100) - 1
    if ($i -lt 0) { $i = 0 }
    return $values[$i]
}
$jitterSum = 0
for ($i = 1; $i -lt $samples.Count; $i++) {
    $jitterSum += [math]::Abs($samples[$i] - $samples[$i - 1])
}
[pscustomobject]@{
    sent       = $sent
    received   = $samples.Count
    loss_pct   = [math]::Round(100 * ($sent - $samples.Count) / $sent, 2)
    rtt_min_ms = $sorted[0]
    rtt_p50_ms = Get-Pct $sorted 50
    rtt_p90_ms = Get-Pct $sorted 90
    rtt_p95_ms = Get-Pct $sorted 95
    rtt_max_ms = $sorted[-1]
    jitter_ms  = [math]::Round($jitterSum / [math]::Max(1, $samples.Count - 1), 2)
} | Format-List
```

**自校验**：`received` 必须等于 ping 汇总行里的 `Received`。正则只抓回复行的 `time=NNms`；汇总行的 `Minimum = NNms` 因为带空格不会被抓进来。两个数对不上就说明输出格式和这里假设的不一样，先看原始文件再信统计值。

`jitter_ms` 是相邻样本 RTT 差的平均绝对值（IPDV），不是标准差。

ICMP 与游戏用的 TCP/WebSocket 走的不是同一条队列，拥塞时表现可能不同。它是**下限估计**，不是协议层 RTT。协议层 RTT 需要帧里带时间戳，那不在本章。

2026-08-27 已按上面的 600 次流程采过一回（约 10 分钟，不是 24 小时）。数字与结论在 §12。原始 `rtt-raw.txt` 含对端地址，**不要提交**。

---

## 9. 资源基线

[CD-44 §2](../../Confirmed-docs/40-technical/44-deployment.md) 按 50 CCU ÷ 8 人 ≈ 7 局并发设计。纠偏方案的推导是**CPU 先崩，不是内存**——这一步就是去证伪或证实它。

先记空载：

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
```

再造 7 局并发（在测试机上，打本地回环，不占公网）：

```bash
for i in $(seq 1 7); do
  curl -sS -o "/tmp/room-$i.json" -w "%{http_code}\n" \
    -X POST http://127.0.0.1:8080/matchmaking/rooms \
    -H 'content-type: application/json' \
    -d '{"course":"course_01","seats":2}'
done
```

预期：七行全是 `201`，`/tmp/room-*.json` 里各有一个 `roomCode`。

`202` 不是错误，是**这一条没起进程、进了等待队列**：并发上限默认等于端口段容量，先看 `.env` 里的端口段是不是被改小了。注意这里不能用 `curl -f`——它只对 4xx/5xx 失败，202 会安静通过，于是「只起了 3 局」被读成「7 局的数据」。`502` / `503` 去看 `docker compose logs match-host`。

等约 30 秒让对局进程都进入稳定 tick，然后同时采两层：

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
docker compose exec -T match-host ps -eo pid,pcpu,rss,args --sort=-pcpu | head -n 12
nproc   # 记下核数，CPU 百分比脱离核数没有意义
```

预期：`ps` 里的 Godot 进程数等于上一步 `201` 的条数（全绿时是 7）。把每进程 `pcpu` / `rss` 与容器合计一起记下来，并写明实际起了几局。

**注意**：这七局没有真人输入。它测的是空转 tick 循环 + 广播的底噪，**不是**满载。真人输入下的数字只能靠 §7 那种真实对局采，样本量小得多。记录时必须写清楚是哪一种，否则下一次审视会把底噪当成容量结论。

2026-08-27 已按本节采过一次 7 局空转（七行均 `201`）。数字与结论在 §12。该次未跑 `nproc`，CPU 百分比只按 Docker / `ps` 相对单核来读。

采完清掉：

```bash
docker compose restart match-host
```

对局进程随之退出。没有真人输入时它们本来也会在 idle 超时后被回收（CD-44 §3），但不要为了省一条命令去等十分钟。

---

## 10. 排障

| 现象 | 先看哪里 |
|---|---|
| 客户端 `join=FAILED` | 本机 `curl http://<SERVER_HOST>:8080/readyz`；不通就是网络层，不是游戏 |
| 入场后立刻断开 | `docker compose logs gateway`。网关拨不到对局上游时最可能的原因是 `MATCH_HOST_UPSTREAM_HOST` 不是 `match-host` |
| `POST /matchmaking/*` 回 502 | `docker compose logs match-host`。多半是 Godot 起不来：看有没有 `error while loading shared libraries` |
| `POST /matchmaking/*` 回 503 | 容量满，或 MatchHost 没就绪 |
| 结算没落库 | `docker compose logs match-host` 找 settlement POST；控制面 404 说明会话已被注销 |
| 容器起来又退出 | `docker compose logs <service>`。配置项写错时日志会点名那个变量 |

Godot 缺动态库时补 `infra/compose/Dockerfile` 里那份 apt 列表，不要改成在宿主机装。

---

## 11. 停止

```bash
docker compose down          # 停服务，保留数据库 volume
docker compose down -v       # 连数据库一起删。会丢结算记录，确认过再用
```

---

## 12. 本批必须回填的结论

**这一节才是 C1 的主要产出。** 跑通只是前提，结论是「哪些在零延迟下做的决定不成立」。

采样边界（必须和数字一起读，缺一条就把对应结论降级）：

- ICMP **600** 次（手册允许的流程长度），约 10 分钟，**不是** 24 小时。
- ICMP 是下限估计，**不是** WebSocket / 命令帧 / 快照帧 RTT。
- P50 = 3ms 说明这条客户端→测试机路径是**近端 / 同区域**量级，不能当成跨省公网弱网。
- 7 局是 `POST /matchmaking/rooms` 拉起后的**空转 tick**，没有真人输入，不是满载。
- 该次未跑 `nproc`。Docker `CPU %` 与 `ps` `%CPU` 都按相对单核来读；`198.92%` ≈ 两核打满，不能换算成「打满整机」。
- 不入库 IP、域名、SSH 落点、对局 `match-id`。

| 项 | 零延迟下的现状 | 真链路实测（2026-08-27） | 结论 |
|---|---|---|---|
| RTT P50 / P90 / P95 | 无数据（全在 127.0.0.1） | ICMP：min 3 / P50 3 / P90 3 / P95 4 / max 18（ms）；sent=received=600 | 近端。3ms 仍远小于 60Hz 一拍（~16.7ms）。**不能**当「真公网」去改快照 / 插值。 |
| 丢包率 | 无数据 | 0% | 本窗口未观察到 ICMP 丢包。不证明 24h 稳定，也不证明游戏协议不丢。 |
| 抖动（IPDV） | 无数据 | 0.16ms | 可忽略。约束范围同 ICMP 本条路径。 |
| 快照频率 `SNAPSHOT_EVERY_TICKS` | 占位桩 = 2（每 2 个引擎 tick 一帧） | 无协议层到达间隔 | **本样本未证伪。** C3 不得据此改值或写入 [CD-43 §4](../../Confirmed-docs/40-technical/43-networking-and-replay.md#4-未锁定项)。 |
| 心跳频率 `HEARTBEAT_EVERY_TICKS` | 占位桩 = 60 | 7 局均拉起；空转无真人输入，心跳本就不续租 | **本样本未证伪。** |
| 插值窗口 `play_interp_step` | 表现桩 `Fixed.SCALE / 2`，不是插值窗口 | 无 | **本样本未提供把桩换成窗口的依据。** |
| 本席预测与对账 | 无对账；新快照 tick 清 overlay，硬贴最新权威 | 无预测误差 / 快照到达延迟 | **本样本未证伪，也未证明需要平滑对账。** |
| 7 局并发 CPU（空转） | 推导「CPU 先崩」，未实测 | 七行 `201`。负载后 `match-host` 容器 **198.92%**；7 个 Godot Headless 各约 27–30% CPU；node MatchHost ~0%。`control-plane` 7.05%，`gateway` 0.00%（无客户端连入） | **证实 CPU 先于内存。** 7 局空转已约两核。缺 `nproc`，不得把百分比写成整机利用率。 |
| 7 局并发内存 | 推导约 3 GB，未实测 | 空载 → 7 局：gateway 63.02→64.5 MiB；match-host 66.89→**422.2 MiB** / 3.339 GiB；control-plane 93.54→108.1 MiB。容器内 `ps` RSS：Godot 各约 114 MiB，node ~122 MiB，合计 ~920 MiB | **3 GB 推导对空转偏高。** 内存远未到限。cgroup（422 MiB）与 RSS（~920 MiB）不一致，并列记录，不得只取更乐观的那个。 |

网络参数的所有者文档是 [CD-43 §4](../../Confirmed-docs/40-technical/43-networking-and-replay.md#4-未锁定项)，容量是 [CD-44 §2](../../Confirmed-docs/40-technical/44-deployment.md#2-容量与排队)。**本手册不改那两处**——即使以后要改占位数字，也由 C3 按结论一次性写入，避免冻结期反复搬家。

### 对纠偏退出条件的含义

- **E2**（有 RTT / 丢包 / 资源基线）：本表填了数。双机对局与写库已在同日验证。C1 产出 6 写的 **24 小时**采样仍未做。
- **E3**（列出并修正零延迟下做错的网络参数）：本表**列出**了。被证实的是容量推导「CPU 先于内存」；被证伪的是「7 局空转大约要 3 GB」。快照 / 心跳 / 插值 / 对账占位桩在这条 ~3ms ICMP 路径上**没有**被证伪，因此**不修正**那些代码常量。E3 的「修正」仍留给 C3，且需要更像公网的样本或人类另行拍板，不能用本表锁 [CD-63 §1.5](../../Confirmed-docs/60-plan/63-open-decisions.md)。

### 资源摘录（空转）

空载 `docker stats --no-stream`：

```text
NAME                         CPU %     MEM USAGE / LIMIT
craftarena-gateway-1         0.00%     63.02MiB / 3.339GiB
craftarena-match-host-1      0.00%     66.89MiB / 3.339GiB
craftarena-control-plane-1   0.00%     93.54MiB / 3.339GiB
```

七次 `POST /matchmaking/rooms`（`course_01` / `seats=2`）HTTP 状态：`201` × 7。

约 30 秒后：

```text
NAME                         CPU %     MEM USAGE / LIMIT
craftarena-gateway-1         0.00%     64.5MiB / 3.339GiB
craftarena-match-host-1      198.92%   422.2MiB / 3.339GiB
craftarena-control-plane-1   7.05%     108.1MiB / 3.339GiB
```

`match-host` 容器内 `ps`：1 个 node MatchHost（RSS ~122 MiB，%CPU ~0）+ 7 个 Godot Headless（`match_server.tscn`，官方 `course_01`，`--players=2`；各约 27–30% CPU、RSS ~114 MiB）。不记录 `match-id`。

### 执行记录

| 日期 | 执行人 | 结果 |
|---|---|---|
| 2026-08-27 | 人类 | 远端部署与双机对局已跑通 |
| 2026-08-27 | 人类采数，AI 回填本表 | ICMP 600：P50/P90=3ms，P95=4ms，丢包 0%，IPDV 0.16ms。7 局空转全 `201`；match-host 198.92% / 422.2 MiB。结论见上表：CPU 先于内存成立；网络占位桩未被证伪；C3 不得用本样本锁定 CD-43 §4 |
