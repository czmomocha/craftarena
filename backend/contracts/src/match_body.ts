/**
 * 匹配 HTTP 请求体：官方 `course`、已签名 `content: { id, version }`、官方
 * `blueprint` 三者互斥。可选 `gameplay` 缺省为 TRAPRUSH。
 * 字段形状的所有者是 CD-42 §3.5。本文件只实现解析，不查库。
 */

import {
	CONTENT_ID_MAX,
	CONTENT_VERSION_MAX,
	CONTENT_VERSION_MIN,
} from "./content_publish.ts";
import {
	BASTION_MATCH_SEATS,
	DEFAULT_MATCH_GAMEPLAY,
	MATCH_GAMEPLAY_BASTION,
	MATCH_GAMEPLAY_TRAPRUSH,
	isMatchGameplay,
	type MatchGameplay,
} from "./match_gameplay.ts";
import {
	DEFAULT_OFFICIAL_BASTION_BLUEPRINT,
	isOfficialBastionBlueprintId,
	type OfficialBastionBlueprintId,
} from "./official_blueprints.ts";
import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isOfficialTraprushCourseId,
	isValidMatchSeats,
	type OfficialTraprushCourseId,
} from "./official_courses.ts";

export const DEMO_TRAPRUSH_COURSE_ID = "course_f_playable";
export const CONTENT_ID_RE = /^[A-Za-z0-9._-]+$/;

export interface MatchContentRef {
	readonly id: string;
	readonly version: number;
}

export type MatchBodyError =
	| "unexpected_request_body"
	| "invalid_course"
	| "invalid_seats"
	| "invalid_content"
	| "invalid_gameplay"
	| "invalid_blueprint";

export type MatchBodyResult =
	| {
			readonly ok: true;
			readonly kind: "official";
			readonly course: OfficialTraprushCourseId;
			readonly seats: number;
	  }
	| {
			readonly ok: true;
			readonly kind: "blueprint";
			readonly blueprint: OfficialBastionBlueprintId;
			readonly seats: number;
	  }
	| {
			readonly ok: true;
			readonly kind: "content";
			readonly content: MatchContentRef;
			readonly seats: number;
	  }
	| { readonly ok: false; readonly error: MatchBodyError };

const MATCH_BODY_KEYS = ["course", "seats", "content", "gameplay", "blueprint"] as const;

export function isMatchContentId(value: unknown): value is string {
	return (
		typeof value === "string" &&
		value.length >= 1 &&
		value.length <= CONTENT_ID_MAX &&
		CONTENT_ID_RE.test(value)
	);
}

export function isMatchContentVersion(value: unknown): value is number {
	return (
		typeof value === "number" &&
		Number.isInteger(value) &&
		value >= CONTENT_VERSION_MIN &&
		value <= CONTENT_VERSION_MAX
	);
}

export function isReservedMatchContentId(contentId: string): boolean {
	return (
		isOfficialTraprushCourseId(contentId) ||
		contentId === DEMO_TRAPRUSH_COURSE_ID ||
		isOfficialBastionBlueprintId(contentId)
	);
}

export function readMatchContentRef(raw: unknown): MatchContentRef | undefined {
	if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
		return undefined;
	}
	const record = raw as Record<string, unknown>;
	const keys = Object.keys(record);
	if (keys.length !== 2 || !keys.includes("id") || !keys.includes("version")) {
		return undefined;
	}
	const id = record["id"];
	const version = record["version"];
	if (!isMatchContentId(id) || isReservedMatchContentId(id) || !isMatchContentVersion(version)) {
		return undefined;
	}
	return { id, version };
}

/**
 * 空对象 / 省略 body 视为默认官方赛道与默认人数（TRAPRUSH，旧调用逐字节兼容）。
 * `course` / `content` / `blueprint` 同时出现、`gameplay` 与选择器打架、多余字段
 * （含 `players`）、非法 content 一律拒绝。
 */
export function readMatchBody(body: unknown): MatchBodyResult {
	if (body === undefined || body === null) {
		return officialTraprush(DEFAULT_OFFICIAL_TRAPRUSH_COURSE, DEFAULT_MATCHMAKING_SEATS);
	}
	if (typeof body !== "object" || Array.isArray(body)) {
		return { ok: false, error: "unexpected_request_body" };
	}
	const record = body as Record<string, unknown>;
	const keys = Object.keys(record);
	if (keys.some((key) => !MATCH_BODY_KEYS.includes(key as (typeof MATCH_BODY_KEYS)[number]))) {
		return { ok: false, error: "unexpected_request_body" };
	}

	const gameplay = readGameplay(record["gameplay"]);
	if (record["gameplay"] !== undefined && gameplay === undefined) {
		return { ok: false, error: "invalid_gameplay" };
	}

	const hasCourse = record["course"] !== undefined;
	const hasContent = record["content"] !== undefined;
	const hasBlueprint = record["blueprint"] !== undefined;
	const selectors = (hasCourse ? 1 : 0) + (hasContent ? 1 : 0) + (hasBlueprint ? 1 : 0);
	if (selectors > 1) {
		return { ok: false, error: "unexpected_request_body" };
	}

	let seats = DEFAULT_MATCHMAKING_SEATS;
	if (record["seats"] !== undefined) {
		if (!isValidMatchSeats(record["seats"])) {
			return { ok: false, error: "invalid_seats" };
		}
		seats = record["seats"];
	}

	if (gameplay === MATCH_GAMEPLAY_BASTION && (hasCourse || hasContent)) {
		return { ok: false, error: "unexpected_request_body" };
	}
	if (gameplay === MATCH_GAMEPLAY_TRAPRUSH && hasBlueprint) {
		return { ok: false, error: "unexpected_request_body" };
	}

	if (hasBlueprint || gameplay === MATCH_GAMEPLAY_BASTION) {
		if (seats !== BASTION_MATCH_SEATS) {
			return { ok: false, error: "invalid_seats" };
		}
		let blueprint: OfficialBastionBlueprintId = DEFAULT_OFFICIAL_BASTION_BLUEPRINT;
		if (hasBlueprint) {
			if (!isOfficialBastionBlueprintId(record["blueprint"])) {
				return { ok: false, error: "invalid_blueprint" };
			}
			blueprint = record["blueprint"];
		}
		return { ok: true, kind: "blueprint", blueprint, seats };
	}

	if (hasContent) {
		const content = readMatchContentRef(record["content"]);
		if (content === undefined) {
			return { ok: false, error: "invalid_content" };
		}
		return { ok: true, kind: "content", content, seats };
	}

	let course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
	if (hasCourse) {
		if (!isOfficialTraprushCourseId(record["course"])) {
			return { ok: false, error: "invalid_course" };
		}
		course = record["course"];
	}
	return officialTraprush(course, seats);
}

export function matchGameplayOf(result: Extract<MatchBodyResult, { ok: true }>): MatchGameplay {
	if (result.kind === "blueprint") {
		return MATCH_GAMEPLAY_BASTION;
	}
	return DEFAULT_MATCH_GAMEPLAY;
}

function officialTraprush(
	course: OfficialTraprushCourseId,
	seats: number,
): Extract<MatchBodyResult, { ok: true; kind: "official" }> {
	return { ok: true, kind: "official", course, seats };
}

function readGameplay(value: unknown): MatchGameplay | undefined {
	if (value === undefined) {
		return undefined;
	}
	return isMatchGameplay(value) ? value : undefined;
}

export { MATCH_GAMEPLAY_BASTION, MATCH_GAMEPLAY_TRAPRUSH, type MatchGameplay };
