import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

import { REPO_ROOT } from "../src/paths.ts";

// 纠偏 C1 第 2 章。这批断言守的是部署产物里几条「改坏了不会立刻报错、
// 但会静默突破边界」的约束——尤其宪法第二十二条：对局进程不得直连公网。
// 部署由人类执行，CI 看不到那台机器，所以能自动守的部分必须自动守。

const COMPOSE_PATH = "infra/compose/docker-compose.yml";
const DOCKERFILE_PATH = "infra/compose/Dockerfile";
const ENV_EXAMPLE_PATH = "infra/compose/.env.example";
const DOCKERIGNORE_PATH = ".dockerignore";
const RUNBOOK_PATH = "docs/runbooks/server-deploy.md";

const CONFIG_SOURCES = [
	"backend/control-plane/src/config.ts",
	"backend/realtime-gateway/src/config.ts",
	"backend/match-host/src/config.ts",
] as const;

/** compose 内网可以出现的主机：回环、通配绑定，以及三个服务名。 */
const ALLOWED_HOSTS = new Set([
	"127.0.0.1",
	"0.0.0.0",
	"localhost",
	"control-plane",
	"gateway",
	"match-host",
]);

function read(relativePath: string): string {
	return readFileSync(join(REPO_ROOT, relativePath), "utf8");
}

/** services > <service> > environment 下的键固定缩进 6 空格；build args 更深，不算运行时配置。 */
function composeEnvironmentKeys(source: string): string[] {
	return [...source.matchAll(/^ {6}([A-Z][A-Z0-9_]+):/gm)].map((match) => match[1] as string);
}

function configEnvKeys(): Set<string> {
	const keys = new Set<string>();
	for (const source of CONFIG_SOURCES) {
		for (const match of read(source).matchAll(/env\["([A-Z0-9_]+)"\]/g)) {
			keys.add(match[1] as string);
		}
	}
	return keys;
}

function urlHosts(source: string): string[] {
	return [...source.matchAll(/(?:https?|wss?):\/\/([^/"'\s:]+)/g)].map((match) => match[1] as string);
}

describe("infra/compose 部署产物", () => {
	it("不给 match-host 发布任何端口", () => {
		const source = read(COMPOSE_PATH);
		const matchHostBlock = source.slice(source.indexOf("\n  match-host:"));
		assert.notEqual(matchHostBlock, "", "compose 里找不到 match-host 服务");
		assert.doesNotMatch(
			matchHostBlock,
			/^ {4}ports:/m,
			"对局进程只能经网关到达（宪法第二十二条），match-host 不得发布端口",
		);
	});

	it("把网关拨向的对局上游主机设成服务名", () => {
		// 默认值是 127.0.0.1，在 compose 里会让网关拨到自己容器内部，
		// 表现为「入场成功后立刻断开」，很难一眼看出是配置问题。
		assert.match(read(COMPOSE_PATH), /MATCH_HOST_UPSTREAM_HOST:\s*"match-host"/);
	});

	it("只使用后端真实读取的环境变量键", () => {
		const known = configEnvKeys();
		for (const key of composeEnvironmentKeys(read(COMPOSE_PATH))) {
			assert.ok(
				known.has(key),
				`${key} 不在任何 config.ts 里，compose 设了它也不会生效`,
			);
		}
	});

	it("不写死任何真实主机", () => {
		for (const path of [COMPOSE_PATH, ENV_EXAMPLE_PATH]) {
			for (const host of urlHosts(read(path))) {
				assert.ok(ALLOWED_HOSTS.has(host), `${path} 出现了外部主机 ${host}（D11：不入库）`);
			}
		}
	});

	it("要求显式传入 Godot 校验和", () => {
		const source = read(COMPOSE_PATH);
		assert.match(
			source,
			/GODOT_SHA512:\s*"\$\{GODOT_SHA512:\?/,
			"缺校验和必须构建失败，不能有默认值",
		);
		assert.match(read(DOCKERFILE_PATH), /sha512sum -c -/, "下载后必须校验");
	});

	it("dockerignore 排除 node_modules", () => {
		// 开发机上是 Windows / macOS 平台的依赖树，拷进 Linux 镜像会留下错平台产物。
		assert.match(read(DOCKERIGNORE_PATH), /^node_modules$/m);
	});
});

describe("server-deploy runbook", () => {
	it("只用占位符，不写死 IP", () => {
		const source = read(RUNBOOK_PATH);
		const literals = [...source.matchAll(/\b\d{1,3}(?:\.\d{1,3}){3}\b/g)].map((match) => match[0]);
		for (const literal of literals) {
			assert.ok(
				ALLOWED_HOSTS.has(literal),
				`手册里出现了 IP 字面量 ${literal}；主机一律用 <SERVER_HOST>（D11）`,
			);
		}
		assert.match(source, /<SERVER_HOST>/);
	});

	it("写明测试期明文是风险接受而不是产品能力", () => {
		const source = read(RUNBOOK_PATH);
		assert.match(source, /宪法第二十二条/);
		assert.match(source, /不是产品已具备 TLS/);
	});
});
