shader_type spatial;
// Muzzle blast: the pale gas that leaves the barrel together with the bullet.
// A soft, noise-eroded puff that is brightest the instant the shot fires and disperses fast.
// Use on one-shot GPUParticles3D (about 5 particles, lifetime ~0.3 s, moving forward with strong damping).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 blast_color : source_color = vec4(0.92, 0.94, 1.0, 1.0);
instance uniform float blast_opacity = 0.14;   // peak alpha. 0.08-0.2 keeps it subtle
instance uniform float size_mult = 1.0;

// ---- Optional smoke texture (PNG) ----
// A soft grayscale smoke image: white = dense, black = empty (or use its alpha channel).
// Leave use_texture off to keep the procedural puff.
uniform bool use_texture = false;
uniform sampler2D puff_tex : filter_linear_mipmap, repeat_disable, hint_default_white;
uniform bool use_alpha_channel = false;      // read alpha instead of red
uniform int frames_h = 1;                    // flipbook columns (1 = single image)
uniform int frames_v = 1;                    // flipbook rows
uniform float texture_contrast : hint_range(0.5, 3.0) = 1.0;

uniform float start_size : hint_range(0.1, 1.0) = 0.35;   // size at birth vs final size
uniform float noise_scale = 2.4;
uniform float flow_speed = 1.2;
uniform float softness : hint_range(0.05, 1.0) = 0.35;
uniform float fade_power = 1.3;

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

	float t = 1.0 - pow(1.0 - age, 3.0);      // expands fast at first, then slows
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
	vec2 rq = vec2(c * q.x - s * q.y, s * q.x + c * q.y);   // rotated, stays inside -0.5..0.5 for r <= 1
	float r = length(q) * 2.0;

	float dens;
	if (use_texture) {
		// the flipbook plays once across the particle's lifetime
		int total = max(frames_h * frames_v, 1);
		int frame = min(int(floor(age * float(total))), total - 1);
		vec2 cell = vec2(float(frame % frames_h), float(frame / frames_h));
		vec2 tuv = (rq + 0.5 + cell) / vec2(float(max(frames_h, 1)), float(max(frames_v, 1)));
		vec4 tex = texture(puff_tex, tuv);
		float d = use_alpha_channel ? tex.a : tex.r;
		dens = pow(clamp(d, 0.0, 1.0), 1.0 / texture_contrast) * (1.0 - smoothstep(0.7, 1.0, r));
	} else {
		float n = fbm(rq * noise_scale + vec2(seed * 13.37, seed * 7.91) + vec2(age * flow_speed, 0.0));
		float body = 1.0 - smoothstep(0.15, 1.0, r);        // soft round puff, 0 at the quad edge
		dens = body * (0.4 + n);
	}

	float cut = age * 0.8;                                    // the puff erodes as it disperses
	float mask = smoothstep(cut, cut + softness, dens);
	float life = smoothstep(0.0, 0.06, age) * pow(1.0 - age, fade_power);

	ALBEDO = blast_color.rgb * pcolor.rgb;
	ALPHA = clamp(mask * life * blast_opacity * pcolor.a * blast_color.a, 0.0, 1.0);
}
