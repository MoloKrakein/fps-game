shader_type spatial;
// Very light, transparent smoke / gas haze (Modern Warfare 2019 style barrel smoke).
// One shader for both the barrel haze and the ejection-port smoke; every look value is an
// instance uniform that MuzzleFlash.gd sets, so the two emitters can share this material.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 smoke_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
instance uniform float smoke_opacity = 0.12;    // peak alpha. 0.08-0.15 = barrel haze, ~0.2 = ejection smoke
instance uniform float smoke_thickness = 1.0;   // <1 wispier, >1 more solid core
instance uniform float smoke_stretch = 1.8;     // vertical stretch of the haze on screen
instance uniform float size_mult = 1.0;
instance uniform float density = 1.0;           // raised a little by barrel heat

uniform float start_size : hint_range(0.1, 1.0) = 0.5;   // size at birth vs final size
uniform float noise_scale = 2.0;
uniform float rise_speed = 0.35;
uniform float fade_power = 1.4;

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
	return v / 0.875;   // 0..1
}

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	seed = INSTANCE_CUSTOM.x;
	pcolor = COLOR;

	float t = 1.0 - (1.0 - age) * (1.0 - age);          // fast expansion, then slows
	VERTEX.xy *= size_mult * mix(start_size, 1.0, t);
	VERTEX.y *= smoke_stretch;

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q) * 2.0;

	// soft, slowly rising noise; only a gentle modulation so it stays haze-like, not blobby
	float c = cos(seed);
	float s = sin(seed);
	vec2 rq = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	vec2 p = rq * noise_scale + vec2(seed * 13.37, seed * 7.91 - age * rise_speed);
	float n = fbm(p);

	float body = pow(1.0 - smoothstep(0.0, 1.0, r), 1.5);   // soft round falloff, 0 at the quad edge
	float shape = clamp(body * mix(0.55, 1.25, n) * smoke_thickness, 0.0, 1.0);

	float life = smoothstep(0.0, 0.12, age) * pow(1.0 - age, fade_power);

	ALBEDO = smoke_color.rgb * pcolor.rgb;
	ALPHA = clamp(shape * life * density * pcolor.a * smoke_color.a * smoke_opacity, 0.0, 1.0);
}
