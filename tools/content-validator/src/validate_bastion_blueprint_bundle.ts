import { loadJsonFile, validateJsonSchema, type JsonSchemaError } from "./json_schema.ts";
import { BASTION_BLUEPRINT_SCHEMA_PATH } from "./paths.ts";

type JsonObject = { readonly [key: string]: unknown };

const OBSTACLE_DIVERTER = 23;

/**
 * BASTION 蓝图 bundle 的闭合校验。
 *
 * JSON Schema 表达不了跨袋引用、严格升序、两侧预算相等和「分流门要有分支」，
 * 而 `BastionBlueprintDecode` 会拒。两侧不一致的话就会出现 GDScript 拒了、
 * `npm test` 放行的反例——那种反例等于没有（`validate_simulation_bundle.ts`
 * 里同一条理由）。
 */
export function validateBastionBlueprintBundle(instance: unknown): JsonSchemaError[] {
	const errors = validateJsonSchema(loadJsonFile(BASTION_BLUEPRINT_SCHEMA_PATH), instance, {
		schemaPath: BASTION_BLUEPRINT_SCHEMA_PATH,
	});
	if (!isObject(instance)) {
		return errors;
	}
	const nodes = collectNodes(errors, instance);
	pushEdgeErrors(errors, instance, nodes);
	pushCoreErrors(errors, instance, nodes);
	pushSpawnErrors(errors, instance, nodes);
	pushBuildSlotErrors(errors, instance, nodes);
	pushObstacleSlotErrors(errors, instance, nodes);
	pushEntityIdErrors(errors, instance);
	pushWaveErrors(errors, instance);
	pushWhitelistErrors(errors, instance);
	return errors;
}

type NodeIndex = {
	readonly teamOf: Map<number, number>;
	readonly positions: Set<string>;
	readonly outDegree: Map<number, number>;
};


function collectNodes(errors: JsonSchemaError[], instance: JsonObject): NodeIndex {
	const teamOf = new Map<number, number>();
	const positions = new Set<string>();
	const outDegree = new Map<number, number>();
	let previous = 0;
	for (const [index, item] of arrayAt(instance, "waypoints").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const nodeId = integerOrUndefined(item.node_id);
		const teamId = integerOrUndefined(item.team_id);
		if (nodeId === undefined || teamId === undefined) {
			continue;
		}
		if (nodeId <= previous) {
			errors.push({
				path: `$.waypoints/${index}/node_id`,
				message: "waypoints must be strictly ascending by node_id",
			});
		}
		previous = nodeId;
		teamOf.set(nodeId, teamId);
		const key = positionKey(item);
		if (key !== undefined) {
			if (positions.has(key)) {
				errors.push({ path: `$.waypoints/${index}`, message: "duplicate waypoint position" });
			}
			positions.add(key);
		}
	}
	for (const item of arrayAt(instance, "edges")) {
		if (!isObject(item)) {
			continue;
		}
		const fromId = integerOrUndefined(item.from_id);
		if (fromId !== undefined) {
			outDegree.set(fromId, (outDegree.get(fromId) ?? 0) + 1);
		}
	}
	return { teamOf, positions, outDegree };
}

function pushEdgeErrors(errors: JsonSchemaError[], instance: JsonObject, nodes: NodeIndex): void {
	let previousFrom = 0;
	let previousTo = 0;
	for (const [index, item] of arrayAt(instance, "edges").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const fromId = integerOrUndefined(item.from_id);
		const toId = integerOrUndefined(item.to_id);
		if (fromId === undefined || toId === undefined) {
			continue;
		}
		if (fromId === toId) {
			errors.push({ path: `$.edges/${index}`, message: "edge must not be a self loop" });
		}
		const fromTeam = nodes.teamOf.get(fromId);
		const toTeam = nodes.teamOf.get(toId);
		if (fromTeam === undefined || toTeam === undefined) {
			errors.push({ path: `$.edges/${index}`, message: "edge endpoint is not a declared waypoint" });
		} else if (fromTeam !== toTeam) {
			errors.push({ path: `$.edges/${index}`, message: "edge must stay inside one team lane" });
		}
		if (fromId < previousFrom || (fromId === previousFrom && toId <= previousTo)) {
			errors.push({
				path: `$.edges/${index}`,
				message: "edges must be strictly ascending by (from_id, to_id)",
			});
		}
		previousFrom = fromId;
		previousTo = toId;
	}
}

function pushCoreErrors(errors: JsonSchemaError[], instance: JsonObject, nodes: NodeIndex): void {
	const seenTeams = new Set<number>();
	let health: number | undefined;
	for (const [index, item] of arrayAt(instance, "cores").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const teamId = integerOrUndefined(item.team_id);
		const nodeId = integerOrUndefined(item.node_id);
		const maxHealth = integerOrUndefined(item.max_health);
		if (teamId !== undefined) {
			if (seenTeams.has(teamId)) {
				errors.push({ path: `$.cores/${index}/team_id`, message: "one core per team" });
			}
			seenTeams.add(teamId);
		}
		if (teamId !== undefined && nodeId !== undefined && nodes.teamOf.get(nodeId) !== teamId) {
			errors.push({ path: `$.cores/${index}/node_id`, message: "core node is not on this team's lane" });
		}
		if (maxHealth === undefined) {
			continue;
		}
		if (health === undefined) {
			health = maxHealth;
		} else if (health !== maxHealth) {
			errors.push({ path: `$.cores/${index}/max_health`, message: "both cores need the same max_health" });
		}
	}
}

function pushSpawnErrors(errors: JsonSchemaError[], instance: JsonObject, nodes: NodeIndex): void {
	const coreNodes = new Set<number>();
	for (const item of arrayAt(instance, "cores")) {
		const nodeId = isObject(item) ? integerOrUndefined(item.node_id) : undefined;
		if (nodeId !== undefined) {
			coreNodes.add(nodeId);
		}
	}
	const seenNodes = new Set<number>();
	for (const [index, item] of arrayAt(instance, "spawns").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const teamId = integerOrUndefined(item.team_id);
		const nodeId = integerOrUndefined(item.node_id);
		if (nodeId === undefined) {
			continue;
		}
		if (coreNodes.has(nodeId)) {
			errors.push({ path: `$.spawns/${index}/node_id`, message: "spawn must not sit on a core node" });
		}
		if (seenNodes.has(nodeId)) {
			errors.push({ path: `$.spawns/${index}/node_id`, message: "duplicate spawn node" });
		}
		seenNodes.add(nodeId);
		if (teamId !== undefined && nodes.teamOf.get(nodeId) !== teamId) {
			errors.push({ path: `$.spawns/${index}/node_id`, message: "spawn node is not on this team's lane" });
		}
	}
	pushBalanceErrors(errors, instance, "spawns");
}

function pushBuildSlotErrors(errors: JsonSchemaError[], instance: JsonObject, nodes: NodeIndex): void {
	const seen = new Set<string>();
	for (const [index, item] of arrayAt(instance, "build_slots").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const key = positionKey(item);
		if (key === undefined) {
			continue;
		}
		if (nodes.positions.has(key)) {
			errors.push({ path: `$.build_slots/${index}`, message: "build slot sits on a lane cell" });
		}
		if (seen.has(key)) {
			errors.push({ path: `$.build_slots/${index}`, message: "duplicate build slot position" });
		}
		seen.add(key);
	}
	pushBalanceErrors(errors, instance, "build_slots");
}

function pushObstacleSlotErrors(
	errors: JsonSchemaError[],
	instance: JsonObject,
	nodes: NodeIndex,
): void {
	const reserved = new Set<number>();
	for (const bag of ["cores", "spawns"]) {
		for (const item of arrayAt(instance, bag)) {
			const nodeId = isObject(item) ? integerOrUndefined(item.node_id) : undefined;
			if (nodeId !== undefined) {
				reserved.add(nodeId);
			}
		}
	}
	const seen = new Set<number>();
	for (const [index, item] of arrayAt(instance, "obstacle_slots").entries()) {
		if (!isObject(item)) {
			continue;
		}
		const teamId = integerOrUndefined(item.team_id);
		const nodeId = integerOrUndefined(item.node_id);
		if (nodeId === undefined) {
			continue;
		}
		if (reserved.has(nodeId)) {
			errors.push({
				path: `$.obstacle_slots/${index}/node_id`,
				message: "obstacle slot must not sit on a core or spawn node",
			});
		}
		if (seen.has(nodeId)) {
			errors.push({ path: `$.obstacle_slots/${index}/node_id`, message: "duplicate obstacle slot node" });
		}
		seen.add(nodeId);
		if (teamId !== undefined && nodes.teamOf.get(nodeId) !== teamId) {
			errors.push({
				path: `$.obstacle_slots/${index}/node_id`,
				message: "obstacle slot node is not on this team's lane",
			});
		}
		// 分流门掐掉本节点编号最小的那条出边；只有一条出边时掐掉就是封路。
		const whitelist = Array.isArray(item.whitelist) ? item.whitelist : [];
		if (whitelist.includes(OBSTACLE_DIVERTER) && (nodes.outDegree.get(nodeId) ?? 0) < 2) {
			errors.push({
				path: `$.obstacle_slots/${index}/whitelist`,
				message: "diverter needs a node with at least two outgoing edges",
			});
		}
	}
	pushBalanceErrors(errors, instance, "obstacle_slots");
}

/** 两侧都要有、且数量相等（CD-22 §2 对称阵容预算一致）。 */
function pushBalanceErrors(errors: JsonSchemaError[], instance: JsonObject, bag: string): void {
	const counts = new Map<number, number>();
	for (const item of arrayAt(instance, bag)) {
		const teamId = isObject(item) ? integerOrUndefined(item.team_id) : undefined;
		if (teamId !== undefined) {
			counts.set(teamId, (counts.get(teamId) ?? 0) + 1);
		}
	}
	const first = counts.get(1) ?? 0;
	const second = counts.get(2) ?? 0;
	if (first < 1 || second < 1 || first !== second) {
		errors.push({ path: `$.${bag}`, message: "both teams need the same non-zero count" });
	}
}

function pushEntityIdErrors(errors: JsonSchemaError[], instance: JsonObject): void {
	const seen = new Set<number>();
	for (const bag of ["cores", "spawns", "build_slots", "obstacle_slots"]) {
		let previous = 0;
		for (const [index, item] of arrayAt(instance, bag).entries()) {
			const entityId = isObject(item) ? integerOrUndefined(item.entity_id) : undefined;
			if (entityId === undefined) {
				continue;
			}
			if (seen.has(entityId)) {
				errors.push({ path: `$.${bag}/${index}/entity_id`, message: "duplicate entity_id" });
			}
			seen.add(entityId);
			if (bag !== "cores" && entityId <= previous) {
				errors.push({
					path: `$.${bag}/${index}/entity_id`,
					message: `${bag} must be strictly ascending by entity_id`,
				});
			}
			previous = entityId;
		}
	}
}

function pushWaveErrors(errors: JsonSchemaError[], instance: JsonObject): void {
	let expected = 1;
	for (const [index, item] of arrayAt(instance, "waves").entries()) {
		const waveIndex = isObject(item) ? integerOrUndefined(item.index) : undefined;
		if (waveIndex !== undefined && waveIndex !== expected) {
			errors.push({ path: `$.waves/${index}/index`, message: "wave indices must run 1..n" });
		}
		expected += 1;
	}
}

/** 白名单必须严格升序：同一份内容只有一种字节形状，哈希才稳定。 */
function pushWhitelistErrors(errors: JsonSchemaError[], instance: JsonObject): void {
	for (const bag of ["build_slots", "obstacle_slots"]) {
		for (const [index, item] of arrayAt(instance, bag).entries()) {
			if (!isObject(item) || !Array.isArray(item.whitelist)) {
				continue;
			}
			let previous = 0;
			for (const entry of item.whitelist) {
				const prototypeId = integerOrUndefined(entry);
				if (prototypeId === undefined) {
					continue;
				}
				if (prototypeId <= previous) {
					errors.push({
						path: `$.${bag}/${index}/whitelist`,
						message: "whitelist must be strictly ascending",
					});
					break;
				}
				previous = prototypeId;
			}
		}
	}
}

function positionKey(item: JsonObject): string | undefined {
	const x = integerOrUndefined(item.x);
	const y = integerOrUndefined(item.y);
	const z = integerOrUndefined(item.z);
	if (x === undefined || y === undefined || z === undefined) {
		return undefined;
	}
	return `${x}|${y}|${z}`;
}

function arrayAt(instance: JsonObject, key: string): readonly unknown[] {
	const value = instance[key];
	return Array.isArray(value) ? value : [];
}

function integerOrUndefined(value: unknown): number | undefined {
	return typeof value === "number" && Number.isInteger(value) ? value : undefined;
}

function isObject(value: unknown): value is JsonObject {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
