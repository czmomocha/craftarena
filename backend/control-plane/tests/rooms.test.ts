import assert from "node:assert/strict";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID } from "node:crypto";
import { describe, test } from "node:test";

import type { FastifyInstance } from "fastify";

import {
	TICKET_REJECT_REASONS,
	type MatchmakingJoinResponse,
	type RegisterMatchSessionResponse,
	type VerifyMatchTicketResponse,
} from "../../contracts/src/index.ts";
import { loadConfig } from "../src/config.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import {
	MatchHostCapacityError,
	MatchHostHttpLauncher,
	MatchHostLaunchError,
	type MatchLauncher,
} from "../src/match_host.ts";
import { ROOM_CODE_PATTERN, generateRoomCode, normalizeRoomCode } from "../src/rooms.ts";
import { buildServer } from "../src/server.ts";
import { isMatchId } from "../src/tickets.ts";

class FakeMatchLauncher implements MatchLauncher {
	readonly launched: string[] = [];
	readonly launchedCourses: string[] = [];
	seats = 2;
	failWith: Error | undefined;
	#app: FastifyInstance | undefined;
	#nextPort = 19000;

	bind(app: FastifyInstance): void {
		this.#app = app;
	}

	async launch(request: { course?: string; seats?: number } = {}): Promise<{ matchId: string }> {
		if (this.failWith !== undefined) {
			throw this.failWith;
		}
		if (this.#app === undefined) {
			throw new Error("fake launcher is not bound");
		}

		const course = request.course ?? "course_01";
		const seats = request.seats ?? this.seats;
		const matchId = randomUUID();
		const registered = await this.#app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: {
				matchId,
				upstreamUrl: `ws://127.0.0.1:${this.#nextPort}`,
				seats,
				course,
			},
		});
		this.#nextPort += 1;
		if (registered.statusCode !== 201) {
			throw new Error(`fake register failed: ${registered.statusCode}`);
		}
		this.launched.push(matchId);
		this.launchedCourses.push(course);
		return { matchId };
	}
}

describe("room code helpers", () => {
	test("generates uppercase codes that omit confusing characters", () => {
		const code = generateRoomCode();
		assert.match(code, ROOM_CODE_PATTERN);
		assert.equal(normalizeRoomCode(`  ${code.toLowerCase()}  `), code);
		assert.equal(normalizeRoomCode("not-a-code"), undefined);
		assert.equal(normalizeRoomCode("IIIIII"), undefined);
	});
});

describe("control plane matchmaking config", () => {
	test("defaults the match-host URL and launch timeout", () => {
		const defaults = loadConfig({});
		assert.equal(defaults.matchHostUrl, "http://127.0.0.1:8100");
		assert.equal(defaults.matchHostLaunchTimeoutMs, 20_000);
	});

	test("strips a trailing slash on MATCH_HOST_URL", () => {
		assert.equal(loadConfig({ MATCH_HOST_URL: "http://10.0.0.8:8100/" }).matchHostUrl, "http://10.0.0.8:8100");
	});

	test("rejects a non-positive launch timeout", () => {
		assert.throws(
			() => loadConfig({ CONTROL_PLANE_MATCH_HOST_LAUNCH_TIMEOUT_MS: "0" }),
			/CONTROL_PLANE_MATCH_HOST_LAUNCH_TIMEOUT_MS/,
		);
	});
});

describe("control plane matchmaking", () => {
	async function withApp(
		run: (app: FastifyInstance, launcher: FakeMatchLauncher) => Promise<void>,
	): Promise<void> {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const launcher = new FakeMatchLauncher();
		const app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => new Date("2026-08-25T01:00:00.000Z"),
			ticketTtlMs: 60_000,
			matchLauncher: launcher,
		});
		launcher.bind(app);
		await app.ready();
		try {
			await run(app, launcher);
		} finally {
			await app.close();
			database.close();
		}
	}

	test("creates a room, issues a ticket, and lets another player join by code", async () => {
		await withApp(async (app) => {
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 201);
			const room = created.json<MatchmakingJoinResponse>();
			assert.match(room.roomCode, ROOM_CODE_PATTERN);
			assert.ok(isMatchId(room.matchId));
			assert.equal(room.seats, 2);
			assert.equal(room.issued, 1);
			assert.equal(room.seat, 0);
			assert.equal(room.course, "course_01");
			assert.equal(room.expiresAt, "2026-08-25T01:01:00.000Z");
			assert.ok(room.ticket.length >= 32);

			const joined = await app.inject({
				method: "POST",
				url: `/matchmaking/rooms/${room.roomCode.toLowerCase()}/join`,
			});
			assert.equal(joined.statusCode, 201);
			const second = joined.json<MatchmakingJoinResponse>();
			assert.equal(second.matchId, room.matchId);
			assert.equal(second.roomCode, room.roomCode);
			assert.equal(second.issued, 2);
			assert.equal(second.seat, 1);
			assert.notEqual(second.ticket, room.ticket);

			const verified = await app.inject({
				method: "POST",
				url: "/tickets/verify",
				payload: { ticket: room.ticket },
			});
			assert.equal(verified.statusCode, 200);
			assert.equal(verified.json<VerifyMatchTicketResponse>().ok, true);
		});
	});

	test("rejects join when the room is full", async () => {
		await withApp(async (app) => {
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = created.json<MatchmakingJoinResponse>();
			await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });

			const full = await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });
			assert.equal(full.statusCode, 409);
			assert.equal(full.json<{ error: string }>().error, "room_full");
		});
	});

	test("rejects an unknown or invalid room code", async () => {
		await withApp(async (app) => {
			const missing = await app.inject({ method: "POST", url: "/matchmaking/rooms/ABCDEF/join" });
			assert.equal(missing.statusCode, 404);
			assert.equal(missing.json<{ error: string }>().error, "room_not_found");

			const invalid = await app.inject({ method: "POST", url: "/matchmaking/rooms/not-a-code/join" });
			assert.equal(invalid.statusCode, 400);
			assert.equal(invalid.json<{ error: string }>().error, "invalid_room_code");
		});
	});

	test("quick play joins the oldest open room instead of launching another", async () => {
		await withApp(async (app, launcher) => {
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = first.json<MatchmakingJoinResponse>();
			const launches = launcher.launched.length;

			const quick = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			assert.equal(quick.statusCode, 201);
			const joined = quick.json<MatchmakingJoinResponse>();
			assert.equal(joined.matchId, room.matchId);
			assert.equal(joined.roomCode, room.roomCode);
			assert.equal(joined.issued, 2);
			assert.equal(launcher.launched.length, launches);
		});
	});

	test("quick play launches a new room when none are open", async () => {
		await withApp(async (app, launcher) => {
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = first.json<MatchmakingJoinResponse>();
			await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });
			const launches = launcher.launched.length;

			const quick = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			assert.equal(quick.statusCode, 201);
			const created = quick.json<MatchmakingJoinResponse>();
			assert.notEqual(created.matchId, room.matchId);
			assert.equal(created.issued, 1);
			assert.equal(launcher.launched.length, launches + 1);
		});
	});

	test("creating a room always launches instead of joining an open neighbor", async () => {
		await withApp(async (app) => {
			const neighbor = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const open = neighbor.json<MatchmakingJoinResponse>();
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 201);
			assert.notEqual(created.json<MatchmakingJoinResponse>().matchId, open.matchId);
		});
	});

	test("does not put a raw registered session into quick play", async () => {
		await withApp(async (app, launcher) => {
			const raw = await app.inject({
				method: "POST",
				url: "/match-sessions",
				payload: {
					matchId: "eeeeeeee-ffff-0000-1111-222222222222",
					upstreamUrl: "ws://127.0.0.1:19999",
					seats: 8,
				},
			});
			assert.equal(raw.statusCode, 201);
			const launches = launcher.launched.length;

			const quick = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			assert.equal(quick.statusCode, 201);
			assert.notEqual(quick.json<MatchmakingJoinResponse>().matchId, raw.json<RegisterMatchSessionResponse>().matchId);
			assert.equal(launcher.launched.length, launches + 1);
		});
	});

	test("does not admit into a neighbor room", async () => {
		await withApp(async (app) => {
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const keep = first.json<MatchmakingJoinResponse>();
			const drop = second.json<MatchmakingJoinResponse>();

			const joined = await app.inject({ method: "POST", url: `/matchmaking/rooms/${keep.roomCode}/join` });
			assert.equal(joined.json<MatchmakingJoinResponse>().matchId, keep.matchId);
			assert.notEqual(joined.json<MatchmakingJoinResponse>().matchId, drop.matchId);
		});
	});

	test("returns leftover tickets unknown after the session is unregistered", async () => {
		await withApp(async (app) => {
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = created.json<MatchmakingJoinResponse>();

			const deleted = await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });
			assert.equal(deleted.statusCode, 200);

			const verified = await app.inject({
				method: "POST",
				url: "/tickets/verify",
				payload: { ticket: room.ticket },
			});
			assert.equal(verified.statusCode, 401);
			assert.deepEqual(verified.json<VerifyMatchTicketResponse>(), {
				ok: false,
				reason: TICKET_REJECT_REASONS.unknownTicket,
			});

			const joined = await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });
			assert.equal(joined.statusCode, 404);
		});
	});

	test("rejects unexpected bodies so later fields cannot be silently ignored", async () => {
		await withApp(async (app) => {
			for (const url of ["/matchmaking/quick", "/matchmaking/rooms"]) {
				const response = await app.inject({
					method: "POST",
					url,
					payload: { playerId: "guest" },
				});
				assert.equal(response.statusCode, 400, url);
				assert.equal(response.json<{ error: string }>().error, "unexpected_request_body", url);
			}
		});
	});

	test("returns 502 when MatchHost fails to launch", async () => {
		await withApp(async (app, launcher) => {
			launcher.failWith = new MatchHostLaunchError("match host launch returned HTTP 502");
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 502);
			assert.equal(created.json<{ error: string }>().error, "session_launch_failed");
		});
	});

	test("returns 503 when no match launcher is configured", async () => {
		const isolated = new ControlPlaneDatabase(":memory:");
		isolated.migrate();
		const bare = buildServer({ database: isolated, version: "1.2.3-test", logger: false });
		await bare.ready();
		try {
			const created = await bare.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 503);
			assert.equal(created.json<{ error: string }>().error, "match_host_unavailable");
		} finally {
			await bare.close();
			isolated.close();
		}
	});
});

describe("match host http launcher", () => {
	test("POSTs /matches and reads the match id", async () => {
		const seen: { method: string; url: string } = { method: "", url: "" };
		const stub = await listenJson((req, res) => {
			seen.method = req.method ?? "";
			seen.url = req.url ?? "";
			res.writeHead(201, { "content-type": "application/json" });
			res.end(JSON.stringify({ matchId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" }));
		});
		try {
			const launcher = new MatchHostHttpLauncher(stub.url);
			const launched = await launcher.launch();
			assert.equal(launched.matchId, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
			assert.equal(seen.method, "POST");
			assert.equal(seen.url, "/matches");
		} finally {
			await stub.close();
		}
	});

	test("maps HTTP 503 to capacity and other failures to launch errors", async () => {
		const stub = await listenJson((_req, res) => {
			res.writeHead(503, { "content-type": "application/json" });
			res.end(JSON.stringify({ error: "capacity_exhausted" }));
		});
		try {
			const launcher = new MatchHostHttpLauncher(stub.url);
			await assert.rejects(() => launcher.launch(), MatchHostCapacityError);
		} finally {
			await stub.close();
		}

		const failed = await listenJson((_req, res) => {
			res.writeHead(502, { "content-type": "application/json" });
			res.end(JSON.stringify({ error: "session_listen_failed" }));
		});
		try {
			const launcher = new MatchHostHttpLauncher(failed.url);
			await assert.rejects(() => launcher.launch(), MatchHostLaunchError);
		} finally {
			await failed.close();
		}
	});
});

function listenJson(
	handler: (request: IncomingMessage, response: ServerResponse) => void,
): Promise<{ url: string; close: () => Promise<void> }> {
	const server = createServer(handler);
	return new Promise((resolvePromise, rejectPromise) => {
		server.once("error", rejectPromise);
		server.listen(0, "127.0.0.1", () => {
			const address = server.address();
			if (address === null || typeof address === "string") {
				rejectPromise(new Error("expected a TCP listen address"));
				return;
			}
			resolvePromise({
				url: `http://127.0.0.1:${address.port}`,
				close: () =>
					new Promise((closeResolve, closeReject) => {
						server.close((error) => {
							if (error) {
								closeReject(error);
								return;
							}
							closeResolve();
						});
					}),
			});
		});
	});
}
