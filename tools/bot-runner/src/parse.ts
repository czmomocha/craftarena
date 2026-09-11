export const COURSE_EVENT = "bot_run_course";
export const SUMMARY_EVENT = "bot_run_summary";
export const ERROR_EVENT = "bot_run_error";

export type CourseEvent = {
	readonly event: typeof COURSE_EVENT;
	readonly course: string;
	readonly route: string;
	readonly outcome: string;
	readonly reason: string;
	readonly steps: number;
	readonly search_ticks: number;
	readonly expansions: number;
	readonly max_ticks: number | null;
	readonly max_depth: number | null;
	readonly action_count: number | null;
	readonly wall_ms: number | null;
};

export type SummaryEvent = {
	readonly event: typeof SUMMARY_EVENT;
	readonly ok: boolean;
	readonly total: number;
	readonly completable: number;
	readonly not_completable: number;
	readonly route: string;
	readonly max_ticks: number;
	readonly max_depth: number;
	readonly action_count: number;
	readonly wall_ms: number;
};

export type ErrorEvent = {
	readonly event: typeof ERROR_EVENT;
	readonly error: string;
	readonly detail: string;
};

export type ParsedRun = {
	readonly courses: readonly CourseEvent[];
	readonly summary: SummaryEvent | null;
	readonly error: ErrorEvent | null;
};

/**
 * 从 Godot stdout 抽出 `--bot-run` JSON 行。引擎横幅 / WARNING 不是 JSON，丢掉。
 * 坏 JSON 也丢掉：不能把一条脏行当成「什么都没查」。
 */
export function parseBotRunStdout(stdout: string): ParsedRun {
	const courses: CourseEvent[] = [];
	let summary: SummaryEvent | null = null;
	let error: ErrorEvent | null = null;
	for (const rawLine of stdout.split(/\r?\n/)) {
		const line = rawLine.trim();
		if (line === "") {
			continue;
		}
		const parsed = parseJsonObject(line);
		if (parsed === null) {
			continue;
		}
		const event = readString(parsed, "event");
		if (event === COURSE_EVENT) {
			const course = readCourse(parsed);
			if (course !== null) {
				courses.push(course);
			}
			continue;
		}
		if (event === SUMMARY_EVENT) {
			summary = readSummary(parsed);
			continue;
		}
		if (event === ERROR_EVENT && error === null) {
			error = {
				event: ERROR_EVENT,
				error: readString(parsed, "error") ?? "unknown_error",
				detail: readString(parsed, "detail") ?? "",
			};
		}
	}
	return { courses, summary, error };
}

function parseJsonObject(line: string): Record<string, unknown> | null {
	try {
		const value: unknown = JSON.parse(line);
		if (value === null || typeof value !== "object" || Array.isArray(value)) {
			return null;
		}
		return value as Record<string, unknown>;
	} catch {
		return null;
	}
}

function readCourse(raw: Record<string, unknown>): CourseEvent | null {
	const course = readString(raw, "course");
	const outcome = readString(raw, "outcome");
	if (course === undefined || outcome === undefined) {
		return null;
	}
	return {
		event: COURSE_EVENT,
		course,
		route: readString(raw, "route") ?? "",
		outcome,
		reason: readString(raw, "reason") ?? "",
		steps: readNumber(raw, "steps") ?? 0,
		search_ticks: readNumber(raw, "search_ticks") ?? 0,
		expansions: readNumber(raw, "expansions") ?? 0,
		max_ticks: readNumber(raw, "max_ticks"),
		max_depth: readNumber(raw, "max_depth"),
		action_count: readNumber(raw, "action_count"),
		wall_ms: readNumber(raw, "wall_ms"),
	};
}

function readSummary(raw: Record<string, unknown>): SummaryEvent | null {
	const ok = raw["ok"];
	if (typeof ok !== "boolean") {
		return null;
	}
	return {
		event: SUMMARY_EVENT,
		ok,
		total: readNumber(raw, "total") ?? 0,
		completable: readNumber(raw, "completable") ?? 0,
		not_completable: readNumber(raw, "not_completable") ?? 0,
		route: readString(raw, "route") ?? "",
		max_ticks: readNumber(raw, "max_ticks") ?? 0,
		max_depth: readNumber(raw, "max_depth") ?? 0,
		action_count: readNumber(raw, "action_count") ?? 0,
		wall_ms: readNumber(raw, "wall_ms") ?? 0,
	};
}

function readString(raw: Record<string, unknown>, key: string): string | undefined {
	const value = raw[key];
	return typeof value === "string" ? value : undefined;
}

function readNumber(raw: Record<string, unknown>, key: string): number | null {
	const value = raw[key];
	return typeof value === "number" && Number.isFinite(value) ? value : null;
}
