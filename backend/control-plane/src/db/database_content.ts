import type { DatabaseSync } from "node:sqlite";

import { isUniqueConstraint } from "./database_rows.ts";

export interface ContentVersionRecord {
	readonly contentId: string;
	readonly version: number;
	readonly contentHash: string;
	readonly signature: string;
	readonly bundle: Record<string, unknown>;
	readonly createdAt: string;
}

export class ContentVersionExistsError extends Error {
	constructor(contentId: string, version: number) {
		super(`content version already exists: ${contentId}@${version}`);
		this.name = "ContentVersionExistsError";
	}
}

export class ContentVersionNotNextError extends Error {
	constructor(contentId: string, version: number) {
		super(`content version is not the next latest: ${contentId}@${version}`);
		this.name = "ContentVersionNotNextError";
	}
}

export class ControlPlaneContentStore {
	readonly db: DatabaseSync;

	constructor(db: DatabaseSync) {
		this.db = db;
	}

	publish(input: {
		readonly contentId: string;
		readonly version: number;
		readonly contentHash: string;
		readonly signature: string;
		readonly bundle: Record<string, unknown>;
		readonly now: Date;
	}): ContentVersionRecord {
		const createdAt = input.now.toISOString();
		const bundleJson = JSON.stringify(input.bundle);

		this.db.exec("BEGIN");
		try {
			const existing = this.db
				.prepare("SELECT version FROM content_versions WHERE content_id = ? AND version = ?")
				.get(input.contentId, input.version);
			if (existing !== undefined) {
				throw new ContentVersionExistsError(input.contentId, input.version);
			}

			const latest = this.db
				.prepare("SELECT version FROM content_latest WHERE content_id = ?")
				.get(input.contentId);
			const latestVersion = latest === undefined ? 0 : Number(latest["version"]);
			if (latestVersion === 0) {
				if (input.version !== 1) {
					throw new ContentVersionNotNextError(input.contentId, input.version);
				}
			} else if (input.version !== latestVersion + 1) {
				throw new ContentVersionNotNextError(input.contentId, input.version);
			}

			this.db
				.prepare(
					`INSERT INTO content_versions (
						content_id, version, content_hash, signature, bundle_json, created_at
					) VALUES (?, ?, ?, ?, ?, ?)`,
				)
				.run(
					input.contentId,
					input.version,
					input.contentHash,
					input.signature,
					bundleJson,
					createdAt,
				);
			this.db
				.prepare(
					`INSERT INTO content_latest (content_id, version) VALUES (?, ?)
					ON CONFLICT(content_id) DO UPDATE SET version = excluded.version`,
				)
				.run(input.contentId, input.version);
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			if (isUniqueConstraint(error)) {
				throw new ContentVersionExistsError(input.contentId, input.version);
			}
			throw error;
		}

		return {
			contentId: input.contentId,
			version: input.version,
			contentHash: input.contentHash,
			signature: input.signature,
			bundle: input.bundle,
			createdAt,
		};
	}

	getLatest(contentId: string): ContentVersionRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT v.content_id, v.version, v.content_hash, v.signature, v.bundle_json, v.created_at
				FROM content_latest l
				JOIN content_versions v ON v.content_id = l.content_id AND v.version = l.version
				WHERE l.content_id = ?`,
			)
			.get(contentId);
		return row === undefined ? undefined : recordFromRow(row);
	}

	getVersion(contentId: string, version: number): ContentVersionRecord | undefined {
		const row = this.db
			.prepare(
				`SELECT content_id, version, content_hash, signature, bundle_json, created_at
				FROM content_versions WHERE content_id = ? AND version = ?`,
			)
			.get(contentId, version);
		return row === undefined ? undefined : recordFromRow(row);
	}
}

function recordFromRow(row: Record<string, unknown>): ContentVersionRecord {
	const parsed: unknown = JSON.parse(String(row["bundle_json"]));
	if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
		throw new Error("content bundle_json is not an object");
	}
	return {
		contentId: String(row["content_id"]),
		version: Number(row["version"]),
		contentHash: String(row["content_hash"]),
		signature: String(row["signature"]),
		bundle: parsed as Record<string, unknown>,
		createdAt: String(row["created_at"]),
	};
}
