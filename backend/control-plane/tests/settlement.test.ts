import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import type { MatchSettlementResponse, RegisterMatchSessionResponse } from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";
import { isValidSettlementSemantics } from "../src/settlement.ts";

const VALID_BODY = {
	tick: 5,
	stateHash: "abc123",
	padTotal: 3,
	mvpSlot: 0,
	rows: [
		{ slot: 0, place: 1, finishTick: 4, acceptedCount: 3 },
		{ slot: 1, place: 2, finishTick: 4, acceptedCount: 3 },
	],
};

describe("settlement semantics", () => {
	test("accepts consecutive places with mvp at place 1", () => {
		assert.equal(isValidSettlementSemantics(VALID_BODY), true);
	});

	test("rejects duplicate slots, missing places, or mismatched mvp", () => {
		assert.equal(
			isValidSettlementSemantics({
				...VALID_BODY,
				rows: [
					{ slot: 0, place: 1, finishTick: 4, acceptedCount: 3 },
					{ slot: 0, place: 2, finishTick: 4, acceptedCount: 3 },
				],
			}),
			false,
		);
		assert.equal(
			isValidSettlementSemantics({
				...VALID_BODY,
				rows: [
					{ slot: 0, place: 1, finishTick: 4, acceptedCount: 3 },
					{ slot: 1, place: 3, finishTick: 4, acceptedCount: 3 },
				],
			}),
			false,
		);
		assert.equal(isValidSettlementSemantics({ ...VALID_BODY, mvpSlot: 1 }), false);
	});
});

describe("control plane match settlement", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-08-25T12:00:00.000Z");
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

	async function registerMatch(matchId: string): Promise<void> {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://127.0.0.1:18211", seats: 2 },
		});
		assert.equal(created.statusCode, 201);
		assert.equal(created.json<RegisterMatchSessionResponse>().matchId, matchId);
	}

	test("writes once, echoes the board, and refuses a second write", async () => {
		const matchId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
		await registerMatch(matchId);
		const created = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/settlement`,
			payload: VALID_BODY,
		});
		assert.equal(created.statusCode, 201);
		const body = created.json<MatchSettlementResponse>();
		assert.equal(body.matchId, matchId);
		assert.equal(body.tick, 5);
		assert.equal(body.stateHash, "abc123");
		assert.equal(body.padTotal, 3);
		assert.equal(body.mvpSlot, 0);
		assert.deepEqual(body.rows, VALID_BODY.rows);
		assert.equal(body.createdAt, now.toISOString());

		const duplicate = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/settlement`,
			payload: VALID_BODY,
		});
		assert.equal(duplicate.statusCode, 409);
		assert.equal(duplicate.json<{ error: string }>().error, "already_settled");
	});

	test("keeps the record after the live session is unregistered", async () => {
		const matchId = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff";
		await registerMatch(matchId);
		const created = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/settlement`,
			payload: VALID_BODY,
		});
		assert.equal(created.statusCode, 201);
		const deleted = await app.inject({
			method: "DELETE",
			url: `/match-sessions/${matchId}`,
		});
		assert.equal(deleted.statusCode, 200);
		const read = await app.inject({
			method: "GET",
			url: `/match-sessions/${matchId}/settlement`,
		});
		assert.equal(read.statusCode, 200);
		assert.equal(read.json<MatchSettlementResponse>().mvpSlot, 0);

		const afterGone = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/settlement`,
			payload: VALID_BODY,
		});
		assert.equal(afterGone.statusCode, 404);
		assert.equal(afterGone.json<{ error: string }>().error, "match_not_found");
	});

	test("GET is 404 until the first write", async () => {
		const matchId = "dddddddd-eeee-ffff-0000-111111111111";
		await registerMatch(matchId);
		const missing = await app.inject({
			method: "GET",
			url: `/match-sessions/${matchId}/settlement`,
		});
		assert.equal(missing.statusCode, 404);
		assert.equal(missing.json<{ error: string }>().error, "settlement_not_found");
	});

	test("rejects unknown matches, extra fields, and unfinished rows", async () => {
		const missing = await app.inject({
			method: "POST",
			url: "/match-sessions/11111111-2222-3333-4444-555555555555/settlement",
			payload: VALID_BODY,
		});
		assert.equal(missing.statusCode, 404);

		const extraMatch = "cccccccc-dddd-eeee-ffff-000000000000";
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId: extraMatch, upstreamUrl: "ws://127.0.0.1:18212", seats: 2 },
		});
		assert.equal(created.statusCode, 201);

		const extra = await app.inject({
			method: "POST",
			url: `/match-sessions/${extraMatch}/settlement`,
			payload: { ...VALID_BODY, mmr: 1200 },
		});
		assert.equal(extra.statusCode, 400);

		const unfinished = await app.inject({
			method: "POST",
			url: `/match-sessions/${extraMatch}/settlement`,
			payload: {
				...VALID_BODY,
				rows: [
					{ slot: 0, place: 1, finishTick: -1, acceptedCount: 1 },
					{ slot: 1, place: 2, finishTick: 4, acceptedCount: 3 },
				],
			},
		});
		assert.equal(unfinished.statusCode, 400);
	});
});
