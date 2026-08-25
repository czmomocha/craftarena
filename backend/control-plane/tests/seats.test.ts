import assert from "node:assert/strict";
import { describe, test } from "node:test";

import type { FastifyInstance } from "fastify";
import { randomUUID } from "node:crypto";

import type {
	MatchmakingJoinResponse,
	MatchmakingQueueWaitingResponse,
} from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { MatchHostCapacityError, type MatchLauncher } from "../src/match_host.ts";
import { buildServer } from "../src/server.ts";

class FakeMatchLauncher implements MatchLauncher {
	readonly launchedCourses: string[] = [];
	readonly launchedSeats: number[] = [];
	seats = 2;
	remainingCapacity = 100;
	#app: FastifyInstance | undefined;
	#nextPort = 23000;

	bind(app: FastifyInstance): void {
		this.#app = app;
	}

	async launch(request: { course?: string; seats?: number } = {}): Promise<{ matchId: string }> {
		if (this.remainingCapacity <= 0) {
			throw new MatchHostCapacityError("match host is at capacity");
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
		this.remainingCapacity -= 1;
		this.launchedCourses.push(course);
		this.launchedSeats.push(seats);
		return { matchId };
	}
}

describe("control plane seats per match", () => {
	async function withApp(run: (app: FastifyInstance, launcher: FakeMatchLauncher) => Promise<void>): Promise<void> {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const launcher = new FakeMatchLauncher();
		const app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => new Date("2026-08-25T06:00:00.000Z"),
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

	test("empty body defaults to 2 seats and echoes them on join", async () => {
		await withApp(async (app, launcher) => {
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 201);
			const room = created.json<MatchmakingJoinResponse>();
			assert.equal(room.seats, 2);
			assert.equal(room.course, "course_01");
			assert.deepEqual(launcher.launchedSeats, [2]);
		});
	});

	test("quick play with seats 8 does not join a 2-seat room on the same course", async () => {
		await withApp(async (app, launcher) => {
			const two = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01", seats: 2 },
			});
			const eight = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01", seats: 8 },
			});
			assert.equal(two.statusCode, 201);
			assert.equal(eight.statusCode, 201);
			const twoRoom = two.json<MatchmakingJoinResponse>();
			const eightRoom = eight.json<MatchmakingJoinResponse>();
			assert.equal(twoRoom.seats, 2);
			assert.equal(eightRoom.seats, 8);
			assert.notEqual(twoRoom.matchId, eightRoom.matchId);
			assert.deepEqual(launcher.launchedSeats, [2, 8]);

			const quick = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_01", seats: 8 },
			});
			assert.equal(quick.statusCode, 201);
			const joined = quick.json<MatchmakingJoinResponse>();
			assert.equal(joined.matchId, eightRoom.matchId);
			assert.equal(joined.seats, 8);
			assert.equal(joined.issued, 2);
			assert.equal(joined.seat, 1);
		});
	});

	test("join by room code returns that room's seats and rejects a body", async () => {
		await withApp(async (app) => {
			const created = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { seats: 4 },
			});
			const room = created.json<MatchmakingJoinResponse>();
			assert.equal(room.seats, 4);
			const joined = await app.inject({
				method: "POST",
				url: `/matchmaking/rooms/${room.roomCode}/join`,
			});
			assert.equal(joined.statusCode, 201);
			assert.equal(joined.json<MatchmakingJoinResponse>().seats, 4);

			const swapped = await app.inject({
				method: "POST",
				url: `/matchmaking/rooms/${room.roomCode}/join`,
				payload: { seats: 8 },
			});
			assert.equal(swapped.statusCode, 400);
			assert.equal(swapped.json<{ error: string }>().error, "unexpected_request_body");
		});
	});

	test("queue remembers seats and does not take leftover seats of another size", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { seats: 2 },
			});
			const room = occupying.json<MatchmakingJoinResponse>();

			const queued = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { seats: 8 },
			});
			assert.equal(queued.statusCode, 202);
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();
			assert.equal(waiting.seats, 8);
			assert.equal(waiting.course, "course_01");

			const stillWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(stillWaiting.json<MatchmakingQueueWaitingResponse>().status, "waiting");
			assert.equal(stillWaiting.json<MatchmakingQueueWaitingResponse>().seats, 8);
			assert.deepEqual(launcher.launchedSeats, [2]);
			assert.equal(room.issued, 1);
		});
	});

	test("queue drain launches the waiter's seats when capacity returns", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { seats: 2 },
			});
			assert.equal(occupying.statusCode, 201);
			const occupied = occupying.json<MatchmakingJoinResponse>();

			const queued = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { seats: 8 },
			});
			assert.equal(queued.statusCode, 202);

			launcher.remainingCapacity = 1;
			assert.equal(
				(await app.inject({ method: "DELETE", url: `/match-sessions/${occupied.matchId}` })).statusCode,
				200,
			);

			const waiting = queued.json<MatchmakingQueueWaitingResponse>();
			const ready = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(ready.statusCode, 200);
			assert.equal(ready.json<{ status: string }>().status, "ready");
			assert.equal(ready.json<{ seats: number }>().seats, 8);
			assert.deepEqual(launcher.launchedSeats, [2, 8]);
		});
	});

	test("rejects out-of-range seats, aliases, and extra fields", async () => {
		await withApp(async (app) => {
			const zero = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { seats: 0 },
			});
			assert.equal(zero.statusCode, 400);
			assert.equal(zero.json<{ error: string }>().error, "invalid_seats");

			const nine = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { seats: 9 },
			});
			assert.equal(nine.statusCode, 400);
			assert.equal(nine.json<{ error: string }>().error, "invalid_seats");

			const alias = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { players: 2 },
			});
			assert.equal(alias.statusCode, 400);
			assert.equal(alias.json<{ error: string }>().error, "unexpected_request_body");
		});
	});
});
