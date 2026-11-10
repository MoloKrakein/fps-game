class_name PlayerTime extends RefCounted
## Time helpers for everything the player owns (movement, camera, weapon, aim).
##
## While bullet time is on, Engine.time_scale is low, so every delta the engine
## hands out is small. The world should stay slow, but the player and their gun
## should not, so player-side code converts the delta back with these helpers.
## At normal speed (time_scale == 1) all of them return the delta unchanged.

## Share of real time the player's MOVEMENT runs at (set by BulletTime).
## 1.0 = full real-time speed, 0.5 = half speed. Gun, aim and camera ignore it.
static var movement_scale: float = 1.0


static func world_scale() -> float:
	return maxf(Engine.time_scale, 0.001)


static func is_slowed() -> bool:
	return Engine.time_scale < 0.999


## Delta for the gun, aiming and camera: always real time.
static func real(delta: float) -> float:
	return delta / world_scale()


## Delta for player movement (gravity, slides, stance timers).
static func move(delta: float) -> float:
	return real(delta) * movement_scale


## Factor for CharacterBody3D.move_and_slide(). It integrates with the scaled
## physics delta, so multiply velocity by this before the call and divide after.
static func move_factor() -> float:
	return movement_scale / world_scale()


## SceneTreeTimer that keeps counting in real time.
static func real_timer(seconds: float) -> SceneTreeTimer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.create_timer(seconds, true, false, true)


## Makes a tween ignore Engine.time_scale. Returns the tween so it can be chained.
static func real_tween(tween: Tween) -> Tween:
	if tween != null:
		tween.set_ignore_time_scale(true)
	return tween


static func reset() -> void:
	movement_scale = 1.0
