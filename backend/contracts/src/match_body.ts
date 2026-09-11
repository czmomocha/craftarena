/**
 * 匹配 HTTP 请求体：官方 `course` 与已签名 `content: { id, version }` 互斥。
 * 字段形状的所有者是 CD-42 §3.5。本文件只实现解析，不查库。
 */

import {
	CONTENT_ID_MAX,
	CONTENT_VERSION_MAX,
	CONTENT_VERSION_MIN,
} from "./content_publish.ts";
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
	| "invalid_content";

export type MatchBodyResult =
	| {
			readonly ok: true;
			readonly kind: "official";
			readonly course: OfficialTraprushCourseId;
			readonly seats: number;
	  }
	| {
			readonly ok: true;
			readonly kind: "content";
			readonly content: MatchContentRef;
			readonly seats: number;
	  }
	| { readonly ok: false; readonly error: MatchBodyError };

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
	return isOfficialTraprushCourseId(contentId) || contentId === DEMO_TRAPRUSH_COURSE_ID;
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
 * 空对象 / 省略 body 视为默认官方赛道与默认人数。
 * `course` 与 `content` 同时出现、多余字段（含 `players`）、非法 content 一律拒绝。
 */
export function readMatchBody(body: unknown): MatchBodyResult {
	if (body === undefined || body === null) {
		return {
			ok: true,
			kind: "official",
			course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
			seats: DEFAULT_MATCHMAKING_SEATS,
		};
	}
	if (typeof body !== "object" || Array.isArray(body)) {
		return { ok: false, error: "unexpected_request_body" };
	}
	const record = body as Record<string, unknown>;
	const keys = Object.keys(record);
	if (keys.some((key) => key !== "course" && key !== "seats" && key !== "content")) {
		return { ok: false, error: "unexpected_request_body" };
	}

	const hasCourse = record["course"] !== undefined;
	const hasContent = record["content"] !== undefined;
	if (hasCourse && hasContent) {
		return { ok: false, error: "unexpected_request_body" };
	}

	let seats = DEFAULT_MATCHMAKING_SEATS;
	if (record["seats"] !== undefined) {
		if (!isValidMatchSeats(record["seats"])) {
			return { ok: false, error: "invalid_seats" };
		}
		seats = record["seats"];
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
	return { ok: true, kind: "official", course, seats };
}
