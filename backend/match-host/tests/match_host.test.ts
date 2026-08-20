import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { loadConfig } from "../src/config.ts";
import { createLease, evaluateLease, renewLease } from "../src/lease.ts";
import type { LaunchedProcess, MatchExit, MatchLaunchSpec, ProcessLauncher } from "../src/launcher.ts";
import { PortAllocator } from "../src/ports.ts";
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
});

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
	function makeRegistry(overrides: { now?: () => number; maxConcurrentMatches?: number } = {}) {
		const launcher = new FakeLauncher();
		const registry = new MatchRegistry({
			launcher,
			portRangeMin: 42000,
			portRangeMax: 42009,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: overrides.maxConcurrentMatches ?? 10,
			...(overrides.now === undefined ? {} : { now: overrides.now }),
		});
		return { launcher, registry };
	}

	test("starting a match launches one process with its own port", () => {
		const { launcher, registry } = makeRegistry();

		const first = registry.start();
		const second = registry.start();

		assert.equal(launcher.launched.length, 2);
		assert.notEqual(first.port, second.port);
		assert.equal(registry.runningCount(), 2);
	});

	test("stopping a match kills the process and frees its port", () => {
		const { launcher, registry } = makeRegistry({ maxConcurrentMatches: 1 });

		const match = registry.start();
		assert.throws(() => registry.start(), MatchCapacityError);

		const stopped = registry.stop(match.matchId);
		assert.equal(stopped?.state, "stopped");
		assert.equal(stopped?.stopReason, "requested");
		assert.deepEqual(launcher.killed, [match.matchId]);

		// 槽位释放后必须能再开一场，否则容量会随时间单调递减。
		assert.doesNotThrow(() => registry.start());
	});

	test("reclaims matches whose lease went idle", () => {
		let now = 0;
		const { registry } = makeRegistry({ now: () => now });

		const match = registry.start();
		now = IDLE_MS - 1;
		assert.deepEqual(registry.reclaimExpired(), []);

		now = IDLE_MS;
		const reclaimed = registry.reclaimExpired();
		assert.equal(reclaimed.length, 1);
		assert.equal(reclaimed[0]?.matchId, match.matchId);
		assert.equal(reclaimed[0]?.stopReason, "idle_timeout");
		assert.equal(registry.runningCount(), 0);
	});

	test("renewing keeps a match alive past the idle deadline", () => {
		let now = 0;
		const { registry } = makeRegistry({ now: () => now });

		const match = registry.start();
		now = IDLE_MS - 1;
		registry.renew(match.matchId);

		now = IDLE_MS;
		assert.deepEqual(registry.reclaimExpired(), []);
		assert.equal(registry.runningCount(), 1);
	});

	test("renewing an unknown or stopped match returns undefined", () => {
		const { registry } = makeRegistry();
		const match = registry.start();
		registry.stop(match.matchId);

		assert.equal(registry.renew(match.matchId), undefined);
		assert.equal(registry.renew("does-not-exist"), undefined);
	});

	test("shutdown kills every running match", () => {
		const { launcher, registry } = makeRegistry();
		registry.start();
		registry.start();

		registry.shutdown();

		assert.equal(launcher.killed.length, 2);
		assert.equal(registry.runningCount(), 0);
	});
});

describe("match host http", () => {
	function makeApp(maxConcurrentMatches = 10) {
		const registry = new MatchRegistry({
			launcher: new FakeLauncher(),
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
		return { app, registry };
	}

	test("POST /matches creates a match and GET /matches/:id returns it", async () => {
		const { app } = makeApp();
		try {
			const created = await app.inject({ method: "POST", url: "/matches" });
			assert.equal(created.statusCode, 201);

			const body = created.json<{ matchId: string; port: number; state: string }>();
			assert.equal(body.state, "running");
			assert.ok(body.port >= 42000 && body.port <= 42009);

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
