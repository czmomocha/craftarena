import { basename, resolve } from "node:path";

/**
 * Local worktree port map. Defaults match each service `config.ts`.
 * Formula owner: README「并行工作区」. Do not copy these numbers into Confirmed-docs.
 */
export const PORT_STRIDE = 100;

export const BASE_PORTS = {
	controlPlane: 8080,
	gateway: 8090,
	matchHost: 8100,
	matchRangeMin: 42000,
	matchRangeMax: 42099,
} as const;

export type WorktreePorts = {
	readonly CONTROL_PLANE_PORT: number;
	readonly GATEWAY_PORT: number;
	readonly MATCH_HOST_PORT: number;
	readonly MATCH_HOST_PORT_RANGE_MIN: number;
	readonly MATCH_HOST_PORT_RANGE_MAX: number;
	readonly CONTROL_PLANE_URL: string;
};

/** Slot 0 is the primary checkout. Worktrees land in 1–9. */
export function worktreeSlot(
	cwd: string,
	rootWorktreePath: string | undefined,
	env: NodeJS.ProcessEnv = process.env,
): number {
	if (rootWorktreePath !== undefined && resolve(cwd) === resolve(rootWorktreePath)) {
		return 0;
	}
	const override = env["WORKTREE_SLOT"];
	if (override !== undefined && override.trim() !== "") {
		const parsed = Number.parseInt(override, 10);
		if (!Number.isInteger(parsed) || parsed < 1 || parsed > 9) {
			throw new Error(`WORKTREE_SLOT must be an integer in 1..9, received: ${override}`);
		}
		return parsed;
	}
	return hashSlot(basename(resolve(cwd)));
}

export function hashSlot(name: string): number {
	let hash = 0;
	for (const char of name) {
		hash = (Math.imul(hash, 33) + char.charCodeAt(0)) >>> 0;
	}
	return (hash % 9) + 1;
}

export function portsForSlot(slot: number): WorktreePorts {
	if (!Number.isInteger(slot) || slot < 0 || slot > 9) {
		throw new Error(`worktree slot must be 0..9, received: ${slot}`);
	}
	const delta = slot * PORT_STRIDE;
	const controlPlane = BASE_PORTS.controlPlane + delta;
	return {
		CONTROL_PLANE_PORT: controlPlane,
		GATEWAY_PORT: BASE_PORTS.gateway + delta,
		MATCH_HOST_PORT: BASE_PORTS.matchHost + delta,
		MATCH_HOST_PORT_RANGE_MIN: BASE_PORTS.matchRangeMin + delta,
		MATCH_HOST_PORT_RANGE_MAX: BASE_PORTS.matchRangeMax + delta,
		CONTROL_PLANE_URL: `http://127.0.0.1:${controlPlane}`,
	};
}
