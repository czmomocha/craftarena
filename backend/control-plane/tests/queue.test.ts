import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { describe, test } from "node:test";

import type { FastifyInstance } from "fastify";

import type {
	CancelMatchQueueResponse,
	MatchmakingJoinResponse,
	MatchmakingQueueStatusResponse,
	MatchmakingQueueWaitingResponse,
	VerifyMatchTicketResponse,
} from "../../contracts/src/index.ts";
import { loadConfig } from "../src/config.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import {
	MatchHostCapacityError,
	MatchHostLaunchError,
	type MatchLauncher,
} from "../src/match_host.ts";
import {
	DEFAULT_QUEUE_SLOT_ESTIMATE_MS,
	DEFAULT_QUEUE_TTL_MS,
	hashQueueToken,
} from "../src/queue.ts";
import { ROOM_CODE_PATTERN } from "../src/rooms.ts";
import { buildServer } from "../src/server.ts";
import { isMatchId } from "../src/tickets.ts";

class FakeMatchLauncher implements MatchLauncher {
	readonly launched: string[] = [];
	seats = 2;
	remainingCapacity = 100;
	failWith: Error | undefined;
	#app: FastifyInstance | undefined;
	#nextPort = 21000;

	bind(app: FastifyInstance): void {
		this.#app = app;
	}

	async launch(): Promise<{ matchId: string }> {
		if (this.failWith !== undefined) {
			throw this.failWith;
		}
		if (this.remainingCapacity <= 0) {
			throw new MatchHostCapacityError("match host is at capacity");
		}
		if (this.#app === undefined) {
			throw new Error("fake launcher is not bound");
		}

		const matchId = randomUUID();
		const registered = await this.#app.inject({
			method: "POST",
			url: "/match-sessions",
			payload: {
				matchId,
				upstreamUrl: `ws://127.0.0.1:${this.#nextPort}`,
				seats: this.seats,
			},
		});
		this.#nextPort += 1;
		if (registered.statusCode !== 201) {
			throw new Error(`fake register failed: ${registered.statusCode}`);
		}
		this.remainingCapacity -= 1;
		this.launched.push(matchId);
		return { matchId };
	}
}

describe("queue token helpers", () => {
	test("hashes queue tokens so the plaintext is not a lookup key", () => {
		const token = "opaque-queue-token";
		assert.notEqual(hashQueueToken(token), token);
		assert.equal(hashQueueToken(token), hashQueueToken(token));
		assert.notEqual(hashQueueToken(token), hashQueueToken(`${token}-x`));
	});
});

describe("control plane queue config", () => {
	test("defaults queue ttl and slot estimate to development placeholders", () => {
		const defaults = loadConfig({});
		assert.equal(defaults.queueTtlMs, DEFAULT_QUEUE_TTL_MS);
		assert.equal(defaults.queueSlotEstimateMs, DEFAULT_QUEUE_SLOT_ESTIMATE_MS);
	});

	test("rejects a non-positive queue ttl or slot estimate", () => {
		assert.throws(() => loadConfig({ CONTROL_PLANE_QUEUE_TTL_MS: "0" }), /CONTROL_PLANE_QUEUE_TTL_MS/);
		assert.throws(
			() => loadConfig({ CONTROL_PLANE_QUEUE_SLOT_ESTIMATE_MS: "-1" }),
			/CONTROL_PLANE_QUEUE_SLOT_ESTIMATE_MS/,
		);
	});
});

describe("control plane matchmaking queue", () => {
	async function withApp(
		run: (app: FastifyInstance, launcher: FakeMatchLauncher, clock: { now: Date }) => Promise<void>,
		overrides: { readonly queueTtlMs?: number; readonly queueSlotEstimateMs?: number } = {},
	): Promise<void> {
		const database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		const launcher = new FakeMatchLauncher();
		const clock = { now: new Date("2026-08-25T02:00:00.000Z") };
		const app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => clock.now,
			ticketTtlMs: 60_000,
			queueTtlMs: overrides.queueTtlMs ?? 600_000,
			queueSlotEstimateMs: overrides.queueSlotEstimateMs ?? 30_000,
			matchLauncher: launcher,
		});
		launcher.bind(app);
		await app.ready();
		try {
			await run(app, launcher, clock);
		} finally {
			await app.close();
			database.close();
		}
	}

	test("enqueues create-room when MatchHost is at capacity and reports position plus estimate", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 0;
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 202);
			const queued = created.json<MatchmakingQueueWaitingResponse>();
			assert.equal(queued.status, "waiting");
			assert.equal(queued.position, 1);
			assert.equal(queued.estimatedWaitMs, 30_000);
			assert.equal(queued.expiresAt, "2026-08-25T02:10:00.000Z");
			assert.ok(queued.queueToken.length >= 32);
		});
	});

	test("lets the client poll until a freed slot launches and issues a ticket", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(occupying.statusCode, 201);
			const room = occupying.json<MatchmakingJoinResponse>();

			const queued = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(queued.statusCode, 202);
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();

			const stillWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(stillWaiting.statusCode, 200);
			assert.deepEqual(stillWaiting.json<MatchmakingQueueStatusResponse>(), waiting);

			launcher.remainingCapacity = 1;
			const deleted = await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });
			assert.equal(deleted.statusCode, 200);

			const ready = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(ready.statusCode, 200);
			const admitted = ready.json<MatchmakingQueueStatusResponse>();
			assert.equal(admitted.status, "ready");
			if (admitted.status !== "ready") {
				return;
			}
			assert.match(admitted.roomCode, ROOM_CODE_PATTERN);
			assert.ok(isMatchId(admitted.matchId));
			assert.notEqual(admitted.matchId, room.matchId);
			assert.equal(admitted.issued, 1);
			assert.equal(admitted.expiresAt, "2026-08-25T02:01:00.000Z");

			const verified = await app.inject({
				method: "POST",
				url: "/tickets/verify",
				payload: { ticket: admitted.ticket },
			});
			assert.equal(verified.statusCode, 200);
			assert.equal(verified.json<VerifyMatchTicketResponse>().ok, true);
		});
	});

	test("serves two waiters in FIFO order when only one slot frees at a time", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();

			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const ahead = first.json<MatchmakingQueueWaitingResponse>();
			const behind = second.json<MatchmakingQueueWaitingResponse>();
			assert.equal(ahead.position, 1);
			assert.equal(behind.position, 2);
			assert.equal(behind.estimatedWaitMs, 60_000);

			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

			const firstReady = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			const secondWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			assert.equal(firstReady.json<MatchmakingQueueStatusResponse>().status, "ready");
			assert.equal(secondWaiting.json<MatchmakingQueueWaitingResponse>().status, "waiting");
			assert.equal(secondWaiting.json<MatchmakingQueueWaitingResponse>().position, 1);
			assert.equal(secondWaiting.json<MatchmakingQueueWaitingResponse>().estimatedWaitMs, 30_000);
		});
	});

	test("seats a later quick waiter into leftover seats of the room launched for the head", async () => {
		await withApp(async (app, launcher) => {
			launcher.seats = 2;
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });

			const first = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			const ahead = first.json<MatchmakingQueueWaitingResponse>();
			const behind = second.json<MatchmakingQueueWaitingResponse>();
			assert.equal(first.statusCode, 202);
			assert.equal(second.statusCode, 202);

			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

			const firstReady = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			const secondReady = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			const admittedHead = firstReady.json<MatchmakingQueueStatusResponse>();
			const admittedTail = secondReady.json<MatchmakingQueueStatusResponse>();
			assert.equal(admittedHead.status, "ready");
			assert.equal(admittedTail.status, "ready");
			if (admittedHead.status !== "ready" || admittedTail.status !== "ready") {
				return;
			}
			assert.equal(admittedHead.matchId, admittedTail.matchId);
			assert.equal(admittedHead.issued, 2);
			assert.equal(admittedTail.issued, 2);
			assert.notEqual(admittedHead.ticket, admittedTail.ticket);
		});
	});

	test("does not let a create-room waiter take leftover seats of another room", async () => {
		await withApp(async (app, launcher) => {
			launcher.seats = 2;
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });

			const create = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const extra = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const ahead = create.json<MatchmakingQueueWaitingResponse>();
			const behind = extra.json<MatchmakingQueueWaitingResponse>();

			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

			const firstReady = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			const secondWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			assert.equal(firstReady.json<MatchmakingQueueStatusResponse>().status, "ready");
			assert.equal(secondWaiting.json<MatchmakingQueueStatusResponse>().status, "waiting");
			assert.equal(launcher.launched.length, 2);
		});
	});

	test("quick play still joins an open room immediately when MatchHost cannot launch", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = created.json<MatchmakingJoinResponse>();
			assert.equal(launcher.remainingCapacity, 0);

			const quick = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			assert.equal(quick.statusCode, 201);
			const joined = quick.json<MatchmakingJoinResponse>();
			assert.equal(joined.matchId, room.matchId);
			assert.equal(joined.issued, 2);
		});
	});

	test("joining by room code never queues when the room is full", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = created.json<MatchmakingJoinResponse>();
			await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });

			const full = await app.inject({ method: "POST", url: `/matchmaking/rooms/${room.roomCode}/join` });
			assert.equal(full.statusCode, 409);
			assert.equal(full.json<{ error: string }>().error, "room_full");
		});
	});

	test("cancel drops the head so the next waiter becomes first", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 0;
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const ahead = first.json<MatchmakingQueueWaitingResponse>();
			const behind = second.json<MatchmakingQueueWaitingResponse>();

			const cancelled = await app.inject({
				method: "DELETE",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			assert.equal(cancelled.statusCode, 200);
			assert.deepEqual(cancelled.json<CancelMatchQueueResponse>(), { ok: true });

			const missing = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			assert.equal(missing.statusCode, 404);
			assert.equal(missing.json<{ error: string }>().error, "queue_not_found");

			const promoted = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			assert.equal(promoted.json<MatchmakingQueueWaitingResponse>().position, 1);
		});
	});

	test("rejects cancel after the waiter is already ready", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			const queued = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();

			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

			const cancel = await app.inject({
				method: "DELETE",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(cancel.statusCode, 409);
			assert.equal(cancel.json<{ error: string }>().error, "queue_already_ready");
		});
	});

	test("does not admit a cancelled waiter when a slot later frees", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			const queued = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();
			await app.inject({ method: "DELETE", url: `/matchmaking/queue/${waiting.queueToken}` });

			const launches = launcher.launched.length;
			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });
			assert.equal(launcher.launched.length, launches);

			const missing = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.equal(missing.statusCode, 404);
		});
	});

	test("returns 404 for an unknown or expired queue token", async () => {
		await withApp(
			async (app, _launcher, clock) => {
				const unknown = await app.inject({ method: "GET", url: "/matchmaking/queue/not-a-real-token" });
				assert.equal(unknown.statusCode, 404);

				const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
				const waiting = created.json<MatchmakingQueueWaitingResponse>();
				clock.now = new Date("2026-08-25T02:20:00.000Z");
				const expired = await app.inject({
					method: "GET",
					url: `/matchmaking/queue/${waiting.queueToken}`,
				});
				assert.equal(expired.statusCode, 404);
				assert.equal(expired.json<{ error: string }>().error, "queue_not_found");
			},
			{ queueTtlMs: 60_000 },
		);
	});

	test("skips an expired waiter so the next living entry is served", async () => {
		await withApp(
			async (app, launcher, clock) => {
				launcher.remainingCapacity = 1;
				const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
				const room = occupying.json<MatchmakingJoinResponse>();
				const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
				clock.now = new Date("2026-08-25T02:00:30.000Z");
				const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
				const stale = first.json<MatchmakingQueueWaitingResponse>();
				const living = second.json<MatchmakingQueueWaitingResponse>();

				clock.now = new Date("2026-08-25T02:01:10.000Z");
				launcher.remainingCapacity = 1;
				await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

				const expired = await app.inject({
					method: "GET",
					url: `/matchmaking/queue/${stale.queueToken}`,
				});
				const ready = await app.inject({
					method: "GET",
					url: `/matchmaking/queue/${living.queueToken}`,
				});
				assert.equal(expired.statusCode, 404);
				assert.equal(ready.json<MatchmakingQueueStatusResponse>().status, "ready");
			},
			{ queueTtlMs: 60_000 },
		);
	});

	test("does not leak a neighbor queue entry through another token", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 0;
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const ahead = first.json<MatchmakingQueueWaitingResponse>();
			const behind = second.json<MatchmakingQueueWaitingResponse>();
			assert.notEqual(ahead.queueToken, behind.queueToken);

			const polled = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			const body = polled.json<MatchmakingQueueWaitingResponse>();
			assert.equal(body.queueToken, ahead.queueToken);
			assert.equal(body.position, 1);
		});
	});

	test("rejects unexpected bodies on queue cancel", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 0;
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const waiting = created.json<MatchmakingQueueWaitingResponse>();

			const cancel = await app.inject({
				method: "DELETE",
				url: `/matchmaking/queue/${waiting.queueToken}`,
				payload: { playerId: "guest" },
			});
			assert.equal(cancel.statusCode, 400);
			assert.equal(cancel.json<{ error: string }>().error, "unexpected_request_body");
		});
	});

	test("does not enqueue when MatchHost is missing or launch fails for a non-capacity reason", async () => {
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

		await withApp(async (app, launcher) => {
			launcher.failWith = new MatchHostLaunchError("match host launch returned HTTP 502");
			const created = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(created.statusCode, 502);
			assert.equal(created.json<{ error: string }>().error, "session_launch_failed");
		});
	});

	test("marks the head failed when a drained launch fails and continues with the next waiter", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			const first = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const second = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const ahead = first.json<MatchmakingQueueWaitingResponse>();
			const behind = second.json<MatchmakingQueueWaitingResponse>();

			launcher.failWith = new MatchHostLaunchError("match host launch returned HTTP 502");
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });

			const failed = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${ahead.queueToken}`,
			});
			assert.equal(failed.statusCode, 200);
			assert.deepEqual(failed.json<MatchmakingQueueStatusResponse>(), {
				status: "failed",
				error: "session_launch_failed",
			});
			const stillWaiting = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			assert.equal(stillWaiting.json<MatchmakingQueueStatusResponse>().status, "waiting");

			launcher.failWith = undefined;
			launcher.remainingCapacity = 1;
			const occupyingAgain = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			assert.equal(occupyingAgain.statusCode, 201);
			launcher.remainingCapacity = 1;
			await app.inject({
				method: "DELETE",
				url: `/match-sessions/${occupyingAgain.json<MatchmakingJoinResponse>().matchId}`,
			});

			const ready = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${behind.queueToken}`,
			});
			assert.equal(ready.json<MatchmakingQueueStatusResponse>().status, "ready");
		});
	});

	test("fails an uncollected ready entry when its match is unregistered", async () => {
		await withApp(async (app, launcher) => {
			launcher.remainingCapacity = 1;
			const occupying = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const room = occupying.json<MatchmakingJoinResponse>();
			const queued = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const waiting = queued.json<MatchmakingQueueWaitingResponse>();

			launcher.remainingCapacity = 1;
			await app.inject({ method: "DELETE", url: `/match-sessions/${room.matchId}` });
			const ready = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			const admitted = ready.json<MatchmakingQueueStatusResponse>();
			assert.equal(admitted.status, "ready");
			if (admitted.status !== "ready") {
				return;
			}

			await app.inject({ method: "DELETE", url: `/match-sessions/${admitted.matchId}` });
			const failed = await app.inject({
				method: "GET",
				url: `/matchmaking/queue/${waiting.queueToken}`,
			});
			assert.deepEqual(failed.json<MatchmakingQueueStatusResponse>(), {
				status: "failed",
				error: "session_unregistered",
			});
		});
	});
});
