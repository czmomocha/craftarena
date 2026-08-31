export const PROTECTED_BRANCHES: readonly string[] = ["main"];

export type Permission = "allow" | "deny";

export type Decision = {
	readonly permission: Permission;
	readonly code: string;
	readonly message: string;
};

const ALLOW: Decision = {
	permission: "allow",
	code: "allow",
	message: "allowed",
};

export type DecideOptions = {
	readonly currentBranch?: string | undefined;
	/**
	 * `game/project.godot` 在**索引**里带着的本机 Godot AI 条目（CD-51 §7.3）。
	 * 非空就等于「下一条 commit 会把它带进历史」，必须拦。
	 */
	readonly stagedProjectSettingsLocalOnly?: readonly string[] | undefined;
	/**
	 * 同上，但在**工作树**里。非空时任何会把该文件塞进索引的 `git add` / `commit -a`
	 * 都要拦，否则就变成上一条。
	 */
	readonly worktreeProjectSettingsLocalOnly?: readonly string[] | undefined;
};

const PROJECT_SETTINGS_PATH = "game/project.godot";
const SCRUB_COMMAND = "npm run godot-settings:scrub";

export function isProtectedBranch(name: string): boolean {
	const normalized = name.replace(/^refs\/heads\//, "").replace(/^refs\/remotes\/[^/]+\//, "");
	return PROTECTED_BRANCHES.includes(normalized);
}

export function decideShellCommand(command: string, options: DecideOptions = {}): Decision {
	for (const quoted of quotedSegments(command)) {
		if (hasGitToken(quoted) && quoted !== command) {
			const nested = decideShellCommand(quoted, options);
			if (nested.permission === "deny") {
				return nested;
			}
		}
	}

	if (!hasGitToken(command)) {
		return ALLOW;
	}

	const tokens = tokenize(command);
	const gitIndex = tokens.findIndex((token) => isGitExecutable(token));
	if (gitIndex === -1) {
		return ALLOW;
	}

	const afterGit = skipGitGlobals(tokens.slice(gitIndex + 1));
	const subcommand = afterGit[0];
	if (subcommand === undefined) {
		return ALLOW;
	}

	if (subcommand === "worktree") {
		return decideWorktree(afterGit.slice(1));
	}
	if (subcommand === "push") {
		return decidePush(afterGit.slice(1), options.currentBranch);
	}
	const settings = decideProjectSettings(subcommand, afterGit.slice(1), options);
	if (settings.permission === "deny") {
		return settings;
	}
	if (isProtectedWrite(subcommand, afterGit.slice(1)) && branchIsProtected(options.currentBranch)) {
		return deny(
			"commit-on-protected",
			`git ${subcommand} on protected branch '${options.currentBranch ?? "unknown"}' is blocked`,
		);
	}
	return ALLOW;
}

/**
 * Godot AI 插件每次运行都会把 `autoload/_mcp_game_helper` 与
 * `res://addons/godot_ai/plugin.cfg` 写回 `game/project.godot`。插件在
 * `.gitignore` 里、不是我们的代码，改不了它的写入；能做的是让那次写入进不了
 * 提交。它已经漏进过一个 commit（PR #193 前的分支上有修正提交），所以这里
 * fail closed：只要索引脏就不许 commit，只要工作树脏就不许把它 add 进索引。
 */
function decideProjectSettings(
	subcommand: string,
	args: readonly string[],
	options: DecideOptions,
): Decision {
	const stagedEntries = options.stagedProjectSettingsLocalOnly ?? [];
	const worktreeEntries = options.worktreeProjectSettingsLocalOnly ?? [];

	if (subcommand === "commit") {
		if (args.includes("--help") || args.includes("-h") || args.includes("--dry-run")) {
			return ALLOW;
		}
		if (stagedEntries.length > 0) {
			return denyProjectSettings("index", stagedEntries);
		}
		if (worktreeEntries.length > 0 && stagesEverything(args)) {
			return denyProjectSettings("working tree", worktreeEntries);
		}
		return ALLOW;
	}
	if (subcommand !== "add" && subcommand !== "stage") {
		return ALLOW;
	}
	if (worktreeEntries.length === 0) {
		return ALLOW;
	}
	if (!addTouchesProjectSettings(args)) {
		return ALLOW;
	}
	return denyProjectSettings("working tree", worktreeEntries);
}

function denyProjectSettings(where: string, entries: readonly string[]): Decision {
	return deny(
		"godot-ai-project-settings",
		`${PROJECT_SETTINGS_PATH} in the ${where} carries machine-local Godot AI entries (${entries.join(", ")}); CD-51 section 7.3 forbids committing them. Run \`${SCRUB_COMMAND}\` first.`,
	);
}

function stagesEverything(args: readonly string[]): boolean {
	return args.some((arg) => arg === "-a" || arg === "--all" || /^-[a-zA-Z]*a[a-zA-Z]*$/.test(arg));
}

function addTouchesProjectSettings(args: readonly string[]): boolean {
	const paths: string[] = [];
	let onlyPaths = false;
	for (const arg of args) {
		if (arg === "--") {
			onlyPaths = true;
			continue;
		}
		if (!onlyPaths && arg.startsWith("-")) {
			if (arg === "-A" || arg === "--all" || arg === "-u" || arg === "--update") {
				return true;
			}
			continue;
		}
		paths.push(arg);
	}
	return paths.some(coversProjectSettings);
}

function coversProjectSettings(pathArg: string): boolean {
	const normalized = pathArg.replace(/\\/g, "/").replace(/^\.\//, "").replace(/\/+$/, "");
	if (normalized === "" || normalized === "." || normalized === "*") {
		return true;
	}
	if (normalized === PROJECT_SETTINGS_PATH) {
		return true;
	}
	if (PROJECT_SETTINGS_PATH.startsWith(`${normalized}/`)) {
		return true;
	}
	return normalized.endsWith("*") && PROJECT_SETTINGS_PATH.startsWith(normalized.slice(0, -1));
}

function decideWorktree(args: readonly string[]): Decision {
	if (args[0] !== "remove") {
		return ALLOW;
	}
	if (args.some((arg) => arg === "--force" || arg === "-f")) {
		return deny("worktree-force-remove", "git worktree remove --force is blocked");
	}
	return ALLOW;
}

function decidePush(args: readonly string[], currentBranch: string | undefined): Decision {
	if (args.includes("--all") || args.includes("--mirror")) {
		return deny("push-all", "git push --all/--mirror is blocked");
	}

	const { deleteMode, refspecs, implicit } = parsePushArgs(args);
	if (implicit) {
		if (currentBranch === undefined) {
			return deny("push-implicit-unknown", "git push without a refspec is blocked unless the current branch is known and not protected");
		}
		if (isProtectedBranch(currentBranch)) {
			return deny("push-protected", `git push of protected branch '${currentBranch}' is blocked`);
		}
		return ALLOW;
	}

	for (const spec of refspecs) {
		const dest = refspecDestination(spec);
		if (dest === "HEAD") {
			if (currentBranch === undefined) {
				return deny(
					"push-implicit-unknown",
					"git push of HEAD is blocked unless the current branch is known and not protected",
				);
			}
			if (isProtectedBranch(currentBranch)) {
				return deny("push-protected", `git push of protected branch '${currentBranch}' via HEAD is blocked`);
			}
			continue;
		}
		if (isProtectedBranch(dest) || (deleteMode && isProtectedBranch(spec))) {
			return deny("push-protected", `git push updating '${dest}' is blocked`);
		}
	}
	return ALLOW;
}

function parsePushArgs(args: readonly string[]): {
	readonly deleteMode: boolean;
	readonly refspecs: readonly string[];
	readonly implicit: boolean;
} {
	const positional: string[] = [];
	let deleteMode = false;
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (arg === undefined) {
			break;
		}
		if (arg === "--") {
			positional.push(...args.slice(index + 1));
			break;
		}
		if (arg === "--delete" || arg === "-d") {
			deleteMode = true;
			continue;
		}
		if (arg === "--repo" || arg === "-o" || arg === "--push-option" || arg === "-C") {
			index += 1;
			continue;
		}
		if (arg.startsWith("-")) {
			continue;
		}
		positional.push(arg);
	}

	if (positional.length === 0) {
		return { deleteMode, refspecs: [], implicit: true };
	}
	if (positional.length === 1) {
		const only = positional[0] ?? "";
		if (only.includes(":") || only.startsWith("refs/")) {
			return { deleteMode, refspecs: [only], implicit: false };
		}
		return { deleteMode, refspecs: [], implicit: true };
	}
	return { deleteMode, refspecs: positional.slice(1), implicit: false };
}

function refspecDestination(spec: string): string {
	const trimmed = spec.replace(/^\+/, "");
	if (trimmed.startsWith(":")) {
		return trimmed.slice(1);
	}
	const colon = trimmed.indexOf(":");
	if (colon === -1) {
		return trimmed;
	}
	return trimmed.slice(colon + 1);
}

function isProtectedWrite(subcommand: string, args: readonly string[]): boolean {
	if (args.includes("--abort") || args.includes("--help") || args.includes("-h")) {
		return false;
	}
	return (
		subcommand === "commit" ||
		subcommand === "merge" ||
		subcommand === "rebase" ||
		subcommand === "cherry-pick" ||
		subcommand === "revert" ||
		subcommand === "am"
	);
}

function branchIsProtected(name: string | undefined): boolean {
	return name !== undefined && isProtectedBranch(name);
}

function skipGitGlobals(tokens: readonly string[]): readonly string[] {
	for (let index = 0; index < tokens.length; index += 1) {
		const token = tokens[index];
		if (token === undefined) {
			break;
		}
		if (token === "--") {
			return tokens.slice(index + 1);
		}
		if (token === "-C" || token === "--git-dir" || token === "--work-tree" || token === "-c") {
			index += 1;
			continue;
		}
		if (
			token.startsWith("--git-dir=") ||
			token.startsWith("--work-tree=") ||
			token.startsWith("-c")
		) {
			continue;
		}
		if (token.startsWith("-")) {
			continue;
		}
		return tokens.slice(index);
	}
	return [];
}

function hasGitToken(command: string): boolean {
	return /\bgit(?:\.exe)?\b/i.test(command);
}

function isGitExecutable(token: string): boolean {
	return /(?:^|[\\/])git(?:\.exe)?$/i.test(token);
}

function quotedSegments(command: string): string[] {
	const segments: string[] = [];
	const pattern = /"([^"]*)"|'([^']*)'/g;
	for (const match of command.matchAll(pattern)) {
		const value = match[1] ?? match[2];
		if (value !== undefined && value.length > 0) {
			segments.push(value);
		}
	}
	return segments;
}

function tokenize(command: string): string[] {
	const tokens: string[] = [];
	const pattern = /"([^"]*)"|'([^']*)'|(\S+)/g;
	for (const match of command.matchAll(pattern)) {
		tokens.push(match[1] ?? match[2] ?? match[3] ?? "");
	}
	return tokens;
}

function deny(code: string, message: string): Decision {
	return { permission: "deny", code, message };
}
