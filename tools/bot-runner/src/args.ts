/**
 * 薄壳自己只吃 `--report=`。其余原样转给 Godot `--bot-run`。
 *
 * `--report` 没有 `=` 是错误：默默丢掉会让 nightly 以为写出了产物。
 * `--report=` 空路径同样拒绝。
 */
export type ParsedArgs = {
	readonly reportPath: string | null;
	readonly godotUserArgs: readonly string[];
};

export type ArgsError = {
	readonly error: "missing_report_path" | "empty_report_path";
};

export function parseArgs(argv: readonly string[]): ParsedArgs | ArgsError {
	let reportPath: string | null = null;
	const godotUserArgs: string[] = [];
	for (const arg of argv) {
		if (arg === "--report") {
			return { error: "missing_report_path" };
		}
		if (arg.startsWith("--report=")) {
			const value = arg.slice("--report=".length).trim();
			if (value === "") {
				return { error: "empty_report_path" };
			}
			reportPath = value;
			continue;
		}
		godotUserArgs.push(arg);
	}
	return { reportPath, godotUserArgs };
}

export function formatArgsError(error: ArgsError): string {
	if (error.error === "missing_report_path") {
		return "bot-runner: --report requires a path (--report=artifacts/bot-run.json).";
	}
	return "bot-runner: --report= path is empty.";
}
