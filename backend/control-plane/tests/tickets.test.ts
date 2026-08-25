import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import {
	TICKET_REJECT_REASONS,
	type IssueMatchTicketResponse,
	type RegisterMatchSessionResponse,
	type UnregisterMatchSessionResponse,
	type VerifyMatchTicketResponse,
	type VerifyMatchTicketSuccess,
} from "../../contracts/src/index.ts";
import { loadConfig } from "../src/config.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";
import { DEFAULT_TICKET_TTL_MS, hashTicket, isMatchId, parseUpstreamUrl } from "../src/tickets.ts";

describe("ticket helpers", () => {
	test("accepts ws and wss upstreams and rejects everything else", () => {
		assert.equal(parseUpstreamUrl("ws://127.0.0.1:18211"), "ws://127.0.0.1:18211");
		assert.equal(parseUpstreamUrl("  wss://match.internal:443/ws  "), "wss://match.internal:443/ws");
		assert.equal(parseUpstreamUrl("http://127.0.0.1:18211"), undefined);
		assert.equal(parseUpstreamUrl("file:///tmp/match"), undefined);
		assert.equal(parseUpstreamUrl("ws://user:pass@127.0.0.1:18211"), undefined);
		assert.equal(parseUpstreamUrl("ws://127.0.0.1:18211#frag"), undefined);
		assert.equal(parseUpstreamUrl("   "), undefined);
	});

	test("hashes tickets so the plaintext is not a lookup key", () => {
		const ticket = "opaque-ticket-value";
		assert.notEqual(hashTicket(ticket), ticket);
		assert.equal(hashTicket(ticket), hashTicket(ticket));
		assert.notEqual(hashTicket(ticket), hashTicket(`${ticket}-x`));
	});
});

describe("control plane ticket config", () => {
	test("defaults the ticket ttl to the development placeholder", () => {
		assert.equal(loadConfig({}).ticketTtlMs, DEFAULT_TICKET_TTL_MS);
		assert.equal(loadConfig({ CONTROL_PLANE_TICKET_TTL_MS: "5000" }).ticketTtlMs, 5000);
	});

	test("rejects a non-positive ticket ttl instead of silently defaulting", () => {
		assert.throws(() => loadConfig({ CONTROL_PLANE_TICKET_TTL_MS: "0" }), /positive integer/);
		assert.throws(() => loadConfig({ CONTROL_PLANE_TICKET_TTL_MS: "-1" }), /positive integer/);
		assert.throws(() => loadConfig({ CONTROL_PLANE_TICKET_TTL_MS: "nope" }), /positive integer/);
	});
});

describe("control plane match tickets", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-08-25T00:00:00.000Z");
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

	test("registers a match session and issues a one-time ticket that verifies to the same upstream", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:18211" },
		});
		assert.equal(created.statusCode, 201);
		const session = created.json<RegisterMatchSessionResponse>();
		assert.ok(isMatchId(session.matchId));
		assert.equal(session.upstreamUrl, "ws://127.0.0.1:18211");
		assert.equal(session.course, "course_01");

		const issued = await app.inject({
			method: "POST",
			url: `/match-sessions/${session.matchId}/tickets`,
		});
		assert.equal(issued.statusCode, 201);
		const ticketBody = issued.json<IssueMatchTicketResponse>();
		assert.equal(ticketBody.matchId, session.matchId);
		assert.equal(ticketBody.expiresAt, "2026-08-25T00:01:00.000Z");
		assert.equal(ticketBody.seat, 0);
		assert.ok(ticketBody.ticket.length >= 32);
		assert.notEqual(ticketBody.ticket, hashTicket(ticketBody.ticket));

		const verified = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: ticketBody.ticket },
		});
		assert.equal(verified.statusCode, 200);
		assert.deepEqual(verified.json<VerifyMatchTicketResponse>(), {
			ok: true,
			upstreamUrl: "ws://127.0.0.1:18211",
			seat: 0,
		});
	});

	test("rejects a ninth ticket when the default seat cap is full", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:18213" },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		assert.equal(created.json<RegisterMatchSessionResponse>().seats, 8);
		for (let index = 0; index < 8; index += 1) {
			const issued = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
			assert.equal(issued.statusCode, 201, `ticket ${index + 1}`);
		}
		const overflow = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
		assert.equal(overflow.statusCode, 409);
		assert.equal(overflow.json<{ error: string }>().error, "match_full");
	});

	test("honors a caller-supplied seat count of one", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:18214", seats: 1 },
		});
		assert.equal(created.statusCode, 201);
		assert.equal(created.json<RegisterMatchSessionResponse>().seats, 1);
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		assert.equal((await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` })).statusCode, 201);
		const overflow = await app.inject({ method: "POST", url: `/match-sessions/${matchId}/tickets` });
		assert.equal(overflow.statusCode, 409);
		assert.equal(overflow.json<{ error: string }>().error, "match_full");
	});

	test("issues independent one-time tickets for the same match", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:18212" },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		const first = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		const second = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		const ticketA = first.json<IssueMatchTicketResponse>().ticket;
		const ticketB = second.json<IssueMatchTicketResponse>().ticket;
		assert.notEqual(ticketA, ticketB);

		const verifiedA = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: ticketA },
		});
		const verifiedB = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: ticketB },
		});
		assert.equal(verifiedA.statusCode, 200);
		assert.equal(verifiedB.statusCode, 200);
		assert.equal(verifiedA.json<VerifyMatchTicketSuccess>().upstreamUrl, "ws://127.0.0.1:18212");
		assert.equal(verifiedB.json<VerifyMatchTicketSuccess>().upstreamUrl, "ws://127.0.0.1:18212");
		assert.equal(verifiedA.json<VerifyMatchTicketSuccess>().seat, 0);
		assert.equal(verifiedB.json<VerifyMatchTicketSuccess>().seat, 1);
	});

	test("accepts a caller-supplied match id", async () => {
		const matchId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://10.0.0.8:9100" },
		});
		assert.equal(created.statusCode, 201);
		assert.equal(created.json<RegisterMatchSessionResponse>().matchId, matchId);
	});

	test("rejects an invalid upstream url", async () => {
		const response = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "http://127.0.0.1:80" },
		});
		assert.equal(response.statusCode, 400);
		assert.equal(response.json<{ error: string }>().error, "invalid_upstream_url");
	});

	test("rejects extra keys on register", async () => {
		const response = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:1", playerId: "nope" },
		});
		assert.equal(response.statusCode, 400);
		assert.match(JSON.stringify(response.json()), /additional properties|unexpected_request_body/);
	});

	test("rejects a duplicate match id", async () => {
		const matchId = "11111111-2222-3333-4444-555555555555";
		const first = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://127.0.0.1:1" },
		});
		assert.equal(first.statusCode, 201);

		const second = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://127.0.0.1:2" },
		});
		assert.equal(second.statusCode, 409);
		assert.equal(second.json<{ error: string }>().error, "match_already_exists");
	});

	test("rejects an unknown match when issuing a ticket", async () => {
		const response = await app.inject({
			method: "POST",
			url: "/match-sessions/99999999-9999-9999-9999-999999999999/tickets",
		});
		assert.equal(response.statusCode, 404);
		assert.equal(response.json<{ error: string }>().error, "match_not_found");
	});

	test("rejects a ticket issue body so later fields cannot be silently ignored", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:3" },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;

		const response = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
			payload: { playerId: "guest" },
		});
		assert.equal(response.statusCode, 400);
		assert.equal(response.json<{ error: string }>().error, "unexpected_request_body");
	});

	test("rejects unknown, blank, expired, and already consumed tickets", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:4" },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;
		const issued = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		const ticket = issued.json<IssueMatchTicketResponse>().ticket;

		const unknown = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: "not-a-real-ticket" },
		});
		assert.equal(unknown.statusCode, 401);
		assert.deepEqual(unknown.json<VerifyMatchTicketResponse>(), {
			ok: false,
			reason: TICKET_REJECT_REASONS.unknownTicket,
		});

		const blank = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: "   " },
		});
		assert.equal(blank.statusCode, 401);
		assert.deepEqual(blank.json<VerifyMatchTicketResponse>(), {
			ok: false,
			reason: TICKET_REJECT_REASONS.missingTicket,
		});

		const first = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket },
		});
		assert.equal(first.statusCode, 200);

		const reused = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket },
		});
		assert.equal(reused.statusCode, 401);
		assert.deepEqual(reused.json<VerifyMatchTicketResponse>(), {
			ok: false,
			reason: TICKET_REJECT_REASONS.consumedTicket,
		});

		const later = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		const expiring = later.json<IssueMatchTicketResponse>().ticket;
		now = new Date("2026-08-25T00:02:00.000Z");
		const expired = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: expiring },
		});
		assert.equal(expired.statusCode, 401);
		assert.deepEqual(expired.json<VerifyMatchTicketResponse>(), {
			ok: false,
			reason: TICKET_REJECT_REASONS.expiredTicket,
		});
	});

	test("unregisters a session so leftover tickets and new issues fail", async () => {
		const matchId = "aaaaaaaa-bbbb-cccc-dddd-ffffffffffff";
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://127.0.0.1:18220" },
		});
		assert.equal(created.statusCode, 201);
		const leftover = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		assert.equal(leftover.statusCode, 201);
		const leftoverTicket = leftover.json<IssueMatchTicketResponse>().ticket;

		const deleted = await app.inject({
			method: "DELETE",
			url: `/match-sessions/${matchId}`,
		});
		assert.equal(deleted.statusCode, 200);
		assert.deepEqual(deleted.json<UnregisterMatchSessionResponse>(), { matchId });

		const issued = await app.inject({
			method: "POST",
			url: `/match-sessions/${matchId}/tickets`,
		});
		assert.equal(issued.statusCode, 404);
		assert.equal(issued.json<{ error: string }>().error, "match_not_found");

		const verified = await app.inject({
			method: "POST",
			url: "/tickets/verify",
			payload: { ticket: leftoverTicket },
		});
		assert.equal(verified.statusCode, 401);
		assert.deepEqual(verified.json<VerifyMatchTicketResponse>(), {
			ok: false,
			reason: TICKET_REJECT_REASONS.unknownTicket,
		});
	});

	test("allows the same match id to register again after unregister", async () => {
		const matchId = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff";
		const first = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://127.0.0.1:18221" },
		});
		assert.equal(first.statusCode, 201);
		const deleted = await app.inject({
			method: "DELETE",
			url: `/match-sessions/${matchId}`,
		});
		assert.equal(deleted.statusCode, 200);

		const second = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId, upstreamUrl: "ws://10.0.0.8:9101" },
		});
		assert.equal(second.statusCode, 201);
		assert.equal(second.json<RegisterMatchSessionResponse>().upstreamUrl, "ws://10.0.0.8:9101");
	});

	test("does not unregister a neighbor session", async () => {
		const keepId = "cccccccc-dddd-eeee-ffff-000000000000";
		const dropId = "dddddddd-eeee-ffff-0000-111111111111";
		await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId: keepId, upstreamUrl: "ws://127.0.0.1:18222" },
		});
		await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { matchId: dropId, upstreamUrl: "ws://127.0.0.1:18223" },
		});

		const deleted = await app.inject({
			method: "DELETE",
			url: `/match-sessions/${dropId}`,
		});
		assert.equal(deleted.statusCode, 200);

		const kept = await app.inject({
			method: "POST",
			url: `/match-sessions/${keepId}/tickets`,
		});
		assert.equal(kept.statusCode, 201);
	});

	test("rejects an unknown match when unregistering", async () => {
		const response = await app.inject({
			method: "DELETE",
			url: "/match-sessions/99999999-9999-9999-9999-999999999999",
		});
		assert.equal(response.statusCode, 404);
		assert.equal(response.json<{ error: string }>().error, "match_not_found");
	});

	test("rejects an invalid match id when unregistering", async () => {
		const response = await app.inject({
			method: "DELETE",
			url: "/match-sessions/not-a-uuid",
		});
		assert.equal(response.statusCode, 400);
		assert.equal(response.json<{ error: string }>().error, "invalid_match_id");
	});

	test("rejects an unregister body so later fields cannot be silently ignored", async () => {
		const created = await app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: { upstreamUrl: "ws://127.0.0.1:18224" },
		});
		const matchId = created.json<RegisterMatchSessionResponse>().matchId;

		const response = await app.inject({
			method: "DELETE",
			url: `/match-sessions/${matchId}`,
			payload: { force: true },
		});
		assert.equal(response.statusCode, 400);
		assert.equal(response.json<{ error: string }>().error, "unexpected_request_body");
	});
});
