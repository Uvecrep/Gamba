shader_type canvas_item;

uniform float fade_top : hint_range(0.0, 1.0) = 0.1;
uniform float fade_bottom : hint_range(0.0, 1.0) = 0.1;
uniform float speed = 0.5;
uniform bool animate = true;

void fragment() {
    vec2 uv = UV;

    // Animate UV if needed
    if (animate) {
        uv.y -= TIME * speed;
        uv.y = fract(uv.y); // wrap vertically
    }

    // Sample the texture
    vec4 tex_color = texture(TEXTURE, uv);

    // Compute vertical fade
    float fade = 1.0;
    if (uv.y < fade_top) {
        fade *= uv.y / fade_top;
    } else if (uv.y > 1.0 - fade_bottom) {
        fade *= (1.0 - uv.y) / fade_bottom;
    }

    COLOR = vec4(tex_color.rgb, tex_color.a * fade);
}