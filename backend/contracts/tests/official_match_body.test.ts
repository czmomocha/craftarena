import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isValidMatchSeats,
	readOfficialMatchBody,
} from "../src/official_courses.ts";

describe("official match body", () => {
	test("empty body defaults to course_01 and 2 seats", () => {
		assert.deepEqual(readOfficialMatchBody(undefined), {
			ok: true,
			course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
			seats: DEFAULT_MATCHMAKING_SEATS,
		});
		assert.deepEqual(readOfficialMatchBody({}), {
			ok: true,
			course: "course_01",
			seats: 2,
		});
		assert.deepEqual(readOfficialMatchBody({ course: "course_03" }), {
			ok: true,
			course: "course_03",
			seats: 2,
		});
		assert.deepEqual(readOfficialMatchBody({ seats: 8 }), {
			ok: true,
			course: "course_01",
			seats: 8,
		});
	});

	test("rejects paths, unknown ids, out-of-range seats, and extra fields", () => {
		assert.equal(readOfficialMatchBody({ course: "course_99" }).ok, false);
		assert.equal(
			(readOfficialMatchBody({ course: "res://content/official/traprush/course_01.json" }) as { error: string })
				.error,
			"invalid_course",
		);
		assert.equal((readOfficialMatchBody({ seats: 0 }) as { error: string }).error, "invalid_seats");
		assert.equal((readOfficialMatchBody({ seats: 9 }) as { error: string }).error, "invalid_seats");
		assert.equal((readOfficialMatchBody({ seats: 2.5 }) as { error: string }).error, "invalid_seats");
		assert.equal((readOfficialMatchBody({ seats: "2" }) as { error: string }).error, "invalid_seats");
		assert.equal(
			(readOfficialMatchBody({ course: "course_01", players: 2 }) as { error: string }).error,
			"unexpected_request_body",
		);
		assert.equal(isValidMatchSeats(1), true);
		assert.equal(isValidMatchSeats(8), true);
		assert.equal(isValidMatchSeats(0), false);
	});
});
