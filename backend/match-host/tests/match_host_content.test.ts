import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { describe, test } from "node:test";

import type { ContentVersionView } from "../../contracts/src/index.ts";
import { GodotProcessLauncher, type MatchLaunchSpec, type ProcessLauncher, type LaunchedProcess, type MatchExit } from "../src/launcher.ts";
import { type MatchListenProbe, type MatchListenWaitSpec } from "../src/listen_probe.ts";
import {
	MatchSessionRegisterError,
	type MatchSessionRegisterSpec,
	type MatchSessionRegistrar,
} from "../src/registrar.ts";
import { MatchRegistry } from "../src/registry.ts";
import { buildMatchHost } from "../src/server.ts";
import type { ContentEnvelopeFetcher } from "../src/content_envelope.ts";

const LEASE_MS = 30 * 60 * 1000;
const IDLE_MS = 10 * 60 * 1000;
const ENVELOPE: ContentVersionView = {
	schema_version: 1,
	content_id: "ugc_aabbccddeeff00112233445566778899",
	version: 2,
	content_hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	signature: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
	bundle: { schema_version: 2, cell: 65536 },
};

describe("match host signed content", () => {
	test("buildArgs uses content-envelope and omits course", () => {
		const launcher = new GodotProcessLauncher({
			executable: "/opt/godot/godot",
			projectPath: "/repo/game",
			scene: "res://src/server/match_server.tscn",
			course: "res://content/official/traprush/course_01.json",
			players: 2,
		});
		const args = launcher.buildArgs({
			matchId: "m-ugc",
			port: 42001,
			contentEnvelopePath: "/tmp/craftarena-match-envelopes/m-ugc.json",
			players: 2,
		});
		assert.ok(args.includes("--content-envelope=/tmp/craftarena-match-envelopes/m-ugc.json"));
		assert.equal(
			args.some((arg) => arg.startsWith("--course=")),
			false,
		);
	});

	test("POST /matches with content fetches the envelope, launches, and registers hash", async () => {
		const launcher = new RecordingLauncher();
		const registrar = new RecordingRegistrar();
		const fetcher = new StubEnvelopeFetcher();
		const registry = new MatchRegistry({
			launcher,
			registrar,
			listenProbe: new ImmediateListenProbe(),
			contentEnvelope: fetcher,
			upstreamHost: "127.0.0.1",
			seats: 2,
			portRangeMin: 43000,
			portRangeMax: 43009,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: 4,
		});
		const app = buildMatchHost({
			registry,
			maxConcurrentMatches: 4,
			version: "1.2.3-test",
			logger: false,
		});
		try {
			const created = await app.inject({
				method: "POST",
				url: "/matches",
				payload: { content: { id: ENVELOPE.content_id, version: ENVELOPE.version }, seats: 3 },
			});
			assert.equal(created.statusCode, 201);
			const body = created.json<{
				course: string | null;
				content?: { id: string; version: number };
				content_hash?: string;
				seats: number;
			}>();
			assert.equal(body.course, null);
			assert.deepEqual(body.content, { id: ENVELOPE.content_id, version: ENVELOPE.version });
			assert.equal(body.content_hash, ENVELOPE.content_hash);
			assert.equal(body.seats, 3);
			assert.deepEqual(fetcher.fetched, [{ id: ENVELOPE.content_id, version: ENVELOPE.version }]);
			assert.equal(launcher.launched.length, 1);
			const spec = launcher.launched[0] as MatchLaunchSpec;
			assert.equal(spec.course, undefined);
			assert.equal(typeof spec.contentEnvelopePath, "string");
			assert.equal(existsSync(spec.contentEnvelopePath ?? ""), true);
			assert.deepEqual(registrar.registered[0]?.content, {
				id: ENVELOPE.content_id,
				version: ENVELOPE.version,
			});
			assert.equal(registrar.registered[0]?.content_hash, ENVELOPE.content_hash);
			assert.equal(registrar.registered[0]?.course, undefined);
			await registry.stop(created.json<{ matchId: string }>().matchId);
			assert.equal(existsSync(spec.contentEnvelopePath ?? ""), false);
		} finally {
			await app.close();
		}
	});

	test("POST /matches returns 502 when the envelope is missing", async () => {
		const registry = new MatchRegistry({
			launcher: new RecordingLauncher(),
			registrar: new RecordingRegistrar(),
			listenProbe: new ImmediateListenProbe(),
			contentEnvelope: {
				fetch: async () => {
					throw new MatchSessionRegisterError("content envelope fetch returned HTTP 404");
				},
			},
			upstreamHost: "127.0.0.1",
			seats: 2,
			portRangeMin: 43100,
			portRangeMax: 43109,
			leaseDurationMs: LEASE_MS,
			idleTimeoutMs: IDLE_MS,
			maxConcurrentMatches: 4,
		});
		const app = buildMatchHost({
			registry,
			maxConcurrentMatches: 4,
			version: "1.2.3-test",
			logger: false,
		});
		try {
			const rejected = await app.inject({
				method: "POST",
				url: "/matches",
				payload: { content: { id: ENVELOPE.content_id, version: 1 } },
			});
			assert.equal(rejected.statusCode, 502);
		} finally {
			await app.close();
		}
	});
});

class StubEnvelopeFetcher implements ContentEnvelopeFetcher {
	readonly fetched: Array<{ id: string; version: number }> = [];

	async fetch(id: string, version: number): Promise<ContentVersionView> {
		this.fetched.push({ id, version });
		if (id !== ENVELOPE.content_id || version !== ENVELOPE.version) {
			throw new MatchSessionRegisterError("content envelope fetch returned HTTP 404");
		}
		return ENVELOPE;
	}
}

class RecordingRegistrar implements MatchSessionRegistrar {
	readonly registered: MatchSessionRegisterSpec[] = [];

	async register(spec: MatchSessionRegisterSpec): Promise<void> {
		this.registered.push(spec);
	}

	async recordSettlement(): Promise<void> {}

	async unregister(): Promise<void> {}
}

class ImmediateListenProbe implements MatchListenProbe {
	async waitUntilListening(_spec: MatchListenWaitSpec): Promise<void> {}
}

class RecordingLauncher implements ProcessLauncher {
	readonly launched: MatchLaunchSpec[] = [];
	#nextPid = 2000;
	readonly #settle = new Map<string, (exit: MatchExit) => void>();

	launch(spec: MatchLaunchSpec): LaunchedProcess {
		this.launched.push(spec);
		const pid = this.#nextPid++;
		let settle: (exit: MatchExit) => void = () => {};
		const exited = new Promise<MatchExit>((resolvePromise) => {
			settle = resolvePromise;
		});
		this.#settle.set(spec.matchId, settle);
		return {
			pid,
			exited,
			recentOutput: () => ["fake content match"],
			kill: () => {
				settle({ code: 0, signal: "SIGTERM" });
			},
		};
	}
}
