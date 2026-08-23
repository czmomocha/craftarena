class_name AuthoringSurfaceNames
extends RefCounted

## CD-32 editor surfaces. Capabilities differ; AuthoringDocument does not.
## Android/iOS have no authoring surface in v1.

const INTERNAL_DEV: String = "internal_dev"
const DESKTOP_FULL: String = "desktop_full"
const WEB_LIGHT: String = "web_light"

const ALL: PackedStringArray = [
	INTERNAL_DEV,
	DESKTOP_FULL,
	WEB_LIGHT,
]


static func contains(surface: String) -> bool:
	return ALL.has(surface)


static func allows_edit_commands(surface: String) -> bool:
	return contains(surface)


static func allows_rule_templates(surface: String) -> bool:
	return contains(surface)


static func allows_freeform_rule_graph(surface: String) -> bool:
	return surface == INTERNAL_DEV or surface == DESKTOP_FULL


static func allows_advanced_debug(surface: String) -> bool:
	return surface == INTERNAL_DEV or surface == DESKTOP_FULL


static func allows_batch_generate(surface: String) -> bool:
	return surface == INTERNAL_DEV


static func allows_performance_analysis(surface: String) -> bool:
	return surface == INTERNAL_DEV


static func allows_validator_details(surface: String) -> bool:
	return surface == INTERNAL_DEV
