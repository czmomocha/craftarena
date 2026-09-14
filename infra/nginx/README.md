# 测试期 Web 静态（Nginx）

操作步骤在 [`docs/runbooks/server-deploy.md`](../../docs/runbooks/server-deploy.md) §14。本目录只放配置，不写死 IP / 域名。

| 文件 | 作用 |
|---|---|
| `craftarena-web.conf` | 明文 `listen 80`，`root /var/www/craftarena-web`，Godot `.wasm` MIME，`Cache-Control: no-cache` |

不要在这里加 443 / 证书。公开 TLS 排到 M7 之后。
