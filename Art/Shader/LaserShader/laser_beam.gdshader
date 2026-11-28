shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_back;

uniform vec4 laser_color : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 10.0) = 3.0;
uniform float beam_gain : hint_range(0.0, 5.0) = 1.0;
uniform float edge_falloff : hint_range(0.5, 8.0) = 2.5;   // higher = thinner bright core
uniform float start_fade : hint_range(0.0, 0.5) = 0.05;    // fades beam near the muzzle
uniform float end_fade : hint_range(0.0, 0.25) = 0.03;
uniform float flicker_amount : hint_range(0.0, 0.3) = 0.04;
uniform float flicker_speed = 40.0;

void fragment() {
    // Bright core, soft edges (view-facing = center of the cylinder)
    float core = pow(clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_falloff);

    // Fade in from the emitter so it doesn't look pasted on
    float fade_in = 1.0;
    if (start_fade > 0.0) {
        fade_in = smoothstep(0.0, start_fade, UV.y);
    }

    // Soften the beam where it meets a surface instead of cutting off sharply.
    float fade_out = 1.0;
    if (end_fade > 0.0) {
        fade_out = 1.0 - smoothstep(1.0 - end_fade, 1.0, UV.y);
    }

    // Subtle flicker
    float flicker = 1.0 + sin(TIME * flicker_speed) * flicker_amount;

    ALBEDO = laser_color.rgb * intensity * beam_gain * flicker;
    ALPHA = core * fade_in * fade_out;
}