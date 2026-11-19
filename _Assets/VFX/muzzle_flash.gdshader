shader_type spatial;
// Simple, toned-down muzzle flash: a soft glow with a few short petals, gone in a few frames.
// Draw it on a one-shot GPUParticles3D quad (amount 1, lifetime ~0.05 s).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 flash_color : source_color = vec4(1.0, 0.72, 0.32, 1.0);
instance uniform float intensity = 3.0;     // HDR. Around 2-4 is subtle, 6+ is loud
instance uniform float spikes = 5.0;        // number of petals

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float petal_sharpness = 5.0;
uniform float petal_length = 0.8;           // 0..1, how far the petals reach
uniform float core_size = 0.22;

varying float age;
varying float seed;
varying vec4 pcolor;

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	seed = INSTANCE_CUSTOM.x;
	pcolor = COLOR;

	VERTEX.xy *= mix(0.75, 1.1, age);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	float c = cos(seed);
	float s = sin(seed);
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);

	float r = length(uv);
	float ang = atan(uv.y, uv.x);

	float lobe = pow(abs(cos(ang * spikes * 0.5)), petal_sharpness);
	float reach = mix(0.3, petal_length, lobe);
	float petals = pow(1.0 - smoothstep(0.0, reach, r), 1.5);

	float core = exp(-pow(r / core_size, 2.0));
	float glow = exp(-r * r * 4.0) * 0.4;
	float edge = 1.0 - smoothstep(0.7, 1.0, r);

	float fade = (1.0 - age) * (1.0 - age);
	vec3 col = flash_color.rgb * (petals + glow) + core_color.rgb * core;
	ALBEDO = col * edge * intensity * fade * pcolor.rgb;
}
