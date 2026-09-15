import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { FIXTURES_DIR, OFFICIAL_CONTENT_DIR, TEST_FIXTURE_CONTENT_DIR } from "./paths.ts";

export type EnvelopeKind = "command" | "event";
export type FixtureKind =
	| EnvelopeKind
	| "component"
	| "authoring"
	| "simulation_bundle"
	| "bastion_blueprint_bundle"
	| "audio_bank";

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

/**
 * BASTION bundle 的正反例住在 `game/content/test_fixtures/`，不在本工具的
 * `fixtures/` 下：GDScript 的解码器与本文件的校验器必须吃**同一批文件**，
 * 否则两侧各自绿着、口径已经分叉了也没人知道。
 */
export function loadBastionBlueprintFixtures(): FixtureFile[] {
	const root = join(TEST_FIXTURE_CONTENT_DIR, "bastion/bundles");
	return [
		...loadJsonTree(join(root, "valid"), "bastion_blueprint_bundle", true),
		...loadJsonTree(join(root, "invalid"), "bastion_blueprint_bundle", false),
	];
}

export function loadAudioBankFixtures(): FixtureFile[] {
	return loadKindFixtures("audio_bank");
}

export function loadOfficialAuthoringDocuments(): FixtureFile[] {
	return loadJsonTree(OFFICIAL_CONTENT_DIR, "authoring", true);
}

/**
 * `game/content/test_fixtures/` 下的灰盒蓝图。它们不是官方内容，但仍然必须是
 * 合法 `AuthoringDocument`——BASTION 编译器的输入就是它，夹具自己先烂掉的话，
 * 所有正反例都在测一份不合法的输入。
 */
export function loadTestFixtureAuthoringDocuments(): FixtureFile[] {
	return loadJsonTree(join(TEST_FIXTURE_CONTENT_DIR, "bastion/blueprints"), "authoring", true);
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
