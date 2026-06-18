shader_type canvas_item;

uniform float zoom : hint_range(0.1, 1.0) = 0.7;
uniform vec2 pan_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = pan_offset + UV * zoom;
	COLOR.rgb = texture(TEXTURE, uv).rgb;
}
