import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";

import {
	plazaDisplayName,
	plazaTagsFromBundle,
	type PlazaItemView,
	type PlazaListView,
} from "../../contracts/src/index.ts";
import { CONTENT_SIGN_DEV_KEY, signContentMessage } from "../src/content_sign.ts";
import { ControlPlaneDatabase } from "../src/db/database.ts";
import { buildServer } from "../src/server.ts";

const HASH_A = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const HASH_B = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const HASH_C = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
const ID_A = "ugc_plaza_a";
const ID_B = "ugc_plaza_b";
const ID_C = "ugc_plaza_c";

describe("control plane content plaza", () => {
	let database: ControlPlaneDatabase;
	let now: Date;
	let app: ReturnType<typeof buildServer>;

	before(async () => {
		database = new ControlPlaneDatabase(":memory:");
		database.migrate();
		now = new Date("2026-09-10T08:00:00.000Z");
		app = buildServer({
			database,
			version: "1.2.3-test",
			logger: false,
			now: () => now,
			contentSignKey: CONTENT_SIGN_DEV_KEY,
		});
		await app.ready();
	});

	after(async () => {
		await app.close();
		database.close();
	});

	test("publish auto-lists with a system name and occupancy tags", async () => {
		const empty = await app.inject({ method: "GET", url: "/content/plaza" });
		assert.equal(empty.statusCode, 200);
		assert.deepEqual(empty.json<PlazaListView>(), { tab: "newest", items: [] });

		const published = await publish(app, ID_A, 1, HASH_A, {
			schema_version: 2,
			portals: [{ entity_id: 1 }],
			hazards: [{ entity_id: 2 }],
		});
		assert.equal(published.statusCode, 201);

		const listed = await app.inject({ method: "GET", url: "/content/plaza?tab=newest" });
		assert.equal(listed.statusCode, 200);
		const body = listed.json<PlazaListView>();
		assert.equal(body.tab, "newest");
		assert.equal(body.items.length, 1);
		const item = body.items[0];
		if (item === undefined) {
			assert.fail("expected one plaza item");
		}
		assert.equal(item.content_id, ID_A);
		assert.equal(item.version, 1);
		assert.equal(item.content_hash, HASH_A);
		assert.equal(item.display_name, plazaDisplayName(ID_A));
		assert.deepEqual(item.tags, plazaTagsFromBundle({ portals: [1], hazards: [1] }));
		assert.equal(item.play_count, 0);
		assert.equal(item.verified, false);
		assert.equal(item.listed_at, now.toISOString());
		assert.equal("bundle" in item, false);
	});

	test("unverified items stay off the verified tab until a play is recorded", async () => {
		const verifiedEmpty = await app.inject({ method: "GET", url: "/content/plaza?tab=verified" });
		assert.equal(verifiedEmpty.json<PlazaListView>().items.length, 0);

		const play = await app.inject({
			method: "POST",
			url: `/content/${ID_A}/plays`,
			payload: { match_id: "match_a1" },
		});
		assert.equal(play.statusCode, 200);
		const played = play.json<PlazaItemView>();
		assert.equal(played.play_count, 1);
		assert.equal(played.verified, true);

		const again = await app.inject({
			method: "POST",
			url: `/content/${ID_A}/plays`,
			payload: { match_id: "match_a1" },
		});
		assert.equal(again.statusCode, 409);

		const verified = await app.inject({ method: "GET", url: "/content/plaza?tab=verified" });
		assert.equal(verified.json<PlazaListView>().items[0]?.content_id, ID_A);
	});

	test("ratings reject free text and sort the rating tab by average", async () => {
		now = new Date("2026-09-10T09:00:00.000Z");
		assert.equal((await publish(app, ID_B, 1, HASH_B, { schema_version: 2 })).statusCode, 201);
		now = new Date("2026-09-10T10:00:00.000Z");
		assert.equal((await publish(app, ID_C, 1, HASH_C, { schema_version: 2 })).statusCode, 201);

		const freeText = await app.inject({
			method: "POST",
			url: `/content/${ID_B}/ratings`,
			payload: { rater: "p1", stars: 5, tags: ["nice_map"] },
		});
		assert.equal(freeText.statusCode, 400);

		const extra = await app.inject({
			method: "POST",
			url: `/content/${ID_B}/ratings`,
			payload: { rater: "p1", stars: 5, tags: [], title: "nope" },
		});
		assert.equal(extra.statusCode, 400);

		assert.equal(
			(
				await app.inject({
					method: "POST",
					url: `/content/${ID_B}/ratings`,
					payload: { rater: "p1", stars: 5, tags: ["ice"] },
				})
			).statusCode,
			200,
		);
		assert.equal(
			(
				await app.inject({
					method: "POST",
					url: `/content/${ID_C}/ratings`,
					payload: { rater: "p1", stars: 1, tags: [] },
				})
			).statusCode,
			200,
		);

		const rating = await app.inject({ method: "GET", url: "/content/plaza?tab=rating" });
		const ids = rating.json<PlazaListView>().items.map((item) => item.content_id);
		assert.deepEqual(ids.slice(0, 2), [ID_B, ID_C]);
		assert.equal(ids[2], ID_A);

		const newest = await app.inject({ method: "GET", url: "/content/plaza?tab=newest" });
		assert.deepEqual(
			newest.json<PlazaListView>().items.map((item) => item.content_id),
			[ID_C, ID_B, ID_A],
		);

		const plays = await app.inject({ method: "GET", url: "/content/plaza?tab=plays" });
		assert.equal(plays.json<PlazaListView>().items[0]?.content_id, ID_A);
	});

	test("unknown tab and missing content are rejected without listing official courses", async () => {
		const badTab = await app.inject({ method: "GET", url: "/content/plaza?tab=popular" });
		assert.equal(badTab.statusCode, 400);
		const missing = await app.inject({
			method: "POST",
			url: "/content/course_01/plays",
			payload: { match_id: "match_official" },
		});
		assert.equal(missing.statusCode, 404);
		const plaza = await app.inject({ method: "GET", url: "/content/plaza" });
		const ids = plaza.json<PlazaListView>().items.map((item) => item.content_id);
		assert.equal(ids.includes("course_01"), false);
	});
});

async function publish(
	app: ReturnType<typeof buildServer>,
	contentId: string,
	version: number,
	contentHash: string,
	bundle: Record<string, unknown>,
) {
	return app.inject({
		method: "POST",
		url: "/content/publish",
		payload: {
			schema_version: 1,
			content_id: contentId,
			version,
			content_hash: contentHash,
			signature: signContentMessage(CONTENT_SIGN_DEV_KEY, contentId, version, contentHash),
			bundle,
		},
	});
}
