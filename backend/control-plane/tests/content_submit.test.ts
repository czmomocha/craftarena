import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { after, before, describe, test } from "node:test";

import type {
	AccountSessionView,
	ContentSubmitView,
	ContentVersionView,
	GuestMintView,
	PlazaListView,
} from "../../contracts/src/index.ts";
import { CONTENT_SIGN_DEV_KEY } from "../src/content_sign.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

const HASH = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const BUNDLE = { schema_version: 2, cell: 65536 };

describe("control plane content submit", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-11T12:00:00.000Z");
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

	test("guest submit allocates id, signs, lists on plaza, and omits signature", async () => {
		const guest = await mintGuest(app);
		const submitted = await submit(app, guest, BUNDLE, HASH);
		assert.equal(submitted.statusCode, 201);
		const body = submitted.json<ContentSubmitView>();
		assert.match(body.id, /^ugc_[0-9a-f]{32}$/);
		assert.equal(body.version, 1);
		assert.equal(body.content_hash, HASH);
		assert.equal(body.latest, 1);
		assert.equal("signature" in body, false);
		assert.equal("content_id" in body, false);
		assert.notEqual(body.id, "course_01");
		assert.notEqual(body.id, "course_f_playable");

		const owner = database.getContentOwner(body.id);
		assert.equal(owner?.ownerKind, "guest");
		assert.equal(owner?.ownerId, guest.guest_id);

		const latest = await app.inject({ method: "GET", url: `/content/${body.id}/latest` });
		assert.equal(latest.statusCode, 200);
		const stored = latest.json<ContentVersionView>();
		assert.equal(stored.content_id, body.id);
		assert.equal(stored.signature.length, 64);
		assert.equal(stored.content_hash, HASH);

		const plaza = await app.inject({ method: "GET", url: "/content/plaza?tab=newest" });
		assert.equal(plaza.statusCode, 200);
		const listed = plaza.json<PlazaListView>().items;
		assert.equal(listed.some((item) => item.content_id === body.id), true);
	});

	test("account session can submit and two guests get distinct ids", async () => {
		const registered = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: { username: "warm_forge", password: "password1" },
		});
		assert.equal(registered.statusCode, 201);
		const session = registered.json<AccountSessionView>().session;
		const first = await app.inject({
			method: "POST",
			url: "/content/submit",
			headers: { authorization: `Bearer ${session}` },
			payload: { bundle: BUNDLE, content_hash: HASH },
		});
		assert.equal(first.statusCode, 201);
		const accountId = first.json<ContentSubmitView>().id;
		assert.equal(database.getContentOwner(accountId)?.ownerKind, "account");

		const guestA = await mintGuest(app);
		const guestB = await mintGuest(app);
		const a = await submit(app, guestA, BUNDLE, HASH);
		const b = await submit(app, guestB, BUNDLE, HASH);
		assert.equal(a.statusCode, 201);
		assert.equal(b.statusCode, 201);
		assert.notEqual(a.json<ContentSubmitView>().id, b.json<ContentSubmitView>().id);
	});

	test("rejects missing auth, extra keys, bad hash, and bad bundle", async () => {
		const guest = await mintGuest(app);
		const unauth = await app.inject({
			method: "POST",
			url: "/content/submit",
			payload: { bundle: BUNDLE, content_hash: HASH },
		});
		assert.equal(unauth.statusCode, 401);
		assert.deepEqual(unauth.json(), { error: "session_invalid" });

		const extra = await submit(app, guest, BUNDLE, HASH, {
			signature: HASH,
			version: 1,
			content_id: "course_01",
		});
		assert.equal(extra.statusCode, 400);

		const badHash = await submit(app, guest, BUNDLE, "not-a-hash");
		assert.equal(badHash.statusCode, 400);

		const badBundle = await submit(app, guest, { note: "no schema" }, HASH);
		assert.equal(badBundle.statusCode, 400);
		assert.deepEqual(badBundle.json(), { error: "bundle_invalid" });
	});

	test("claimed guest cannot submit and key-holding publish stays unbound", async () => {
		const guest = await mintGuest(app);
		const claimed = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: {
				username: "bold_spire",
				password: "password1",
				guest_id: guest.guest_id,
				recovery_key: guest.recovery_key,
			},
		});
		assert.equal(claimed.statusCode, 201);
		const rejected = await submit(app, guest, BUNDLE, HASH);
		assert.equal(rejected.statusCode, 409);
		assert.deepEqual(rejected.json(), { error: "guest_claimed" });

		const tool = await app.inject({
			method: "POST",
			url: "/content/publish",
			payload: {
				schema_version: 1,
				content_id: "ugc_tool_01",
				version: 1,
				content_hash: HASH,
				signature: signTool("ugc_tool_01", 1, HASH),
				bundle: BUNDLE,
			},
		});
		assert.equal(tool.statusCode, 201);
		assert.equal(database.getContentOwner("ugc_tool_01"), undefined);
	});
});

async function mintGuest(app: ReturnType<typeof buildServer>): Promise<GuestMintView> {
	const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
	assert.equal(minted.statusCode, 201);
	return minted.json<GuestMintView>();
}

async function submit(
	app: ReturnType<typeof buildServer>,
	guest: GuestMintView,
	bundle: Record<string, unknown>,
	contentHash: string,
	extra: Record<string, unknown> = {},
) {
	return app.inject({
		method: "POST",
		url: "/content/submit",
		headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
		payload: { bundle, content_hash: contentHash, ...extra },
	});
}

function signTool(contentId: string, version: number, contentHash: string): string {
	return createHmac("sha256", CONTENT_SIGN_DEV_KEY)
		.update(`${contentId}\n${version}\n${contentHash}`)
		.digest("hex");
}
