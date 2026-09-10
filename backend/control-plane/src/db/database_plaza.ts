import type { DatabaseSync } from "node:sqlite";

import {
	plazaDisplayName,
	plazaTagsFromBundle,
	type PlazaTab,
} from "../../../contracts/src/content_plaza.ts";
import { isUniqueConstraint } from "./database_rows.ts";
import { ContentVersionMissingError } from "./database_content.ts";

export class PlazaPlayExistsError extends Error {
	constructor(contentId: string, matchId: string) {
		super(`plaza play already recorded: ${contentId}/${matchId}`);
		this.name = "PlazaPlayExistsError";
	}
}

export class PlazaRatingExistsError extends Error {
	constructor(contentId: string, rater: string) {
		super(`plaza rating already recorded: ${contentId}/${rater}`);
		this.name = "PlazaRatingExistsError";
	}
}

export interface PlazaListingRecord {
	readonly contentId: string;
	readonly version: number;
	readonly contentHash: string;
	readonly displayName: string;
	readonly tags: readonly string[];
	readonly playCount: number;
	readonly ratingSum: number;
	readonly ratingCount: number;
	readonly verified: boolean;
	readonly listedAt: string;
}

export function upsertPlazaListing(
	db: DatabaseSync,
	input: {
		readonly contentId: string;
		readonly version: number;
		readonly contentHash: string;
		readonly bundle: Record<string, unknown>;
		readonly listedAt: string;
	},
): void {
	const tagsJson = JSON.stringify(plazaTagsFromBundle(input.bundle));
	const existing = db.prepare("SELECT content_id FROM content_plaza WHERE content_id = ?").get(input.contentId);
	if (existing === undefined) {
		db.prepare(
			`INSERT INTO content_plaza (
				content_id, version, content_hash, display_name, tags_json,
				play_count, rating_sum, rating_count, verified, listed_at
			) VALUES (?, ?, ?, ?, ?, 0, 0, 0, 0, ?)`,
		).run(
			input.contentId,
			input.version,
			input.contentHash,
			plazaDisplayName(input.contentId),
			tagsJson,
			input.listedAt,
		);
		return;
	}
	db.prepare(
		`UPDATE content_plaza SET version = ?, content_hash = ?, tags_json = ?, listed_at = ?
		WHERE content_id = ?`,
	).run(input.version, input.contentHash, tagsJson, input.listedAt, input.contentId);
}

export function syncPlazaLatest(
	db: DatabaseSync,
	input: {
		readonly contentId: string;
		readonly version: number;
		readonly contentHash: string;
		readonly bundle: Record<string, unknown>;
	},
): void {
	const existing = db.prepare("SELECT content_id FROM content_plaza WHERE content_id = ?").get(input.contentId);
	if (existing === undefined) {
		return;
	}
	db.prepare(
		`UPDATE content_plaza SET version = ?, content_hash = ?, tags_json = ? WHERE content_id = ?`,
	).run(input.version, input.contentHash, JSON.stringify(plazaTagsFromBundle(input.bundle)), input.contentId);
}

export class ControlPlanePlazaStore {
	readonly db: DatabaseSync;

	constructor(db: DatabaseSync) {
		this.db = db;
	}

	get(contentId: string): PlazaListingRecord | undefined {
		const row = this.db.prepare(`${PLAZA_SELECT} WHERE content_id = ?`).get(contentId);
		return row === undefined ? undefined : listingFromRow(row);
	}

	list(tab: PlazaTab): readonly PlazaListingRecord[] {
		const order = orderSql(tab);
		const filter = tab === "verified" ? "WHERE verified = 1" : "";
		const rows = this.db.prepare(`${PLAZA_SELECT} ${filter} ${order}`).all();
		return rows.map((row) => listingFromRow(row));
	}

	recordPlay(contentId: string, matchId: string, now: Date): PlazaListingRecord {
		const createdAt = now.toISOString();
		this.db.exec("BEGIN");
		try {
			const listing = this.get(contentId);
			if (listing === undefined) {
				throw new ContentVersionMissingError(contentId, 0);
			}
			this.db
				.prepare(
					"INSERT INTO content_plaza_plays (content_id, match_id, created_at) VALUES (?, ?, ?)",
				)
				.run(contentId, matchId, createdAt);
			this.db
				.prepare(
					"UPDATE content_plaza SET play_count = play_count + 1, verified = 1 WHERE content_id = ?",
				)
				.run(contentId);
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			if (isUniqueConstraint(error)) {
				throw new PlazaPlayExistsError(contentId, matchId);
			}
			throw error;
		}
		const updated = this.get(contentId);
		if (updated === undefined) {
			throw new ContentVersionMissingError(contentId, 0);
		}
		return updated;
	}

	rate(input: {
		readonly contentId: string;
		readonly rater: string;
		readonly stars: number;
		readonly tags: readonly string[];
		readonly now: Date;
	}): PlazaListingRecord {
		const createdAt = input.now.toISOString();
		this.db.exec("BEGIN");
		try {
			const listing = this.get(input.contentId);
			if (listing === undefined) {
				throw new ContentVersionMissingError(input.contentId, 0);
			}
			this.db
				.prepare(
					`INSERT INTO content_plaza_ratings (
						content_id, rater, stars, tags_json, created_at
					) VALUES (?, ?, ?, ?, ?)`,
				)
				.run(input.contentId, input.rater, input.stars, JSON.stringify(input.tags), createdAt);
			this.db
				.prepare(
					`UPDATE content_plaza SET rating_sum = rating_sum + ?, rating_count = rating_count + 1
					WHERE content_id = ?`,
				)
				.run(input.stars, input.contentId);
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			if (isUniqueConstraint(error)) {
				throw new PlazaRatingExistsError(input.contentId, input.rater);
			}
			throw error;
		}
		const updated = this.get(input.contentId);
		if (updated === undefined) {
			throw new ContentVersionMissingError(input.contentId, 0);
		}
		return updated;
	}
}

const PLAZA_SELECT = `SELECT content_id, version, content_hash, display_name, tags_json,
	play_count, rating_sum, rating_count, verified, listed_at FROM content_plaza`;

function orderSql(tab: PlazaTab): string {
	if (tab === "plays") {
		return "ORDER BY play_count DESC, listed_at DESC, content_id ASC";
	}
	if (tab === "rating") {
		return `ORDER BY CASE WHEN rating_count = 0 THEN 1 ELSE 0 END ASC,
			CASE WHEN rating_count = 0 THEN 0 ELSE (rating_sum * 1000) / rating_count END DESC,
			rating_count DESC, listed_at DESC, content_id ASC`;
	}
	return "ORDER BY listed_at DESC, content_id ASC";
}

function listingFromRow(row: Record<string, unknown>): PlazaListingRecord {
	const parsed: unknown = JSON.parse(String(row["tags_json"]));
	if (!Array.isArray(parsed)) {
		throw new Error("content plaza tags_json is not an array");
	}
	return {
		contentId: String(row["content_id"]),
		version: Number(row["version"]),
		contentHash: String(row["content_hash"]),
		displayName: String(row["display_name"]),
		tags: parsed.map((item) => String(item)),
		playCount: Number(row["play_count"]),
		ratingSum: Number(row["rating_sum"]),
		ratingCount: Number(row["rating_count"]),
		verified: Number(row["verified"]) === 1,
		listedAt: String(row["listed_at"]),
	};
}
