import { mkdirSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { ContentVersionView, MatchContentRef } from "../../contracts/src/index.ts";
import { MatchSessionRegisterError } from "./registrar.ts";

export interface ContentEnvelopeFetcher {
	fetch(id: string, version: number): Promise<ContentVersionView>;
}

export class ControlPlaneContentEnvelopeFetcher implements ContentEnvelopeFetcher {
	readonly #baseUrl: string;
	readonly #timeoutMs: number;

	constructor(baseUrl: string, timeoutMs = 2000) {
		this.#baseUrl = baseUrl.replace(/\/+$/, "");
		this.#timeoutMs = timeoutMs;
	}

	async fetch(id: string, version: number): Promise<ContentVersionView> {
		let response: Response;
		try {
			response = await fetch(
				`${this.#baseUrl}/content/${encodeURIComponent(id)}/versions/${version}`,
				{ signal: AbortSignal.timeout(this.#timeoutMs) },
			);
		} catch (error) {
			throw new MatchSessionRegisterError(error instanceof Error ? error.message : String(error));
		}
		if (response.status !== 200) {
			throw new MatchSessionRegisterError(`content envelope fetch returned HTTP ${response.status}`);
		}
		let body: unknown;
		try {
			body = await response.json();
		} catch {
			throw new MatchSessionRegisterError("content envelope fetch returned a non-JSON body");
		}
		if (typeof body !== "object" || body === null) {
			throw new MatchSessionRegisterError("content envelope fetch returned an invalid body");
		}
		const view = body as ContentVersionView;
		if (view.content_id !== id || view.version !== version || typeof view.content_hash !== "string") {
			throw new MatchSessionRegisterError("content envelope fetch returned a mismatched envelope");
		}
		return view;
	}
}

export function writeMatchEnvelopeFile(matchId: string, envelope: ContentVersionView): string {
	const directory = join(tmpdir(), "craftarena-match-envelopes");
	mkdirSync(directory, { recursive: true });
	const path = join(directory, `${matchId}.json`);
	writeFileSync(path, JSON.stringify(envelope));
	return path;
}

export function removeMatchEnvelopeFile(path: string | undefined): void {
	if (path === undefined) {
		return;
	}
	try {
		unlinkSync(path);
	} catch {
		// 进程已停或测试已删。
	}
}

export function contentRefOf(view: ContentVersionView): MatchContentRef {
	return { id: view.content_id, version: view.version };
}
