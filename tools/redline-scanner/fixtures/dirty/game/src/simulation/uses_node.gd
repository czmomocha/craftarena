extends Node


func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	tree.quit()
