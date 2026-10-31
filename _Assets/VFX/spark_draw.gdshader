shader_type spatial;
// Draw shader for sparks. Use on the QuadMesh (size 1x1) in the spark emitter's Draw Pass 1.
// Cylindrical billboard: the quad's Y axis follows the velocity written by spark_sim.gdshader.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec4 spark_color : source_color = vec4(1.0, 0.7, 0.25, 1.0);
uniform vec4 cool_color : source_color = vec4(0.9, 0.2, 0.05, 1.0);
uniform float intensity = 6.0;
uniform float width = 0.008;
uniform vec4 flash_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float flash_width = 0.42;
uniform float flash_intensity = 14.0;

varying float age;
varying float flash_amount;

void vertex() {
	age = INSTANCE_CUSTOM.y;

	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;                       // velocity * stretch
	float axis_length = length(axis);
	flash_amount = 1.0 - smoothstep(0.3, 0.7, axis_length);
	axis = axis_length > 0.0001 ? axis : vec3(0.0, 1.0, 0.0);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - center;
	vec3 side = normalize(cross(axis, to_cam) + vec3(0.00001));
	float particle_width = mix(width, flash_width, flash_amount);
	float w = particle_width * (1.0 - age * 0.7);          // thins out as it cools

	vec3 world_pos = center + normalize(axis) * VERTEX.y * mix(axis_length, 1.0, flash_amount)
			+ side * VERTEX.x * w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = 1.0 - UV.y;                              // UV.y = 0 is the head
	float shape = pow(across, 1.5) * mix(0.1, 1.0, along * along);

	vec3 col = mix(spark_color.rgb, cool_color.rgb, age);
	col = mix(col, flash_color.rgb, flash_amount);
	float fade = 1.0 - age * age;
	float output_intensity = mix(intensity, flash_intensity, flash_amount);
	ALBEDO = col * output_intensity * shape * fade;
	ALPHA = shape * fade;
}
