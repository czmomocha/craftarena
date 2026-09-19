import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

import {
	TRAPRUSH_REPLAY_SERVER_RING,
	type TraprushReplayTape,
} from "../../../contracts/src/traprush_replay.ts";
import type { ContentOwnerKind } from "./database_content.ts";

export interface TraprushReplayRecord {
	readonly replayId: string;
	readonly ownerKind: ContentOwnerKind;
	readonly ownerId: string;
	readonly matchId: string;
	readonly courseId: string;
	readonly tapeJson: string;
	readonly createdAt: string;
}

export class TraprushReplayExistsError extends Error {
	constructor(matchId: string, ownerKind: string, ownerId: string) {
		super(`traprush replay already exists: ${matchId} ${ownerKind} ${ownerId}`);
		this.name = "TraprushReplayExistsError";
	}
}

export class ControlPlaneReplayStore {
	readonly db: DatabaseSync;

	constructor(db: DatabaseSync) {
		this.db = db;
	}

	listOwnersForMatch(matchId: string): readonly { readonly ownerKind: ContentOwnerKind; readonly ownerId: string }[] {
		const rows = this.db
			.prepare(
				`SELECT owner_kind AS owner_kind, owner_id AS owner_id
				 FROM match_tickets
				 WHERE match_id = ? AND superseded_at IS NULL
				   AND owner_kind IS NOT NULL AND owner_id IS NOT NULL`,
			)
			.all(matchId);
		const seen = new Set<string>();
		const owners: { readonly ownerKind: ContentOwnerKind; readonly ownerId: string }[] = [];
		for (const row of rows) {
			const ownerKind = String(row["owner_kind"]);
			const ownerId = String(row["owner_id"]);
			if (ownerKind !== "guest" && ownerKind !== "account") {
				continue;
			}
			const key = `${ownerKind}:${ownerId}`;
			if (seen.has(key)) {
				continue;
			}
			seen.add(key);
			owners.push({ ownerKind, ownerId });
		}
		return owners;
	}

	insertForOwners(input: {
		readonly matchId: string;
		readonly tape: TraprushReplayTape;
		readonly owners: readonly { readonly ownerKind: ContentOwnerKind; readonly ownerId: string }[];
		readonly now: Date;
	}): number {
		const tapeJson = JSON.stringify(input.tape);
		const createdAt = input.now.toISOString();
		let stored = 0;
		this.db.exec("BEGIN");
		try {
			for (const owner of input.owners) {
				const existing = this.db
					.prepare(
						`SELECT replay_id AS replay_id FROM traprush_replays
						 WHERE match_id = ? AND owner_kind = ? AND owner_id = ?`,
					)
					.get(input.matchId, owner.ownerKind, owner.ownerId);
				if (existing !== undefined) {
					continue;
				}
				this.db
					.prepare(
						`INSERT INTO traprush_replays
						 (replay_id, owner_kind, owner_id, match_id, course_id, tape_json, created_at)
						 VALUES (?, ?, ?, ?, ?, ?, ?)`,
					)
					.run(
						randomUUID(),
						owner.ownerKind,
						owner.ownerId,
						input.matchId,
						input.tape.course_id,
						tapeJson,
						createdAt,
					);
				this.trimRing(owner.ownerKind, owner.ownerId);
				stored += 1;
			}
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
		return stored;
	}

	listForOwner(ownerKind: ContentOwnerKind, ownerId: string): readonly TraprushReplayRecord[] {
		const rows = this.db
			.prepare(
				`SELECT replay_id, owner_kind, owner_id, match_id, course_id, tape_json, created_at
				 FROM traprush_replays
				 WHERE owner_kind = ? AND owner_id = ?
				 ORDER BY created_at DESC, replay_id DESC`,
			)
			.all(ownerKind, ownerId);
		return rows.map((row) => recordFromRow(row));
	}

	getForOwner(
		replayId: string,
		ownerKind: ContentOwnerKind,
		ownerId: string,
	): TraprushReplayRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT replay_id, owner_kind, owner_id, match_id, course_id, tape_json, created_at
				 FROM traprush_replays
				 WHERE replay_id = ? AND owner_kind = ? AND owner_id = ?`,
			)
			.get(replayId, ownerKind, ownerId);
		return row === undefined ? undefined : recordFromRow(row);
	}

	trimRing(ownerKind: ContentOwnerKind, ownerId: string): void {
		const row = this.db
			.prepare(
				`SELECT COUNT(*) AS n FROM traprush_replays WHERE owner_kind = ? AND owner_id = ?`,
			)
			.get(ownerKind, ownerId);
		const count = row === undefined ? 0 : Number(row["n"]);
		const extra = count - TRAPRUSH_REPLAY_SERVER_RING;
		if (extra <= 0) {
			return;
		}
		this.db
			.prepare(
				`DELETE FROM traprush_replays WHERE replay_id IN (
					SELECT replay_id FROM traprush_replays
					WHERE owner_kind = ? AND owner_id = ?
					ORDER BY created_at ASC, replay_id ASC
					LIMIT ?
				)`,
			)
			.run(ownerKind, ownerId, extra);
	}
}

function recordFromRow(row: Record<string, unknown>): TraprushReplayRecord {
	return {
		replayId: String(row["replay_id"]),
		ownerKind: String(row["owner_kind"]) as ContentOwnerKind,
		ownerId: String(row["owner_id"]),
		matchId: String(row["match_id"]),
		courseId: String(row["course_id"]),
		tapeJson: String(row["tape_json"]),
		createdAt: String(row["created_at"]),
	};
}
