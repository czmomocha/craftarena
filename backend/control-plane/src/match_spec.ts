import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	MATCH_GAMEPLAY_BASTION,
	readMatchBody,
	type MatchContentRef,
	type OfficialBastionBlueprintId,
	type OfficialTraprushCourseId,
} from "../../contracts/src/index.ts";
import type { ControlPlaneDatabase, MatchQueueRecord, MatchSessionRecord } from "./db/database.ts";

export type MatchPlaySpec =
	| { readonly kind: "official"; readonly course: OfficialTraprushCourseId; readonly seats: number }
	| { readonly kind: "blueprint"; readonly blueprint: OfficialBastionBlueprintId; readonly seats: number }
	| { readonly kind: "content"; readonly content: MatchContentRef; readonly seats: number };

export function resolveMatchSpec(
	database: ControlPlaneDatabase,
	body: unknown,
): { readonly ok: true; readonly spec: MatchPlaySpec } | { readonly ok: false; readonly error: string } {
	const parsed = readMatchBody(body);
	if (!parsed.ok) {
		return { ok: false, error: parsed.error };
	}
	if (parsed.kind === "content") {
		const stored = database.getContentVersion(parsed.content.id, parsed.content.version);
		if (stored === undefined) {
			return { ok: false, error: "invalid_content" };
		}
		return { ok: true, spec: { kind: "content", content: parsed.content, seats: parsed.seats } };
	}
	if (parsed.kind === "blueprint") {
		return { ok: true, spec: { kind: "blueprint", blueprint: parsed.blueprint, seats: parsed.seats } };
	}
	return { ok: true, spec: { kind: "official", course: parsed.course, seats: parsed.seats } };
}

export function findOpenForSpec(database: ControlPlaneDatabase, spec: MatchPlaySpec): MatchSessionRecord | undefined {
	if (spec.kind === "content") {
		return database.findOldestOpenContentRoom(spec.content.id, spec.content.version, spec.seats);
	}
	if (spec.kind === "blueprint") {
		return database.findOldestOpenBlueprintRoom(spec.blueprint, spec.seats);
	}
	return database.findOldestOpenRoom(spec.course, spec.seats);
}

export function findOpenForWaiter(database: ControlPlaneDatabase, waiter: MatchQueueRecord): MatchSessionRecord | undefined {
	if (waiter.contentId !== undefined && waiter.contentVersion !== undefined) {
		return database.findOldestOpenContentRoom(waiter.contentId, waiter.contentVersion, waiter.seats);
	}
	if (waiter.gameplay === MATCH_GAMEPLAY_BASTION && waiter.blueprint !== undefined) {
		return database.findOldestOpenBlueprintRoom(waiter.blueprint, waiter.seats);
	}
	if (waiter.course === null) {
		return undefined;
	}
	return database.findOldestOpenRoom(waiter.course, waiter.seats);
}

export function playSpecFromQueue(record: MatchQueueRecord): MatchPlaySpec {
	if (record.contentId !== undefined && record.contentVersion !== undefined) {
		return {
			kind: "content",
			content: { id: record.contentId, version: record.contentVersion },
			seats: record.seats,
		};
	}
	if (record.gameplay === MATCH_GAMEPLAY_BASTION && record.blueprint !== undefined) {
		return { kind: "blueprint", blueprint: record.blueprint, seats: record.seats };
	}
	return {
		kind: "official",
		course: record.course ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: record.seats,
	};
}
