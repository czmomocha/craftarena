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
	seats = 2;
	remainingCapacity = 100;
	#app: FastifyInstance | undefined;
	#nextPort = 22000;

	bind(app: FastifyInstance): void {
		this.#app = app;
	}

	async launch(request: { course?: string } = {}): Promise<{ matchId: string }> {
		if (this.remainingCapacity <= 0) {
			throw new MatchHostCapacityError("match host is at capacity");
		}
		if (this.#app === undefined) {
			throw new Error("fake launcher is not bound");
		}
		const course = request.course ?? "course_01";
		const matchId = randomUUID();
		const registered = await this.#app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: {
				matchId,
				upstreamUrl: `ws://127.0.0.1:${this.#nextPort}`,
				seats: this.seats,
				course,
			},
		});
		this.#nextPort += 1;
		if (registered.statusCode !== 201) {
			throw new Error(`fake register failed: ${registered.statusCode}`);
		}
		this.remainingCapacity -= 1;
		this.launchedCourses.push(course);
		return { matchId };
	}
}

describe("control plane official course select", () => {
	async function withApp(run: (app: FastifyInstance, launcher: FakeMatchLauncher) => Promise<void>): Promise<void> {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const launcher = new FakeMatchLauncher();
		const app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => new Date("2026-08-25T05:00:00.000Z"),
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

	test("empty body defaults to course_01 and echoes it on join", async () => {
		await withApp(async (app, launcher) => {
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 201);
			const room = created.json<MatchmakingJoinResponse>();
			assert.equal(room.course, "course_01");
			assert.deepEqual(launcher.launchedCourses, ["course_01"]);
		});
	});

	test("create room with course_02 does not join a course_01 quick-play room", async () => {
		await withApp(async (app, launcher) => {
			const first = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01" },
			});
			const second = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_02" },
			});
			assert.equal(first.statusCode, 201);
			assert.equal(second.statusCode, 201);
			const course01 = first.json<MatchmakingJoinResponse>();
			const course02 = second.json<MatchmakingJoinResponse>();
			assert.equal(course01.course, "course_01");
			assert.equal(course02.course, "course_02");
			assert.notEqual(course01.matchId, course02.matchId);
			assert.deepEqual(launcher.launchedCourses, ["course_01", "course_02"]);

			const quick = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_02" },
			});
			assert.equal(quick.statusCode, 201);
			const joined = quick.json<MatchmakingJoinResponse>();
			assert.equal(joined.matchId, course02.matchId);
			assert.equal(joined.course, "course_02");
			assert.equal(joined.issued, 2);
		});
	});

	test("join by room code returns that room's course", async () => {
		await withApp(async (app) => {
			const created = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_03" },
			});
			const room = created.json<MatchmakingJoinResponse>();
			const joined = await app.inject({
				method: "POST",
				url: `/matchmaking/rooms/${room.roomCode}/join`,
			});
			assert.equal(joined.statusCode, 201);
			assert.equal(joined.json<MatchmakingJoinResponse>().course, "course_03");
		});
	});

	test("queue remembers the requested course and does not take leftover seats of another course", async () => {
		await withApp(async (app, launcher) => {
			launcher.seats = 2;
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01" },
			});
			const room = occupying.json<MatchmakingJoinResponse>();

			const queued = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_02" },
			});
			assert.equal(queued.statusCode, 202);
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();
			assert.equal(waiting.course, "course_02");

			const stillWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(stillWaiting.json<MatchmakingQueueWaitingResponse>().status, "waiting");
			assert.equal(stillWaiting.json<MatchmakingQueueWaitingResponse>().course, "course_02");
			assert.deepEqual(launcher.launchedCourses, ["course_01"]);
			assert.equal(room.issued, 1);
		});
	});

	test("rejects unknown courses, res:// paths, and extra fields", async () => {
		await withApp(async (app) => {
			const unknown = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_99" },
			});
			assert.equal(unknown.statusCode, 400);
			assert.equal(unknown.json<{ error: string }>().error, "invalid_course");

			const path = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "res://content/official/traprush/course_01.json" },
			});
			assert.equal(path.statusCode, 400);
			assert.equal(path.json<{ error: string }>().error, "invalid_course");

			const extra = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_01", seats: 8 },
			});
			assert.equal(extra.statusCode, 400);
			assert.equal(extra.json<{ error: string }>().error, "unexpected_request_body");
		});
	});

	test("join by room code rejects a body so callers cannot swap the locked course", async () => {
		await withApp(async (app) => {
			const created = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_02" },
			});
			const room = created.json<MatchmakingJoinResponse>();
			const swapped = await app.inject({
				method: "POST",
				url: `/matchmaking/rooms/${room.roomCode}/join`,
				payload: { course: "course_03" },
			});
			assert.equal(swapped.statusCode, 400);
			assert.equal(swapped.json<{ error: string }>().error, "unexpected_request_body");
		});
	});

	test("queue drain launches the waiter's course when capacity returns", async () => {
		await withApp(async (app, launcher) => {
			launcher.seats = 2;
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01" },
			});
			assert.equal(occupying.statusCode, 201);
			const occupied = occupying.json<MatchmakingJoinResponse>();

			const queued = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { course: "course_02" },
			});
			assert.equal(queued.statusCode, 202);
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();

			launcher.remainingCapacity = 1;
			assert.equal(
				(await app.inject({ method: "DELETE", url: `/match-sessions/${occupied.matchId}` })).statusCode,
				200,
			);

			const ready = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(ready.statusCode, 200);
			assert.equal(ready.json<{ status: string }>().status, "ready");
			assert.equal(ready.json<{ course: string }>().course, "course_02");
			assert.notEqual(ready.json<{ matchId: string }>().matchId, occupied.matchId);
			assert.deepEqual(launcher.launchedCourses, ["course_01", "course_02"]);
		});
	});

	test("match-sessions defaults to course_01 and rejects unknown ids", async () => {
		await withApp(async (app) => {
			const created = await app.inject({
				method: "POST",
				url: "/match-sessions",
				payload: { upstreamUrl: "ws://127.0.0.1:19110" },
			});
			assert.equal(created.statusCode, 201);
			assert.equal(created.json<{ course: string }>().course, "course_01");

			const requested = await app.inject({
				method: "POST",
				url: "/match-sessions",
				payload: { upstreamUrl: "ws://127.0.0.1:19111", course: "course_02" },
			});
			assert.equal(requested.statusCode, 201);
			assert.equal(requested.json<{ course: string }>().course, "course_02");

			const invalid = await app.inject({
				method: "POST",
				url: "/match-sessions",
				payload: { upstreamUrl: "ws://127.0.0.1:19112", course: "course_99" },
			});
			assert.equal(invalid.statusCode, 400);
			assert.equal(invalid.json<{ error: string }>().error, "invalid_course");
		});
	});
});
