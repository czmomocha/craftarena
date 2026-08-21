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
};

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
	if (isProtectedWrite(subcommand, afterGit.slice(1)) && branchIsProtected(options.currentBranch)) {
		return deny(
			"commit-on-protected",
			`git ${subcommand} on protected branch '${options.currentBranch ?? "unknown"}' is blocked`,
		);
	}
	return ALLOW;
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
			if (currentBranch === undefined || isProtectedBranch(currentBranch)) {
				return deny("push-protected", "git push of HEAD onto a protected branch is blocked");
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
