import { execFileSync } from "node:child_process";

export interface ChangeSet {
	/** 仓库相对路径，正斜杠，已去重。 */
	readonly paths: readonly string[];
	/** 真正用上的对比基线；没找到就是 undefined，此时只看工作区。 */
	readonly base: string | undefined;
}

/**
 * 「这一刀改了什么」= 工作区改动 + 未跟踪文件 + 本分支相对 base 的提交。
 *
 * 三者都要：只看工作区会漏掉已经 commit 的部分，只看分支差异会漏掉还没 commit
 * 的部分，而「提交前跑一下测试」这个场景恰好两边都有。
 */
export function discoverChanges(repoRoot: string, base: string): ChangeSet {
	const paths = new Set<string>();

	for (const line of git(repoRoot, ["diff", "--name-only", "HEAD"])) {
		paths.add(line);
	}
	for (const line of git(repoRoot, ["ls-files", "--others", "--exclude-standard"])) {
		paths.add(line);
	}

	const resolved = resolveBase(repoRoot, base);
	if (resolved !== undefined) {
		for (const line of git(repoRoot, ["diff", "--name-only", `${resolved}...HEAD`])) {
			paths.add(line);
		}
	}

	return { paths: [...paths], base: resolved };
}

/** 优先用 `origin/<base>`，本地没有远端引用时退回 `<base>`，都没有就只看工作区。 */
function resolveBase(repoRoot: string, base: string): string | undefined {
	for (const candidate of [`origin/${base}`, base]) {
		try {
			execFileSync("git", ["rev-parse", "--verify", "--quiet", `${candidate}^{commit}`], {
				cwd: repoRoot,
				stdio: ["ignore", "ignore", "ignore"],
			});
			return candidate;
		} catch {
			continue;
		}
	}
	return undefined;
}

function git(repoRoot: string, args: readonly string[]): readonly string[] {
	const stdout = execFileSync("git", [...args], {
		cwd: repoRoot,
		encoding: "utf8",
		stdio: ["ignore", "pipe", "pipe"],
	});
	return stdout
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0);
}
