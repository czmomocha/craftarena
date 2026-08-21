/**
 * L0 JSON Schema filenames under `backend/contracts/schemas/`.
 * Component Schema v1 is not in this list; CD-42 §1 still has no wire schema.
 */
export const L0_CONTRACT_VERSION = 1;

export const L0_SCHEMA_FILES = [
	"canonical_payload.schema.json",
	"shared_command.schema.json",
	"shared_domain_event.schema.json",
] as const;

export type L0SchemaFile = (typeof L0_SCHEMA_FILES)[number];
