export const ALLOW_PRAGMA = "redline-allow:";

export type PreparedLine = {
	readonly code: string;
	readonly allows: ReadonlySet<string>;
};

/** Pull `# redline-allow: a, b` tags, then drop comments and quoted strings. */
export function prepareLine(line: string): PreparedLine {
	const commentIndex = findCommentStart(line);
	const comment = commentIndex === -1 ? "" : line.slice(commentIndex);
	const beforeComment = commentIndex === -1 ? line : line.slice(0, commentIndex);
	return {
		code: stripDoubleQuotedStrings(beforeComment),
		allows: parseAllowPragma(comment),
	};
}

function parseAllowPragma(comment: string): ReadonlySet<string> {
	const marker = comment.indexOf(ALLOW_PRAGMA);
	if (marker === -1) {
		return new Set();
	}
	const raw = comment.slice(marker + ALLOW_PRAGMA.length);
	const tokens = raw
		.split(",")
		.map((token) => token.trim())
		.filter((token) => token.length > 0 && !token.startsWith("#"));
	return new Set(tokens);
}

function findCommentStart(line: string): number {
	let inString = false;
	for (let index = 0; index < line.length; index += 1) {
		const char = line[index];
		if (char === "\\" && inString) {
			index += 1;
			continue;
		}
		if (char === "\"") {
			inString = !inString;
			continue;
		}
		if (!inString && char === "#") {
			return index;
		}
	}
	return -1;
}

function stripDoubleQuotedStrings(source: string): string {
	let out = "";
	let inString = false;
	for (let index = 0; index < source.length; index += 1) {
		const char = source[index];
		if (char === "\\" && inString) {
			index += 1;
			continue;
		}
		if (char === "\"") {
			inString = !inString;
			continue;
		}
		if (!inString) {
			out += char;
		}
	}
	return out;
}
