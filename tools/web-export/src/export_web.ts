import { spawnSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

import {
	EXPORT_OUTPUT_FROM_GAME,
	EXPORT_RELATIVE_DIR,
	WEB_PRESET_NAME,
} from "./constants.ts";
import { resolveGodotExecutable } from "./godot.ts";
import { REPO_ROOT } from "./paths.ts";
import { verifyWebExportDir } from "./verify.ts";

export type SpawnResult = {
	readonly status: number | null;
	readonly stdout: string;
	readonly stderr: string;
	readonly error: Error | undefined;
};

export type SpawnFn = (executable: string, args: readonly string[], cwd: string) => SpawnResult;

export type ExportIo = {
	readonly argv: readonly string[];
	readonly env: NodeJS.ProcessEnv;
	readonly platform: NodeJS.Platform;
	readonly cwd?: string;
	readonly spawn?: SpawnFn;
	readonly mkdir?: (dir: string) => void;
	readonly log?: (line: string) => void;
	readonly logError?: (line: string) => void;
};

export function defaultSpawn(executable: string, args: readonly string[], cwd: string): SpawnResult {
	const result = spawnSync(executable, [...args], {
		cwd,
		encoding: "utf8",
		maxBuffer: 16 * 1024 * 1024,
	});
	return {
		status: result.status,
		stdout: result.stdout ?? "",
		stderr: result.stderr ?? "",
		error: result.error,
	};
}

export function webExportGodotArgs(): string[] {
	return ["--headless", "--path", "game", "--export-release", WEB_PRESET_NAME, EXPORT_OUTPUT_FROM_GAME];
}

export function wantsDryRun(argv: readonly string[]): boolean {
	return argv.includes("--dry-run");
}

/**
 * One command: Godot `--export-release Web` into `export/web/`, then prove
 * `.html` / `.js` / `.wasm` / `.pck` landed. `--dry-run` prints the engine
 * command and does not spawn.
 */
export function runExportWeb(io: ExportIo): number {
	const log = io.log ?? console.log;
	const logError = io.logError ?? console.error;
	const cwd = io.cwd ?? REPO_ROOT;
	const outDir = join(cwd, EXPORT_RELATIVE_DIR);

	let engine: ReturnType<typeof resolveGodotExecutable>;
	try {
		engine = resolveGodotExecutable(io.env, io.platform);
	} catch (error) {
		logError(error instanceof Error ? error.message : String(error));
		return 1;
	}

	const godotArgs = webExportGodotArgs();
	log(`web-export: ${engine.executable} (from ${engine.source})`);
	log(`web-export: ${[engine.executable, ...godotArgs].join(" ")}`);

	if (wantsDryRun(io.argv)) {
		log("web-export: dry-run, not spawning Godot");
		return 0;
	}

	const mkdir = io.mkdir ?? ((dir: string) => mkdirSync(dir, { recursive: true }));
	mkdir(outDir);

	const spawn = io.spawn ?? defaultSpawn;
	const spawned = spawn(engine.executable, godotArgs, cwd);
	if (spawned.stdout !== "") {
		log(spawned.stdout.endsWith("\n") ? spawned.stdout.slice(0, -1) : spawned.stdout);
	}
	if (spawned.stderr !== "") {
		logError(spawned.stderr.endsWith("\n") ? spawned.stderr.slice(0, -1) : spawned.stderr);
	}
	if (spawned.error !== undefined) {
		logError(`web-export: failed to start ${engine.executable}: ${spawned.error.message}`);
		return 1;
	}
	if (spawned.status !== 0) {
		logError(`web-export: Godot exited ${String(spawned.status)}`);
		return spawned.status ?? 1;
	}

	const verified = verifyWebExportDir(outDir);
	if (!verified.ok) {
		logError(`web-export: ${verified.error}`);
		return 1;
	}
	log(
		JSON.stringify({
			event: "web_export",
			ok: true,
			dir: outDir,
			files: verified.files,
		}),
	);
	return 0;
}
