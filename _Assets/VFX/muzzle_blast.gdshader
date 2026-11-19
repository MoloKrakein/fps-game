shader_type spatial;
// Muzzle blast / port gas: pale gas that leaves the gun.
// Two looks from one shader:
//   jet_stretch = 0  -> a lumpy round puff that swells in place (billboard)
//   jet_stretch > 0  -> an elongated streak along the particle's travel direction, so many of them
//                       form a jet / cone of gas. Needs the particle's "Align Y" flag, which GasBurst sets.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 blast_color : source_color = vec4(0.92, 0.94, 1.0, 1.0);
instance uniform float blast_opacity = 0.14;   // peak alpha. 0.08-0.2 keeps it subtle
instance uniform float size_mult = 1.0;
instance uniform float jet_stretch = 0.0;      // 0 = round puff. 3-4 = jet, length is this many times the width

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
uniform float fade_power = 2.0;                 // higher = vanishes sooner
uniform float shape_warp : hint_range(0.0, 1.0) = 0.6;   // 0 = clean circle, 1 = very lumpy outline

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
	float f = size_mult * mix(start_size, 1.0, t);

	if (jet_stretch > 0.01) {
		// streak along the travel direction (the quad's Y axis, from Align Y), facing the camera around that axis
		vec3 center = MODEL_MATRIX[3].xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		vec3 axis = MODEL_MATRIX[1].xyz;
		float al = length(axis);
		axis = al > 0.0001 ? axis / al : vec3(0.0, 1.0, 0.0);
		vec3 to_cam = INV_VIEW_MATRIX[3].xyz - center;
		vec3 side = cross(axis, to_cam);
		float sl = length(side);
		side = sl > 0.00001 ? side / sl : vec3(1.0, 0.0, 0.0);
		vec3 world_pos = center + axis * (VERTEX.y * jet_stretch * f * s) + side * (VERTEX.x * f * s);
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
	} else {
		VERTEX.xy *= f;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		// POSITION is written in the jet branch, so it has to be written here too,
		// otherwise the round puff gets no screen position at all.
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	bool jet = jet_stretch > 0.01;
	vec2 q = UV - 0.5;
	float c = cos(seed);
	float s = sin(seed);
	// round puffs get a random rotation. Jets must keep their orientation.
	vec2 rq = jet ? q : vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	float r = length(q) * 2.0;

	// lumpy outline, so the puff is not a clean circle
	float lump = vnoise(vec2(atan(rq.y, rq.x) * 1.5 + seed * 5.0, seed * 3.0 + age * flow_speed));
	r *= mix(1.0, 0.65 + 0.7 * lump, shape_warp);

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
		vec2 flow = jet ? vec2(0.0, age * flow_speed) : vec2(age * flow_speed, 0.0);
		float n = fbm(rq * noise_scale + vec2(seed * 13.37, seed * 7.91) + flow);
		float body = 1.0 - smoothstep(0.15, 1.0, r);        // soft round puff, 0 at the quad edge
		dens = body * (0.4 + n);
	}

	float cut = age * 0.8;                                    // the puff erodes as it disperses
	float mask = smoothstep(cut, cut + softness, dens);
	if (jet) {
		mask *= mix(0.5, 1.0, 1.0 - UV.y);   // denser at the head of the streak than at its tail
	}
	float life = smoothstep(0.0, 0.06, age) * pow(1.0 - age, fade_power);

	ALBEDO = blast_color.rgb * pcolor.rgb;
	ALPHA = clamp(mask * life * blast_opacity * pcolor.a * blast_color.a, 0.0, 1.0);
}