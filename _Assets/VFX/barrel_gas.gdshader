shader_type spatial;
// Quick, subtle, white star-shaped gas burst that appears a split second after the shot
// and disperses almost immediately (no lingering smoke).
// Use on a one-shot GPUParticles3D, lifetime ~0.15 s, listed in MuzzleFlash.gas_particles.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 smoke_color : source_color = vec4(0.95, 0.96, 1.0, 1.0);
instance uniform float density = 1.0;
instance uniform float size_mult = 1.0;
instance uniform float petals = 6.0;
instance uniform float max_opacity : hint_range(0.0, 1.0) = 0.35;

uniform float petal_sharpness = 4.5;
uniform float petal_reach_min = 0.28;
uniform float noise_scale = 3.0;
uniform float flow_speed = 1.5;
uniform float start_size = 0.25;
uniform float softness : hint_range(0.01, 1.0) = 0.22;
uniform float fade_power = 1.6;
uniform vec4 warm_color : source_color = vec4(1.0, 0.8, 0.55, 1.0);
uniform float warm_amount : hint_range(0.0, 1.0) = 0.08;
uniform float warm_time : hint_range(0.01, 1.0) = 0.12;

varying float age;
varying float seed;
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	seed = INSTANCE_CUSTOM.x;
	pcolor = COLOR;

	float t = 1.0 - pow(1.0 - age, 3.0);
	VERTEX.xy *= size_mult * mix(start_size, 1.0, t);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 q = UV - 0.5;
	float c = cos(seed);
	float s = sin(seed);
	vec2 uv = vec2(c * q.x - s * q.y, s * q.x + c * q.y) * 2.0;
	float r = length(uv);
	float ang = atan(uv.y, uv.x);

	float lobe = pow(abs(cos(ang * petals * 0.5)), petal_sharpness);
	float nr = fbm(vec2(ang * 1.5 + seed * 7.0, seed * 3.0 + age * flow_speed));
	float reach = mix(petal_reach_min, 1.0, lobe) * mix(0.7, 1.0, nr);

	float d = pow(1.0 - smoothstep(0.0, reach, r), 1.3);
	float n = fbm(uv * noise_scale + vec2(seed * 9.1, seed * 4.7) + vec2(age * flow_speed, 0.0));
	float cut = age * 0.85;
	float mask = smoothstep(cut, cut + softness, d * (0.5 + n));

	float edge = 1.0 - smoothstep(0.75, 1.0, r);
	float fade = pow(1.0 - age, fade_power) * smoothstep(0.0, 0.05, age);
	float warm = warm_amount * (1.0 - smoothstep(0.0, warm_time, age));

	ALBEDO = mix(smoke_color.rgb, warm_color.rgb, warm) * pcolor.rgb;
	ALPHA = clamp(mask * edge * fade * density * pcolor.a * smoke_color.a * max_opacity, 0.0, 1.0);
}
