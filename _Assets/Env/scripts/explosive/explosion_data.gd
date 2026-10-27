class_name ExplosionData extends Resource
## Describes one explosion. Weapons, grenades, barrels, etc. can all export this
## and hand it to Explosion.detonate().

@export_group("Damage")
@export var radius: float = 5.0
## Inside this radius damage and force are at full strength.
@export var core_radius: float = 0.75
@export var damage: float = 100.0
## 0 = no falloff, 1 = damage reaches zero at the edge of the radius.
@export_range(0.0, 1.0) var falloff: float = 1.0
## Shape of the falloff: 1 = linear, above 1 = stays strong then drops sharply
## near the edge, below 1 = drops fast close to the centre.
@export var falloff_curve: float = 1.0
@export_range(0.0, 1.0) var armor_penetration: float = 0.0
## Applied to anything that is not an enemy or the player (crates, barrels, props).
@export var object_damage_multiplier: float = 1.0
## 1 = the attacker is hurt fully by their own blast, 0 = immune (rocket jumping).
@export_range(0.0, 1.0) var self_damage_multiplier: float = 1.0

@export_group("Force")
## Total impulse delivered to a target at full strength.
@export var force: float = 10.0
## Source-engine style lift so props fly up instead of only sliding away.
@export_range(0.0, 1.0) var upward_bias: float = 0.35

@export_group("Cover")
## Walls and solid props shield targets from the blast.
@export var requires_line_of_sight: bool = true
@export_flags_3d_physics var target_mask: int = 15
## Layers that block the blast (usually just the world).
@export_flags_3d_physics var blocker_mask: int = 1

@export_group("Feedback")
## Read by anything in the "explosion_listener" group (camera shake, audio ducking...).
@export var camera_shake: float = 1.0
## Optional real effect (particles, sound). Falls back to a placeholder fireball + light.
@export var effect_scene: PackedScene
