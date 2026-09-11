@tool
extends Control
## Keeps the `rect_size` uniform of a rounded-rect shader in sync with this
## node's size, so corners stay circular and gradients stay normalised when the
## control is resized.
##
## Works for any Control, and for both shaders that need it:
##   * shaders/rounded_gradient.gdshader  (gradient fill, e.g. the TRAPRUSH card)
##   * shaders/rounded_texture.gdshader   (rounded corners on a TextureRect)

func _ready() -> void:
	if material is ShaderMaterial:
		resized.connect(_sync_rect_size)
		_sync_rect_size()


func _sync_rect_size() -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", size)
