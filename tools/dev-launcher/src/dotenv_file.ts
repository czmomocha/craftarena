export type EnvMap = { [key: string]: string };

export function parseDotEnv(source: string): EnvMap {
	const values: EnvMap = {};
	for (const rawLine of source.split(/\r?\n/)) {
		const line = rawLine.trim();
		if (line === "" || line.startsWith("#")) {
			continue;
		}
		const separator = line.indexOf("=");
		if (separator <= 0) {
			continue;
		}
		const key = line.slice(0, separator).trim();
		let value = line.slice(separator + 1).trim();
		if (
			(value.startsWith("\"") && value.endsWith("\"")) ||
			(value.startsWith("'") && value.endsWith("'"))
		) {
			value = value.slice(1, -1);
		}
		if (key.length > 0) {
			values[key] = value;
		}
	}
	return values;
}

/** Existing keys win, matching Node 24 `process.loadEnvFile()`. */
export function applyDotEnv(source: string, env: NodeJS.ProcessEnv): void {
	const parsed = parseDotEnv(source);
	for (const [key, value] of Object.entries(parsed)) {
		if (env[key] === undefined) {
			env[key] = value;
		}
	}
}

export function mergeDotEnv(existing: string, updates: EnvMap): string {
	const merged = { ...parseDotEnv(existing), ...updates };
	const lines = Object.entries(merged).map(([key, value]) => `${key}=${value}`);
	return `${lines.join("\n")}\n`;
}
