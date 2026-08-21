import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { FIXTURES_DIR } from "./paths.ts";

export type EnvelopeKind = "command" | "event";

export type FixtureFile = {
	readonly kind: EnvelopeKind;
	readonly valid: boolean;
	readonly name: string;
	readonly path: string;
	readonly instance: unknown;
};

export function loadEnvelopeFixtures(): FixtureFile[] {
	const fixtures: FixtureFile[] = [];
	for (const kind of ["command", "event"] as const) {
		for (const valid of [true, false]) {
			const directory = join(FIXTURES_DIR, kind, valid ? "valid" : "invalid");
			for (const name of readdirSync(directory).sort()) {
				if (!name.endsWith(".json")) {
					continue;
				}
				const path = join(directory, name);
				fixtures.push({
					kind,
					valid,
					name,
					path,
					instance: JSON.parse(readFileSync(path, "utf8")) as unknown,
				});
			}
		}
	}
	return fixtures;
}
