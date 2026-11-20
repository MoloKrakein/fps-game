class_name SoundEngine
extends Node
## Runtime sound service. Gameplay either:
##   - calls SoundEngine.play_sound(def, ...) with a SoundEventDef resource, or
##   - emits EventBus.sound_requested(event_id, ...) for sounds registered by ID.
## This node owns pooling, limits and buses. Volume sliders live in AudioSettings.

## Set in _ready, so any script can call SoundEngine.play_sound() without a node path.
static var instance: SoundEngine

@export_group("Buses")
@export var sfx_bus_name: StringName = &"SFX"

@export_group("Playback")
@export var max_players: int = 48
@export var default_max_distance: float = 40.0

@export_group("Events")
## Sounds that are requested by name. Each SoundEventDef needs an event_id.
@export var events: Array[SoundEventDef] = []

var _definitions: Dictionary[StringName, SoundEventDef] = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _warned_events: Dictionary[StringName, bool] = {}


func _ready() -> void:
	instance = self
	_ensure_bus(sfx_bus_name)
	for def: SoundEventDef in events:
		if def != null and def.event_id != &"":
			_definitions[def.event_id] = def
	EventBus.sound_requested.connect(_on_sound_requested)


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
	var pitch: float = randf_range(def.pitch_min, def.pitch_max) * pitch_scale
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
		player_3d.set_meta(&"started_at", now)
		player_3d.play()
	else:
		var player: AudioStreamPlayer = _acquire_2d_player()
		player.stream = stream
		player.bus = bus
		player.volume_db = volume
		player.pitch_scale = pitch
		player.set_meta(&"def", def)
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