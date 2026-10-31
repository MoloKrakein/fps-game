shader_type spatial;
// Motion streak behind a flying casing: a soft quad stretched from the casing backwards along its
// velocity, always facing the camera. Driven per casing by BulletCasing through instance uniforms.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec3 streak_axis = vec3(0.0);  // world vector from the casing to the tail of the streak
instance uniform float streak_alpha = 0.0;
instance uniform float streak_width = 0.014;
instance uniform vec4 streak_color : source_color = vec4(0.95, 0.75, 0.35, 1.0);

varying float along;   // 0 at the casing, 1 at the tail

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - center;
	vec3 side = cross(streak_axis, to_cam);
	float sl = length(side);
	side = sl > 0.00001 ? side / sl : vec3(1.0, 0.0, 0.0);

	float t = VERTEX.y + 0.5;      // quad is -0.5..0.5, so t runs 0..1
	along = t;
	vec3 world_pos = center + streak_axis * t + side * VERTEX.x * streak_width;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float fade = pow(1.0 - along, 1.3);
	ALBEDO = streak_color.rgb;
	ALPHA = clamp(streak_alpha * pow(across, 0.8) * fade, 0.0, 1.0);
}
