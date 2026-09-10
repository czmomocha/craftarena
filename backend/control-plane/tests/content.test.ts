import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { after, before, describe, test } from "node:test";

import type { ContentPatchView, ContentVersionView } from "../../contracts/src/index.ts";
import { CONTENT_SIGN_DEV_KEY, signContentMessage, signPatchMessage } from "../src/content_sign.ts";
import { loadConfig } from "../src/config.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

const HASH_V1 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const HASH_V2 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const HASH_PATCH = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
const CONTENT_ID = "ugc_pipe_01";

describe("control plane content sign config", () => {
	test("defaults to the documented test key", () => {
		assert.equal(loadConfig({}).contentSignKey, CONTENT_SIGN_DEV_KEY);
	});

	test("rejects a short CONTENT_SIGN_KEY instead of silently defaulting", () => {
		assert.throws(() => loadConfig({ CONTENT_SIGN_KEY: "tooshort" }), /16-64 UTF-8 bytes/);
	});
});

describe("control plane content publish", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-10T00:00:00.000Z");
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => now,
			contentSignKey: CONTENT_SIGN_DEV_KEY,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("publishes v1 then v2 and keeps the old version readable", async () => {
		const first = await publish(app, 1, HASH_V1, { schema_version: 2, note: "v1" });
		assert.equal(first.statusCode, 201);
		const firstBody = first.json<ContentVersionView>();
		assert.equal(firstBody.content_id, CONTENT_ID);
		assert.equal(firstBody.version, 1);
		assert.equal(firstBody.content_hash, HASH_V1);
		assert.deepEqual(firstBody.bundle, { schema_version: 2, note: "v1" });

		const latestOne = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/latest` });
		assert.equal(latestOne.statusCode, 200);
		assert.equal(latestOne.json<ContentVersionView>().version, 1);

		const second = await publish(app, 2, HASH_V2, { schema_version: 2, note: "v2" });
		assert.equal(second.statusCode, 201);
		assert.equal(second.json<ContentVersionView>().version, 2);
		assert.equal(second.json<ContentVersionView>().content_hash, HASH_V2);

		const latestTwo = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/latest` });
		assert.equal(latestTwo.statusCode, 200);
		assert.equal(latestTwo.json<ContentVersionView>().content_hash, HASH_V2);

		const old = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/versions/1` });
		assert.equal(old.statusCode, 200);
		assert.equal(old.json<ContentVersionView>().content_hash, HASH_V1);
		assert.deepEqual(old.json<ContentVersionView>().bundle, { schema_version: 2, note: "v1" });
	});

	test("rejects a replayed version and a skipped version without moving latest", async () => {
		const replay = await publish(app, 1, HASH_V1, { schema_version: 2, note: "again" });
		assert.equal(replay.statusCode, 409);
		assert.deepEqual(replay.json(), { error: "version_exists" });

		const skipped = await publish(app, 4, HASH_V2, { schema_version: 2, note: "skip" });
		assert.equal(skipped.statusCode, 409);
		assert.deepEqual(skipped.json(), { error: "version_not_next" });

		const latest = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/latest` });
		assert.equal(latest.json<ContentVersionView>().version, 2);
	});

	test("rejects a bad signature before writing", async () => {
		const otherId = "ugc_pipe_bad";
		const signature = signContentMessage(CONTENT_SIGN_DEV_KEY, otherId, 1, HASH_V1);
		const flipped = signature.startsWith("0") ? `1${signature.slice(1)}` : `0${signature.slice(1)}`;
		const rejected = await app.inject({
			method: "POST",
			url: "/content/publish",
			payload: {
				schema_version: 1,
				content_id: otherId,
				version: 1,
				content_hash: HASH_V1,
				signature: flipped,
				bundle: { schema_version: 2 },
			},
		});
		assert.equal(rejected.statusCode, 400);
		assert.deepEqual(rejected.json(), { error: "signature_mismatch" });

		const missing = await app.inject({ method: "GET", url: `/content/${otherId}/latest` });
		assert.equal(missing.statusCode, 404);
		assert.deepEqual(missing.json(), { error: "content_not_found" });
	});

	test("rejects extra body keys and unknown versions", async () => {
		const extra = await app.inject({
			method: "POST",
			url: "/content/publish",
			payload: {
				schema_version: 1,
				content_id: "ugc_pipe_extra",
				version: 1,
				content_hash: HASH_V1,
				signature: signContentMessage(CONTENT_SIGN_DEV_KEY, "ugc_pipe_extra", 1, HASH_V1),
				bundle: { schema_version: 2 },
				latest: true,
			},
		});
		assert.equal(extra.statusCode, 400);

		const missingVersion = await app.inject({
			method: "GET",
			url: `/content/${CONTENT_ID}/versions/9`,
		});
		assert.equal(missingVersion.statusCode, 404);
		assert.deepEqual(missingVersion.json(), { error: "version_not_found" });
	});
});

describe("control plane content store transaction", () => {
	test("a failed increment leaves latest on the previous version", () => {
		const database = new ControlPlaneDatabase(":memory:");
		try {
			database.migrate();
			const now = new Date("2026-09-10T01:00:00.000Z");
			database.publishContent({
				contentId: CONTENT_ID,
				version: 1,
				contentHash: HASH_V1,
				signature: hmac(CONTENT_ID, 1, HASH_V1),
				bundle: { note: "v1" },
				now,
			});
			assert.throws(
				() =>
					database.publishContent({
						contentId: CONTENT_ID,
						version: 3,
						contentHash: HASH_V2,
						signature: hmac(CONTENT_ID, 3, HASH_V2),
						bundle: { note: "skip" },
						now,
					}),
				/not the next stored version/,
			);
			assert.equal(database.getContentLatest(CONTENT_ID)?.version, 1);
			assert.equal(database.getContentVersion(CONTENT_ID, 3), undefined);
		} finally {
			database.close();
		}
	});
});

describe("control plane content patch and rollback", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-10T02:00:00.000Z");
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => now,
			contentSignKey: CONTENT_SIGN_DEV_KEY,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("stores a P0 patch without moving latest and rejects P2 ops", async () => {
		const published = await publish(app, 1, HASH_V1, { schema_version: 2, note: "base" });
		assert.equal(published.statusCode, 201);

		const p0 = await patch(app, 1, 1, "p0", [
			{ bag: "visual", entity_id: 0, field: "fx_revision", value: 2 },
		]);
		assert.equal(p0.statusCode, 201);
		const body = p0.json<ContentPatchView>();
		assert.equal(body.seq, 1);
		assert.equal(body.level, "p0");
		assert.equal(body.patch_hash, HASH_PATCH);

		const listed = await app.inject({
			method: "GET",
			url: `/content/${CONTENT_ID}/patches?base_version=1`,
		});
		assert.equal(listed.statusCode, 200);
		assert.equal(listed.json<{ patches: ContentPatchView[] }>().patches.length, 1);

		const latest = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/latest` });
		assert.equal(latest.json<ContentVersionView>().version, 1);

		const skipped = await patch(app, 1, 3, "p0", [
			{ bag: "visual", entity_id: 0, field: "fx_revision", value: 3 },
		]);
		assert.equal(skipped.statusCode, 409);
		assert.deepEqual(skipped.json(), { error: "seq_not_next" });

		const underreported = await patch(app, 1, 2, "p0", [
			{ bag: "destructibles", entity_id: 40, field: "durability", value: 2 },
		]);
		assert.equal(underreported.statusCode, 400);
		assert.deepEqual(underreported.json(), { error: "level_underreported" });

		const forbidden = await patch(app, 1, 2, "p1", [
			{ bag: "solids", entity_id: 80, field: "x", value: 1 },
		]);
		assert.equal(forbidden.statusCode, 400);
		assert.deepEqual(forbidden.json(), { error: "level_forbidden" });
	});

	test("rolls latest back to v1 while v2 stays readable", async () => {
		const second = await publish(app, 2, HASH_V2, { schema_version: 2, note: "v2" });
		assert.equal(second.statusCode, 201);
		const rolled = await app.inject({
			method: "POST",
			url: `/content/${CONTENT_ID}/rollback`,
			payload: { schema_version: 1, target_version: 1 },
		});
		assert.equal(rolled.statusCode, 200);
		assert.equal(rolled.json<ContentVersionView>().version, 1);
		assert.equal(rolled.json<ContentVersionView>().content_hash, HASH_V1);

		const latest = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/latest` });
		assert.equal(latest.json<ContentVersionView>().version, 1);
		const already = await app.inject({
			method: "POST",
			url: `/content/${CONTENT_ID}/rollback`,
			payload: { schema_version: 1, target_version: 1 },
		});
		assert.equal(already.statusCode, 409);
		assert.deepEqual(already.json(), { error: "already_latest" });
		const old = await app.inject({ method: "GET", url: `/content/${CONTENT_ID}/versions/2` });
		assert.equal(old.statusCode, 200);
		assert.equal(old.json<ContentVersionView>().content_hash, HASH_V2);

		const replayV2 = await publish(app, 2, HASH_V2, { schema_version: 2, note: "again" });
		assert.equal(replayV2.statusCode, 409);
		const third = await publish(
			app,
			3,
			"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
			{ schema_version: 2, note: "v3" },
		);
		assert.equal(third.statusCode, 201);
		assert.equal(third.json<ContentVersionView>().version, 3);
	});
});

async function publish(
	app: ReturnType<typeof buildServer>,
	version: number,
	contentHash: string,
	bundle: Record<string, unknown>,
) {
	return app.inject({
		method: "POST",
		url: "/content/publish",
		payload: {
			schema_version: 1,
			content_id: CONTENT_ID,
			version,
			content_hash: contentHash,
			signature: signContentMessage(CONTENT_SIGN_DEV_KEY, CONTENT_ID, version, contentHash),
			bundle,
		},
	});
}

function hmac(contentId: string, version: number, contentHash: string): string {
	return createHmac("sha256", CONTENT_SIGN_DEV_KEY)
		.update(`${contentId}\n${version}\n${contentHash}`)
		.digest("hex");
}

async function patch(
	app: ReturnType<typeof buildServer>,
	baseVersion: number,
	seq: number,
	level: "p0" | "p1",
	ops: Array<{ bag: string; entity_id: number; field: string; value: number }>,
) {
	return app.inject({
		method: "POST",
		url: "/content/patch",
		payload: {
			schema_version: 1,
			content_id: CONTENT_ID,
			base_version: baseVersion,
			seq,
			level,
			patch_hash: HASH_PATCH,
			signature: signPatchMessage(CONTENT_SIGN_DEV_KEY, CONTENT_ID, baseVersion, seq, HASH_PATCH),
			ops,
		},
	});
}
