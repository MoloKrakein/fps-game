shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// Per-weapon values (set from MuzzleFlash.configure via set_instance_shader_parameter)
instance uniform vec4 flash_color : source_color = vec4(1.0, 0.62, 0.22, 1.0);
instance uniform float intensity = 8.0;   // >1 so Glow / bloom picks it up
instance uniform float spikes = 6.0;      // number of star points

// Shared look
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float spike_sharpness = 12.0;
uniform float spike_length = 0.95;
uniform float core_size = 0.09;
uniform float jitter = 0.35;              // random length variation per spike

varying float age;    // 0..1 over the particle lifetime
varying float seed;   // per-particle random (particle angle)
varying vec4 pcolor;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	pcolor = COLOR;

	VERTEX.xy *= mix(0.7, 1.15, age); // quick pop

	// camera-facing billboard that keeps the particle scale
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

	// star shape: N lobes, each with a random length
	float lobe = pow(max(cos(ang * spikes * 0.5), 0.0), max(spike_sharpness * 2.0, 10.0));
	float rnd = vnoise(vec2(ang * 2.0 + seed * 5.0, seed * 3.0));
	float reach = mix(0.035, spike_length, lobe) * mix(1.0 - jitter, 1.0, rnd);
	float star = pow(1.0 - smoothstep(reach * 0.35, reach, r), 2.5);

	float core = exp(-pow(r / min(core_size, 0.1), 2.0));
	float glow = exp(-r * r * 10.0) * 0.12;
	float edge = 1.0 - smoothstep(0.7, 1.0, r); // no visible quad edges

	float fade = (1.0 - age);
	fade *= fade;

	vec3 col = flash_color.rgb * (star + glow) + core_color.rgb * core * 0.8;
	ALBEDO = col * edge * intensity * fade * pcolor.rgb;
}
