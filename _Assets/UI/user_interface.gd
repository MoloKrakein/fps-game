class_name UserInterface extends CanvasLayer

@export var crosshair: Reticle

@onready var health_bar: ProgressBar = %HealthBar
@onready var armor_bar: ProgressBar = %ArmorBar

@onready var current_ammo_label: Label = %CurrentAmmoLabel
@onready var reserved_ammo_label: Label = %ReservedAmmoLabel

func set_health_value(health: float, max_health: float) -> void:
    if health_bar:
        health_bar.value = health
        health_bar.max_value = max_health

func set_armor_value(armor: float, max_armor: float) -> void:
    if armor_bar:
        armor_bar.value = armor
        armor_bar.max_value = max_armor

func set_ammo_values(current_ammo: int, reserved_ammo: int) -> void:
    if current_ammo_label:
        current_ammo_label.text = str(current_ammo)
    if reserved_ammo_label:
        reserved_ammo_label.text = str(reserved_ammo)