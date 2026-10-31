class_name CasingEjectionProfile extends Resource
## One resource per weapon that describes how its casings leave the gun.
## Create it in the inspector (New CasingEjectionProfile) or use the static presets below.

@export_group("Direction")
## Direction in the ejection port's local space: +X = right, +Y = up, -Z = forward.
@export var direction: Vector3 = Vector3(1.0, 0.7, -0.1)
## Random cone around the direction.
@export_range(0.0, 90.0, 0.5) var spread_degrees: float = 12.0

@export_group("Strength")
## Master multiplier on the ejection speed.
@export var power: float = 1.0
## Ejection speed range in m/s.
@export var speed_min: float = 2.5
@export var speed_max: float = 4.0
## How much of the weapon / player velocity the casing inherits (0 = none, 1 = all).
@export_range(0.0, 1.0, 0.05) var inherit_velocity: float = 0.5

@export_group("Spin")
## Tumble speed range in rad/s.
@export var spin_min: float = 8.0
@export var spin_max: float = 20.0
## Spin axis in port space. Leave at zero for a fully random axis.
@export var spin_axis: Vector3 = Vector3.ZERO
## Random tilt of the spin axis when spin_axis is set.
@export_range(0.0, 90.0, 1.0) var spin_axis_jitter_degrees: float = 25.0

@export_group("Physics")
@export var mass: float = 0.01
@export var linear_damp: float = 0.1
@export var angular_damp: float = 0.3
@export var gravity_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.35
@export_range(0.0, 1.0, 0.01) var friction: float = 0.6
## Seconds before the casing is removed. 0 = use the casing's own lifetime.
@export var lifetime: float = 0.0

@export_group("Start")
## Random offset of the spawn point around the port, in metres.
@export var position_jitter: float = 0.004
## Delay between casings when several leave in the same shot.
@export var burst_stagger: float = 0.04

@export_group("Tube (delayed / forward ejection)")
## 0 = every shot ejects immediately. >0 = casings queue in a tube first (see CasingTube).
@export var tube_capacity: int = 0
## Once the tube is full: chance per shot that one extra casing is pushed out too (dribbling).
@export_range(0.0, 1.0, 0.05) var tube_extra_chance: float = 0.25


## Normal side / top ejection (the defaults).
static func side_ejection() -> CasingEjectionProfile:
	return CasingEjectionProfile.new()


## FN F2000 / FS2000 style: casings travel through a tube above the barrel and leave forward
## and to the right from a port near the muzzle, only once the tube is full.
static func fn_f2000() -> CasingEjectionProfile:
	var p := CasingEjectionProfile.new()
	p.direction = Vector3(0.55, 0.15, -1.0)
	p.spread_degrees = 10.0
	p.speed_min = 1.5
	p.speed_max = 2.8
	p.inherit_velocity = 0.6
	p.spin_min = 4.0
	p.spin_max = 12.0
	p.tube_capacity = 5
	p.tube_extra_chance = 0.25
	p.burst_stagger = 0.05
	return p
