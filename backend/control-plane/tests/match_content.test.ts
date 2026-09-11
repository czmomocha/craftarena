import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import type {
	ContentSubmitView,
	GuestMintView,
	MatchmakingJoinResponse,
} from "../../contracts/src/index.ts";
import { CONTENT_SIGN_DEV_KEY } from "../src/content_sign.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";
import { FakeMatchLauncher } from "./fake_match_launcher.ts";

const HASH = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const BUNDLE = { schema_version: 2, cell: 65536 };

describe("control plane signed content matchmaking", () => {
	let database: ControlPlaneDatabase;
	let app: ReturnType<typeof buildServer>;
	let launcher: FakeMatchLauncher;
	let contentId: string;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		launcher = new FakeMatchLauncher(24000);
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => new Date("2026-09-11T14:00:00.000Z"),
			matchLauncher: launcher,
			contentSignKey: CONTENT_SIGN_DEV_KEY,
		});
		launcher.bind(app);
		await app.ready();
		const guest = await mintGuest(app);
		const submitted = await submit(app, guest);
		assert.equal(submitted.statusCode, 201);
		contentId = submitted.json<ContentSubmitView>().id;
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("create room pins content version and omits stuffing course", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { content: { id: contentId, version: 1 }, seats: 1 },
		});
		assert.equal(created.statusCode, 201);
		const body = created.json<MatchmakingJoinResponse>();
		assert.equal(body.course, null);
		assert.deepEqual(body.content, { id: contentId, version: 1 });
		assert.equal(body.content_hash, HASH);
		assert.equal("course" in body, true);
		assert.notEqual(body.roomCode, undefined);
		assert.deepEqual(launcher.launchedContent[launcher.launchedContent.length - 1], {
			id: contentId,
			version: 1,
		});
	});

	test("quick play joins the same pinned content room", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { content: { id: contentId, version: 1 }, seats: 2 },
		});
		assert.equal(created.statusCode, 201);
		const first = created.json<MatchmakingJoinResponse>();
		const joined = await app.inject({
			method: "POST",
			url: "/matchmaking/quick",
			payload: { content: { id: contentId, version: 1 }, seats: 2 },
		});
		assert.equal(joined.statusCode, 201);
		const second = joined.json<MatchmakingJoinResponse>();
		assert.equal(second.matchId, first.matchId);
		assert.equal(second.course, null);
		assert.deepEqual(second.content, { id: contentId, version: 1 });
		assert.equal(second.content_hash, HASH);
	});

	test("join by code returns the room content and rejects a body", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { content: { id: contentId, version: 1 }, seats: 4 },
		});
		assert.equal(created.statusCode, 201);
		const first = created.json<MatchmakingJoinResponse>();
		const rejected = await app.inject({
			method: "POST",
			url: `/matchmaking/rooms/${first.roomCode}/join`,
			payload: { content: { id: contentId, version: 1 } },
		});
		assert.equal(rejected.statusCode, 400);
		assert.equal(rejected.json<{ error: string }>().error, "unexpected_request_body");
		const joined = await app.inject({
			method: "POST",
			url: `/matchmaking/rooms/${first.roomCode}/join`,
		});
		assert.equal(joined.statusCode, 201);
		const body = joined.json<MatchmakingJoinResponse>();
		assert.equal(body.course, null);
		assert.deepEqual(body.content, { id: contentId, version: 1 });
		assert.equal(body.content_hash, HASH);
	});

	test("official rooms still omit content keys", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { course: "course_02" },
		});
		assert.equal(created.statusCode, 201);
		const body = created.json<MatchmakingJoinResponse>();
		assert.equal(body.course, "course_02");
		assert.equal("content" in body, false);
		assert.equal("content_hash" in body, false);
	});

	test("rejects unknown, reserved, dual, and unpinned content", async () => {
		const unknown = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { content: { id: "ugc_ffffffffffffffffffffffffffffffff", version: 1 } },
		});
		assert.equal(unknown.statusCode, 400);
		assert.equal(unknown.json<{ error: string }>().error, "invalid_content");

		const officialId = await app.inject({
			method: "POST",
			url: "/matchmaking/quick",
			payload: { content: { id: "course_01", version: 1 } },
		});
		assert.equal(officialId.statusCode, 400);
		assert.equal(officialId.json<{ error: string }>().error, "invalid_content");

		const demo = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { content: { id: "course_f_playable", version: 1 } },
		});
		assert.equal(demo.statusCode, 400);

		const both = await app.inject({
			method: "POST",
			url: "/matchmaking/rooms",
			payload: { course: "course_01", content: { id: contentId, version: 1 } },
		});
		assert.equal(both.statusCode, 400);
		assert.equal(both.json<{ error: string }>().error, "unexpected_request_body");
	});
});

async function mintGuest(app: ReturnType<typeof buildServer>): Promise<GuestMintView> {
	const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
	assert.equal(minted.statusCode, 201);
	return minted.json<GuestMintView>();
}

async function submit(app: ReturnType<typeof buildServer>, guest: GuestMintView) {
	return app.inject({
		method: "POST",
		url: "/content/submit",
		headers: { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key },
		payload: { bundle: BUNDLE, content_hash: HASH },
	});
}
