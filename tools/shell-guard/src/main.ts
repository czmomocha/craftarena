import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { stdin, stdout } from "node:process";

import {
	PROJECT_SETTINGS_PATH,
	findLocalOnlyEntries,
} from "../../godot-project-settings/src/local_only.ts";
import { decideShellCommand, type Decision } from "./decide.ts";

type HookInput = {
	readonly command?: unknown;
	readonly cwd?: unknown;
};

const input = await readStdinJson();
const command = typeof input.command === "string" ? input.command : "";
const cwd = typeof input.cwd === "string" && input.cwd !== "" ? input.cwd : process.cwd();
const decision = decideShellCommand(command, {
	currentBranch: readCurrentBranch(cwd),
	stagedProjectSettingsLocalOnly: readIndexProjectSettings(cwd),
	worktreeProjectSettingsLocalOnly: readWorktreeProjectSettings(cwd),
});
stdout.write(`${JSON.stringify(toHookResponse(decision))}\n`);

async function readStdinJson(): Promise<HookInput> {
	const chunks: Buffer[] = [];
	for await (const chunk of stdin) {
		chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
	}
	const raw = Buffer.concat(chunks).toString("utf8").trim();
	if (raw === "") {
		return {};
	}
	try {
		return JSON.parse(raw) as HookInput;
	} catch {
		return {};
	}
}

function readCurrentBranch(cwd: string): string | undefined {
	try {
		const output = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
			cwd,
			encoding: "utf8",
			timeout: 2000,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		if (output === "" || output === "HEAD") {
			return undefined;
		}
		return output;
	} catch {
		return undefined;
	}
}

/**
 * 读仓库根，而不是 hook 报来的 cwd：命令可能在任意子目录里发出，而
 * `game/project.godot` 的路径是相对仓库根的。读不到就当干净 —— 这条守卫的作用
 * 是拦住已知的污染，不是在无法判断时把所有 git 命令锁死。
 */
function repoRoot(cwd: string): string | undefined {
	try {
		const output = execFileSync("git", ["rev-parse", "--show-toplevel"], {
			cwd,
			encoding: "utf8",
			timeout: 2000,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		return output === "" ? undefined : output;
	} catch {
		return undefined;
	}
}

function readWorktreeProjectSettings(cwd: string): readonly string[] {
	const root = repoRoot(cwd);
	if (root === undefined) {
		return [];
	}
	try {
		return findLocalOnlyEntries(readFileSync(`${root}/${PROJECT_SETTINGS_PATH}`, "utf8"));
	} catch {
		return [];
	}
}

function readIndexProjectSettings(cwd: string): readonly string[] {
	const root = repoRoot(cwd);
	if (root === undefined) {
		return [];
	}
	try {
		const output = execFileSync("git", ["show", `:${PROJECT_SETTINGS_PATH}`], {
			cwd: root,
			encoding: "utf8",
			timeout: 2000,
			stdio: ["ignore", "pipe", "ignore"],
		});
		return findLocalOnlyEntries(output);
	} catch {
		return [];
	}
}

function toHookResponse(decision: Decision): {
	readonly permission: Decision["permission"];
	readonly user_message: string;
	readonly agent_message: string;
} {
	if (decision.permission === "allow") {
		return { permission: "allow", user_message: "", agent_message: "" };
	}
	return {
		permission: "deny",
		user_message: decision.message,
		agent_message: decision.message,
	};
}
