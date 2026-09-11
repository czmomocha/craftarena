shader_type canvas_item;
render_mode unshaded;

// Rounded-rect linear gradient.
//
// StyleBoxFlat can only fill a *solid* colour, so the one gradient in the
// Craft Arena design system (channel/traprush-a -> channel/traprush-b, 115 deg)
// cannot be expressed as a theme stylebox.  This shader fills that gap and
// keeps the card's 16 px corner radius.
//
// `rect_size` must be kept in sync with the node size - see scripts/rounded_gradient.gd.

uniform vec4 color_from : source_color = vec4(0.85098, 0.211765, 0.419608, 1.0);
uniform vec4 color_to : source_color = vec4(0.949019, 0.474510, 0.184314, 1.0);
uniform float angle_deg : hint_range(0.0, 360.0) = 115.0;
uniform float corner_radius : hint_range(0.0, 256.0) = 16.0;
uniform vec2 rect_size = vec2(1296.0, 300.0);
uniform float edge_softness : hint_range(0.1, 4.0) = 1.0;

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = abs(UV * rect_size - half_size);

	// Signed distance to a rounded rectangle.
	vec2 inner = max(p - (half_size - vec2(corner_radius)), vec2(0.0));
	float dist = length(inner) - corner_radius;
	float alpha = 1.0 - smoothstep(-edge_softness, edge_softness, dist);

	// Linear gradient along angle_deg, normalised so it spans the whole rect.
	// CSS-style angle: 0 deg points up and the angle increases clockwise, so
	// 115 deg runs left-to-right with a slight downward tilt (magenta -> orange).
	float rad = radians(angle_deg);
	vec2 dir = vec2(sin(rad), -cos(rad));
	vec2 centred = (UV - vec2(0.5)) * rect_size;
	float extent = abs(dir.x) * rect_size.x + abs(dir.y) * rect_size.y;
	float t = clamp(dot(centred, dir) / extent + 0.5, 0.0, 1.0);

	vec4 col = mix(color_from, color_to, t);
	COLOR = vec4(col.rgb, col.a * alpha);
}
