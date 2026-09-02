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
		course: officialCourseFromRow(row["course"]),
		seats: Number(row["seats"]),
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
		course: officialCourseFromRow(row["course"]),
	};
}

export function officialCourseFromRow(value: unknown): OfficialTraprushCourseId {
	return isOfficialTraprushCourseId(value) ? value : DEFAULT_OFFICIAL_TRAPRUSH_COURSE;
}

export function isUniqueConstraint(error: unknown): boolean {
	return error instanceof Error && error.message.includes("UNIQUE constraint failed");
}

