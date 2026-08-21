extends RefCounted

## `_physics_process` is not the `_process` token the scanner looks for.
func _physics_process_budget() -> int:
	return 1
