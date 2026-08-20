import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { probeReadyEndpoint, waitUntilReady, type ProbeResult } from "../src/readiness.ts";
import { SERVICES, parseListeningUrl } from "../src/services.ts";

describe("service list", () => {
	it("starts the control plane before the gateway that probes it", () => {
		const names = SERVICES.map((service) => service.name);
		assert.ok(names.indexOf("control-plane") < names.indexOf("gateway"));
	});

	it("points every entry at a TypeScript file under its own package", () => {
		for (const service of SERVICES) {
			assert.match(service.entry, /^backend\/[a-z-]+\/src\/main\.ts$/);
		}
	});
});

describe("listening address parsing", () => {
	it("reads the address out of a pino json line", () => {
		const line = JSON.stringify({ level: 30, msg: "Server listening at http://127.0.0.1:8080" });
		assert.equal(parseListeningUrl(line), "http://127.0.0.1:8080");
	});

	it("also works when the log is plain text", () => {
		assert.equal(parseListeningUrl("Server listening at http://127.0.0.1:8090"), "http://127.0.0.1:8090");
	});

	it("rewrites wildcard addresses to something actually connectable", () => {
		const wildcardV4 = JSON.stringify({ msg: "Server listening at http://0.0.0.0:8100" });
		assert.equal(parseListeningUrl(wildcardV4), "http://127.0.0.1:8100");

		const wildcardV6 = JSON.stringify({ msg: "Server listening at http://[::]:8100" });
		assert.equal(parseListeningUrl(wildcardV6), "http://[::1]:8100");
	});

	it("ignores unrelated lines instead of guessing", () => {
		assert.equal(parseListeningUrl(JSON.stringify({ msg: "control plane ready" })), undefined);
		assert.equal(parseListeningUrl("{ not json after all"), undefined);
		assert.equal(parseListeningUrl(""), undefined);
	});
});

describe("readiness polling", () => {
	it("returns as soon as a probe succeeds", async () => {
		let calls = 0;
		await waitUntilReady(
			async () => {
				calls += 1;
				return calls >= 3 ? { ok: true } : { ok: false, reason: "warming up" };
			},
			{ timeoutMs: 1000, intervalMs: 1, now: () => 0, sleep: async () => {} },
		);

		assert.equal(calls, 3);
	});

	it("reports the last failure reason when it times out", async () => {
		let clock = 0;
		const probe = async (): Promise<ProbeResult> => ({ ok: false, reason: "ECONNREFUSED" });

		await assert.rejects(
			waitUntilReady(probe, {
				timeoutMs: 10,
				intervalMs: 5,
				now: () => clock,
				sleep: async () => {
					clock += 5;
				},
			}),
			/not ready within 10ms: ECONNREFUSED/,
		);
	});

	it("probes at least once even with a zero timeout", async () => {
		let calls = 0;
		await waitUntilReady(
			async () => {
				calls += 1;
				return { ok: true };
			},
			{ timeoutMs: 0, intervalMs: 1, now: () => 0, sleep: async () => {} },
		);

		assert.equal(calls, 1);
	});
});

describe("readyz probe", () => {
	it("turns a refused connection into a readable reason instead of throwing", async () => {
		// 端口 1 上不会有服务，用它拿一个确定的连接失败。
		const result = await probeReadyEndpoint("http://127.0.0.1:1", 250);
		assert.equal(result.ok, false);
		assert.ok(!result.ok && result.reason.length > 0);
	});
});
