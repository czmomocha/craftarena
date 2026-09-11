import {
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	isOfficialTraprushCourseId,
	type OfficialTraprushCourseId,
} from "../../../contracts/src/official_courses.ts";
import type {
	MatchQueueRecord,
	MatchQueueRowStatus,
	MatchSessionRecord,
	MatchSettlementRecord,
} from "./database.ts";

export function queueFromRow(row: Record<string, unknown>): MatchQueueRecord {
	const matchId = row["match_id"];
	const ticket = row["ticket"];
	const ticketExpiresAt = row["ticket_expires_at"];
	const error = row["error"];
	return {
		rowid: Number(row["rowid"]),
		tokenHash: String(row["token_hash"]),
		kind: row["kind"] === "create_room" ? "create_room" : "quick",
		status: queueStatusFromRow(row["status"]),
		createdAt: String(row["created_at"]),
		expiresAt: String(row["expires_at"]),
		matchId: matchId === null || matchId === undefined ? undefined : String(matchId),
		ticket: ticket === null || ticket === undefined ? undefined : String(ticket),
		ticketExpiresAt:
			ticketExpiresAt === null || ticketExpiresAt === undefined ? undefined : String(ticketExpiresAt),
		error: error === null || error === undefined ? undefined : String(error),
		course: courseFromRow(row["course"]),
		seats: Number(row["seats"]),
		contentId: optionalText(row["content_id"]),
		contentVersion: optionalInt(row["content_version"]),
	};
}

export function queueStatusFromRow(value: unknown): MatchQueueRowStatus {
	if (value === "ready" || value === "failed" || value === "cancelled" || value === "waiting") {
		return value;
	}
	return "waiting";
}

export function settlementFromRow(row: Record<string, unknown>): MatchSettlementRecord {
	return {
		matchId: String(row["match_id"]),
		tick: Number(row["tick"]),
		stateHash: String(row["state_hash"]),
		padTotal: Number(row["pad_total"]),
		mvpSlot: Number(row["mvp_slot"]),
		rowsJson: String(row["rows_json"]),
		createdAt: String(row["created_at"]),
	};
}

export function sessionFromRow(row: Record<string, unknown>): MatchSessionRecord {
	const roomCode = row["room_code"];
	return {
		matchId: String(row["match_id"]),
		upstreamUrl: String(row["upstream_url"]),
		createdAt: String(row["created_at"]),
		roomCode: roomCode === null || roomCode === undefined ? undefined : String(roomCode),
		seats: Number(row["seats"]),
		course: courseFromRow(row["course"]),
		contentId: optionalText(row["content_id"]),
		contentVersion: optionalInt(row["content_version"]),
		contentHash: optionalText(row["content_hash"]),
	};
}

export function courseFromRow(value: unknown): OfficialTraprushCourseId | null {
	if (isOfficialTraprushCourseId(value)) {
		return value;
	}
	if (value === "" || value === null || value === undefined) {
		return null;
	}
	return DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
}

export function officialCourseFromRow(value: unknown): OfficialTraprushCourseId {
	return courseFromRow(value) ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
}

function optionalText(value: unknown): string | undefined {
	if (value === null || value === undefined) {
		return undefined;
	}
	const text = String(value);
	return text === "" ? undefined : text;
}

function optionalInt(value: unknown): number | undefined {
	if (value === null || value === undefined) {
		return undefined;
	}
	const number = Number(value);
	return Number.isInteger(number) ? number : undefined;
}

export function isUniqueConstraint(error: unknown): boolean {
	return error instanceof Error && error.message.includes("UNIQUE constraint failed");
}

