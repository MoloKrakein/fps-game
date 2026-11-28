class_name SoundEngine
extends Node
## Runtime sound service. Gameplay either:
##   - calls SoundEngine.play_sound(def, ...) with a SoundEventDef resource, or
##   - emits EventBus.sound_requested(event_id, ...) for sounds registered by ID.
## This node owns pooling, limits and buses. Volume sliders live in AudioSettings.

## Set in _ready, so any script can call SoundEngine.play_sound() without a node path.
static var instance: SoundEngine
static var _warned_no_instance: bool = false

@export_group("Buses")
@export var sfx_bus_name: StringName = &"SFX"

@export_group("Playback")
@export var max_players: int = 48
@export var default_max_distance: float = 40.0

@export_group("Bullet time")
## Pitch of a fully slowed sound (1.0 = no change). Real time_scale is far lower than this,
## but a pitch that deep just sounds like a rumble. 0.5 - 0.7 reads as slow motion.
@export_range(0.2, 1.0, 0.01) var slowmo_pitch: float = 0.6
## The SFX bus is muffled towards this cutoff during bullet time. 20000 = no muffling.
@export_range(500.0, 20000.0, 50.0) var slowmo_lowpass_hz: float = 5000.0

@export_group("Events")
## Sounds that are requested by name. Each SoundEventDef needs an event_id.
@export var events: Array[SoundEventDef] = []

var _definitions: Dictionary[StringName, SoundEventDef] = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _warned_events: Dictionary[StringName, bool] = {}
var _slowmo: float = 0.0 # 0..1, fed by EventBus.bullet_time_changed
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	instance = self
	_ensure_bus(sfx_bus_name)
	for def: SoundEventDef in events:
		if def != null and def.event_id != &"":
			_definitions[def.event_id] = def
	_setup_slowmo_filter()
	EventBus.sound_requested.connect(_on_sound_requested)
	if EventBus.has_signal(&"bullet_time_changed"):
		EventBus.connect(&"bullet_time_changed", _on_bullet_time_changed)
	else:
		push_warning("SoundEngine: EventBus has no 'bullet_time_changed' signal, so sounds will not slow down in bullet time.")


func _exit_tree() -> void:
	if instance == self:
		instance = null


#region Public API
## Safe to call from anywhere. Does nothing if def is null or no SoundEngine is in the scene.
static func play_sound(
	def: SoundEventDef,
	world_position: Vector3 = Vector3.ZERO,
	volume_scale: float = 1.0,
	pitch_scale: float = 1.0,
	spatial: bool = true
) -> void:
	if instance != null:
		instance.play_def(def, world_position, volume_scale, pitch_scale, spatial)
	elif def != null and not _warned_no_instance:
		_warned_no_instance = true
		push_warning("SoundEngine.play_sound() was called but no SoundEngine node is in the running scene.")


## Code registration, for events you would rather not author as resources.
func register_event(
	event_id: StringName,
	streams: Array[AudioStream],
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0,
	max_instances: int = 8,
	cooldown: float = 0.0
) -> void:
	if event_id == &"" or streams.is_empty():
		push_error("SoundEngine: register_event needs an ID and at least one stream.")
		return
	if pitch_min <= 0.0 or pitch_max < pitch_min:
		push_error("SoundEngine event '%s' has invalid pitch bounds." % event_id)
		return
	var def: SoundEventDef = SoundEventDef.new()
	def.event_id = event_id
	def.streams = streams
	def.volume_db = volume_db
	def.pitch_min = pitch_min
	def.pitch_max = pitch_max
	def.max_instances = maxi(max_instances, 1)
	def.cooldown = maxf(cooldown, 0.0)
	_definitions[event_id] = def


func play_event(
	event_id: StringName,
	world_position: Vector3 = Vector3.ZERO,
	volume_scale: float = 1.0,
	pitch_scale: float = 1.0,
	spatial: bool = true
) -> void:
	var def: SoundEventDef = _definitions.get(event_id)
	if def == null:
		_warn_missing_event(event_id)
		return
	play_def(def, world_position, volume_scale, pitch_scale, spatial)


func play_def(
	def: SoundEventDef,
	world_position: Vector3 = Vector3.ZERO,
	volume_scale: float = 1.0,
	pitch_scale: float = 1.0,
	spatial: bool = true
) -> void:
	if def == null or def.streams.is_empty():
		return
	if volume_scale <= 0.0 or pitch_scale <= 0.0:
		return

	var now: float = Time.get_ticks_msec() * 0.001
	if now - def.last_played_at < def.cooldown:
		return
	if _active_count(def) >= def.max_instances:
		return

	var stream: AudioStream = _pick_stream(def)
	var base_pitch: float = randf_range(def.pitch_min, def.pitch_max) * pitch_scale
	var pitch: float = base_pitch * _slow_factor(def)
	var volume: float = def.volume_db + linear_to_db(volume_scale)
	if def.volume_jitter_db > 0.0:
		volume += randf_range(-def.volume_jitter_db, def.volume_jitter_db)
	var bus: StringName = def.bus if def.bus != &"" else sfx_bus_name

	if spatial:
		var player_3d: AudioStreamPlayer3D = _acquire_3d_player()
		player_3d.stream = stream
		player_3d.bus = bus
		player_3d.volume_db = volume
		player_3d.pitch_scale = pitch
		player_3d.max_distance = def.max_distance if def.max_distance > 0.0 else default_max_distance
		player_3d.global_position = world_position
		player_3d.set_meta(&"def", def)
		player_3d.set_meta(&"base_pitch", base_pitch)
		player_3d.set_meta(&"started_at", now)
		player_3d.play()
	else:
		var player: AudioStreamPlayer = _acquire_2d_player()
		player.stream = stream
		player.bus = bus
		player.volume_db = volume
		player.pitch_scale = pitch
		player.set_meta(&"def", def)
		player.set_meta(&"base_pitch", base_pitch)
		player.set_meta(&"started_at", now)
		player.play()

	def.last_played_at = now
#endregion


func _on_sound_requested(
	event_id: StringName,
	world_position: Vector3,
	volume_scale: float,
	pitch_scale: float,
	spatial: bool
) -> void:
	play_event(event_id, world_position, volume_scale, pitch_scale, spatial)


#region Bullet time
func _on_bullet_time_changed(intensity: float) -> void:
	_slowmo = clampf(intensity, 0.0, 1.0)
	# Sounds that are already playing (tails, casings mid-bounce) slow down and speed up live.
	for player: AudioStreamPlayer3D in _players_3d:
		if player.playing:
			player.pitch_scale = _voice_pitch(player)
	for player: AudioStreamPlayer in _players_2d:
		if player.playing:
			player.pitch_scale = _voice_pitch(player)
	_update_slowmo_filter()


func _slow_factor(def: SoundEventDef) -> float:
	return lerpf(1.0, slowmo_pitch, _slowmo * def.slowmo_amount)


func _voice_pitch(player: Node) -> float:
	var def: SoundEventDef = player.get_meta(&"def", null)
	if def == null:
		return 1.0
	return maxf(player.get_meta(&"base_pitch", 1.0) * _slow_factor(def), 0.01)


func _setup_slowmo_filter() -> void:
	var bus_index: int = AudioServer.get_bus_index(sfx_bus_name)
	if bus_index < 0:
		return
	# The bus outlives scene reloads, so drop the filter a previous SoundEngine left behind.
	for index: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus_index, index).resource_name == &"SlowmoLowpass":
			AudioServer.remove_bus_effect(bus_index, index)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.resource_name = &"SlowmoLowpass"
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus_index, _lowpass)
	AudioServer.set_bus_effect_enabled(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1, false)


func _update_slowmo_filter() -> void:
	if _lowpass == null:
		return
	var bus_index: int = AudioServer.get_bus_index(sfx_bus_name)
	if bus_index < 0:
		return
	# Interpolate in log space so the sweep sounds even.
	_lowpass.cutoff_hz = exp(lerpf(log(20000.0), log(slowmo_lowpass_hz), _slowmo))
	# Only pay for the filter while bullet time is on.
	for index: int in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, index) == _lowpass:
			AudioServer.set_bus_effect_enabled(bus_index, index, _slowmo > 0.001)
#endregion


## Random take, never the same one twice in a row (when there is a choice).
func _pick_stream(def: SoundEventDef) -> AudioStream:
	var count: int = def.streams.size()
	var index: int = randi() % count
	if count > 1 and index == def.last_stream_index:
		index = (index + 1 + randi() % (count - 1)) % count
	def.last_stream_index = index
	return def.streams[index]


#region Pooling
## Free player first; otherwise grow the pool; otherwise steal the oldest voice.
func _acquire_3d_player() -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = null
	for player: AudioStreamPlayer3D in _players_3d:
		if not player.playing:
			return player
		if oldest == null or _started_at(player) < _started_at(oldest):
			oldest = player
	if _players_3d.size() < max_players:
		var created: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		add_child(created)
		_players_3d.append(created)
		return created
	oldest.stop()
	return oldest


func _acquire_2d_player() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for player: AudioStreamPlayer in _players_2d:
		if not player.playing:
			return player
		if oldest == null or _started_at(player) < _started_at(oldest):
			oldest = player
	if _players_2d.size() < max_players:
		var created: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(created)
		_players_2d.append(created)
		return created
	oldest.stop()
	return oldest


func _started_at(player: Node) -> float:
	return player.get_meta(&"started_at", 0.0)


func _active_count(def: SoundEventDef) -> int:
	var active: int = 0
	for player: AudioStreamPlayer3D in _players_3d:
		if player.playing and player.get_meta(&"def", null) == def:
			active += 1
	for player: AudioStreamPlayer in _players_2d:
		if player.playing and player.get_meta(&"def", null) == def:
			active += 1
	return active
#endregion


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _warn_missing_event(event_id: StringName) -> void:
	if _warned_events.has(event_id):
		return
	_warned_events[event_id] = true
	push_warning("SoundEngine has no registered event '%s'." % event_id)
