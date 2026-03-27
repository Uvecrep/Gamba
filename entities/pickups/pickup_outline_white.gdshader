shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_size = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_size;

	float outline_alpha = 0.0;
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, -offset.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(offset.x, offset.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-offset.x, -offset.y)).a);

	bool is_outline_pixel = (base.a <= 0.001) && (outline_alpha > 0.001);
	if (is_outline_pixel) {
		COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
	} else {
		COLOR = base;
	}
}
