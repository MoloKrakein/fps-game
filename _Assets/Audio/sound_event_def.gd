class_name SoundEventDef
extends Resource
## One sound "recipe": a pool of takes plus how they are randomised and limited.
## Create these as .tres files and assign them wherever a sound is needed
## (WeaponSoundProfile, casing scenes, SoundEngine.events, ...).

## Only needed when the sound is requested by name through EventBus.sound_requested.
@export var event_id: StringName = &""
@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.1) var volume_db: float = 0.0
## Random +/- dB per play. A little (0.5 - 1.5) stops repeated sounds feeling robotic.
@export_range(0.0, 6.0, 0.1) var volume_jitter_db: float = 0.0
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.0
## How many copies of this sound may overlap. Gunshots with long tails need a high value,
## otherwise full-auto fire silently drops shots.
@export_range(1, 64) var max_instances: int = 8
## Minimum seconds between two plays. 0 = none.
@export var cooldown: float = 0.0
## 3D only. 0 = use SoundEngine.default_max_distance.
@export var max_distance: float = 0.0
## Leave empty for the SFX bus. Set to e.g. &"Music" for other buses.
@export var bus: StringName = &""
## How strongly bullet time slows this sound. 1 = fully (gunshots, casings),
## 0 = never (hitmarker, UI ticks that should stay crisp).
@export_range(0.0, 1.0, 0.05) var slowmo_amount: float = 1.0

# Runtime bookkeeping, not saved.
var last_played_at: float = -INF
var last_stream_index: int = -1