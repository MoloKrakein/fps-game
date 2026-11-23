extends PanelContainer
## Drop-in volume sliders (Master / Music / SFX). Add this node to any menu, nothing else to set up.

const ROWS: Array[Array] = [
	[&"Master", "Master"],
	[&"Music", "Music"],
	[&"SFX", "Sound effects"],
]

## Optional: played when an SFX slider is released, so the player hears the new level.
@export var sfx_preview: SoundEventDef


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)

	for row: Array in ROWS:
		var bus: StringName = row[0]

		var line: HBoxContainer = HBoxContainer.new()
		box.add_child(line)

		var label: Label = Label.new()
		label.text = row[1]
		label.custom_minimum_size.x = 140.0
		line.add_child(label)

		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = AudioSettings.get_volume(bus)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 240.0
		line.add_child(slider)

		var percent: Label = Label.new()
		percent.custom_minimum_size.x = 52.0
		percent.text = "%d%%" % roundi(slider.value * 100.0)
		line.add_child(percent)

		slider.value_changed.connect(func(value: float) -> void:
			AudioSettings.set_volume(bus, value, false)
			percent.text = "%d%%" % roundi(value * 100.0))
		slider.drag_ended.connect(func(_changed: bool) -> void:
			AudioSettings.save_settings()
			if bus == &"SFX":
				SoundEngine.play_sound(sfx_preview, Vector3.ZERO, 1.0, 1.0, false))
