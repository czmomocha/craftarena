import type { CourseEvent, ErrorEvent, ParsedRun, SummaryEvent } from "./parse.ts";

export const EMPTY_RUN_MESSAGE =
	"bot-runner: no bot_run_course / bot_run_summary / bot_run_error lines — nothing was checked.";

export type ReportCourse = {
	readonly course: string;
	readonly route: string;
	readonly outcome: string;
	readonly reason: string;
	readonly completable: boolean;
	readonly steps: number;
	readonly search_ticks: number;
	readonly expansions: number;
	readonly max_ticks: number | null;
	readonly max_depth: number | null;
};

export type BotRunReport = {
	readonly ok: boolean;
	readonly exit_code: number;
	readonly empty: boolean;
	readonly route: string;
	readonly courses: readonly ReportCourse[];
	readonly summary: SummaryEvent | null;
	readonly error: ErrorEvent | null;
};

export function isEmptyRun(parsed: ParsedRun): boolean {
	return parsed.courses.length === 0 && parsed.summary === null && parsed.error === null;
}

export function assembleReport(parsed: ParsedRun, exitCode: number): BotRunReport {
	const empty = isEmptyRun(parsed);
	const summary = parsed.summary;
	const courses = parsed.courses.map((course) => toReportCourse(course, summary));
	const route = summary?.route ?? parsed.courses[0]?.route ?? "";
	const ok = !empty && exitCode === 0 && parsed.error === null && (summary?.ok ?? courses.every((c) => c.completable));
	return {
		ok,
		exit_code: empty ? 1 : exitCode,
		empty,
		route,
		courses,
		summary,
		error: parsed.error,
	};
}

function toReportCourse(course: CourseEvent, summary: SummaryEvent | null): ReportCourse {
	return {
		course: course.course,
		route: course.route,
		outcome: course.outcome,
		reason: course.reason,
		completable: course.outcome === "completable",
		steps: course.steps,
		search_ticks: course.search_ticks,
		expansions: course.expansions,
		max_ticks: course.max_ticks ?? summary?.max_ticks ?? null,
		max_depth: course.max_depth ?? summary?.max_depth ?? null,
	};
}
