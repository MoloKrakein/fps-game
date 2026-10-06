class_name AmmoUI extends Node

@onready var reload_timer_bar: ProgressBar = %AmmoBar
@onready var chamber_indicator: ColorRect = %ChamberIndicator
@onready var current_ammo_label: Label = %CurrentAmmoLabel
@onready var reserved_ammo_label: Label = %ReservedAmmoLabel


var reload_tween: Tween

func _ready() -> void:
	EventBus.weapon_ammo_changed.connect(set_ammo_values)
	EventBus.weapon_chamber_status.connect(set_chamber_visual)
	# check if the variables are loaded correctly
	if not reload_timer_bar:
		push_error("reload_timer_bar is not assigned in AmmoUI")
	if not chamber_indicator:
		push_error("chamber_indicator is not assigned in AmmoUI")
	if not current_ammo_label:
		push_error("current_ammo_label is not assigned in AmmoUI")
	if not reserved_ammo_label:
		push_error("reserved_ammo_label is not assigned in AmmoUI")
	



func set_ammo_values(current_ammo: int = 0, reserved_ammo: int = 0, reload_time: float = 0.0) -> void:
	if current_ammo_label:
		current_ammo_label.text = str(current_ammo)
	if reserved_ammo_label:
		reserved_ammo_label.text = str(reserved_ammo)

	if reload_timer_bar and reload_time > 0.0:
		set_reload_timer_value(reload_time)

		
func set_reload_timer_value(reload_time: float) -> void:
	if not reload_timer_bar: return
	
	# 1. Kill any existing animation so they don't fight each other
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
		
	# 2. Reset the bar to 0 before we start filling it
	reload_timer_bar.value = 0.0
	
	# 3. Create a new animation that fills the bar to its max_value
	reload_tween = create_tween()
	
	# Format: tween_property(node, "property_name", target_value, duration_in_seconds)
	reload_tween.tween_property(reload_timer_bar, "value", reload_timer_bar.max_value, reload_time)

# func set_ammo_bar_values(current_ammo: int, max_ammo_in_magazine: int) -> void:
#     if ammo_bar:
#         ammo_bar.value = current_ammo
#         ammo_bar.max_value = max_ammo_in_magazine

func set_chamber_visual(is_chambered: bool) -> void:
	if not chamber_indicator: return
	
	# Green if a bullet is ready, Red if empty
	if is_chambered:
		chamber_indicator.color = Color("#00ff2a3d")
	else:
		chamber_indicator.color = Color("#ff002a3d")