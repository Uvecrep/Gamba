shader_type canvas_item;
render_mode unshaded;

uniform bool glow_enabled = true;
uniform float glow_radius = 2.2;
uniform float glow_strength = 0.18;
uniform float glow_bias = 0.0;
uniform float pulse_amount = 0.03;
uniform float pulse_speed = 1.0;
uniform float flicker_amount = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec4 final_color = base;

	if (glow_enabled) {
		vec2 glow_offset = TEXTURE_PIXEL_SIZE * glow_radius;
		vec3 glow_rgb_sum = vec3(0.0);
		float glow_alpha_sum = 0.0;
		float glow_alpha_max = 0.0;

	vec4 sample_col = texture(TEXTURE, UV + vec2(glow_offset.x, 0.0));
	float sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-glow_offset.x, 0.0));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(0.0, glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(0.0, -glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(glow_offset.x, glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(glow_offset.x, -glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-glow_offset.x, glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-glow_offset.x, -glow_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	vec2 wide_offset = glow_offset * 1.6;
	sample_col = texture(TEXTURE, UV + vec2(wide_offset.x, 0.0));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-wide_offset.x, 0.0));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(0.0, wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(0.0, -wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(wide_offset.x, wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(wide_offset.x, -wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-wide_offset.x, wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

	sample_col = texture(TEXTURE, UV + vec2(-wide_offset.x, -wide_offset.y));
	sample_alpha = sample_col.a;
	if (sample_alpha > 0.001) {
		glow_rgb_sum += sample_col.rgb * sample_alpha;
		glow_alpha_sum += sample_alpha;
		glow_alpha_max = max(glow_alpha_max, sample_alpha);
	}

		if (glow_alpha_sum > 0.001) {
			vec3 glow_rgb = glow_rgb_sum / glow_alpha_sum;
			float pulse = 1.0 + pulse_amount * sin(TIME * max(pulse_speed, 0.01));
			float flicker_wave = (
				sin(TIME * 17.0 + 0.35) * 0.5 +
				sin(TIME * 31.0 + 1.1) * 0.35 +
				sin(TIME * 53.0 + 2.4) * 0.15
			);
			float flicker = 1.0 + (flicker_wave * flicker_amount);
			float glow_intensity = max((glow_strength + glow_bias) * pulse * flicker, 0.0);

			float outside_alpha = (1.0 - base.a) * glow_alpha_max;
			vec3 outside_glow = glow_rgb * outside_alpha * glow_intensity * 0.45;
			vec3 inside_glow = glow_rgb * base.a * glow_intensity * 0.12;

			final_color = vec4(base.rgb + outside_glow + inside_glow, max(base.a, outside_alpha * glow_intensity));
		}
	}

	COLOR = final_color;
}
