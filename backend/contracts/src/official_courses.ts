/**
 * 一期官方 TRAPRUSH 赛道标识。
 *
 * HTTP JSON 只走这些 id，不接受 `res://` 路径或 UGC 课。Godot 对局进程
 * 仍用 `res://content/official/traprush/{id}.json` 读 AuthoringDocument。
 * 人数按场下发仍待。OpenAPI 仍未生成。
 */

export const OFFICIAL_TRAPRUSH_COURSE_IDS = ["course_01", "course_02", "course_03"] as const;

export type OfficialTraprushCourseId = (typeof OFFICIAL_TRAPRUSH_COURSE_IDS)[number];

export const DEFAULT_OFFICIAL_TRAPRUSH_COURSE: OfficialTraprushCourseId = "course_01";

const OFFICIAL_TRAPRUSH_COURSE_DIR = "res://content/official/traprush";

export function isOfficialTraprushCourseId(value: unknown): value is OfficialTraprushCourseId {
	return typeof value === "string" && (OFFICIAL_TRAPRUSH_COURSE_IDS as readonly string[]).includes(value);
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
	},
} as const;

export type OfficialCourseBodyError = "unexpected_request_body" | "invalid_course";

export type OfficialCourseBodyResult =
	| { readonly ok: true; readonly course: OfficialTraprushCourseId }
	| { readonly ok: false; readonly error: OfficialCourseBodyError };

/**
 * 空对象 / 省略 body 视为默认官方赛道。多余字段拒绝，避免调用方以为人数等已生效。
 */
export function readOfficialCourseBody(body: unknown): OfficialCourseBodyResult {
	if (body === undefined || body === null) {
		return { ok: true, course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE };
	}
	if (typeof body !== "object" || Array.isArray(body)) {
		return { ok: false, error: "unexpected_request_body" };
	}
	const keys = Object.keys(body);
	if (keys.length === 0) {
		return { ok: true, course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE };
	}
	if (keys.some((key) => key !== "course")) {
		return { ok: false, error: "unexpected_request_body" };
	}
	const course = (body as { readonly course?: unknown }).course;
	if (course === undefined) {
		return { ok: true, course: DEFAULT_OFFICIAL_TRAPRUSH_COURSE };
	}
	if (!isOfficialTraprushCourseId(course)) {
		return { ok: false, error: "invalid_course" };
	}
	return { ok: true, course };
}
