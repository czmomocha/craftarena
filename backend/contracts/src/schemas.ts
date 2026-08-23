/**
 * L0 JSON Schema filenames under `backend/contracts/schemas/`.
 * Component Schema v1 is a separate catalog; OpenAPI is still not in this list.
 */
export const L0_CONTRACT_VERSION = 1;
export const COMPONENT_SCHEMA_VERSION = 1;

export const L0_SCHEMA_FILES = [
	"canonical_payload.schema.json",
	"shared_command.schema.json",
	"shared_domain_event.schema.json",
] as const;

export const COMPONENT_SCHEMA_FILES = ["component_record.schema.json"] as const;

export type L0SchemaFile = (typeof L0_SCHEMA_FILES)[number];
export type ComponentSchemaFile = (typeof COMPONENT_SCHEMA_FILES)[number];
