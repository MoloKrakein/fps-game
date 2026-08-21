class_name UserInterface extends CanvasLayer

@onready var crosshair: Reticle = %Reticle

@onready var health_bar: ProgressBar = %HealthBar
@onready var armor_bar: ProgressBar = %ArmorBar
@onready var ammo_bar: ProgressBar = %AmmoBar

@onready var current_ammo_label: Label = %CurrentAmmoLabel
@onready var reserved_ammo_label: Label = %ReservedAmmoLabel

func _ready() -> void:
    # Connect signals to update UI elements when values change
    EventBus.player_health_changed.connect(set_health_value)
    EventBus.player_armor_changed.connect(set_armor_value)
    EventBus.weapon_ammo_changed.connect(set_ammo_values)

func set_health_value(health: float, max_health: float) -> void:
    if health_bar:
        # print("Setting health value: ", health, " / ", max_health)
        health_bar.value = health
        health_bar.max_value = max_health

func set_armor_value(armor: float, max_armor: float) -> void:
    if armor_bar:
        # print("Setting armor value: ", armor, " / ", max_armor)
        armor_bar.value = armor
        armor_bar.max_value = max_armor

func set_ammo_values(current_ammo: int, reserved_ammo: int, mags_ammo: int = 0) -> void:
    if current_ammo_label:
        current_ammo_label.text = str(current_ammo)
    if reserved_ammo_label:
        reserved_ammo_label.text = str(reserved_ammo)

    if ammo_bar and mags_ammo >= 0:
        # set_ammo_bar_values(current_ammo, )  # Assuming max ammo is the sum of current and reserved
        set_ammo_bar_values(current_ammo, mags_ammo)
    else:
        ammo_bar.value = 0

func set_ammo_bar_values(current_ammo: int, max_ammo_in_magazine: int) -> void:
    if ammo_bar:
        ammo_bar.value = current_ammo
        ammo_bar.max_value = max_ammo_in_magazine

func set_crosshair_visibility(_is_visible: bool) -> void:
    if crosshair:
        crosshair.visible = _is_visible

# initialize the UI elements with default values
# func _ready() -> void: