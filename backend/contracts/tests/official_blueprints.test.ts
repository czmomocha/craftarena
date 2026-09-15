import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
	DEFAULT_OFFICIAL_BASTION_BLUEPRINT,
	isOfficialBastionBlueprintId,
	officialBastionBlueprintIdFromPath,
	officialBastionBlueprintPath,
} from "../src/official_blueprints.ts";
import { readOfficialMatchBody } from "../src/official_courses.ts";

describe("official BASTION blueprint ids", () => {
	test("names blueprint_01 and rejects paths", () => {
		assert.equal(DEFAULT_OFFICIAL_BASTION_BLUEPRINT, "blueprint_01");
		assert.equal(isOfficialBastionBlueprintId("blueprint_01"), true);
		assert.equal(isOfficialBastionBlueprintId("blueprint_02"), false);
		assert.equal(isOfficialBastionBlueprintId("course_01"), false);
		assert.equal(isOfficialBastionBlueprintId(""), false);
		assert.equal(isOfficialBastionBlueprintId("res://content/official/bastion/blueprint_01.json"), false);
		assert.equal(
			officialBastionBlueprintPath("blueprint_01"),
			"res://content/official/bastion/blueprint_01.json",
		);
		assert.equal(
			officialBastionBlueprintIdFromPath("res://content/official/bastion/blueprint_01.json"),
			"blueprint_01",
		);
		assert.equal(officialBastionBlueprintIdFromPath("res://content/official/traprush/course_01.json"), undefined);
		assert.equal(officialBastionBlueprintIdFromPath("blueprint_01"), undefined);
	});

	test("does not sneak into the TRAPRUSH course match body", () => {
		const result = readOfficialMatchBody({ course: "blueprint_01" });
		assert.equal(result.ok, false);
		assert.equal((result as { error: string }).error, "invalid_course");
	});
});
