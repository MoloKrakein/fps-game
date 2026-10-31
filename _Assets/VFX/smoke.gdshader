shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Per-weapon values (set from MuzzleFlash via set_instance_shader_parameter)
instance uniform vec4 smoke_color : source_color = vec4(0.72, 0.72, 0.74, 1.0);
instance uniform float density = 1.0;    // 0..1, raised by barrel heat
instance uniform float size_mult = 1.0;
instance uniform float smoke_opacity : hint_range(0.0, 1.0) = 0.55;
instance uniform float smoke_thickness : hint_range(0.05, 3.0) = 1.0;
instance uniform float smoke_stretch : hint_range(1.0, 4.0) = 1.8;

// Shared look (tune once per material: barrel / ejection use different materials)
uniform vec4 shadow_color : source_color = vec4(0.28, 0.29, 0.32, 1.0);
uniform vec4 heat_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float heat_strength = 1.5;       // orange tint right after the shot
uniform float heat_time : hint_range(0.01, 1.0) = 0.15;
uniform float noise_scale = 2.2;
uniform float flow_speed = 0.35;
uniform float grow = 3.0;                // final size vs start size
uniform float softness : hint_range(0.01, 1.0) = 0.25;
uniform float fade_power = 1.5;
uniform bool soft_particles = false; // turn on once the smoke shows up
uniform float soft_distance = 0.15;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

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
	for (int i = 0; i < 4; i++) {
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

	float t = 1.0 - (1.0 - age) * (1.0 - age); // fast expansion, then slows
	VERTEX.xy *= size_mult * mix(1.0, grow, t);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 q = UV - 0.5;                       // unrotated, used for fake top lighting
	q.x /= smoke_stretch;                    // elongated barrel trail instead of a round puff
	float c = cos(seed);
	float s = sin(seed);
	vec2 uv = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	float r = length(uv) * 2.0;

	// animated noise: slow drift + a faster detail layer
	vec2 p = uv * noise_scale + vec2(seed * 13.37, seed * 7.91);
	p += vec2(age * flow_speed, -age * flow_speed * 1.4);
	float n1 = fbm(p);
	float n2 = fbm(p * 1.9 - vec2(age * flow_speed * 2.0));
	float d = n1 * 0.65 + n2 * 0.35;

	float shape = 1.0 - smoothstep(0.2, 1.0, r);
	float dens = d * shape * (1.0 + smoke_thickness * 1.2);

	// dissolve: the threshold rises with age, so the smoke erodes into wisps
	float cut = age * 0.85;
	float a = smoothstep(cut, cut + softness, dens);
	a *= pow(1.0 - age, fade_power) * smoothstep(0.0, 0.03, age);
	a *= density * smoke_opacity * pcolor.a * smoke_color.a;

	// colour: shadow -> light, lit from above, plus a short hot tint
	float lit = clamp(0.5 - q.y * 0.8 + (d - 0.5) * 0.6, 0.0, 1.0);
	vec3 col = mix(shadow_color.rgb, smoke_color.rgb, lit);
	float hot = (1.0 - smoothstep(0.0, heat_time, age)) * (1.0 - clamp(r, 0.0, 1.0));
	col += heat_color.rgb * heat_strength * hot;

	if (soft_particles) {
		float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		v.xyz /= v.w;
		a *= clamp((-v.z - (-VERTEX.z)) / soft_distance, 0.0, 1.0);
	}

	ALBEDO = col * pcolor.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
