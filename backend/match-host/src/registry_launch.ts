import type { LaunchedProcess, MatchExit } from "./launcher.ts";
import { MatchListenError, type MatchListenProbe } from "./listen_probe.ts";
import { MatchSessionRegisterError } from "./registrar.ts";

export const FAILURE_OUTPUT_LINES = 5;
export const FAILURE_OUTPUT_LINE_CHARS = 200;

export function describeRecentOutput(lines: readonly string[]): string {
	if (lines.length === 0) {
		return "";
	}
	const tail = lines
		.slice(-FAILURE_OUTPUT_LINES)
		.map((line) =>
			line.length > FAILURE_OUTPUT_LINE_CHARS ? `${line.slice(0, FAILURE_OUTPUT_LINE_CHARS)}...` : line,
		);
	return `; last output: ${tail.join(" | ")}`;
}

/**
 * 把 catch 到的东西整成要抛给 `POST /matches` 的错误，同时决定它是 502 还是 500。
 * `launched` 为 false 表示连子进程都没派生出来（端口耗尽、参数非法），那不是上游失败。
 */
export function toStartFailure(error: unknown, launched: boolean): Error {
	if (error instanceof MatchListenError || error instanceof MatchSessionRegisterError) {
		return error;
	}
	if (!launched) {
		return error instanceof Error ? error : new Error(String(error));
	}
	return new MatchSessionRegisterError(error instanceof Error ? error.message : String(error));
}

export async function waitUntilListening(
	listenProbe: MatchListenProbe,
	process: LaunchedProcess,
	port: number,
): Promise<void> {
	const abort = new AbortController();
	let settled = false;
	let processExit: MatchExit | undefined;

	type ListenRace =
		| { readonly kind: "listening" }
		| { readonly kind: "listen_failed"; readonly error: unknown }
		| { readonly kind: "exited"; readonly exit: MatchExit };

	const listenAttempt: Promise<ListenRace> = listenProbe
		.waitUntilListening({ port, signal: abort.signal })
		.then(() => ({ kind: "listening" as const }))
		.catch((error: unknown) => ({ kind: "listen_failed" as const, error }));

	const exitAttempt: Promise<ListenRace> = process.exited.then((exit) => {
		if (!settled) {
			processExit = exit;
			abort.abort();
		}
		return { kind: "exited" as const, exit };
	});

	const outcome = await Promise.race([listenAttempt, exitAttempt]);
	settled = true;
	// 每条 listen 失败都带上进程最后几行输出：引擎起不来的真实原因只在那里。
	const output = describeRecentOutput(process.recentOutput());
	if (processExit !== undefined) {
		throw new MatchListenError(
			`match process exited before listen (code=${processExit.code}, signal=${processExit.signal})${output}`,
		);
	}
	if (outcome.kind === "listening") {
		return;
	}

	if (outcome.kind === "listen_failed" && outcome.error instanceof MatchListenError) {
		throw new MatchListenError(`${outcome.error.message}${output}`);
	}
	if (outcome.kind === "listen_failed") {
		throw new MatchListenError(
			`${outcome.error instanceof Error ? outcome.error.message : String(outcome.error)}${output}`,
		);
	}
	throw new MatchListenError(
		`match process exited before listen (code=${outcome.exit.code}, signal=${outcome.exit.signal})${output}`,
	);
}
