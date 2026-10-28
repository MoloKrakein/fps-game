shader_type spatial;
// Subtle muzzle gas / heat haze (Call of Duty style).
// Mostly refracts the scene behind it (air distortion) with only a faint haze tint.
// Uses the same instance uniforms as smoke.gdshader, so MuzzleFlash.gd drives it unchanged.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 smoke_color : source_color = vec4(0.85, 0.87, 0.9, 1.0);
instance uniform float density = 1.0;     // raised by barrel heat
instance uniform float size_mult = 1.0;

uniform float distortion = 0.015;         // heat haze strength (screen UV units)
uniform float tint_amount : hint_range(0.0, 1.0) = 0.18;  // how visible the gas itself is
uniform float noise_scale = 3.0;
uniform float flow_speed = 1.2;
uniform float grow = 2.5;                 // final size vs start size
uniform float softness : hint_range(0.01, 1.0) = 0.35;
uniform float fade_power = 1.5;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

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
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	pcolor = COLOR;

	float t = 1.0 - (1.0 - age) * (1.0 - age);
	VERTEX.xy *= size_mult * mix(1.0, grow, t);

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
	vec2 uv = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	float r = length(uv) * 2.0;

	// turbulent flow that keeps moving as the gas expands
	vec2 p = uv * noise_scale + vec2(seed * 13.37, seed * 7.91);
	p += vec2(age * flow_speed, -age * flow_speed * 0.7);
	float n = fbm(p);

	float shape = 1.0 - smoothstep(0.1, 1.0, r);
	float dens = n * shape * 1.8;

	float cut = age * 0.9;
	float mask = smoothstep(cut, cut + softness, dens);
	mask *= pow(1.0 - age, fade_power) * smoothstep(0.0, 0.04, age);
	mask *= density * pcolor.a;
	mask = clamp(mask, 0.0, 1.0);

	// refraction: push the background along the noise gradient
	vec2 e = vec2(0.02, 0.0);
	vec2 grad = vec2(fbm(p + e.xy) - fbm(p - e.xy), fbm(p + e.yx) - fbm(p - e.yx)) / 0.04;
	vec2 offset = grad * distortion * mask;
	vec3 scene = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;

	ALBEDO = mix(scene, smoke_color.rgb, tint_amount);
	ALPHA = mask;
}
