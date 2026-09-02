import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, test } from "node:test";

import { ControlPlaneDatabase } from "../src/db/database.ts";
import { hasRequestBody, hasUnexpectedKeys } from "../src/server_matchmaking.ts";
import { describeRecentOutput, toStartFailure } from "../../match-host/src/registry_launch.ts";
import { MatchListenError } from "../../match-host/src/listen_probe.ts";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../..");
const E9_LINE_CAP = 400;

const SPLIT_FILES = [
	"backend/control-plane/src/server.ts",
	"backend/control-plane/src/server_matchmaking.ts",
	"backend/control-plane/src/server_sessions.ts",
	"backend/control-plane/src/db/database.ts",
	"backend/control-plane/src/db/database_rows.ts",
	"backend/control-plane/src/db/database_sessions.ts",
	"backend/control-plane/src/db/database_tickets.ts",
	"backend/control-plane/src/db/database_queue.ts",
	"backend/match-host/src/registry.ts",
	"backend/match-host/src/registry_launch.ts",
] as const;

function lineCount(relativePath: string): number {
	const text = readFileSync(resolve(repoRoot, relativePath), "utf8");
	return text.split("\n").length;
}

describe("C5 E9 remaining splits", () => {
	test("control-plane and match-host split files stay under 400 lines", () => {
		for (const relativePath of SPLIT_FILES) {
			const count = lineCount(relativePath);
			assert.ok(
				count < E9_LINE_CAP,
				`${relativePath} is ${count} lines; E9 cap is ${E9_LINE_CAP} including blanks`,
			);
		}
	});

	test("ControlPlaneDatabase facade still issues and consumes tickets", () => {
		const database = new ControlPlaneDatabase(":memory:");
		try {
			database.migrate();
			const now = new Date("2026-09-02T12:00:00.000Z");
			const session = database.insertMatchSession({
				upstreamUrl: "ws://127.0.0.1:19001",
				now,
				seats: 2,
			});
			const issued = database.issueTicket(session.matchId, now, 60_000);
			assert.equal(issued.matchId, session.matchId);
			assert.equal(issued.seat, 0);
			assert.equal(database.countTickets(session.matchId), 1);

			const consumed = database.consumeTicket(issued.ticket, now);
			assert.equal(consumed.ok, true);
			if (consumed.ok) {
				assert.equal(consumed.upstreamUrl, "ws://127.0.0.1:19001");
				assert.equal(consumed.seat, 0);
			}
		} finally {
			database.close();
		}
	});

	test("matchmaking helpers still reject extra keys and empty bodies", () => {
		assert.equal(hasUnexpectedKeys({ ticket: "a", extra: 1 }, ["ticket"]), true);
		assert.equal(hasUnexpectedKeys({ ticket: "a" }, ["ticket"]), false);
		assert.equal(hasRequestBody(undefined), false);
		assert.equal(hasRequestBody({}), false);
		assert.equal(hasRequestBody({ ticket: "a" }), true);
	});

	test("registry launch helpers stay on the extracted module", () => {
		assert.equal(describeRecentOutput([]), "");
		assert.equal(describeRecentOutput(["ready"]), "; last output: ready");
		const listen = new MatchListenError("port closed");
		assert.equal(toStartFailure(listen, true), listen);
		const wrapped = toStartFailure(new Error("spawn failed"), true);
		assert.equal(wrapped.name, "MatchSessionRegisterError");
	});
});
