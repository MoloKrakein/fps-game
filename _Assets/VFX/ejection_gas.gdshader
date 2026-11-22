shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 gas_color : source_color = vec4(0.8, 0.82, 0.84, 1.0);
instance uniform float gas_opacity : hint_range(0.0, 1.0) = 0.28;
instance uniform float gas_size = 1.0;
instance uniform float vent_direction = 1.0;

uniform float turbulence = 4.0;
uniform float softness = 0.18;
uniform float fade_power = 1.25;

varying float particle_age;
varying float particle_seed;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.7);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	particle_age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	particle_seed = INSTANCE_CUSTOM.x;
	float growth = mix(0.22, 1.0, pow(particle_age, 0.62));
	VERTEX.xy *= gas_size * growth;

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	q.x *= vent_direction;

	float age = clamp(particle_age, 0.0, 1.0);
	float seed = particle_seed + FRAGCOORD.x * 0.0001 + FRAGCOORD.y * 0.0001;
	float spread = mix(0.18, 1.0, pow(age, 0.72));
	vec2 origin = vec2(mix(-0.72, -0.18, age), mix(0.08, -0.04, age));

	vec2 p = q - origin;
	p.x /= 1.0 + age * 0.7;
	p.y /= 0.82 + age * 0.18;

	float radius = length(p);
	float warped = fbm(q * turbulence + vec2(seed * 9.0, age * 2.5));
	float body = 1.0 - smoothstep(spread - softness, spread + softness, radius + warped * 0.22);

	float source = 1.0 - smoothstep(-0.62, -0.12, q.x);
	source *= 1.0 - smoothstep(-0.45, 0.25, age);
	body = max(body, source * (1.0 - smoothstep(-0.78, -0.42, q.x)));

	float edge = 1.0 - smoothstep(0.78, 1.0, length(q));
	float fade_in = smoothstep(0.0, 0.06, age);
	float fade_out = pow(1.0 - age, fade_power);
	float alpha = body * edge * fade_in * fade_out * gas_opacity;

	ALBEDO = gas_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
