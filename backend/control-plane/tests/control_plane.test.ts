import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import type { HealthPayload, ReadinessPayload } from "../../contracts/src/index.ts";
import { loadConfig } from "../src/config.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

describe("control plane config", () => {
	test("falls back to loopback and the default port", () => {
		const config = loadConfig({});
		assert.equal(config.host, "127.0.0.1");
		assert.equal(config.port, 8080);
	});

	test("keeps :memory: verbatim instead of resolving it as a path", () => {
		const config = loadConfig({ CONTROL_PLANE_DB_PATH: ":memory:" });
		assert.equal(config.databasePath, ":memory:");
	});

	test("rejects a port outside the valid range instead of silently defaulting", () => {
		assert.throws(() => loadConfig({ CONTROL_PLANE_PORT: "70000" }), /must be an integer/);
		assert.throws(() => loadConfig({ CONTROL_PLANE_PORT: "not-a-port" }), /must be an integer/);
	});
});

describe("control plane database", () => {
	test("migrations are idempotent", () => {
		const database = new ControlPlaneDatabase(":memory:");
		try {
			const first = database.migrate();
			const second = database.migrate();

			assert.ok(first.length > 0, "first run should apply at least one migration");
			assert.deepEqual(second, [], "second run must be a no-op");
		} finally {
			database.close();
		}
	});

	test("read-write probe round-trips the value it wrote", () => {
		const database = new ControlPlaneDatabase(":memory:");
		try {
			database.migrate();
			assert.equal(database.probeReadWrite(new Date("2026-08-20T00:00:00.000Z")), true);
		} finally {
			database.close();
		}
	});
});

describe("control plane http", () => {
	let database: ControlPlaneDatabase;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		app = buildServer({ database, version: "1.2.3-test", logger: false });
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("GET /healthz reports the service identity and version", async () => {
		const response = await app.inject({ method: "GET", url: "/healthz" });

		assert.equal(response.statusCode, 200);
		const body = response.json<HealthPayload>();
		assert.equal(body.service, "control-plane");
		assert.equal(body.status, "ok");
		assert.equal(body.version, "1.2.3-test");
		assert.ok(body.uptimeSeconds >= 0);
	});

	test("GET /readyz reports the sqlite round-trip check", async () => {
		const response = await app.inject({ method: "GET", url: "/readyz" });

		assert.equal(response.statusCode, 200);
		const body = response.json<ReadinessPayload>();
		assert.equal(body.status, "ready");
		assert.deepEqual(
			body.checks.map((check) => check.name),
			["sqlite_read_write"],
		);
		assert.ok(body.checks.every((check) => check.ok));
	});

	test("GET /readyz returns 503 once the database is gone", async () => {
		// 数据库关掉之后就绪检查必须失败。如果这里还是 200，说明 /readyz
		// 只是在回显常量，不能作为流量门禁使用。
		const brokenDatabase = new ControlPlaneDatabase(":memory:");
		brokenDatabase.migrate();
		brokenDatabase.close();

		const brokenApp = buildServer({
			database: brokenDatabase,
			version: "1.2.3-test",
			logger: false,
		});
		await brokenApp.ready();

		try {
			const response = await brokenApp.inject({ method: "GET", url: "/readyz" });

			assert.equal(response.statusCode, 503);
			const body = response.json<ReadinessPayload>();
			assert.equal(body.status, "not_ready");
			assert.equal(body.checks[0]?.ok, false);
			assert.ok((body.checks[0]?.detail ?? "").length > 0);
		} finally {
			await brokenApp.close();
		}
	});
});
