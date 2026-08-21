extends RefCounted

var position: int = 65536


func step(delta_ticks: int) -> int:
	return position + delta_ticks
