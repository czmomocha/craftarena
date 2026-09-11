import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { formatArgsError, parseArgs } from "./args.ts";
import { botRunGodotArgs, resolveGodotExecutable } from "./godot.ts";
import { parseBotRunStdout } from "./parse.ts";
import { REPO_ROOT } from "./paths.ts";
import { assembleReport, EMPTY_RUN_MESSAGE, isEmptyRun } from "./report.ts";

export type SpawnResult = {
	readonly status: number | null;
	readonly stdout: string;
	readonly stderr: string;
	readonly error: Error | undefined;
};

export type SpawnFn = (executable: string, args: readonly string[], cwd: string) => SpawnResult;

export type RunIo = {
	readonly argv: readonly string[];
	readonly env: NodeJS.ProcessEnv;
	readonly platform: NodeJS.Platform;
	readonly cwd?: string;
	readonly spawn?: SpawnFn;
	readonly log?: (line: string) => void;
	readonly logError?: (line: string) => void;
	readonly writeFile?: (path: string, contents: string) => void;
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

/**
 * 调 Godot `--bot-run`，把 NDJSON 原样打到 stdout，可选写出报告 JSON。
 * 空输出（引擎横幅之外没有任何 bot_run_* 行）一律 exit 1，避免「什么都没查」假绿。
 */
export function runBotRun(io: RunIo): number {
	const log = io.log ?? console.log;
	const logError = io.logError ?? console.error;
	const parsedArgs = parseArgs(io.argv);
	if ("error" in parsedArgs) {
		logError(formatArgsError(parsedArgs));
		return 1;
	}

	let engine: ReturnType<typeof resolveGodotExecutable>;
	try {
		engine = resolveGodotExecutable(io.env, io.platform);
	} catch (error) {
		logError(error instanceof Error ? error.message : String(error));
		return 1;
	}

	const cwd = io.cwd ?? REPO_ROOT;
	const godotArgs = botRunGodotArgs(parsedArgs.godotUserArgs);
	const spawn = io.spawn ?? defaultSpawn;
	log(`bot-runner: ${engine.executable} (from ${engine.source})`);
	const spawned = spawn(engine.executable, godotArgs, cwd);
	if (spawned.stdout !== "") {
		log(spawned.stdout.endsWith("\n") ? spawned.stdout.slice(0, -1) : spawned.stdout);
	}
	if (spawned.stderr !== "") {
		logError(spawned.stderr.endsWith("\n") ? spawned.stderr.slice(0, -1) : spawned.stderr);
	}
	if (spawned.error !== undefined) {
		logError(`bot-runner: failed to start ${engine.executable}: ${spawned.error.message}`);
		return 1;
	}

	const parsed = parseBotRunStdout(spawned.stdout);
	const godotStatus = spawned.status ?? 1;
	const report = assembleReport(parsed, godotStatus);
	if (parsedArgs.reportPath !== null) {
		const reportPath = resolve(cwd, parsedArgs.reportPath);
		const writeFile = io.writeFile ?? writeReportFile;
		writeFile(reportPath, `${JSON.stringify(report, null, "\t")}\n`);
		log(`bot-runner: wrote ${reportPath}`);
	}
	if (isEmptyRun(parsed)) {
		logError(EMPTY_RUN_MESSAGE);
		return 1;
	}
	return report.exit_code;
}

function writeReportFile(path: string, contents: string): void {
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, contents, "utf8");
}
