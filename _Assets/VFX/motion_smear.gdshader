shader_type spatial;
// Subtle motion-blur "smear" drawn as a material_overlay on top of an object's normal material.
// The trailing side of the mesh is stretched backwards along its velocity and drawn as a faint ghost.
// Velocity is pushed in every frame by motion_smear.gd. Below speed_range.x nothing is visible.
render_mode blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec3 blur_velocity = vec3(0.0);                // world space, m/s
instance uniform float blur_length = 0.03;                      // shutter time in seconds
instance uniform vec2 speed_range = vec2(1.0, 8.0);             // no blur .. full blur (m/s)
instance uniform float opacity = 0.3;
instance uniform vec4 tint : source_color = vec4(0.8, 0.6, 0.25, 1.0);

varying float tail;      // 1 on the side that trails the motion
varying float strength;  // 0..1 from speed

void vertex() {
	vec3 v = blur_velocity;
	float spd = length(v);
	vec3 vdir = v / max(spd, 0.0001);

	vec3 n_world = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float facing = -dot(n_world, vdir);
	tail = smoothstep(-0.2, 0.4, facing);
	strength = smoothstep(speed_range.x, speed_range.y, spd);

	p_world -= v * blur_length * tail;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p_world, 1.0);
}

void fragment() {
	ALBEDO = tint.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.45;
	ALPHA = opacity * strength * tail * tail;
}
