class_name MatchHazardWarn
extends RefCounted

## Presentation-only hazard telegraph (F-line FB / D-F7).
## HAZARD_WARN_TICKS lives on PlaceholderSpec; this file never writes
## SimulationWorld solidity. Authority still uses TraprushHazardCycle.

const WARN_PREFIX: String = "warn_"
const HazardCycleGd := preload("res://src/games/traprush/hazard_cycle.gd")


static func is_warning(tick_index: int, cooldown_ticks: int, warn_ticks: int) -> bool:
	if cooldown_ticks < 1 or warn_ticks < 1:
		return false
	if HazardCycleGd.is_solid(tick_index, cooldown_ticks):
		return false
	var phase: int = tick_index / cooldown_ticks
	if (phase % 2) == 0:
		return false
	var next_solid: int = (phase + 1) * cooldown_ticks
	var remaining: int = next_solid - tick_index
	return remaining > 0 and remaining <= warn_ticks


static func warn_name(entity_id: int) -> String:
	return "%s%d" % [WARN_PREFIX, entity_id]


static func pulse_albedo(tick_index: int) -> Color:
	var color: Color = PlaceholderSpec.HAZARD_ALBEDO
	if (tick_index % 4) < 2:
		color.a = 0.95
	else:
		color.a = 0.35
	return color
