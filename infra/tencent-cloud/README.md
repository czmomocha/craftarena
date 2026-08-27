# 腾讯云测试环境差异

[CD-44 §1](../../Confirmed-docs/40-technical/44-deployment.md) 把腾讯云香港定为一期长期测试环境的目标机房。**编排产物只有一份**，在 [`infra/compose/`](../compose/)；本目录不复制一套云上专用的 compose，只记录「在云主机上跑那一份」时与裸机不同的地方。

按 D11（2026-08-27），具体规格、发行版、实例 ID、域名与 SSH 落点**不入库**，部署时由人类代入。下面全是占位符。

## 1. 安全组只需要放行两个端口

| 端口 | 服务 | 谁来连 |
|---|---|---|
| `<CONTROL_PLANE_PUBLISH>`（默认 8080） | 控制面 HTTP | 玩家客户端 |
| `<GATEWAY_PUBLISH>`（默认 8090） | 实时网关 WebSocket | 玩家客户端 |

**不要放行 42000–42099。** 那是对局进程端口段，只在 compose 内网被网关拨到。放行它等于让公网直连 Godot MatchServer，违反宪法第二十二条。`docker-compose.yml` 里 `match-host` 服务没有 `ports:`，安全组再开也没有映射——两层都不开才算成立。

MatchHost 的 `8100` 同理，只在内网。

## 2. 测试期是明文，安全组就是唯一边界

`http` / `ws` 没有传输加密（[CD-43 §2](../../Confirmed-docs/40-technical/43-networking-and-replay.md#2-传输) 2026-08-27 落点）。这意味着：

- 安全组来源尽量收窄到测试者的出口 IP，不要图省事开 `0.0.0.0/0`；
- 不要在这套环境里放任何真实凭据或个人数据；
- 公开运营前必须补域名与受信证书，回到宪法第二十二条。

风险已在 [CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) 登记为「已接受」，接受的是**测试期**，不是产品形态。

## 3. 数据盘

控制面 SQLite 落在 `control-plane-data` 这个 docker volume 里。要换到云硬盘，把 `docker-compose.yml` 的 volume 改成绑定挂载 `<DATA_MOUNT>:/data`，不要改控制面的 `CONTROL_PLANE_DB_PATH`——数据库路径的所有者是服务配置，不是编排。

[CD-44 §5](../../Confirmed-docs/40-technical/44-deployment.md) 已声明一期不做备份。云盘快照如果开了，那是运维便利，**不得**对外表述为项目已具备备份能力（宪法第二十四条）。

## 4. 操作步骤在别处

装 Docker、拉起、连客户端、采基线、排障全部在 [`docs/runbooks/server-deploy.md`](../../docs/runbooks/server-deploy.md)。那份手册不区分云主机与裸机，本目录只补上面三条差异。
