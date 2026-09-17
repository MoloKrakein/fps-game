shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


// ============================================================
// COLOR GRADING
// ============================================================

group_uniforms color_grading;

uniform float contrast : hint_range(0.5, 2.0, 0.01) = 1.08;
uniform float brightness : hint_range(-0.2, 0.2, 0.005) = 0.0;
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 0.92;

// Slight color bias for shadows and highlights.
uniform vec3 shadow_tint : source_color = vec3(0.97, 0.99, 1.02);
uniform vec3 highlight_tint : source_color = vec3(1.02, 1.00, 0.97);

// Strength of the shadow/highlight color separation.
uniform float color_split : hint_range(0.0, 1.0, 0.01) = 0.20;


// ============================================================
// RETRO CHARACTER
// ============================================================

group_uniforms retro_style;

// Number of color levels.
uniform float color_steps : hint_range(2.0, 32.0, 1.0) = 12.0;

// How much posterization affects the final image.
uniform float posterize_strength : hint_range(0.0, 1.0, 0.01) = 0.22;

// Ordered dithering.
uniform float dither_strength : hint_range(0.0, 0.15, 0.001) = 0.025;

// Film grain.
uniform float grain_strength : hint_range(0.0, 0.15, 0.001) = 0.022;
uniform float grain_scale : hint_range(100.0, 2000.0, 10.0) = 900.0;


// ============================================================
// MODERN POLISH
// ============================================================

group_uniforms modern_polish;

// Small amount of sharpening.
uniform float sharpen_strength : hint_range(0.0, 1.0, 0.01) = 0.12;

// Chromatic aberration around the screen edges.
uniform float chromatic_aberration : hint_range(0.0, 0.02, 0.001) = 0.0015;

// How much of the chromatic aberration is concentrated toward
// the edges of the screen.
uniform float chromatic_edge_falloff : hint_range(0.1, 5.0, 0.1) = 2.0;


// ============================================================
// VIGNETTE
// ============================================================

group_uniforms vignette;

uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.16;

uniform float vignette_radius : hint_range(0.1, 1.5, 0.01) = 0.78;

uniform float vignette_softness : hint_range(0.01, 1.0, 0.01) = 0.35;


// ============================================================
// EDGE DEFINITION
// ============================================================

group_uniforms edges;

// This is deliberately subtle.
// It enhances geometry separation rather than creating
// thick comic-book outlines.
uniform float edge_strength : hint_range(0.0, 1.0, 0.01) = 0.10;

uniform float edge_threshold : hint_range(0.0, 1.0, 0.01) = 0.18;


// ============================================================
// OPTIONAL SCREEN PIXELATION
// ============================================================

group_uniforms pixelation;

// Disabled by default.
// 1.0 = normal resolution.
// Lower values produce a lower-resolution appearance.
uniform float pixelation : hint_range(0.25, 1.0, 0.01) = 1.0;


// ============================================================
// BASIC FUNCTIONS
// ============================================================

float luminance(vec3 color)
{
	return dot(color, vec3(0.299, 0.587, 0.114));
}


// ============================================================
// RGB → HSV
// ============================================================

vec3 rgb_to_hsv(vec3 c)
{
	vec4 K = vec4(
		0.0,
		-1.0 / 3.0,
		2.0 / 3.0,
		-1.0
	);

	vec4 p = mix(
		vec4(c.bg, K.wz),
		vec4(c.gb, K.xy),
		step(c.b, c.g)
	);

	vec4 q = mix(
		vec4(p.xyw, c.r),
		vec4(c.r, p.yzx),
		step(p.x, c.r)
	);

	float d = q.x - min(q.w, q.y);
	float e = 0.000001;

	return vec3(
		abs(q.z + (q.w - q.y) / (6.0 * d + e)),
		d / (q.x + e),
		q.x
	);
}


// ============================================================
// HSV → RGB
// ============================================================

vec3 hsv_to_rgb(vec3 c)
{
	vec3 p = abs(
		fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0))
		* 6.0 - 3.0
	);

	return c.z * mix(
		vec3(1.0),
		clamp(p - 1.0, 0.0, 1.0),
		c.y
	);
}


// ============================================================
// COLOR ADJUSTMENT
// ============================================================

vec3 adjust_color(vec3 color)
{
	color = (color - 0.5) * contrast + 0.5;

	color += brightness;

	vec3 hsv = rgb_to_hsv(color);

	hsv.y *= saturation;

	color = hsv_to_rgb(hsv);

	return clamp(color, 0.0, 1.0);
}


// ============================================================
// POSTERIZATION
// ============================================================

vec3 posterize(vec3 color)
{
	vec3 quantized =
		floor(color * color_steps + 0.5)
		/ color_steps;

	return mix(
		color,
		quantized,
		posterize_strength
	);
}


// ============================================================
// BAYER 4×4 DITHER
// ============================================================

float bayer4(vec2 pixel)
{
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));

	int index = x + y * 4;

	float matrix[16] = float[](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);

	return matrix[index] / 16.0 - 0.5;
}


// ============================================================
// RANDOM NOISE
// ============================================================

float random_noise(vec2 uv)
{
	return fract(
		sin(dot(uv, vec2(12.9898, 78.233)))
		* 43758.5453
	);
}


// ============================================================
// SOBEL EDGE
// ============================================================

float sobel_edge(vec2 uv)
{
	vec2 texel =
		1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));

	float tl =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(-1.0, -1.0)
		).rgb);

	float t =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(0.0, -1.0)
		).rgb);

	float tr =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(1.0, -1.0)
		).rgb);

	float l =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(-1.0, 0.0)
		).rgb);

	float r =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(1.0, 0.0)
		).rgb);

	float bl =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(-1.0, 1.0)
		).rgb);

	float b =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(0.0, 1.0)
		).rgb);

	float br =
		luminance(texture(
			SCREEN_TEXTURE,
			uv + texel * vec2(1.0, 1.0)
		).rgb);

	float gx =
		-tr
		- 2.0 * r
		- br
		+ tl
		+ 2.0 * l
		+ bl;

	float gy =
		-tl
		- 2.0 * t
		- tr
		+ bl
		+ 2.0 * b
		+ br;

	return sqrt(gx * gx + gy * gy);
}


// ============================================================
// SHARPEN
// ============================================================

vec3 sharpen_image(vec2 uv, vec3 original)
{
	if (sharpen_strength <= 0.0)
	{
		return original;
	}

	vec2 texel =
		1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));

	vec3 center =
		texture(SCREEN_TEXTURE, uv).rgb;

	vec3 north =
		texture(
			SCREEN_TEXTURE,
			uv + vec2(0.0, -texel.y)
		).rgb;

	vec3 south =
		texture(
			SCREEN_TEXTURE,
			uv + vec2(0.0, texel.y)
		).rgb;

	vec3 east =
		texture(
			SCREEN_TEXTURE,
			uv + vec2(texel.x, 0.0)
		).rgb;

	vec3 west =
		texture(
			SCREEN_TEXTURE,
			uv + vec2(-texel.x, 0.0)
		).rgb;

	vec3 blur =
		(north + south + east + west) * 0.25;

	vec3 detail =
		center - blur;

	return clamp(
		original + detail * sharpen_strength,
		0.0,
		1.0
	);
}


// ============================================================
// CHROMATIC ABERRATION
// ============================================================

vec3 chromatic_sample(vec2 uv)
{
	if (chromatic_aberration <= 0.0)
	{
		return texture(
			SCREEN_TEXTURE,
			uv
		).rgb;
	}

	vec2 centered =
		uv - 0.5;

	float edge =
		pow(
			clamp(length(centered) * 2.0, 0.0, 1.0),
			chromatic_edge_falloff
		);

	vec2 direction =
		normalize(centered + vec2(0.0001));

	vec2 offset =
		direction
		* chromatic_aberration
		* edge;

	float red =
		texture(
			SCREEN_TEXTURE,
			uv + offset
		).r;

	float green =
		texture(
			SCREEN_TEXTURE,
			uv
		).g;

	float blue =
		texture(
			SCREEN_TEXTURE,
			uv - offset
		).b;

	return vec3(
		red,
		green,
		blue
	);
}


// ============================================================
// VIGNETTE
// ============================================================

float calculate_vignette(vec2 uv)
{
	vec2 centered =
		uv - 0.5;

	float distance_from_center =
		length(centered);

	return smoothstep(
		vignette_radius,
		vignette_radius + vignette_softness,
		distance_from_center
	);
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
	vec2 uv = SCREEN_UV;

	// --------------------------------------------------------
	// Pixelation
	// --------------------------------------------------------

	if (pixelation < 0.999)
	{
		vec2 resolution =
			vec2(textureSize(SCREEN_TEXTURE, 0));

		vec2 pixel_grid =
			resolution * pixelation;

		uv =
			(floor(uv * pixel_grid) + 0.5)
			/ pixel_grid;
	}


	// --------------------------------------------------------
	// Base image
	// --------------------------------------------------------

	vec4 screen =
		texture(SCREEN_TEXTURE, uv);

	vec3 color =
		chromatic_sample(uv);


	// --------------------------------------------------------
	// Color grading
	// --------------------------------------------------------

	color =
		adjust_color(color);


	// --------------------------------------------------------
	// Shadow / highlight color separation
	// --------------------------------------------------------

	float brightness_value =
		luminance(color);

	float shadow_mask =
		1.0 -
		smoothstep(
			0.15,
			0.55,
			brightness_value
		);

	float highlight_mask =
		smoothstep(
			0.55,
			0.90,
			brightness_value
		);

	color *= mix(
		vec3(1.0),
		shadow_tint,
		shadow_mask * color_split
	);

	color *= mix(
		vec3(1.0),
		highlight_tint,
		highlight_mask * color_split
	);


	// --------------------------------------------------------
	// Posterization
	// --------------------------------------------------------

	color =
		posterize(color);


	// --------------------------------------------------------
	// Dithering
	// --------------------------------------------------------

	vec2 screen_size =
		vec2(textureSize(SCREEN_TEXTURE, 0));

	vec2 pixel =
		uv * screen_size;

	float dither =
		bayer4(pixel);

	color +=
		dither * dither_strength;


	// --------------------------------------------------------
	// Edge definition
	// --------------------------------------------------------

	float edge =
		sobel_edge(uv);

	float edge_mask =
		smoothstep(
			edge_threshold,
			edge_threshold + 0.15,
			edge
		);

	color *=
		1.0 -
		edge_mask * edge_strength;


	// --------------------------------------------------------
	// Sharpen
	// --------------------------------------------------------

	color =
		sharpen_image(
			uv,
			color
		);


	// --------------------------------------------------------
	// Film grain
	// --------------------------------------------------------

	float grain =
		random_noise(
			pixel / grain_scale
			+ TIME * 0.05
		);

	grain =
		(grain - 0.5)
		* grain_strength;

	color += grain;


	// --------------------------------------------------------
	// Vignette
	// --------------------------------------------------------

	float vignette =
		calculate_vignette(uv);

	color *=
		1.0 -
		vignette * vignette_strength;


	// --------------------------------------------------------
	// Final output
	// --------------------------------------------------------

	COLOR = vec4(
		clamp(color, 0.0, 1.0),
		screen.a
	);
}
