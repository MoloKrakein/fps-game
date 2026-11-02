shader_type spatial;
// Bullet tracer: a glowing streak from the projectile (head) back along its path (tail).
// One camera-facing quad per tracer, driven every frame by projectile_tracer.gd through instance
// uniforms. Additive and HDR, so Glow / bloom makes it shine.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec3 tracer_axis = vec3(0.0);     // world vector from the head to the tail
instance uniform float tracer_alpha = 0.0;         // 0..1 (start fade, end fade)
instance uniform float tracer_width = 0.03;        // metres
instance uniform vec4 tracer_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
instance uniform float tracer_intensity = 8.0;
instance uniform float tracer_seed = 0.0;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float tail_power = 1.6;                    // higher = shorter visible tail
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.15;
uniform float min_pixel_width = 1.5;               // never thinner than this on screen, so it stays visible far away

varying float along;   // 0 at the head, 1 at the tail

void vertex() {
	vec3 head = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - head;
	float dist = length(to_cam);

	vec3 side = cross(tracer_axis, to_cam);
	float sl = length(side);
	side = sl > 0.00001 ? side / sl : vec3(1.0, 0.0, 0.0);

	// width in metres that equals min_pixel_width pixels at this distance
	float pixel_world = dist * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(tracer_width, pixel_world * min_pixel_width);

	float t = VERTEX.y + 0.5;           // 0..1 along the streak
	along = t;
	vec3 world_pos = head + tracer_axis * t + side * VERTEX.x * w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);       // 1 in the middle, 0 at the edges
	float glow = pow(across, 1.5);
	float core = pow(across, 6.0);

	float tail = pow(1.0 - along, tail_power);
	float head = 0.5 + 0.5 * smoothstep(0.0, 0.03, along);   // soft, bright tip
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * 60.0 + tracer_seed + along * 20.0));

	vec3 col = tracer_color.rgb * glow + core_color.rgb * core * 1.5;
	ALBEDO = col * tracer_intensity * tail * head * flicker * tracer_alpha;
}
