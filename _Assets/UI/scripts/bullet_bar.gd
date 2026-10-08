extends Bar

@export var available_ammo_color: Color
@export var empty_ammo_color: Color

@onready var segmented_bar := $SegmentedBar as SegmentedBar


func set_ammo(current_ammo: float) -> void:
    segmented_bar.set_value(current_ammo)

func set_max_ammo(max_ammo: float) -> void:
    segmented_bar.set_max(max_ammo)


