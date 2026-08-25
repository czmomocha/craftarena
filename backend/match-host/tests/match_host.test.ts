import assert from "node:assert/strict";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { describe, test } from "node:test";

import type { IssueMatchTicketResponse, VerifyMatchTicketSuccess } from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../../control-plane/src/db/database.ts";
import { buildServer } from "../../control-plane/src/server.ts";
import { loadConfig } from "../src/config.ts";
import { createLease, evaluateLease, renewLease } from "../src/lease.ts";
import type { LaunchedProcess, MatchExit, MatchLaunchSpec, ProcessLauncher } from "../src/launcher.ts";
import { GodotProcessLauncher } from "../src/launcher.ts";
import { PortAllocator } from "../src/ports.ts";
import {
	ControlPlaneMatchSessionRegistrar,
	MatchSessionRegisterError,
	buildMatchUpstreamUrl,
	type MatchSessionRegisterSpec,
	type MatchSessionRegistrar,
} from "../src/registrar.ts";
import { MatchCapacityError, MatchRegistry } from "../src/registry.ts";
import { buildMatchHost } from "../src/server.ts";

const LEASE_MS = 30 * 60 * 1000;
const IDLE_MS = 10 * 60 * 1000;

describe("match host config", () => {
	test("prefers the console build on Windows so crash output is not lost", () => {
		const env = { GODOT4: "C:\\Tools\\Godot.exe", GODOT4_CONSOLE: "C:\\Tools\\Godot_console.exe" };

		assert.equal(loadConfig(env, "win32").godotExecutable, "C:\\Tools\\Godot_console.exe");
		// 其他平台没有 GUI/console 之分，多一个变量只会让部署配置分叉。
		assert.equal(loadConfig(env, "linux").godotExecutable, "C:\\Tools\\Godot.exe");
	});

	test("falls back to GODOT4 on Windows when no console build is configured", () => {
		assert.equal(loadConfig({ GODOT4: "C:\\Tools\\Godot.exe" }, "win32").godotExecutable, "C:\\Tools\\Godot.exe");
		assert.equal(
			loadConfig({ GODOT4: "C:\\Tools\\Godot.exe", GODOT4_CONSOLE: "  " }, "win32").godotExecutable,
			"C:\\Tools\\Godot.exe",
		);
	});

	test("match course and players default to the dev placeholder and are overridable", () => {
		const defaults = loadConfig({}, "linux");
		assert.equal(defaults.matchCourse, "res://content/official/traprush/course_01.json");
		assert.equal(defaults.matchPlayers, 2);

		const overridden = loadConfig(
			{ MATCH_HOST_COURSE: "res://content/official/traprush/course_03.json", MATCH_HOST_PLAYERS: "8" },
			"linux",
		);
		assert.equal(overridden.matchCourse, "res://content/official/traprush/course_03.json");
		assert.equal(overridden.matchPlayers, 8);
	});

	test("match players outside the TRAPRUSH room size are rejected", () => {
		assert.throws(() => loadConfig({ MATCH_HOST_PLAYERS: "0" }, "linux"), /MATCH_HOST_PLAYERS/);
		assert.throws(() => loadConfig({ MATCH_HOST_PLAYERS: "9" }, "linux"), /MATCH_HOST_PLAYERS/);
	});

	test("defaults the control-plane URL and advertised upstream host", () => {
		const defaults = loadConfig({}, "linux");
		assert.equal(defaults.controlPlaneUrl, "http://127.0.0.1:8080");
		assert.equal(defaults.upstreamHost, "127.0.0.1");
	});

	test("strips a trailing slash on CONTROL_PLANE_URL and accepts an advertised host", () => {
		const loaded = loadConfig(
			{ CONTROL_PLANE_URL: "http://10.0.0.8:8080/", MATCH_HOST_UPSTREAM_HOST: "match.internal" },
			"linux",
		);
		assert.equal(loaded.controlPlaneUrl, "http://10.0.0.8:8080");
		assert.equal(loaded.upstreamHost, "match.internal");
	});

	test("treats a blank MATCH_HOST_UPSTREAM_HOST as the loopback default", () => {
		assert.equal(loadConfig({ MATCH_HOST_UPSTREAM_HOST: "  " }, "linux").upstreamHost, "127.0.0.1");
	});

	test("rejects an advertised host that cannot be turned into a ws upstream", () => {
		assert.throws(() => loadConfig({ MATCH_HOST_UPSTREAM_HOST: "http://127.0.0.1" }, "linux"), /upstream host/);
		assert.throws(() => loadConfig({ MATCH_HOST_UPSTREAM_HOST: "127.0.0.1:9" }, "linux"), /upstream host/);
	});
});

describe("match upstream URL", () => {
	test("builds a ws URL from host and port", () => {
		assert.equal(buildMatchUpstreamUrl("127.0.0.1", 42000), "ws://127.0.0.1:42000");
		assert.equal(buildMatchUpstreamUrl("  match.internal  ", 9), "ws://match.internal:9");
	});

	test("rejects hosts that would smuggle a scheme, userinfo, or extra port", () => {
		assert.throws(() => buildMatchUpstreamUrl("ws://127.0.0.1", 1), MatchSessionRegisterError);
		assert.throws(() => buildMatchUpstreamUrl("user@host", 1), MatchSessionRegisterError);
		assert.throws(() => buildMatchUpstreamUrl("127.0.0.1:80", 1), MatchSessionRegisterError);
		assert.throws(() => buildMatchUpstreamUrl("", 1), MatchSessionRegisterError);
		assert.throws(() => buildMatchUpstreamUrl("127.0.0.1", 0), MatchSessionRegisterError);
	});
});

describe("godot process launcher args", () => {
	test("passes course and players through to the match process", () => {
		const launcher = new GodotProcessLauncher({
			executable: "godot",
			projectPath: "/repo/game",
			scene: "res://src/server/match_server.tscn",
			course: "res://content/official/traprush/course_02.json",
			players: 4,
		});

		const args = launcher.buildArgs({ matchId: "m-1", port: 42000 });

		assert.ok(args.includes("--match-id=m-1"));
		assert.ok(args.includes("--port=42000"));
		assert.ok(args.includes("--course=res://content/official/traprush/course_02.json"));
		assert.ok(args.includes("--players=4"));
		// `--` 之后才是场景脚本参数，引擎不解释。
		const separator = args.indexOf("--");
		assert.ok(separator >= 0);
		assert.ok(args.indexOf("--match-id=m-1") > separator);
	});
});

/** 假的控制面登记：让租约测试不必起 HTTP，也证明 MatchHost 只依赖接口、不查库。 */
class FakeRegistrar implements MatchSessionRegistrar {
	readonly registered: MatchSessionRegisterSpec[] = [];
	failWith: Error | undefined;
	gate: Promise<void> | undefined;

	async register(spec: MatchSessionRegisterSpec): Promise<void> {
		if (this.gate !== undefined) {
			await this.gate;
		}
		if (this.failWith !== undefined) {
			throw this.failWith;
		}
		this.registered.push(spec);
	}
}

/** 假的进程启动器：让租约、端口与回收逻辑可以在没装 Godot 的机器上测。 */
class FakeLauncher implements ProcessLauncher {
	readonly launched: MatchLaunchSpec[] = [];
	readonly killed: string[] = [];
	#nextPid = 1000;

	launch(spec: MatchLaunchSpec): LaunchedProcess {
		this.launched.push(spec);
		const pid = this.#nextPid++;
		let settle: (exit: MatchExit) => void = () => {};
		const exited = new Promise<MatchExit>((resolvePromise) => {
			settle = resolvePromise;
		});

		return {
			pid,
			exited,
			recentOutput: () => [`fake process ${pid} output`],
			kill: () => {
				this.killed.push(spec.matchId);
				settle({ code: 0, signal: "SIGTERM" });
			},
		};
	}
}

describe("port allocator", () => {
	test("hands out distinct ports and reuses them only after cycling the range", () => {
		const allocator = new PortAllocator(42000, 42002);

		const first = allocator.allocate();
		const second = allocator.allocate();
		assert.notEqual(first, second);

		// 立刻释放再申请，不应该马上拿回同一个端口，否则会撞上前一场对局的在途报文。
		allocator.release(first);
		const third = allocator.allocate();
		assert.notEqual(third, first);
	});

	test("throws once the range is exhausted", () => {
		const allocator = new PortAllocator(42000, 42001);
		allocator.allocate();
		allocator.allocate();
		assert.throws(() => allocator.allocate(), /no free port/);
	});

	test("rejects an invalid range", () => {
		assert.throws(() => new PortAllocator(42100, 42000), /invalid port range/);
		assert.throws(() => new PortAllocator(80, 90), /invalid port range/);
	});
});

describe("lease rules (CD-44 section 3)", () => {
	test("a fresh lease is alive", () => {
		const lease = createLease(0, LEASE_MS);
		assert.equal(evaluateLease(lease, 0, IDLE_MS).expired, false);
	});

	test("expires by idle timeout after 10 minutes without valid input", () => {
		const lease = createLease(0, LEASE_MS);
		const status = evaluateLease(lease, IDLE_MS, IDLE_MS);

		assert.equal(status.expired, true);
		assert.equal(status.reason, "idle_timeout");
	});

	test("valid input pushes the idle deadline out", () => {
		const lease = renewLease(createLease(0, LEASE_MS), IDLE_MS - 1, LEASE_MS);
		assert.equal(evaluateLease(lease, IDLE_MS, IDLE_MS).expired, false);
	});

	test("the 30 minute lease is reported separately from idle timeout", () => {
		// 构造一个 lastValidInputAt 很新、但绝对租约已过的状态，确认两条规则各自独立生效。
		const lease = { createdAt: 0, lastValidInputAt: LEASE_MS, expiresAt: LEASE_MS };
		const status = evaluateLease(lease, LEASE_MS, IDLE_MS);

		assert.equal(status.expired, true);
		assert.equal(status.reason, "lease_expired");
	});
});

describe("match registry", () => {
	function makeRegistry(
		overrides: { now?: () => number; maxConcurrentMatches?: number; registrar?: FakeRegistrar } = {},
	) {
		const launcher = new FakeLauncher();
		const registrar = overrides.registrar ?? new FakeRegistrar();
		const registry = new MatchRegistry({
			launcher,
			registrar,
			upstreamHost: "127.0.0.1",
			portRangeMin: 42000,
			portRangeMax: 42009,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: overrides.maxConcurrentMatches ?? 10,
			...(overrides.now === undefined ? {} : { now: overrides.now }),
		});
		return { launcher, registrar, registry };
	}

	test("starting a match launches one process with its own port", async () => {
		const { launcher, registry } = makeRegistry();

		const first = await registry.start();
		const second = await registry.start();

		assert.equal(launcher.launched.length, 2);
		assert.notEqual(first.port, second.port);
		assert.equal(registry.runningCount(), 2);
	});

	test("registers the launched match with the same id and a ws upstream", async () => {
		const { launcher, registrar, registry } = makeRegistry();

		const match = await registry.start();

		assert.equal(launcher.launched.length, 1);
		assert.equal(launcher.launched[0]?.matchId, match.matchId);
		assert.deepEqual(registrar.registered, [
			{ matchId: match.matchId, upstreamUrl: `ws://127.0.0.1:${match.port}` },
		]);
		assert.equal(match.upstreamUrl, `ws://127.0.0.1:${match.port}`);
	});

	test("does not register when the process fails to launch", async () => {
		const registrar = new FakeRegistrar();
		const fallback = new FakeLauncher();
		let shouldThrow = true;
		const registry = new MatchRegistry({
			launcher: {
				launch: (spec) => {
					if (shouldThrow) {
						shouldThrow = false;
						throw new Error("spawn failed");
					}
					return fallback.launch(spec);
				},
			},
			registrar,
			upstreamHost: "127.0.0.1",
			portRangeMin: 42000,
			portRangeMax: 42000,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: 10,
		});

		await assert.rejects(() => registry.start(), /spawn failed/);
		assert.deepEqual(registrar.registered, []);
		assert.equal(registry.runningCount(), 0);
		assert.equal(registry.occupiedCount(), 0);
		// 端口必须还回去，否则一次 spawn 失败就会把单端口号段耗死。
		const recovered = await registry.start();
		assert.equal(recovered.port, 42000);
		assert.equal(registrar.registered.length, 1);
	});

	test("kills the process and frees the slot when registration fails", async () => {
		const registrar = new FakeRegistrar();
		registrar.failWith = new MatchSessionRegisterError("control plane register returned HTTP 503");
		const { launcher, registry } = makeRegistry({ registrar, maxConcurrentMatches: 1 });

		await assert.rejects(() => registry.start(), MatchSessionRegisterError);
		assert.equal(launcher.killed.length, 1);
		assert.equal(registry.runningCount(), 0);
		assert.equal(registry.occupiedCount(), 0);
		assert.deepEqual(registrar.registered, []);

		registrar.failWith = undefined;
		const recovered = await registry.start();
		assert.equal(recovered.state, "running");
		assert.equal(registry.runningCount(), 1);
	});

	test("counts an in-flight registration against capacity", async () => {
		let release: () => void = () => {};
		const registrar = new FakeRegistrar();
		registrar.gate = new Promise<void>((resolvePromise) => {
			release = resolvePromise;
		});
		const { registry } = makeRegistry({ registrar, maxConcurrentMatches: 1 });

		const pending = registry.start();
		await waitFor(() => registry.occupiedCount() === 1);
		await assert.rejects(() => registry.start(), MatchCapacityError);

		release();
		const match = await pending;
		assert.equal(match.state, "running");
		assert.equal(registry.runningCount(), 1);
	});

	test("stopping a match kills the process and frees its port", async () => {
		const { launcher, registry } = makeRegistry({ maxConcurrentMatches: 1 });

		const match = await registry.start();
		await assert.rejects(() => registry.start(), MatchCapacityError);

		const stopped = registry.stop(match.matchId);
		assert.equal(stopped?.state, "stopped");
		assert.equal(stopped?.stopReason, "requested");
		assert.deepEqual(launcher.killed, [match.matchId]);

		// 槽位释放后必须能再开一场，否则容量会随时间单调递减。
		await assert.doesNotReject(() => registry.start());
	});

	test("reclaims matches whose lease went idle", async () => {
		let now = 0;
		const { registry } = makeRegistry({ now: () => now });

		const match = await registry.start();
		now = IDLE_MS - 1;
		assert.deepEqual(registry.reclaimExpired(), []);

		now = IDLE_MS;
		const reclaimed = registry.reclaimExpired();
		assert.equal(reclaimed.length, 1);
		assert.equal(reclaimed[0]?.matchId, match.matchId);
		assert.equal(reclaimed[0]?.stopReason, "idle_timeout");
		assert.equal(registry.runningCount(), 0);
	});

	test("renewing keeps a match alive past the idle deadline", async () => {
		let now = 0;
		const { registry } = makeRegistry({ now: () => now });

		const match = await registry.start();
		now = IDLE_MS - 1;
		registry.renew(match.matchId);

		now = IDLE_MS;
		assert.deepEqual(registry.reclaimExpired(), []);
		assert.equal(registry.runningCount(), 1);
	});

	test("renewing an unknown or stopped match returns undefined", async () => {
		const { registry } = makeRegistry();
		const match = await registry.start();
		registry.stop(match.matchId);

		assert.equal(registry.renew(match.matchId), undefined);
		assert.equal(registry.renew("does-not-exist"), undefined);
	});

	test("shutdown kills every running match", async () => {
		const { launcher, registry } = makeRegistry();
		await registry.start();
		await registry.start();

		registry.shutdown();

		assert.equal(launcher.killed.length, 2);
		assert.equal(registry.runningCount(), 0);
	});
});

describe("match host http", () => {
	function makeApp(maxConcurrentMatches = 10, registrar: FakeRegistrar = new FakeRegistrar()) {
		const registry = new MatchRegistry({
			launcher: new FakeLauncher(),
			registrar,
			upstreamHost: "127.0.0.1",
			portRangeMin: 42000,
			portRangeMax: 42009,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches,
		});
		const app = buildMatchHost({
			registry,
			maxConcurrentMatches,
			version: "1.2.3-test",
			logger: false,
		});
		return { app, registry, registrar };
	}

	test("POST /matches creates a match and GET /matches/:id returns it", async () => {
		const { app } = makeApp();
		try {
			const created = await app.inject({ method: "POST", url: "/matches" });
			assert.equal(created.statusCode, 201);

			const body = created.json<{ matchId: string; port: number; state: string; upstreamUrl: string }>();
			assert.equal(body.state, "running");
			assert.ok(body.port >= 42000 && body.port <= 42009);
			assert.equal(body.upstreamUrl, `ws://127.0.0.1:${body.port}`);

			const fetched = await app.inject({ method: "GET", url: `/matches/${body.matchId}` });
			assert.equal(fetched.statusCode, 200);
			assert.equal(fetched.json<{ matchId: string }>().matchId, body.matchId);
		} finally {
			await app.close();
		}
	});

	test("DELETE /matches/:id stops the match", async () => {
		const { app } = makeApp();
		try {
			const created = await app.inject({ method: "POST", url: "/matches" });
			const { matchId } = created.json<{ matchId: string }>();

			const deleted = await app.inject({ method: "DELETE", url: `/matches/${matchId}` });
			assert.equal(deleted.statusCode, 200);
			assert.equal(deleted.json<{ state: string }>().state, "stopped");
		} finally {
			await app.close();
		}
	});

	test("POST /matches works without a body regardless of Content-Type", async () => {
		// curl -X POST 与 PowerShell 的 Invoke-RestMethod 都会带上一个非 JSON 的
		// 默认 Content-Type。如果这里退回 415，运维手动开一场对局就会失败。
		const { app } = makeApp();
		try {
			const response = await app.inject({
				method: "POST",
				url: "/matches",
				headers: { "content-type": "application/x-www-form-urlencoded" },
			});
			assert.equal(response.statusCode, 201);
		} finally {
			await app.close();
		}
	});

	test("POST /matches rejects an unexpected request body instead of ignoring it", async () => {
		const { app } = makeApp();
		try {
			// 分别覆盖 Fastify 内置能解析的类型和走兜底解析器的类型，
			// 两条路径都必须拒绝，否则调用方会以为自己传的参数生效了。
			const bodies = [
				{ contentType: "application/json", payload: JSON.stringify({ surprise: 1 }) },
				{ contentType: "text/plain", payload: "surprise=1" },
				{ contentType: "application/x-www-form-urlencoded", payload: "surprise=1" },
			];

			for (const { contentType, payload } of bodies) {
				const response = await app.inject({
					method: "POST",
					url: "/matches",
					headers: { "content-type": contentType },
					payload,
				});
				assert.equal(response.statusCode, 400, contentType);
				assert.equal(response.json<{ error: string }>().error, "unexpected_request_body", contentType);
			}
		} finally {
			await app.close();
		}
	});

	test("unknown match ids are 404, not 500", async () => {
		const { app } = makeApp();
		try {
			for (const url of ["/matches/nope", "/matches/nope/renew"]) {
				const method = url.endsWith("/renew") ? "POST" : "GET";
				const response = await app.inject({ method, url });
				assert.equal(response.statusCode, 404, `${method} ${url}`);
			}
		} finally {
			await app.close();
		}
	});

	test("POST /matches returns 502 when the control plane refuses to register", async () => {
		const registrar = new FakeRegistrar();
		registrar.failWith = new MatchSessionRegisterError("control plane register returned HTTP 503");
		const { app, registry } = makeApp(1, registrar);
		try {
			const rejected = await app.inject({ method: "POST", url: "/matches" });
			assert.equal(rejected.statusCode, 502);
			assert.equal(rejected.json<{ error: string }>().error, "session_register_failed");
			assert.equal(registry.runningCount(), 0);

			const ready = await app.inject({ method: "GET", url: "/readyz" });
			assert.equal(ready.statusCode, 200);
		} finally {
			await app.close();
		}
	});

	test("POST /matches returns 503 at capacity and /readyz agrees", async () => {
		const { app } = makeApp(1);
		try {
			await app.inject({ method: "POST", url: "/matches" });

			const rejected = await app.inject({ method: "POST", url: "/matches" });
			assert.equal(rejected.statusCode, 503);
			assert.equal(rejected.json<{ error: string }>().error, "capacity_exhausted");

			const ready = await app.inject({ method: "GET", url: "/readyz" });
			assert.equal(ready.statusCode, 503);
		} finally {
			await app.close();
		}
	});
});

describe("control plane match session registrar", () => {
	test("POSTs matchId and upstreamUrl and accepts HTTP 201", async () => {
		const seen: { method: string; url: string; body?: unknown } = { method: "", url: "" };
		const stub = await listenJson((req, res) => {
			let raw = "";
			req.on("data", (chunk: Buffer) => {
				raw += chunk.toString();
			});
			req.on("end", () => {
				seen.method = req.method ?? "";
				seen.url = req.url ?? "";
				seen.body = JSON.parse(raw) as unknown;
				res.writeHead(201, { "content-type": "application/json" });
				res.end(JSON.stringify({ matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", upstreamUrl: "ws://127.0.0.1:9" }));
			});
		});
		try {
			const registrar = new ControlPlaneMatchSessionRegistrar(stub.url);
			await registrar.register({
				matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				upstreamUrl: "ws://127.0.0.1:9",
			});
			assert.equal(seen.method, "POST");
			assert.equal(seen.url, "/match-sessions");
			assert.deepEqual(seen.body, {
				matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				upstreamUrl: "ws://127.0.0.1:9",
			});
		} finally {
			await stub.close();
		}
	});

	test("throws when the control plane is not a register-success response", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(503, { "content-type": "application/json" });
			res.end(JSON.stringify({ status: "not_ready" }));
		});
		try {
			const registrar = new ControlPlaneMatchSessionRegistrar(stub.url);
			await assert.rejects(
				() =>
					registrar.register({
						matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
						upstreamUrl: "ws://127.0.0.1:9",
					}),
				MatchSessionRegisterError,
			);
		} finally {
			await stub.close();
		}
	});

	test("throws when the echoed match id does not match", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(201, { "content-type": "application/json" });
			res.end(JSON.stringify({ matchId: "11111111-2222-3333-4444-555555555555", upstreamUrl: "ws://127.0.0.1:9" }));
		});
		try {
			const registrar = new ControlPlaneMatchSessionRegistrar(stub.url);
			await assert.rejects(
				() =>
					registrar.register({
						matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
						upstreamUrl: "ws://127.0.0.1:9",
					}),
				/mismatched match id/,
			);
		} finally {
			await stub.close();
		}
	});
});

describe("match host registers with a real control plane", () => {
	test("POST /matches then a ticket verifies back to the advertised upstream", async () => {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const controlPlane = buildServer({ database, version: "1.2.3-test", logger: false });
		await controlPlane.listen({ host: "127.0.0.1", port: 0 });

		const registry = new MatchRegistry({
			launcher: new FakeLauncher(),
			registrar: new ControlPlaneMatchSessionRegistrar(httpBase(controlPlane)),
			upstreamHost: "127.0.0.1",
			portRangeMin: 42000,
			portRangeMax: 42009,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: 2,
		});
		const app = buildMatchHost({
			registry,
			maxConcurrentMatches: 2,
			version: "1.2.3-test",
			logger: false,
		});

		try {
			const created = await app.inject({ method: "POST", url: "/matches" });
			assert.equal(created.statusCode, 201);
			const match = created.json<{ matchId: string; port: number; upstreamUrl: string }>();
			assert.equal(match.upstreamUrl, `ws://127.0.0.1:${match.port}`);

			const issued = await controlPlane.inject({
				method: "POST",
				url: `/match-sessions/${match.matchId}/tickets`,
			});
			assert.equal(issued.statusCode, 201);
			const ticket = issued.json<IssueMatchTicketResponse>().ticket;

			const verified = await controlPlane.inject({
				method: "POST",
				url: "/tickets/verify",
				payload: { ticket },
			});
			assert.equal(verified.statusCode, 200);
			assert.equal(verified.json<VerifyMatchTicketSuccess>().upstreamUrl, match.upstreamUrl);

			const echoed = await controlPlane.inject({
				method: "POST",
				url: "/match-sessions",
				payload: { matchId: match.matchId, upstreamUrl: match.upstreamUrl },
			});
			assert.equal(echoed.statusCode, 409);
		} finally {
			await app.close();
			await controlPlane.close();
			database.close();
		}
	});
});

function httpBase(app: { server: { address(): string | { port: number } | null } }): string {
	return `http://127.0.0.1:${socketPort(app.server.address())}`;
}

function socketPort(address: string | { port: number } | null): number {
	if (address === null || typeof address === "string") {
		throw new Error("expected a TCP listen address");
	}
	return address.port;
}

async function listenJson(
	handler: (request: IncomingMessage, response: ServerResponse) => void,
): Promise<{ url: string; close: () => Promise<void> }> {
	const server = createServer(handler);
	await new Promise<void>((resolvePromise, rejectPromise) => {
		server.once("error", rejectPromise);
		server.listen(0, "127.0.0.1", () => resolvePromise());
	});
	return {
		url: `http://127.0.0.1:${socketPort(server.address())}`,
		close: () =>
			new Promise<void>((resolvePromise, rejectPromise) => {
				server.close((error) => {
					if (error) {
						rejectPromise(error);
						return;
					}
					resolvePromise();
				});
			}),
	};
}

async function waitFor(condition: () => boolean, timeoutMs = 2000): Promise<void> {
	const deadline = Date.now() + timeoutMs;
	while (!condition()) {
		if (Date.now() > deadline) {
			throw new Error("timed out waiting for condition");
		}
		await new Promise((resolvePromise) => setTimeout(resolvePromise, 5));
	}
}
