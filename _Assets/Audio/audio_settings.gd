extends Node
## Autoload named "AudioSettings" (no class_name on purpose, it would clash with the autoload).
## Owns the Master / Music / SFX buses and the player's volume choices.
## Volumes are linear 0..1 (what a slider shows) and saved to user://audio_settings.cfg.

signal volume_changed(bus_name: StringName, linear: float)

const SAVE_PATH: String = "user://audio_settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
const DEFAULTS: Dictionary[StringName, float] = {
	&"Master": 1.0,
	&"Music": 0.8,
	&"SFX": 1.0,
}

var _volumes: Dictionary[StringName, float] = {}


func _ready() -> void:
	for bus: StringName in BUSES:
		_ensure_bus(bus)
	_load()
	for bus: StringName in BUSES:
		_apply(bus)


func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULTS.get(bus, 1.0))


## Pass save = false while a slider is being dragged, then call save_settings() on release.
func set_volume(bus: StringName, linear: float, save: bool = true) -> void:
	_volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply(bus)
	volume_changed.emit(bus, _volumes[bus])
	if save:
		save_settings()


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: StringName in BUSES:
		cfg.set_value("volume", String(bus), get_volume(bus))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var loaded: bool = cfg.load(SAVE_PATH) == OK
	for bus: StringName in BUSES:
		var fallback: float = DEFAULTS.get(bus, 1.0)
		_volumes[bus] = clampf(float(cfg.get_value("volume", String(bus), fallback)) if loaded else fallback, 0.0, 1.0)


func _apply(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var linear: float = get_volume(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
