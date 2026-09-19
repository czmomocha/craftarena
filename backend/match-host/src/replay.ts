import { readFileSync } from "node:fs";

import type { RecordMatchReplayRequest, TraprushReplayTape } from "../../contracts/src/traprush_replay.ts";
import { TRAPRUSH_REPLAY_SCHEMA_VERSION } from "../../contracts/src/traprush_replay.ts";

export function readReplayTape(path: string | undefined): RecordMatchReplayRequest | undefined {
	if (path === undefined || path === "") {
		return undefined;
	}
	let text: string;
	try {
		text = readFileSync(path, "utf8");
	} catch {
		return undefined;
	}
	if (text.length < 2) {
		return undefined;
	}
	let parsed: unknown;
	try {
		parsed = JSON.parse(text);
	} catch {
		return undefined;
	}
	if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
		return undefined;
	}
	const tape = parsed as TraprushReplayTape;
	if (tape.schema_version !== TRAPRUSH_REPLAY_SCHEMA_VERSION) {
		return undefined;
	}
	if (!Array.isArray(tape.commands) || !Array.isArray(tape.finish_ticks)) {
		return undefined;
	}
	return { tape };
}

export async function tryRecordReplay(
	path: string | undefined,
	posted: boolean,
	record: (payload: RecordMatchReplayRequest) => Promise<void>,
): Promise<boolean> {
	if (posted) {
		return true;
	}
	const payload = readReplayTape(path);
	if (payload === undefined) {
		return false;
	}
	await record(payload);
	return true;
}

export async function flushReplayEntries(
	entries: Iterable<
		[string, { record: { state: string }; replayPosted: boolean; replayOutPath?: string | undefined }]
	>,
	recordReplay: (matchId: string, payload: RecordMatchReplayRequest) => Promise<void>,
): Promise<void> {
	for (const [matchId, entry] of entries) {
		if (entry.record.state !== "running") {
			continue;
		}
		try {
			entry.replayPosted = await tryRecordReplay(
				entry.replayOutPath,
				entry.replayPosted,
				(payload) => recordReplay(matchId, payload),
			);
		} catch {
			continue;
		}
	}
}
