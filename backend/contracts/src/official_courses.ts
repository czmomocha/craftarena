/**
 * 一期官方 TRAPRUSH 赛道标识与匹配 JSON 人数。
 *
 * HTTP JSON 只走这些 id，不接受 `res://` 路径或 UGC 课。Godot 对局进程
 * 仍用 `res://content/official/traprush/{id}.json` 读 AuthoringDocument。
 * `seats` 是本场人数（1～8），不是 `players` 别名。OpenAPI 仍未生成。
 */

export const OFFICIAL_TRAPRUSH_COURSE_IDS = ["course_01", "course_02", "course_03"] as const;

export type OfficialTraprushCourseId = (typeof OFFICIAL_TRAPRUSH_COURSE_IDS)[number];

export const DEFAULT_OFFICIAL_TRAPRUSH_COURSE: OfficialTraprushCourseId = "course_01";

/** 匹配 / POST /matches 省略 `seats` 时的人数。与 MatchHost 开发期占位一致，不是产品锁定开局人数。 */
export const DEFAULT_MATCHMAKING_SEATS = 2;
export const MIN_MATCH_SEATS = 1;
export const MAX_MATCH_SEATS = 8;

const OFFICIAL_TRAPRUSH_COURSE_DIR = "res://content/official/traprush";

export function isOfficialTraprushCourseId(value: unknown): value is OfficialTraprushCourseId {
	return typeof value === "string" && (OFFICIAL_TRAPRUSH_COURSE_IDS as readonly string[]).includes(value);
}

export function isValidMatchSeats(value: unknown): value is number {
	return typeof value === "number" && Number.isInteger(value) && value >= MIN_MATCH_SEATS && value <= MAX_MATCH_SEATS;
}

export function officialTraprushCoursePath(id: OfficialTraprushCourseId): string {
	return `${OFFICIAL_TRAPRUSH_COURSE_DIR}/${id}.json`;
}

export function officialTraprushCourseIdFromPath(path: string): OfficialTraprushCourseId | undefined {
	for (const id of OFFICIAL_TRAPRUSH_COURSE_IDS) {
		if (path === officialTraprushCoursePath(id)) {
			return id;
		}
	}
	return undefined;
}

export const officialTraprushCourseIdSchema = {
	type: "string",
	enum: [...OFFICIAL_TRAPRUSH_COURSE_IDS],
} as const;

export const matchCourseBodySchema = {
	type: "object",
	additionalProperties: false,
	properties: {
		course: officialTraprushCourseIdSchema,
		seats: { type: "integer", minimum: MIN_MATCH_SEATS, maximum: MAX_MATCH_SEATS },
	},
} as const;

export type OfficialMatchBodyError = "unexpected_request_body" | "invalid_course" | "invalid_seats";

export type OfficialMatchBodyResult =
	| { readonly ok: true; readonly course: OfficialTraprushCourseId; readonly seats: number }
	| { readonly ok: false; readonly error: OfficialMatchBodyError };

/**
 * 空对象 / 省略 body 视为默认官方赛道与默认人数。
 * 多余字段（含 `players`）拒绝，避免调用方以为未锁字段已生效。
 */
export function readOfficialMatchBody(body: unknown): OfficialMatchBodyResult {
	if (body === undefined || body === null) {
		return {
			ok: true,
			course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
			seats: DEFAULT_MATCHMAKING_SEATS,
		};
	}
	if (typeof body !== "object" || Array.isArray(body)) {
		return { ok: false, error: "unexpected_request_body" };
	}
	const record = body as Record<string, unknown>;
	const keys = Object.keys(record);
	if (keys.some((key) => key !== "course" && key !== "seats")) {
		return { ok: false, error: "unexpected_request_body" };
	}

	let course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
	if (record["course"] !== undefined) {
		if (!isOfficialTraprushCourseId(record["course"])) {
			return { ok: false, error: "invalid_course" };
		}
		course = record["course"];
	}

	let seats = DEFAULT_MATCHMAKING_SEATS;
	if (record["seats"] !== undefined) {
		if (!isValidMatchSeats(record["seats"])) {
			return { ok: false, error: "invalid_seats" };
		}
		seats = record["seats"];
	}

	return { ok: true, course, seats };
}
