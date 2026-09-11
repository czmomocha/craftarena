shader_type canvas_item;

// Rounded corners for a TextureRect.
//
// Thumbnails in the design carry a 12-16 px radius; TextureRect has no corner
// radius property, so the alpha is shaped here instead of shipping pre-rounded
// bitmaps.
//
// `rect_size` must be kept in sync with the node size - see scripts/rounded_gradient.gd.

uniform float corner_radius : hint_range(0.0, 128.0) = 12.0;
uniform vec2 rect_size = vec2(376.0, 212.0);
uniform float edge_softness : hint_range(0.1, 4.0) = 1.0;

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = abs(UV * rect_size - half_size);

	vec2 inner = max(p - (half_size - vec2(corner_radius)), vec2(0.0));
	float dist = length(inner) - corner_radius;
	float a = 1.0 - smoothstep(-edge_softness, edge_softness, dist);

	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb, c.a * a);
}
