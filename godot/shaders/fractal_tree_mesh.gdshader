// CURRENTLY UNUSED SHADER
shader_type canvas_item;
render_mode blend_mix;

// These uniforms drive the “line” width effect
uniform float base_width : hint_range(1.0, 20.0) = 8.0;
uniform float edge_smooth : hint_range(0.0, 1.0) = 0.1;
uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	// Use UV.y to know how far from the center of the strip we are
	float dist = abs(UV.y - 0.5) * 2.0;  // remap to [0, 1]

	// Simple line profile: 1 in center, 0 at edges
	float alpha = 1.0 - smoothstep(0.5 - edge_smooth, 0.5, dist);
	COLOR = color;
	COLOR.a *= alpha;
}