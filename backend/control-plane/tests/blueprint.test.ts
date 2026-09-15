import assert from "node:assert/strict";
import { describe, test } from "node:test";

import type { FastifyInstance } from "fastify";

import type { MatchmakingJoinResponse } from "../../contracts/src/index.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";
import { FakeMatchLauncher } from "./fake_match_launcher.ts";

describe("control plane official BASTION blueprint matchmaking", () => {
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

	test("omitted gameplay stays TRAPRUSH and does not join a BASTION room", async () => {
		await withApp(async (app, launcher) => {
			const trap = await app.inject({ method: "POST", url: "/matchmaking/rooms" });
			const bastion = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { gameplay: "bastion" },
			});
			assert.equal(trap.statusCode, 201);
			assert.equal(bastion.statusCode, 201);
			const trapRoom = trap.json<MatchmakingJoinResponse>();
			const bastionRoom = bastion.json<MatchmakingJoinResponse>();
			assert.equal(trapRoom.course, "course_01");
			assert.equal(trapRoom.gameplay, undefined);
			assert.equal(bastionRoom.course, null);
			assert.equal(bastionRoom.gameplay, "bastion");
			assert.equal(bastionRoom.blueprint, "blueprint_01");
			assert.equal(bastionRoom.seats, 2);
			assert.notEqual(trapRoom.matchId, bastionRoom.matchId);
			assert.deepEqual(launcher.launchedBlueprints, ["blueprint_01"]);

			const quickTrap = await app.inject({ method: "POST", url: "/matchmaking/quick" });
			assert.equal(quickTrap.statusCode, 201);
			assert.equal(quickTrap.json<MatchmakingJoinResponse>().matchId, trapRoom.matchId);

			const quickBastion = await app.inject({
				method: "POST",
				url: "/matchmaking/quick",
				payload: { blueprint: "blueprint_01" },
			});
			assert.equal(quickBastion.statusCode, 201);
			assert.equal(quickBastion.json<MatchmakingJoinResponse>().matchId, bastionRoom.matchId);
			assert.equal(quickBastion.json<MatchmakingJoinResponse>().issued, 2);
		});
	});

	test("rejects course plus blueprint, bastion seats other than 2, and unknown ids", async () => {
		await withApp(async (app) => {
			const mixed = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "course_01", blueprint: "blueprint_01" },
			});
			assert.equal(mixed.statusCode, 400);

			const seats = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { gameplay: "bastion", seats: 4 },
			});
			assert.equal(seats.statusCode, 400);
			assert.equal(seats.json<{ error: string }>().error, "invalid_seats");

			const unknown = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { blueprint: "blueprint_99" },
			});
			assert.equal(unknown.statusCode, 400);
			assert.equal(unknown.json<{ error: string }>().error, "invalid_blueprint");

			const asCourse = await app.inject({
				method: "POST",
				url: "/matchmaking/rooms",
				payload: { course: "blueprint_01" },
			});
			assert.equal(asCourse.statusCode, 400);
			assert.equal(asCourse.json<{ error: string }>().error, "invalid_course");
		});
	});

	test("migration 0015 defaults old-shaped inserts to TRAPRUSH", async () => {
		const database = new ControlPlaneDatabase(":memory:");
		try {
			const applied = database.migrate();
			assert.ok(applied.includes("0015_match_gameplay_and_teams"));
			const record = database.insertMatchSession({
				upstreamUrl: "ws://127.0.0.1:19120",
				now: new Date("2026-09-15T00:00:00.000Z"),
				seats: 2,
			});
			assert.equal(record.gameplay, "traprush");
			assert.equal(record.blueprint, undefined);
			assert.equal(record.course, "course_01");
		} finally {
			database.close();
		}
	});
});
