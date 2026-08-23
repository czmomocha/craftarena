import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { FIXTURES_DIR, OFFICIAL_CONTENT_DIR } from "./paths.ts";

export type EnvelopeKind = "command" | "event";
export type FixtureKind = EnvelopeKind | "component" | "authoring" | "simulation_bundle";

export type FixtureFile = {
	readonly kind: FixtureKind;
	readonly valid: boolean;
	readonly name: string;
	readonly path: string;
	readonly instance: unknown;
};

export function loadEnvelopeFixtures(): FixtureFile[] {
	return [...loadKindFixtures("command"), ...loadKindFixtures("event")];
}

export function loadComponentFixtures(): FixtureFile[] {
	return loadKindFixtures("component");
}

export function loadAuthoringFixtures(): FixtureFile[] {
	return loadKindFixtures("authoring");
}

export function loadSimulationBundleFixtures(): FixtureFile[] {
	return loadKindFixtures("simulation_bundle");
}

export function loadOfficialAuthoringDocuments(): FixtureFile[] {
	return loadJsonTree(OFFICIAL_CONTENT_DIR, "authoring", true);
}

function loadKindFixtures(kind: FixtureKind): FixtureFile[] {
	const fixtures: FixtureFile[] = [];
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
	return fixtures;
}

function loadJsonTree(directory: string, kind: FixtureKind, valid: boolean): FixtureFile[] {
	const fixtures: FixtureFile[] = [];
	for (const entry of readdirSync(directory, { withFileTypes: true }).sort((left, right) =>
		left.name.localeCompare(right.name),
	)) {
		if (entry.name.startsWith(".")) {
			continue;
		}
		const path = join(directory, entry.name);
		if (entry.isDirectory()) {
			fixtures.push(...loadJsonTree(path, kind, valid));
			continue;
		}
		if (!entry.name.endsWith(".json")) {
			continue;
		}
		fixtures.push({
			kind,
			valid,
			name: entry.name,
			path,
			instance: JSON.parse(readFileSync(path, "utf8")) as unknown,
		});
	}
	return fixtures;
}
