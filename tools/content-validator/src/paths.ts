import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

export const REPO_ROOT = join(here, "../../..");
export const CONTRACTS_SCHEMA_DIR = join(REPO_ROOT, "backend/contracts/schemas");
export const SHARED_SRC_DIR = join(REPO_ROOT, "game/src/shared");
export const FIXTURES_DIR = join(here, "../fixtures");

export const PLAYER_INTENT_NAMES_PATH = join(SHARED_SRC_DIR, "commands/player_intent_names.gd");
export const SHARED_COMMAND_PATH = join(SHARED_SRC_DIR, "commands/shared_command.gd");
export const SHARED_DOMAIN_EVENT_PATH = join(SHARED_SRC_DIR, "events/shared_domain_event.gd");
export const SHARED_IDS_PATH = join(SHARED_SRC_DIR, "ids/shared_ids.gd");
export const CANONICAL_PAYLOAD_PATH = join(SHARED_SRC_DIR, "protocol/canonical_payload.gd");
export const COMPONENT_NAMES_PATH = join(SHARED_SRC_DIR, "schema/component_names.gd");
export const COLLISION_SHAPE_KINDS_PATH = join(SHARED_SRC_DIR, "schema/collision_shape_kinds.gd");
export const TOWER_TARGET_PRIORITIES_PATH = join(SHARED_SRC_DIR, "schema/tower_target_priorities.gd");
export const COMPONENT_RECORD_PATH = join(SHARED_SRC_DIR, "schema/component_record.gd");

export const COMMAND_SCHEMA_PATH = join(CONTRACTS_SCHEMA_DIR, "shared_command.schema.json");
export const EVENT_SCHEMA_PATH = join(CONTRACTS_SCHEMA_DIR, "shared_domain_event.schema.json");
export const CANONICAL_SCHEMA_PATH = join(CONTRACTS_SCHEMA_DIR, "canonical_payload.schema.json");
export const COMPONENT_SCHEMA_PATH = join(CONTRACTS_SCHEMA_DIR, "component_record.schema.json");
