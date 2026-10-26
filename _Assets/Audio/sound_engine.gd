class_name SoundEngine
extends Node
## Runtime sound service. Gameplay emits semantic event IDs; this node owns playback and limits.

class SoundDefinition:
	var streams: Array[AudioStream] = []
	var volume_db: float = 0.0
	var pitch_min: float = 1.0
	var pitch_max: float = 1.0
	var max_instances: int = 8
	var cooldown: float = 0.0
	var last_played_at: float = -INF

@export_group("Buses")
@export var sfx_bus_name: StringName = &"SFX"
@export var master_bus_name: StringName = &"Master"

@export_group("Playback")
@export var max_players: int = 32
@export var default_max_distance: float = 40.0

var _definitions: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _last_warning_events: Dictionary = {}


func _ready() -> void:
	_ensure_bus(master_bus_name)
	_ensure_bus(sfx_bus_name)
	EventBus.sound_requested.connect(_on_sound_requested)


func register_event(
	event_id: StringName,
	streams: Array[AudioStream],
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0,
	max_instances: int = 8,
	cooldown: float = 0.0
) -> void:
	if event_id == &"":
		push_error("SoundEngine cannot register an empty event ID.")
		return
	if streams.is_empty():
		push_error("SoundEngine event '%s' has no audio streams." % event_id)
		return
	if pitch_min <= 0.0 or pitch_max < pitch_min:
		push_error("SoundEngine event '%s' has invalid pitch bounds." % event_id)
		return

	var definition: SoundDefinition = SoundDefinition.new()
	definition.streams = streams
	definition.volume_db = volume_db
	definition.pitch_min = pitch_min
	definition.pitch_max = pitch_max
	definition.max_instances = maxi(max_instances, 1)
	definition.cooldown = maxf(cooldown, 0.0)
	_definitions[event_id] = definition


func play_event(
	event_id: StringName,
	world_position: Vector3 = Vector3.ZERO,
	volume_scale: float = 1.0,
	pitch_scale: float = 1.0,
	spatial: bool = true
) -> void:
	var definition: SoundDefinition = _definitions.get(event_id) as SoundDefinition
	if definition == null:
		_warn_missing_event(event_id)
		return
	if volume_scale <= 0.0 or pitch_scale <= 0.0:
		return

	var now: float = Time.get_ticks_msec() * 0.001
	if now - definition.last_played_at < definition.cooldown:
		return
	if _active_count(event_id) >= definition.max_instances:
		return

	var stream: AudioStream = definition.streams.pick_random()
	var pitch: float = randf_range(definition.pitch_min, definition.pitch_max) * pitch_scale
	if spatial:
		var player_3d: AudioStreamPlayer3D = _get_3d_player()
		if player_3d == null:
			return
		player_3d.stream = stream
		player_3d.volume_db = definition.volume_db + linear_to_db(volume_scale)
		player_3d.pitch_scale = pitch
		player_3d.max_distance = default_max_distance
		player_3d.global_position = world_position
		player_3d.set_meta(&"sound_event_id", event_id)
		player_3d.play()
	else:
		var player: AudioStreamPlayer = _get_ui_player()
		if player == null:
			return
		player.stream = stream
		player.volume_db = definition.volume_db + linear_to_db(volume_scale)
		player.pitch_scale = pitch
		player.set_meta(&"sound_event_id", event_id)
		player.play()
	definition.last_played_at = now


func _on_sound_requested(
	event_id: StringName,
	world_position: Vector3,
	volume_scale: float,
	pitch_scale: float,
	spatial: bool
) -> void:
	play_event(event_id, world_position, volume_scale, pitch_scale, spatial)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _get_3d_player() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in _players:
		if not player.playing:
			return player
	if _players.size() >= max_players:
		return null
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.bus = sfx_bus_name
	add_child(player)
	_players.append(player)
	return player


func _get_ui_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _ui_players:
		if not player.playing:
			return player
	if _ui_players.size() >= max_players:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = sfx_bus_name
	add_child(player)
	_ui_players.append(player)
	return player


func _active_count(event_id: StringName) -> int:
	var active: int = 0
	for player: AudioStreamPlayer3D in _players:
		if player.playing and player.get_meta(&"sound_event_id", &"") == event_id:
			active += 1
	for player: AudioStreamPlayer in _ui_players:
		if player.playing and player.get_meta(&"sound_event_id", &"") == event_id:
			active += 1
	return active


func _warn_missing_event(event_id: StringName) -> void:
	if _last_warning_events.has(event_id):
		return
	_last_warning_events[event_id] = true
	push_warning("SoundEngine has no registered event '%s'." % event_id)
