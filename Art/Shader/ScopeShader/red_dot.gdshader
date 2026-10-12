shader_type spatial;
render_mode blend_mix, cull_back;

// Multiply by MOA to get radians
const float MOA_TO_RADIANS = 0.000290888;
// Multiply by MIL to get radians
const float MIL_TO_RADIANS = 0.001;

/** Expects a transparent texture where white values are the reticle elements */
uniform sampler2D reticle_texture: source_color, repeat_disable; 
/** Color modulation for the reticle_texture */
uniform vec4 reticle_color: source_color = vec4(1.0);
/** Color modulation for the glass */
uniform vec4 glass_color: source_color = vec4(1.0, 1.0, 1.0, 0.1);
/** Reticle light level */
uniform float reticle_emission: hint_range(0.0, 32.0) = 1.0;
/** Size of a reference element (e.g. the center dot) as a fraction of total image size where 1.0
is the full texture. EX: In a texture where the center dot takes up 5% of the total texture set
'ref_element_size' value to 0.05. If 'ref_target_moa' is set to 2.0 the dot will
be resized to 2 MOA. */
uniform float ref_element_size: hint_range(0.01, 1.0, 0.01) = 1.0;
/** Size to make a reference element (e.g. the center dot) in terms of MOA. Used in combination
with 'ref_element_size'. EX: In a texture where the center dot takes up 5% of the total
texture set 'ref_element_size' value to 0.05. If 'ref_target_moa' is set to 2.0
the dot will be resized to 2 MOA. */
uniform float ref_target_moa: hint_range(0.01, 100.0) = 65.0;


group_uniforms point_of_aim;
/** Determines if point-of-aim adjustments (poa_elevation, poa_windage) are performed in MOA
if 1.0, or MIL if 0.0 */
uniform float poa_use_moa: hint_range(0.0, 1.0, 1.0) = 0.0;
/** Subdivisions of poa_elevation and poa_windage. A value of 0.25 will make quarter MOA or quarter
MIL adjustments. */
uniform float poa_subdivision : hint_range(0.0, 1.0, 0.05) = 1.0;
/** Verticle adjustment. To move the point-of-impact upwards increase the value. The reticle will
shift downwards, requiring the weapon to be rotated upwards to put the reticle on target. This
results in the impact shifting up. */
uniform int poa_elevation = 0;
/** Horizontal adjustment. To move the point-of-impact rightwards increase the value. The reticle
will shift leftwards, requiring the weapon to be rotated rightwards to put the reticle on target.
This results in the impact shifting right. */
uniform int poa_windage = 0;


float mask(vec2 uv) {
	return step(0.01, uv.x) * step(uv.x, 0.99) * step(0.01, uv.y) * step(uv.y, 0.99);
}


// Rotate along the x-axis (moves reticle up/down) and y-axis (moves reticle left/ right)
// Credit (CC0) https://godotshaders.com/shader/3d-transformations/
mat3 rotate_poa() {
	// Zeroing Adjustments
	float radians_per_click = poa_subdivision * mix(MOA_TO_RADIANS, MIL_TO_RADIANS, poa_use_moa);
	float radians_x = float(poa_elevation) * radians_per_click;
	float radians_y = float(-poa_windage) * radians_per_click;

	mat3 mat_x = mat3(
		vec3(1, 0, 0),
		vec3(0, cos(radians_x), -sin(radians_x)),
		vec3(0, sin(radians_x),  cos(radians_x))
	);
	mat3 mat_y = mat3(
		vec3(cos(radians_y), 0, sin(radians_y)),
		vec3( 0, 1, 0),
		vec3(-sin(radians_y), 0, cos(radians_y))
	);
	return mat_y * mat_x;
}


void fragment() {
	// Convert from pixel to angular measurements
	float tex_total_moa = ref_target_moa / ref_element_size;
	float tex_rad_width = tex_total_moa * MOA_TO_RADIANS;

	// Get view rotated by point-of-aim adjustments
	vec3 view_dir = (normalize(VIEW * rotate_poa()));

	// Use 'transpose' as a fast inversion (rotation matrix only)
	// Inverse MODELVIEW matrix to bring back to local coords
	vec3 view_local = transpose(mat3(VIEW_MATRIX * MODEL_MATRIX)) * view_dir;

	// Recenter and scale
	vec2 uv = 0.5 + (view_local.xy / tex_rad_width);

	// Mask to in-bounds to discard reticle artifacting at low sizes
	float mask = mask(uv);
	vec4 reticle_sample = texture(reticle_texture, uv);
	reticle_sample.rgb = mix(reticle_sample.rgb, reticle_color.rgb, reticle_color.a);
	reticle_sample.a *= mask;

	// Mask for emission
	float reticle_mask = reticle_sample.a * mask;

	// Make small reticles emit disproportionally more
	float emission_size_factor = 1.0 / sqrt(tex_rad_width);

	// Make sure to enable WorldEnvironment glow
	ALPHA = max(reticle_sample.a, glass_color.a);
	ALBEDO = mix(glass_color.rgb, reticle_color.rgb, reticle_sample.a);
	EMISSION = reticle_sample.rgb * reticle_color.rgb * reticle_mask * (reticle_emission*emission_size_factor);
}
