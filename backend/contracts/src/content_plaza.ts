/**
 * 内容广场 HTTP 契约（CD-12 / CD-31 / CD-33）。
 *
 * 发布成功后自动进入公共列表。名称由词库组合，标签只来自占用袋白名单。
 * 列表不含 bundle。OpenAPI 仍未生成。
 */

export const PLAZA_TABS = ["newest", "rating", "plays", "verified"] as const;
export type PlazaTab = (typeof PLAZA_TABS)[number];
export const DEFAULT_PLAZA_TAB: PlazaTab = "newest";

export const PLAZA_TAG_IDS = [
	"portal",
	"crate",
	"hazard",
	"pickup",
	"mover",
	"conveyor",
	"launch",
	"switch",
	"gate",
	"energy_wall",
	"portal_switch",
	"spike",
	"flame",
	"crusher",
	"roller",
	"rubble",
	"core",
	"pendulum",
	"ice",
] as const;
export type PlazaTagId = (typeof PLAZA_TAG_IDS)[number];

const TAG_BAGS: ReadonlyArray<readonly [PlazaTagId, string]> = [
	["portal", "portals"],
	["crate", "destructibles"],
	["hazard", "hazards"],
	["pickup", "pickups"],
	["mover", "movers"],
	["conveyor", "conveyors"],
	["launch", "launches"],
	["switch", "switches"],
	["gate", "gates"],
	["energy_wall", "energy_walls"],
	["portal_switch", "portal_switches"],
	["spike", "spikes"],
	["flame", "flames"],
	["crusher", "crushers"],
	["roller", "rollers"],
	["rubble", "rubbles"],
	["core", "obstacle_cores"],
	["pendulum", "pendulums"],
	["ice", "ices"],
];

export const PLAZA_ADJECTIVES = [
	"swift",
	"iron",
	"quiet",
	"bold",
	"brisk",
	"calm",
	"dark",
	"fair",
	"keen",
	"lean",
	"pale",
	"rare",
	"stark",
	"true",
	"vivid",
	"warm",
] as const;

export const PLAZA_NOUNS = [
	"lane",
	"gate",
	"spire",
	"arch",
	"brook",
	"cliff",
	"forge",
	"grove",
	"hearth",
	"ridge",
	"run",
	"span",
	"trail",
	"vault",
	"well",
	"yard",
] as const;

export const PLAZA_STARS_MIN = 1;
export const PLAZA_STARS_MAX = 5;
export const PLAZA_RATER_MAX = 64;
export const PLAZA_MATCH_ID_MAX = 64;

export const CONTENT_PLAZA_ERRORS = {
	unexpectedRequestBody: "unexpected_request_body",
	tabInvalid: "tab_invalid",
	idInvalid: "id_invalid",
	contentNotFound: "content_not_found",
	matchIdInvalid: "match_id_invalid",
	playExists: "play_exists",
	raterInvalid: "rater_invalid",
	starsInvalid: "stars_invalid",
	tagsInvalid: "tags_invalid",
	ratingExists: "rating_exists",
} as const;

export type ContentPlazaError =
	(typeof CONTENT_PLAZA_ERRORS)[keyof typeof CONTENT_PLAZA_ERRORS];

export interface PlazaItemView {
	readonly content_id: string;
	readonly version: number;
	readonly content_hash: string;
	readonly display_name: string;
	readonly tags: readonly string[];
	readonly play_count: number;
	readonly rating_sum: number;
	readonly rating_count: number;
	readonly verified: boolean;
	readonly listed_at: string;
}

export interface PlazaListView {
	readonly tab: PlazaTab;
	readonly items: readonly PlazaItemView[];
}

export interface PlazaPlayRequest {
	readonly match_id: string;
}

export interface PlazaRatingRequest {
	readonly rater: string;
	readonly stars: number;
	readonly tags: readonly string[];
}

const ID_RE = /^[A-Za-z0-9._-]+$/;

export function isPlazaTab(value: unknown): value is PlazaTab {
	return typeof value === "string" && (PLAZA_TABS as readonly string[]).includes(value);
}

export function isPlazaTagId(value: unknown): value is PlazaTagId {
	return typeof value === "string" && (PLAZA_TAG_IDS as readonly string[]).includes(value);
}

export function isPlazaRater(value: unknown): value is string {
	return (
		typeof value === "string" &&
		value.length >= 1 &&
		value.length <= PLAZA_RATER_MAX &&
		ID_RE.test(value)
	);
}

export function isPlazaMatchId(value: unknown): value is string {
	return (
		typeof value === "string" &&
		value.length >= 1 &&
		value.length <= PLAZA_MATCH_ID_MAX &&
		ID_RE.test(value)
	);
}

export function isPlazaStars(value: unknown): value is number {
	return (
		typeof value === "number" &&
		Number.isInteger(value) &&
		value >= PLAZA_STARS_MIN &&
		value <= PLAZA_STARS_MAX
	);
}

export function plazaTagsFromBundle(bundle: Record<string, unknown>): readonly PlazaTagId[] {
	const tags: PlazaTagId[] = [];
	for (const [tag, bag] of TAG_BAGS) {
		const raw = bundle[bag];
		if (!Array.isArray(raw) || raw.length === 0) {
			continue;
		}
		tags.push(tag);
	}
	return tags;
}

export function plazaDisplayName(contentId: string): string {
	const hash = fnv1a32(contentId);
	const adjective = PLAZA_ADJECTIVES[hash % PLAZA_ADJECTIVES.length];
	const noun = PLAZA_NOUNS[Math.floor(hash / PLAZA_ADJECTIVES.length) % PLAZA_NOUNS.length];
	return `${adjective}_${noun}`;
}

export function readPlazaTags(raw: unknown): readonly PlazaTagId[] | undefined {
	if (!Array.isArray(raw)) {
		return undefined;
	}
	const tags: PlazaTagId[] = [];
	const seen = new Set<string>();
	for (const item of raw) {
		if (!isPlazaTagId(item) || seen.has(item)) {
			return undefined;
		}
		seen.add(item);
		tags.push(item);
	}
	return tags;
}

export const plazaPlayBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["match_id"],
	properties: {
		match_id: {
			type: "string",
			minLength: 1,
			maxLength: PLAZA_MATCH_ID_MAX,
			pattern: "^[A-Za-z0-9._-]+$",
		},
	},
} as const;

export const plazaRatingBodySchema = {
	type: "object",
	additionalProperties: false,
	required: ["rater", "stars", "tags"],
	properties: {
		rater: {
			type: "string",
			minLength: 1,
			maxLength: PLAZA_RATER_MAX,
			pattern: "^[A-Za-z0-9._-]+$",
		},
		stars: { type: "integer", minimum: PLAZA_STARS_MIN, maximum: PLAZA_STARS_MAX },
		tags: {
			type: "array",
			maxItems: PLAZA_TAG_IDS.length,
			items: { type: "string", enum: [...PLAZA_TAG_IDS] },
		},
	},
} as const;

function fnv1a32(text: string): number {
	let hash = 2166136261;
	for (let index = 0; index < text.length; index += 1) {
		hash ^= text.charCodeAt(index);
		hash = Math.imul(hash, 16777619) >>> 0;
	}
	return hash >>> 0;
}
