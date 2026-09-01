/** 引擎路径是从哪个环境变量来的。写进日志，免得排查时还要猜。 */
export type GodotExecutableSource = "GODOT4" | "GODOT4_CONSOLE";

export interface GodotExecutable {
	readonly executable: string;
	readonly source: GodotExecutableSource;
}

/**
 * 与 `backend/match-host/src/config.ts` 同一套策略，故意保持一致：
 * Windows 上优先 `GODOT4_CONSOLE`（GUI 子系统的 `godot.exe` 不向父进程管道写
 * stdout，测试输出会整片消失），其余平台用 `GODOT4`；**没有 PATH 回退**，
 * 想用 PATH 上的引擎要显式写 `GODOT4=godot`。
 */
export function resolveGodotExecutable(
	env: NodeJS.ProcessEnv,
	platform: NodeJS.Platform,
): GodotExecutable {
	if (platform === "win32") {
		const consoleExecutable = readNonBlank(env["GODOT4_CONSOLE"]);
		if (consoleExecutable !== undefined) {
			return { executable: consoleExecutable, source: "GODOT4_CONSOLE" };
		}
	}
	const executable = readNonBlank(env["GODOT4"]);
	if (executable === undefined) {
		const variables = platform === "win32" ? "GODOT4_CONSOLE or GODOT4" : "GODOT4";
		throw new Error(
			`${variables} must point at the Godot engine executable; the test selector does not fall ` +
				`back to a "godot" on PATH. See CD-51 section 1 and the README command table; ` +
				`set GODOT4=godot to opt into a PATH lookup on purpose.`,
		);
	}
	return { executable, source: "GODOT4" };
}

/** 拼出 GUT 的命令行。`selector` 是 `-gdir=...` 或 `-gtest=...`。 */
export function gutArgs(selector: string): readonly string[] {
	return ["--headless", "--path", "game", "-s", "res://addons/gut/gut_cmdln.gd", selector, "-gexit"];
}

function readNonBlank(raw: string | undefined): string | undefined {
	if (raw === undefined || raw.trim() === "") {
		return undefined;
	}
	return raw.trim();
}
