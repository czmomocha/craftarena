extends KinematicBody

onready var stale_label: Label

func _ready() -> void:
	yield(get_tree(), "idle_frame")
