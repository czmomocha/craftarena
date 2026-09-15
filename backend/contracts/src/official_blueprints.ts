/**
 * 一期官方 BASTION 蓝图标识。
 *
 * HTTP JSON 的官方蓝图只走这些 id，不接受 `res://` 路径。已签名 UGC 仍走互斥的
 * `content: { id, version }`（见 `match_body.ts` / CD-42 §3.5）。Godot 对局
 * 进程仍用 `res://content/official/bastion/{id}.json` 读 AuthoringDocument。
 *
 * 匹配 HTTP 走独立的 `blueprint` 字段，与 `course` / `content` 三者互斥。
 * 把 `blueprint_01` 塞进 `course` 必须继续失败。
 */

export const OFFICIAL_BASTION_BLUEPRINT_IDS = ["blueprint_01"] as const;

export type OfficialBastionBlueprintId = (typeof OFFICIAL_BASTION_BLUEPRINT_IDS)[number];

export const DEFAULT_OFFICIAL_BASTION_BLUEPRINT: OfficialBastionBlueprintId = "blueprint_01";

const OFFICIAL_BASTION_BLUEPRINT_DIR = "res://content/official/bastion";

export function isOfficialBastionBlueprintId(value: unknown): value is OfficialBastionBlueprintId {
	return (
		typeof value === "string" &&
		(OFFICIAL_BASTION_BLUEPRINT_IDS as readonly string[]).includes(value)
	);
}

export function officialBastionBlueprintPath(id: OfficialBastionBlueprintId): string {
	return `${OFFICIAL_BASTION_BLUEPRINT_DIR}/${id}.json`;
}

export function officialBastionBlueprintIdFromPath(path: string): OfficialBastionBlueprintId | undefined {
	for (const id of OFFICIAL_BASTION_BLUEPRINT_IDS) {
		if (path === officialBastionBlueprintPath(id)) {
			return id;
		}
	}
	return undefined;
}

export const officialBastionBlueprintIdSchema = {
	type: "string",
	enum: [...OFFICIAL_BASTION_BLUEPRINT_IDS],
} as const;
