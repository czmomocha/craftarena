import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";

import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

describe("control plane browser access", () => {
	let database: ControlPlaneDatabase;
	let app: ReturnType<typeof buildServer>;
	let webRoot: string;

	before(async () => {
		webRoot = await mkdtemp(join(tmpdir(), "craftarena-web-play-"));
		await writeFile(join(webRoot, "index.html"), "<!doctype html><title>play</title>", "utf8");
		await writeFile(join(webRoot, "index.js"), "window.play = true;", "utf8");
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			webRoot,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("GET /healthz allows a browser origin", async () => {
		const response = await app.inject({
			method: "GET",
			url: "/healthz",
			headers: { origin: "http://127.0.0.1:4173" },
		});
		assert.equal(response.statusCode, 200);
		assert.equal(response.headers["access-control-allow-origin"], "*");
	});

	test("OPTIONS /matchmaking/quick answers the CORS preflight", async () => {
		const response = await app.inject({
			method: "OPTIONS",
			url: "/matchmaking/quick",
			headers: {
				origin: "http://127.0.0.1:4173",
				"access-control-request-method": "POST",
				"access-control-request-headers": "content-type",
			},
		});
		assert.equal(response.statusCode, 204);
		assert.equal(response.headers["access-control-allow-origin"], "*");
		assert.match(String(response.headers["access-control-allow-methods"]), /POST/);
		assert.match(String(response.headers["access-control-allow-headers"]), /content-type/i);
	});

	test("GET /play?edit=1 keeps the query on the slash redirect", async () => {
		const response = await app.inject({ method: "GET", url: "/play?edit=1" });
		assert.equal(response.statusCode, 302);
		assert.equal(response.headers.location, "/play/?edit=1");
	});

	test("GET /play/?edit=1 still serves the exported index", async () => {
		const response = await app.inject({ method: "GET", url: "/play/?edit=1" });
		assert.equal(response.statusCode, 200);
		assert.match(response.body, /play/);
	});

	test("GET /play/ serves the exported index", async () => {
		const response = await app.inject({ method: "GET", url: "/play/" });
		assert.equal(response.statusCode, 200);
		assert.match(response.headers["content-type"] ?? "", /text\/html/);
		assert.match(response.body, /play/);
	});

	test("GET /play/index.js serves a sibling export file", async () => {
		const response = await app.inject({ method: "GET", url: "/play/index.js" });
		assert.equal(response.statusCode, 200);
		assert.match(response.body, /window\.play/);
	});

	test("GET /play/ without a web root explains the missing export dir", async () => {
		const bare = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
		});
		await bare.ready();
		try {
			const response = await bare.inject({ method: "GET", url: "/play/" });
			assert.equal(response.statusCode, 503);
			assert.match(response.body, /web_root_unset/);
			assert.match(response.body, /CRAFTARENA_WEB_ROOT/);
		} finally {
			await bare.close();
		}
	});

	test("GET /play/.. is rejected instead of escaping the web root", async () => {
		const response = await app.inject({ method: "GET", url: "/play/%2e%2e/package.json" });
		assert.ok(response.statusCode === 400 || response.statusCode === 404);
		assert.notEqual(response.statusCode, 200);
	});
});
