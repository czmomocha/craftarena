extends KinematicBody

func _ready() -> void:
	yield(get_tree(), "idle_frame")
