# syntax=docker/dockerfile:1

# Craft Arena 测试环境镜像（纠偏 C1 第 2 章）。
#
# 两个 target：
#   backend    控制面与实时网关。纯 Node 24，无构建步骤（.ts 由运行时剥类型）。
#   match-host MatchHost + Godot Linux 引擎 + game 工程，因为它要为每场对局
#              spawn 一个 Godot Headless 子进程（CD-44 §3）。
#
# Godot 二进制不入库，也不在这里写死校验和：GODOT_SHA512 必须由构建者传入，
# 缺失就构建失败。宁可卡住一次，也不要装一个没人核对过的引擎去跑权威仿真。
# 取值方法见 docs/runbooks/server-deploy.md。

ARG NODE_IMAGE=node:24-bookworm-slim

FROM ${NODE_IMAGE} AS backend
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend ./backend
COPY tools ./tools
# --ignore-scripts：部署镜像不需要任何依赖的安装期脚本，关掉少一个执行面。
RUN npm ci --omit=dev --ignore-scripts

# 空的具名卷首次挂载时会继承镜像里该路径的属主。镜像里没有 /data 时 Docker 建的是
# root:root，而容器以 node 跑，控制面就打不开 SQLite——先建好并交给 node。
RUN mkdir -p /data && chown node:node /data

USER node
ENV NODE_ENV=production

FROM backend AS match-host
USER root

ARG GODOT_VERSION=4.7.2-stable
ARG GODOT_SHA512
ARG GODOT_URL=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip

# 官方 Linux 构建是一个二进制同时带 GUI 与 headless，因此即使只跑 --headless
# 也要满足它的动态链接依赖，否则启动时直接 "error while loading shared libraries"。
RUN set -eux; \
	if [ -z "${GODOT_SHA512}" ]; then \
		echo "GODOT_SHA512 build arg is required; see docs/runbooks/server-deploy.md" >&2; \
		exit 1; \
	fi; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		unzip \
		fontconfig \
		procps \
		libasound2 \
		libdbus-1-3 \
		libgl1 \
		libudev1 \
		libx11-6 \
		libxcursor1 \
		libxi6 \
		libxinerama1 \
		libxrandr2; \
	rm -rf /var/lib/apt/lists/*; \
	curl -fsSL --retry 3 -o /tmp/godot.zip "${GODOT_URL}"; \
	echo "${GODOT_SHA512}  /tmp/godot.zip" | sha512sum -c -; \
	mkdir -p /opt/godot; \
	unzip -j /tmp/godot.zip -d /opt/godot; \
	rm /tmp/godot.zip; \
	mv "/opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64" /opt/godot/godot; \
	chmod +x /opt/godot/godot

COPY game ./game

# 导入一次并把产物交给运行用户：容器跑起来之后 game/ 只读会让引擎在
# .godot/ 上反复报错，而那类报错和真实的资源缺失长得一模一样。
RUN /opt/godot/godot --headless --path /app/game --import \
	&& chown -R node:node /app/game

USER node
ENV GODOT4=/opt/godot/godot
ENV MATCH_HOST_GODOT_PROJECT=/app/game
