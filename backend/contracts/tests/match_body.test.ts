import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isReservedMatchContentId,
	readMatchBody,
	readMatchContentRef,
} from "../src/index.ts";

describe("match body content object", () => {
	test("empty body still defaults to course_01 and 2 seats", () => {
		assert.deepEqual(readMatchBody(undefined), {
			ok: true,
			kind: "official",
			course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
			seats: DEFAULT_MATCHMAKING_SEATS,
		});
		assert.deepEqual(readMatchBody({}), {
			ok: true,
			kind: "official",
			course: "course_01",
			seats: 2,
		});
	});

	test("accepts pinned content id and version without stuffing course", () => {
		assert.deepEqual(readMatchBody({ content: { id: "ugc_aabbccddeeff00112233445566778899", version: 2 } }), {
			ok: true,
			kind: "content",
			content: { id: "ugc_aabbccddeeff00112233445566778899", version: 2 },
			seats: 2,
		});
		assert.deepEqual(
			readMatchBody({ content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1 }, seats: 4 }),
			{
				ok: true,
				kind: "content",
				content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1 },
				seats: 4,
			},
		);
	});

	test("rejects course plus content, reserved ids, and malformed content", () => {
		assert.equal(
			readMatchBody({
				course: "course_01",
				content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1 },
			}).ok,
			false,
		);
		assert.equal(
			(readMatchBody({
				course: "course_01",
				content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1 },
			}) as { error: string }).error,
			"unexpected_request_body",
		);
		assert.equal((readMatchBody({ content: { id: "course_01", version: 1 } }) as { error: string }).error, "invalid_content");
		assert.equal(
			(readMatchBody({ content: { id: "course_f_playable", version: 1 } }) as { error: string }).error,
			"invalid_content",
		);
		assert.equal(
			(readMatchBody({ content: { id: "res://secret.json", version: 1 } }) as { error: string }).error,
			"invalid_content",
		);
		assert.equal(
			(readMatchBody({ content: { id: "ugc_aabbccddeeff00112233445566778899" } }) as { error: string }).error,
			"invalid_content",
		);
		assert.equal(
			(readMatchBody({ content: { id: "ugc_aabbccddeeff00112233445566778899", version: 0 } }) as { error: string })
				.error,
			"invalid_content",
		);
		assert.equal(
			(readMatchBody({
				content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1, extra: true },
			}) as { error: string }).error,
			"invalid_content",
		);
		assert.equal(isReservedMatchContentId("course_05"), true);
		assert.equal(isReservedMatchContentId("course_06"), true);
		assert.equal(isReservedMatchContentId("course_f_playable"), true);
		assert.equal(isReservedMatchContentId("ugc_aabbccddeeff00112233445566778899"), false);
		assert.equal(isReservedMatchContentId("blueprint_01"), true);
		assert.equal(readMatchContentRef({ id: "course_02", version: 1 }), undefined);
	});
});

describe("match body gameplay and blueprint", () => {
	test("omitted gameplay stays TRAPRUSH and still defaults course_01", () => {
		assert.deepEqual(readMatchBody({ gameplay: "traprush" }), {
			ok: true,
			kind: "official",
			course: "course_01",
			seats: 2,
		});
	});

	test("bastion gameplay defaults blueprint_01 and locks two seats", () => {
		assert.deepEqual(readMatchBody({ gameplay: "bastion" }), {
			ok: true,
			kind: "blueprint",
			blueprint: "blueprint_01",
			seats: 2,
		});
		assert.deepEqual(readMatchBody({ blueprint: "blueprint_01" }), {
			ok: true,
			kind: "blueprint",
			blueprint: "blueprint_01",
			seats: 2,
		});
	});

	test("rejects mixed selectors, stuffed course, and illegal seats", () => {
		assert.equal(
			(readMatchBody({ course: "course_01", blueprint: "blueprint_01" }) as { error: string }).error,
			"unexpected_request_body",
		);
		assert.equal(
			(readMatchBody({ gameplay: "bastion", course: "course_01" }) as { error: string }).error,
			"unexpected_request_body",
		);
		assert.equal(
			(readMatchBody({ gameplay: "traprush", blueprint: "blueprint_01" }) as { error: string }).error,
			"unexpected_request_body",
		);
		assert.equal(
			(readMatchBody({ gameplay: "bastion", content: { id: "ugc_aabbccddeeff00112233445566778899", version: 1 } }) as {
				error: string;
			}).error,
			"unexpected_request_body",
		);
		assert.equal((readMatchBody({ course: "blueprint_01" }) as { error: string }).error, "invalid_course");
		assert.equal((readMatchBody({ gameplay: "quake" }) as { error: string }).error, "invalid_gameplay");
		assert.equal((readMatchBody({ blueprint: "blueprint_99" }) as { error: string }).error, "invalid_blueprint");
		assert.equal((readMatchBody({ gameplay: "bastion", seats: 4 }) as { error: string }).error, "invalid_seats");
		assert.equal(
			(readMatchBody({ content: { id: "blueprint_01", version: 1 } }) as { error: string }).error,
			"invalid_content",
		);
	});
});
