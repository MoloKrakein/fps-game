shader_type particles;
// Simulation shader for sparks. Use as the PROCESS material of a GPUParticles3D.
// Required node settings: Local Coords = OFF, One Shot = ON, Explosiveness = 1.
// Emits along the emitter's -Z axis (muzzle forward).

uniform vec3 emit_direction = vec3(0.0, 0.0, -1.0);
uniform float cone_spread = 0.35;
uniform float speed_min = 3.0;
uniform float speed_max = 9.0;
uniform float gravity_strength = 9.8;
uniform float air_drag = 2.5;
uniform float streak_stretch = 0.025;   // streak length = speed * streak_stretch
uniform float min_streak = 0.01;
uniform float lifetime_random = 0.5;    // 0.5 = lifetimes between 50% and 100%

uint spark_hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

// own RNG (avoids the built-in rand_from_seed, whose signature differs between versions)
float spark_rand(inout uint state) {
	state = spark_hash(state + uint(1));
	return float(state & uint(16777215)) / 16777216.0;
}

void start() {
	uint rng = spark_hash(NUMBER + uint(1) + RANDOM_SEED);
	float rx = spark_rand(rng);
	float ry = spark_rand(rng);
	float rz = spark_rand(rng);
	vec3 rnd = vec3(rx, ry, rz) * 2.0 - vec3(1.0);
	vec3 dir = normalize(normalize(emit_direction) + rnd * cone_spread);
	float speed = mix(speed_min, speed_max, spark_rand(rng));
	float life_scale = max(mix(1.0 - lifetime_random, 1.0, spark_rand(rng)), 0.05);

	vec3 world_dir = normalize((EMISSION_TRANSFORM * vec4(dir, 0.0)).xyz);

	TRANSFORM = mat4(
			vec4(1.0, 0.0, 0.0, 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0),
			vec4(EMISSION_TRANSFORM[3].xyz, 1.0));
	VELOCITY = world_dir * speed;

	// CUSTOM.y = normalized age, CUSTOM.z = per-particle lifetime scale
	CUSTOM = vec4(0.0, 0.0, life_scale, 0.0);
}

void process() {
	float particle_lifetime = max(LIFETIME * max(CUSTOM.z, 0.05), 0.001);
	CUSTOM.y += DELTA / particle_lifetime;
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}

	vec3 vel = VELOCITY;
	vel.y -= gravity_strength * DELTA;
	vel *= max(0.0, 1.0 - air_drag * DELTA);
	VELOCITY = vel;

	// stretch the quad's Y axis along the velocity; spark_draw reads it
	float streak = max(length(vel) * streak_stretch, min_streak);
	vec3 ydir = normalize(vel + vec3(0.0001));
	TRANSFORM[1] = vec4(ydir * streak, 0.0);
	// position is integrated automatically from VELOCITY after process()
}
