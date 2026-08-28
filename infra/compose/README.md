# compose 测试环境

纠偏 C1 第 2 章的部署产物。**操作步骤不在这里**，在 [`docs/runbooks/server-deploy.md`](../../docs/runbooks/server-deploy.md)；本文件只说明这几个文件各自负责什么，以及哪些约束不能改。

| 文件 | 作用 |
|---|---|
| `docker-compose.yml` | 控制面 + 实时网关 + MatchHost 三个服务的编排 |
| `Dockerfile` | 两个 target：`backend`（纯 Node 24）与 `match-host`（额外装 Godot Linux 引擎与 `game/` 工程） |
| `craftarena-compose.sh` | 测试机日常 `status` / `down` / `up` / `restart` / `update`。步骤在手册 [§4.1](../../docs/runbooks/server-deploy.md#41-日常更新测试机) |
| `.env.example` | 环境变量模板。复制成 `.env` 再填，`.env` 已被 gitignore |

## 不能改的三条

1. **`match-host` 不发布端口。** 对局进程只在 compose 内网被网关拨到（宪法第二十二条）。想在宿主机上直连对局端口调试，用 `docker compose exec`，不要加 `ports:`。
2. **`GODOT_SHA512` 没有默认值。** 缺失时构建直接失败。装一个没核对过的引擎去跑权威仿真，比构建失败贵得多。
3. **真实主机地址不写进任何文件。** 服务端不需要知道自己叫什么；客户端用 `--server=HOST` 指过来（见 [README 常用命令](../../README.md)）。
4. **不要 `docker compose down -v`。** 会删控制面 SQLite。`craftarena-compose.sh down` 故意不带这个开关。

## 为什么 MatchHost 要单独一个镜像

它是唯一需要 Godot 的服务：每场对局 spawn 一个 Godot Headless 子进程（[CD-44 §3](../../Confirmed-docs/40-technical/44-deployment.md)）。控制面与网关是纯 Node，装引擎只会让它们的镜像白白多几百 MB。

引擎版本必须与 [CD-51 §1](../../Confirmed-docs/50-engineering/51-dev-environment.md) 锁定的开发机版本一致。两边不是同一个引擎时，回放哈希对不上会被误读成仿真 bug。
