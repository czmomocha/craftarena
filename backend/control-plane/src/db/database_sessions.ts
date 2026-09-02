import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

import {
	DEFAULT_MATCHMAKING_SEATS,
	DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
	type OfficialTraprushCourseId,
} from "../../../contracts/src/official_courses.ts";
import { isUniqueConstraint, sessionFromRow, settlementFromRow } from "./database_rows.ts";
import {
	DEFAULT_MATCH_SEATS,
	MatchSessionExistsError,
	MatchSessionNotFoundError,
	MatchSettlementExistsError,
	RoomCodeConflictError,
	type MatchSessionRecord,
	type MatchSettlementRecord,
} from "./database.ts";

export class ControlPlaneSessionStore {
	readonly db: DatabaseSync;

	constructor(db: DatabaseSync) {
		this.db = db;
	}

	insertMatchSession(input: {
		readonly matchId?: string | undefined;
		readonly upstreamUrl: string;
		readonly now: Date;
		readonly seats?: number | undefined;
		readonly course?: OfficialTraprushCourseId | undefined;
	}): MatchSessionRecord {
		const matchId = input.matchId ?? randomUUID();
		const createdAt = input.now.toISOString();
		const seats = input.seats ?? DEFAULT_MATCH_SEATS;
		const course = input.course ?? DEFAULT_OFFICIAL_TRAPRUSH_COURSE;

		try {
			this.db
				.prepare(
					"INSERT INTO match_sessions (match_id, upstream_url, created_at, room_code, seats, course) VALUES (?, ?, ?, NULL, ?, ?)",
				)
				.run(matchId, input.upstreamUrl, createdAt, seats, course);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new MatchSessionExistsError(matchId);
			}
			throw error;
		}

		return { matchId, upstreamUrl: input.upstreamUrl, createdAt, roomCode: undefined, seats, course };
	}

	deleteMatchSession(matchId: string): MatchSessionRecord {
		const existing = this.getMatchSession(matchId);
		if (existing === undefined) {
			throw new MatchSessionNotFoundError(matchId);
		}

		this.db.exec("BEGIN");
		try {
			this.db.prepare("DELETE FROM match_tickets WHERE match_id = ?").run(matchId);
			this.db
				.prepare(
					`UPDATE match_queue
					 SET status = 'failed', error = 'session_unregistered', ticket = NULL, ticket_expires_at = NULL
					 WHERE match_id = ? AND status = 'ready'`,
				)
				.run(matchId);
			this.db.prepare("DELETE FROM match_sessions WHERE match_id = ?").run(matchId);
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}

		return existing;
	}

	insertMatchSettlement(input: {
		readonly matchId: string;
		readonly tick: number;
		readonly stateHash: string;
		readonly padTotal: number;
		readonly mvpSlot: number;
		readonly rowsJson: string;
		readonly now: Date;
	}): MatchSettlementRecord {
		if (this.getMatchSession(input.matchId) === undefined) {
			throw new MatchSessionNotFoundError(input.matchId);
		}
		const createdAt = input.now.toISOString();
		try {
			this.db
				.prepare(
					`INSERT INTO match_settlements
					 (match_id, tick, state_hash, pad_total, mvp_slot, rows_json, created_at)
					 VALUES (?, ?, ?, ?, ?, ?, ?)`,
				)
				.run(
					input.matchId,
					input.tick,
					input.stateHash,
					input.padTotal,
					input.mvpSlot,
					input.rowsJson,
					createdAt,
				);
		} catch (error) {
			if (isUniqueConstraint(error)) {
				throw new MatchSettlementExistsError(input.matchId);
			}
			throw error;
		}
		return {
			matchId: input.matchId,
			tick: input.tick,
			stateHash: input.stateHash,
			padTotal: input.padTotal,
			mvpSlot: input.mvpSlot,
			rowsJson: input.rowsJson,
			createdAt,
		};
	}

	getMatchSettlement(matchId: string): MatchSettlementRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT match_id, tick, state_hash, pad_total, mvp_slot, rows_json, created_at
				 FROM match_settlements WHERE match_id = ?`,
			)
			.get(matchId);
		return row === undefined ? undefined : settlementFromRow(row);
	}

	getMatchSession(matchId: string): MatchSessionRecord | undefined {
		const row = this.db
			.prepare(
				"SELECT match_id, upstream_url, created_at, room_code, seats, course FROM match_sessions WHERE match_id = ?",
			)
			.get(matchId);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	getMatchSessionByRoomCode(roomCode: string): MatchSessionRecord | undefined {
		const row = this.db
			.prepare(
				"SELECT match_id, upstream_url, created_at, room_code, seats, course FROM match_sessions WHERE room_code = ?",
			)
			.get(roomCode);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	/**
	 * 最旧的未满公开房。没有房间码的登记（只走 MatchHost 运维入口）不进快速游戏。
	 * 快速游戏只进同一官方赛道且同一人数的房。
	 */
	findOldestOpenRoom(
		course: OfficialTraprushCourseId = DEFAULT_OFFICIAL_TRAPRUSH_COURSE,
		seats: number = DEFAULT_MATCHMAKING_SEATS,
	): MatchSessionRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT s.match_id, s.upstream_url, s.created_at, s.room_code, s.seats, s.course
				 FROM match_sessions s
				 WHERE s.room_code IS NOT NULL
				 AND s.course = ?
				 AND s.seats = ?
				 AND (
					SELECT COUNT(DISTINCT t.seat) FROM match_tickets t
					WHERE t.match_id = s.match_id AND t.superseded_at IS NULL
				 ) < s.seats
				 ORDER BY s.created_at ASC
				 LIMIT 1`,
			)
			.get(course, seats);
		return row === undefined ? undefined : sessionFromRow(row);
	}

	assignRoomCode(matchId: string, roomCode: string): string {
		try {
			const updated = this.db
				.prepare("UPDATE match_sessions SET room_code = ? WHERE match_id = ? AND room_code IS NULL")
				.run(roomCode, matchId);
			if (updated.changes !== 1) {
				if (this.getMatchSession(matchId) === undefined) {
					throw new MatchSessionNotFoundError(matchId);
				}
				throw new MatchSessionExistsError(matchId);
			}
		} catch (error) {
			if (error instanceof MatchSessionNotFoundError || error instanceof MatchSessionExistsError) {
				throw error;
			}
			if (isUniqueConstraint(error)) {
				throw new RoomCodeConflictError(roomCode);
			}
			throw error;
		}

		return roomCode;
	}

	assignGeneratedRoomCode(matchId: string, generate: () => string, attempts = 8): string {
		for (let attempt = 0; attempt < attempts; attempt += 1) {
			try {
				return this.assignRoomCode(matchId, generate());
			} catch (error) {
				if (error instanceof RoomCodeConflictError) {
					continue;
				}
				throw error;
			}
		}

		throw new RoomCodeConflictError("exhausted");
	}
}
