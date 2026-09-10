import type { DatabaseSync } from "node:sqlite";

import type { ContentPatchOp } from "../../../contracts/src/content_patch.ts";
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
		super(`content version is not the next stored version: ${contentId}@${version}`);
		this.name = "ContentVersionNotNextError";
	}
}

export class ContentVersionMissingError extends Error {
	constructor(contentId: string, version: number) {
		super(`content version missing: ${contentId}@${version}`);
		this.name = "ContentVersionMissingError";
	}
}

export class ContentAlreadyLatestError extends Error {
	constructor(contentId: string, version: number) {
		super(`content latest already at ${contentId}@${version}`);
		this.name = "ContentAlreadyLatestError";
	}
}

export class ContentPatchSeqNotNextError extends Error {
	constructor(contentId: string, baseVersion: number, seq: number) {
		super(`content patch seq is not next: ${contentId}@${baseVersion}#${seq}`);
		this.name = "ContentPatchSeqNotNextError";
	}
}

export interface ContentPatchRecord {
	readonly contentId: string;
	readonly baseVersion: number;
	readonly seq: number;
	readonly level: "p0" | "p1";
	readonly patchHash: string;
	readonly signature: string;
	readonly ops: readonly ContentPatchOp[];
	readonly createdAt: string;
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

			const maxRow = this.db
				.prepare("SELECT MAX(version) AS version FROM content_versions WHERE content_id = ?")
				.get(input.contentId);
			const maxVersion = maxRow === undefined || maxRow["version"] === null ? 0 : Number(maxRow["version"]);
			if (input.version !== maxVersion + 1) {
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

	publishPatch(input: {
		readonly contentId: string;
		readonly baseVersion: number;
		readonly seq: number;
		readonly level: "p0" | "p1";
		readonly patchHash: string;
		readonly signature: string;
		readonly ops: readonly ContentPatchOp[];
		readonly now: Date;
	}): ContentPatchRecord {
		const createdAt = input.now.toISOString();
		const opsJson = JSON.stringify(input.ops);
		this.db.exec("BEGIN");
		try {
			const base = this.db
				.prepare("SELECT version FROM content_versions WHERE content_id = ? AND version = ?")
				.get(input.contentId, input.baseVersion);
			if (base === undefined) {
				throw new ContentVersionMissingError(input.contentId, input.baseVersion);
			}
			const maxRow = this.db
				.prepare(
					"SELECT MAX(seq) AS seq FROM content_patches WHERE content_id = ? AND base_version = ?",
				)
				.get(input.contentId, input.baseVersion);
			const maxSeq = maxRow === undefined || maxRow["seq"] === null ? 0 : Number(maxRow["seq"]);
			if (input.seq !== maxSeq + 1) {
				throw new ContentPatchSeqNotNextError(input.contentId, input.baseVersion, input.seq);
			}
			this.db
				.prepare(
					`INSERT INTO content_patches (
						content_id, base_version, seq, level, patch_hash, signature, ops_json, created_at
					) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
				)
				.run(
					input.contentId,
					input.baseVersion,
					input.seq,
					input.level,
					input.patchHash,
					input.signature,
					opsJson,
					createdAt,
				);
			this.db.exec("COMMIT");
		} catch (error) {
			this.db.exec("ROLLBACK");
			if (isUniqueConstraint(error)) {
				throw new ContentPatchSeqNotNextError(input.contentId, input.baseVersion, input.seq);
			}
			throw error;
		}
		return {
			contentId: input.contentId,
			baseVersion: input.baseVersion,
			seq: input.seq,
			level: input.level,
			patchHash: input.patchHash,
			signature: input.signature,
			ops: input.ops,
			createdAt,
		};
	}

	listPatches(contentId: string, baseVersion: number): readonly ContentPatchRecord[] {
		const rows = this.db
			.prepare(
				`SELECT content_id, base_version, seq, level, patch_hash, signature, ops_json, created_at
				FROM content_patches WHERE content_id = ? AND base_version = ? ORDER BY seq ASC`,
			)
			.all(contentId, baseVersion);
		return rows.map((row) => patchFromRow(row));
	}

	rollbackLatest(contentId: string, targetVersion: number): ContentVersionRecord {
		this.db.exec("BEGIN");
		try {
			const target = this.getVersion(contentId, targetVersion);
			if (target === undefined) {
				throw new ContentVersionMissingError(contentId, targetVersion);
			}
			const latest = this.db
				.prepare("SELECT version FROM content_latest WHERE content_id = ?")
				.get(contentId);
			if (latest === undefined) {
				throw new ContentVersionMissingError(contentId, targetVersion);
			}
			const current = Number(latest["version"]);
			if (current === targetVersion) {
				throw new ContentAlreadyLatestError(contentId, targetVersion);
			}
			this.db
				.prepare("UPDATE content_latest SET version = ? WHERE content_id = ?")
				.run(targetVersion, contentId);
			this.db.exec("COMMIT");
			return target;
		} catch (error) {
			this.db.exec("ROLLBACK");
			throw error;
		}
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

function patchFromRow(row: Record<string, unknown>): ContentPatchRecord {
	const parsed: unknown = JSON.parse(String(row["ops_json"]));
	if (!Array.isArray(parsed)) {
		throw new Error("content ops_json is not an array");
	}
	return {
		contentId: String(row["content_id"]),
		baseVersion: Number(row["base_version"]),
		seq: Number(row["seq"]),
		level: String(row["level"]) as "p0" | "p1",
		patchHash: String(row["patch_hash"]),
		signature: String(row["signature"]),
		ops: parsed as ContentPatchOp[],
		createdAt: String(row["created_at"]),
	};
}
