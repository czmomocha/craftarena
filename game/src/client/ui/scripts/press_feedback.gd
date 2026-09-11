extends Button
## Smart-Animate-style interaction feedback for buttons.
##
## The theme already swaps the StyleBox per state (normal / hover / pressed).
## This script adds the two things a StyleBox cannot express, per spec 0.4:
##   * pressed shrinks the control to 0.99
##   * hover lifts the overall brightness
## Both animate over 120 ms with an ease-out curve, matching the prototype spec.
##
## Attach it directly to any Button (including the channel cards, which are
## flat Buttons wrapping a gradient).  Disabled buttons never animate.

## Scale applied while the button is held down.
@export var press_scale := 0.99
## Brightness multiplier while hovered. 1.0 disables the lift.
@export var hover_brightness := 1.0
## Extra brightness multiplier while held down.
@export var press_brightness := 1.0
@export var duration := 0.12

var _tween: Tween
var _hovered := false
var _down := false


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	if disabled:
		modulate = Color.WHITE


func _centre_pivot() -> void:
	# Scaling around the centre makes the 0.99 press read as a shrink rather
	# than a shift towards the top-left corner.
	pivot_offset = size * 0.5


func _target_scale() -> float:
	return press_scale if (_down and not disabled) else 1.0


func _target_brightness() -> float:
	if disabled:
		return 1.0
	var b := 1.0
	if _hovered:
		b *= hover_brightness
	if _down:
		b *= press_brightness
	return b


func _animate() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var b := _target_brightness()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * _target_scale(), duration)
	_tween.tween_property(self, "modulate", Color(b, b, b, 1.0), duration)


func _on_enter() -> void:
	_hovered = true
	_animate()


func _on_exit() -> void:
	_hovered = false
	_down = false
	_animate()


func _on_down() -> void:
	_down = true
	_animate()


func _on_up() -> void:
	_down = false
	_animate()
