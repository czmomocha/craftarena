import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import type { AccountMeView, AccountSessionView, DraftView, GuestMintView } from "../../contracts/src/index.ts";
import { ACCOUNT_ERRORS } from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

const DOCUMENT = { schema_version: 1, cell: 65536, revision: 1, entities: [] };

describe("control plane account claim", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-10T12:00:00.000Z");
		app = buildServer({ database, version: "1.2.3-test", logger: false, now: () => now });
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("guest draft survives register claim and login", async () => {
		const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
		assert.equal(minted.statusCode, 201);
		const guest = minted.json<GuestMintView>();
		assert.match(guest.guest_id, /^gst_[0-9a-f]{32}$/);
		assert.ok(guest.recovery_key.length >= 32);

		const saved = await app.inject({
			method: "PUT",
			url: "/drafts",
			headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
			payload: { document: DOCUMENT },
		});
		assert.equal(saved.statusCode, 200);
		assert.deepEqual(saved.json<DraftView>().document, DOCUMENT);

		const registered = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: {
				username: "warm_forge",
				password: "password1",
				guest_id: guest.guest_id,
				recovery_key: guest.recovery_key,
			},
		});
		assert.equal(registered.statusCode, 201);
		const session = registered.json<AccountSessionView>();
		assert.equal(session.username, "warm_forge");
		assert.match(session.account_id, /^acc_[0-9a-f]{32}$/);

		const me = await app.inject({
			method: "GET",
			url: "/accounts/me",
			headers: { authorization: `Bearer ${session.session}` },
		});
		assert.equal(me.statusCode, 200);
		assert.equal(me.json<AccountMeView>().username, "warm_forge");

		const claimed = await app.inject({
			method: "GET",
			url: "/drafts",
			headers: { authorization: `Bearer ${session.session}` },
		});
		assert.equal(claimed.statusCode, 200);
		assert.equal(claimed.json<DraftView>().owner_kind, "account");
		assert.deepEqual(claimed.json<DraftView>().document, DOCUMENT);

		const guestAfter = await app.inject({
			method: "GET",
			url: "/drafts",
			headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
		});
		assert.equal(guestAfter.statusCode, 409);
		assert.equal(guestAfter.json<{ error: string }>().error, ACCOUNT_ERRORS.guestClaimed);

		const login = await app.inject({
			method: "POST",
			url: "/accounts/login",
			payload: { username: "warm_forge", password: "password1" },
		});
		assert.equal(login.statusCode, 200);
		assert.equal(login.json<AccountSessionView>().username, "warm_forge");
	});

	test("duplicate username and wrong password are rejected", async () => {
		const taken = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: { username: "warm_forge", password: "password2" },
		});
		assert.equal(taken.statusCode, 409);
		assert.equal(taken.json<{ error: string }>().error, ACCOUNT_ERRORS.usernameTaken);

		const wrong = await app.inject({
			method: "POST",
			url: "/accounts/login",
			payload: { username: "warm_forge", password: "password2" },
		});
		assert.equal(wrong.statusCode, 401);
		assert.equal(wrong.json<{ error: string }>().error, ACCOUNT_ERRORS.credentialsInvalid);
	});

	test("claim after login moves a later guest draft", async () => {
		const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
		const guest = minted.json<GuestMintView>();
		const later = { schema_version: 1, cell: 65536, revision: 2, entities: [{ id: 1 }] };
		const saved = await app.inject({
			method: "PUT",
			url: "/drafts",
			headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
			payload: { document: later },
		});
		assert.equal(saved.statusCode, 200);

		const login = await app.inject({
			method: "POST",
			url: "/accounts/login",
			payload: { username: "warm_forge", password: "password1" },
		});
		const session = login.json<AccountSessionView>().session;
		const conflict = await app.inject({
			method: "POST",
			url: "/accounts/claim",
			headers: { authorization: `Bearer ${session}` },
			payload: { guest_id: guest.guest_id, recovery_key: guest.recovery_key },
		});
		assert.equal(conflict.statusCode, 409);
		assert.equal(conflict.json<{ error: string }>().error, ACCOUNT_ERRORS.draftConflict);
	});

	test("free-text usernames and missing drafts are rejected", async () => {
		const prose = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: { username: "has space", password: "password1" },
		});
		assert.equal(prose.statusCode, 400);

		const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
		const guest = minted.json<GuestMintView>();
		const missing = await app.inject({
			method: "GET",
			url: "/drafts",
			headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
		});
		assert.equal(missing.statusCode, 404);
		assert.equal(missing.json<{ error: string }>().error, ACCOUNT_ERRORS.draftMissing);

		const registered = await app.inject({
			method: "POST",
			url: "/accounts/register",
			payload: {
				username: "quiet_lane",
				password: "password1",
				guest_id: guest.guest_id,
				recovery_key: guest.recovery_key,
			},
		});
		assert.equal(registered.statusCode, 201);
		const empty = await app.inject({
			method: "GET",
			url: "/drafts",
			headers: { authorization: `Bearer ${registered.json<AccountSessionView>().session}` },
		});
		assert.equal(empty.statusCode, 404);
	});
});
