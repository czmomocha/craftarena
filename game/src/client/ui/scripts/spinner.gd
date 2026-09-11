extends Control
## Minimal arc spinner, drawn procedurally so it needs no texture asset and
## stays crisp at any size.  Used by the S2 "matching in progress" row.
##
## Stops redrawing while hidden, so a parked queue panel costs nothing.

@export var line_width := 4.0
@export var color := Color(0.62, 0.64, 0.72)
## Revolutions per second.
@export var speed := 2.2
## Fraction of the circle that is drawn (0-1).
@export var arc_ratio := 0.3
## Number of segments used to approximate the arc.
@export var segments := 32

var _angle := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + delta * speed * TAU, TAU)
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - line_width * 0.5
	if r <= 0.0:
		return
	draw_arc(centre, r, _angle, _angle + TAU * arc_ratio, segments, color, line_width, true)
