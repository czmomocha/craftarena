import { spawn } from "node:child_process";

export interface MatchLaunchSpec {
	readonly matchId: string;
	readonly port: number;
}

export interface MatchExit {
	readonly code: number | null;
	readonly signal: NodeJS.Signals | null;
}

export interface LaunchedProcess {
	readonly pid: number | undefined;
	readonly exited: Promise<MatchExit>;
	/** 进程的最后若干行输出，用于 CD-44 §3 要求的"异常时尽力保留日志"。 */
	recentOutput(): readonly string[];
	kill(): void;
}

/**
 * 进程启动的边界。
 *
 * 抽成接口是为了让 MatchHost 的租约、端口与回收逻辑可以在不装 Godot 的机器上测试，
 * 包括 Linux CI。真实实现见 GodotProcessLauncher。
 */
export interface ProcessLauncher {
	launch(spec: MatchLaunchSpec): LaunchedProcess;
}

export interface GodotLauncherOptions {
	readonly executable: string;
	readonly projectPath: string;
	readonly scene: string;
	/**
	 * 本机所有对局共用的课程与人数。开发期占位：真源是控制面下发的对局配置，
	 * 按场指定是后续章节；数值归 CD-44 §3 与 CD-63 管，这里只是可覆盖的默认。
	 */
	readonly course: string;
	readonly players: number;
	/** 保留的输出行数。取小值：这是崩溃诊断线索，不是完整日志。 */
	readonly retainedOutputLines?: number;
}

const DEFAULT_RETAINED_OUTPUT_LINES = 50;

export class GodotProcessLauncher implements ProcessLauncher {
	readonly #options: GodotLauncherOptions;

	constructor(options: GodotLauncherOptions) {
		this.#options = options;
	}

	/** 纯函数参数构造，不 spawn 进程，方便在无 Godot 的机器上断言。 */
	buildArgs(spec: MatchLaunchSpec): string[] {
		// `--` 之后的参数引擎不解释，由 OS.get_cmdline_user_args() 交给场景脚本。
		return [
			"--headless",
			"--path",
			this.#options.projectPath,
			"--scene",
			this.#options.scene,
			"--",
			`--match-id=${spec.matchId}`,
			`--port=${spec.port}`,
			`--course=${this.#options.course}`,
			`--players=${this.#options.players}`,
		];
	}

	launch(spec: MatchLaunchSpec): LaunchedProcess {
		const child = spawn(this.#options.executable, this.buildArgs(spec), {
			stdio: ["ignore", "pipe", "pipe"],
		});

		const retain = this.#options.retainedOutputLines ?? DEFAULT_RETAINED_OUTPUT_LINES;
		const output: string[] = [];
		const collect = (chunk: Buffer): void => {
			for (const line of chunk.toString().split(/\r?\n/)) {
				if (line.trim() === "") {
					continue;
				}
				output.push(line);
				if (output.length > retain) {
					output.shift();
				}
			}
		};

		child.stdout.on("data", collect);
		child.stderr.on("data", collect);

		const exited = new Promise<MatchExit>((resolvePromise) => {
			child.once("exit", (code, signal) => resolvePromise({ code, signal }));
			// spawn 失败（可执行文件不存在等）不会触发 exit，只有 error。
			// 不在这里兜住的话，调用方会永远等一个不会到来的 Promise。
			child.once("error", (error) => {
				output.push(`spawn failed: ${error.message}`);
				resolvePromise({ code: null, signal: null });
			});
		});

		return {
			pid: child.pid,
			exited,
			recentOutput: () => [...output],
			kill: () => {
				child.kill("SIGTERM");
			},
		};
	}
}
