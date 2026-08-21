/** Mirrors `CanonicalPayload.MAX_DEPTH`. The GDScript sync test owns the number. */
export const CANONICAL_MAX_DEPTH = 8;

/**
 * Depth of the root payload object is 0, matching `CanonicalPayload.is_allowed(value, 0)`.
 * Nested arrays and objects increment. Scalars keep the current depth.
 */
export function canonicalDepth(value: unknown, depth = 0): number {
	if (value === null || typeof value !== "object") {
		return depth;
	}
	if (Array.isArray(value)) {
		let deepest = depth;
		for (const item of value) {
			deepest = Math.max(deepest, canonicalDepth(item, depth + 1));
		}
		return deepest;
	}
	let deepest = depth;
	for (const item of Object.values(value)) {
		deepest = Math.max(deepest, canonicalDepth(item, depth + 1));
	}
	return deepest;
}

export function payloadExceedsCanonicalDepth(payload: unknown): boolean {
	return canonicalDepth(payload) > CANONICAL_MAX_DEPTH;
}
