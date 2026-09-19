import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { after, before, describe, test } from "node:test";

import type { GuestMintView } from "../../contracts/src/index.ts";
import { TRAPRUSH_REPLAY_ERRORS, TRAPRUSH_REPLAY_SERVER_RING } from "../../contracts/src/traprush_replay.ts";
import { officialTraprushCoursePath } from "../../contracts/src/official_courses.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

const HASH = "a".repeat(64);
const PATH = officialTraprushCoursePath("course_01");

function tape(overrides: Record<string, unknown> = {}) {
	return {
		schema_version: 1,
		course_id: "course_01",
		official_path: PATH,
		content_hash: HASH,
		seed: 1,
		go_tick: 180,
		seats: 1,
		commands: [],
		finish_ticks: [12],
		...overrides,
	};
}

describe("control plane TRAPRUSH replay library", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-19T12:00:00.000Z");
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => now,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("POST stores for ticket owners; GET is current-account only", async () => {
		const guestA = await mintGuest(app);
		const guestB = await mintGuest(app);
		const matchId = randomUUID();
		database.insertMatchSession({
			matchId,
			upstreamUrl: "ws://127.0.0.1:18211",
			now,
			seats: 2,
			course: "course_01",
		});
		database.issueTicket(matchId, now, 60_000, { ownerKind: "guest", ownerId: guestA.guest_id });
		database.issueTicket(matchId, now, 60_000, { ownerKind: "guest", ownerId: guestB.guest_id });

		const posted = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/replay`,
			payload: { tape: tape({ seats: 2, finish_ticks: [10, 20] }) },
		});
		assert.equal(posted.statusCode, 201);
		assert.equal(posted.json<{ matchId: string; stored: number }>().stored, 2);

		const listA = await app.inject({
			method: "GET",
			url: "/traprush-replays",
			headers: guestHeaders(guestA),
		});
		assert.equal(listA.statusCode, 200);
		const itemsA = listA.json<{ items: { replay_id: string }[] }>().items;
		assert.equal(itemsA.length, 1);

		const listB = await app.inject({
			method: "GET",
			url: "/traprush-replays",
			headers: guestHeaders(guestB),
		});
		assert.equal(listB.statusCode, 200);
		assert.equal(listB.json<{ items: unknown[] }>().items.length, 1);

		const guestC = await mintGuest(app);
		const listC = await app.inject({
			method: "GET",
			url: "/traprush-replays",
			headers: guestHeaders(guestC),
		});
		assert.equal(listC.statusCode, 200);
		assert.equal(listC.json<{ items: unknown[] }>().items.length, 0);

		const viewOther = await app.inject({
			method: "GET",
			url: `/traprush-replays/${itemsA[0]?.replay_id ?? "missing"}`,
			headers: guestHeaders(guestC),
		});
		assert.equal(viewOther.statusCode, 404);
		assert.deepEqual(viewOther.json(), { error: TRAPRUSH_REPLAY_ERRORS.notFound });
	});

	test("GET without identity is 401; invalid tape and missing match are 400/404", async () => {
		const unauth = await app.inject({ method: "GET", url: "/traprush-replays" });
		assert.equal(unauth.statusCode, 401);

		const missing = await app.inject({
			method: "POST",
			url: `/match-sessions/${randomUUID()}/replay`,
			payload: { tape: tape() },
		});
		assert.equal(missing.statusCode, 404);
		assert.deepEqual(missing.json(), { error: TRAPRUSH_REPLAY_ERRORS.matchNotFound });

		const matchId = randomUUID();
		database.insertMatchSession({
			matchId,
			upstreamUrl: "ws://127.0.0.1:18212",
			now,
			seats: 1,
			course: "course_01",
		});
		const invalid = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/replay`,
			payload: { tape: tape({ official_path: "res://nope.json" }) },
		});
		assert.equal(invalid.statusCode, 400);
		assert.deepEqual(invalid.json(), { error: TRAPRUSH_REPLAY_ERRORS.invalidTape });
	});

	test("no ticket owners still 201 stored:0; ring trims to 100", async () => {
		const orphan = randomUUID();
		database.insertMatchSession({
			matchId: orphan,
			upstreamUrl: "ws://127.0.0.1:18213",
			now,
			seats: 1,
			course: "course_01",
		});
		const empty = await app.inject({
			method: "POST",
			url: `/match-sessions/${orphan}/replay`,
			payload: { tape: tape() },
		});
		assert.equal(empty.statusCode, 201);
		assert.equal(empty.json<{ stored: number }>().stored, 0);

		const guest = await mintGuest(app);
		for (let index = 0; index < TRAPRUSH_REPLAY_SERVER_RING + 1; index += 1) {
			const matchId = randomUUID();
			database.insertMatchSession({
				matchId,
				upstreamUrl: "ws://127.0.0.1:19000",
				now: new Date(now.getTime() + index * 1000),
				seats: 1,
				course: "course_01",
			});
			database.issueTicket(matchId, now, 60_000, { ownerKind: "guest", ownerId: guest.guest_id });
			const stored = database.recordTraprushReplay({
				matchId,
				tape: tape({ finish_ticks: [index] }),
				now: new Date(now.getTime() + index * 1000),
			});
			assert.equal(stored, 1);
		}
		const listed = database.listTraprushReplays("guest", guest.guest_id);
		assert.equal(listed.length, TRAPRUSH_REPLAY_SERVER_RING);
	});
});

async function mintGuest(app: ReturnType<typeof buildServer>): Promise<GuestMintView> {
	const minted = await app.inject({ method: "POST", url: "/accounts/guest" });
	assert.equal(minted.statusCode, 201);
	return minted.json<GuestMintView>();
}

function guestHeaders(guest: GuestMintView): Record<string, string> {
	return { "x-guest-id": guest.guest_id, "x-guest-key": guest.recovery_key };
}
