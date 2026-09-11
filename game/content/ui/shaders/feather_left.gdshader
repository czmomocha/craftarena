shader_type canvas_item;

// Fades the left edge of a sliced illustration to transparent.
//
// The TRAPRUSH art slice carries its own baked gradient (it was cut out of the
// mockup), which does not match the card's shader gradient.  Feathering the
// left edge lets it composite over the gradient without a visible seam.
// Not needed for illustrations that already ship with clean alpha.

uniform float feather : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.0, feather, UV.x);
	COLOR = vec4(c.rgb, c.a * a);
}
