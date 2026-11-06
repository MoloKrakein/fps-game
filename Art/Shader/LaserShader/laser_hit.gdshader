shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled;

uniform vec4 dot_color : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 10.0) = 5.0;
uniform float softness : hint_range(0.5, 6.0) = 2.0;

void vertex() {
    // Billboard
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
    float d = distance(UV, vec2(0.5)) * 2.0;
    float glow = pow(clamp(1.0 - d, 0.0, 1.0), softness);
    float core = smoothstep(0.25, 0.0, d);   // hot white-ish center

    vec3 col = dot_color.rgb * glow + vec3(core);
    ALBEDO = col * intensity;
    ALPHA = glow;
}