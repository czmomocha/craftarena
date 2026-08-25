import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import {
	RECONNECT_TICKET_ERRORS,
	type IssueMatchTicketResponse,
	type RegisterMatchSessionResponse,
	type VerifyMatchTicketSuccess,
} from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

describe("control plane ticket reconnect", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-08-25T04:00:00.000Z");
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => now,
			ticketTtlMs: 60_000,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("reissues the same seat after consume without occupying another seat", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:19100", seats: 2 },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		const first = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
		const original = first.json<IssueMatchTicketResponse>().ticket;

		const verified = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: original },
		});
		assert.equal(verified.statusCode, 200);
		assert.deepEqual(verified.json<VerifyMatchTicketSuccess>(), {
			ok: true,
			upstreamUrl: "ws://127.0.0.1:19100",
			seat: 0,
		});

		now = new Date("2026-08-25T04:10:00.000Z");
		const reissued = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: original },
		});
		assert.equal(reissued.statusCode, 201);
		const next = reissued.json<IssueMatchTicketResponse>();
		assert.equal(next.matchId, matchId);
		assert.notEqual(next.ticket, original);
		assert.equal(next.expiresAt, "2026-08-25T04:11:00.000Z");

		const overflow = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		assert.equal(overflow.statusCode, 201);
		const third = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		assert.equal(third.statusCode, 409);

		const reusedOld = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: original },
		});
		assert.equal(reusedOld.statusCode, 401);

		const verifiedNext = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: next.ticket },
		});
		assert.equal(verifiedNext.statusCode, 200);
		assert.equal(verifiedNext.json<VerifyMatchTicketSuccess>().seat, 0);
	});

	test("rejects unconsumed, superseded, extra fields, and a second seat mismatch", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:19101", seats: 2 },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		const issued = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
		const fresh = issued.json<IssueMatchTicketResponse>().ticket;

		const unconsumed = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: fresh },
		});
		assert.equal(unconsumed.statusCode, 400);
		assert.equal(unconsumed.json<{ error: string }>().error, RECONNECT_TICKET_ERRORS.ticketNotConsumed);

		assert.equal(
			(
				await app.inject({
					method: "POST",
					url: "/tickets/verify",
					payload: { ticket: fresh },
				})
			).statusCode,
			200,
		);

		const extra = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: fresh, playerId: "nope" },
		});
		assert.equal(extra.statusCode, 400);
		assert.match(JSON.stringify(extra.json()), /additional properties|unexpected_request_body/);

		const unknown = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: "not-a-real-ticket" },
		});
		assert.equal(unknown.statusCode, 400);
		assert.equal(unknown.json<{ error: string }>().error, RECONNECT_TICKET_ERRORS.unknownTicket);

		const first = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: fresh },
		});
		assert.equal(first.statusCode, 201);
		const replay = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket: fresh },
		});
		assert.equal(replay.statusCode, 400);
		assert.equal(replay.json<{ error: string }>().error, RECONNECT_TICKET_ERRORS.supersededTicket);

		const other = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:19102", seats: 1 },
		});
		const otherId = other.json<RegisterMatchSessionResponse>().matchId;
		const crossed = await app.inject({
			method: "POST",
			url: `/match-sessions/${otherId}/tickets/reconnect`,
			payload: { ticket: first.json<IssueMatchTicketResponse>().ticket },
		});
		assert.equal(crossed.statusCode, 400);
		assert.equal(crossed.json<{ error: string }>().error, RECONNECT_TICKET_ERRORS.matchMismatch);
	});

	test("cannot reconnect after the session is unregistered", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", upstreamUrl: "ws://127.0.0.1:19103" },
		});
		assert.equal(created.statusCode, 201);
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		const issued = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
		const ticket = issued.json<IssueMatchTicketResponse>().ticket;
		assert.equal(
			(
				await app.inject({
					method: "POST",
					url: "/tickets/verify",
					payload: { ticket },
				})
			).statusCode,
			200,
		);
		assert.equal((await app.inject({ method: "DELETE", url: `/match-sessions/${matchId}` })).statusCode, 200);

		const missing = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets/reconnect`,
			payload: { ticket },
		});
		assert.equal(missing.statusCode, 404);
		assert.equal(missing.json<{ error: string }>().error, RECONNECT_TICKET_ERRORS.matchNotFound);
	});
});
