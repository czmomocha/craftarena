/**
 * L0 JSON Schema filenames under `backend/contracts/schemas/`.
 * Component Schema v1 and AuthoringDocument are separate catalogs; OpenAPI is still not in this list.
 */
export const L0_CONTRACT_VERSION = 1;
export const COMPONENT_SCHEMA_VERSION = 1;

export const L0_SCHEMA_FILES = [
	"canonical_payload.schema.json",
	"shared_command.schema.json",
	"shared_domain_event.schema.json",
] as const;

export const COMPONENT_SCHEMA_FILES = ["component_record.schema.json"] as const;
export const AUTHORING_SCHEMA_FILES = ["authoring_document.schema.json"] as const;
export const AUTHORING_DOCUMENT_SCHEMA_VERSION = 1;
export const SIMULATION_BUNDLE_SCHEMA_FILES = ["simulation_bundle.schema.json"] as const;
export const SIMULATION_BUNDLE_SCHEMA_VERSION = 1;

export type L0SchemaFile = (typeof L0_SCHEMA_FILES)[number];
export type ComponentSchemaFile = (typeof COMPONENT_SCHEMA_FILES)[number];
export type AuthoringSchemaFile = (typeof AUTHORING_SCHEMA_FILES)[number];
export type SimulationBundleSchemaFile = (typeof SIMULATION_BUNDLE_SCHEMA_FILES)[number];
