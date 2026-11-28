class_name UserInterface extends CanvasLayer

@onready var crosshair: CenterContainer = %Reticle
@onready var reticle_draw: Reticle = $Reticle/ReticleDraw

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var armor_bar: TextureProgressBar = %ArmorBar
@onready var reload_timer_bar: ProgressBar = %AmmoBar
@onready var chamber_indicator: ColorRect = %ChamberIndicator
@onready var health_label: Label = %lbl_HP
@onready var armor_label: Label = %lbl_Armor
@onready var ammo_container: PanelContainer = $AmmoContainer

@onready var current_ammo_label: Label = %CurrentAmmoLabel
@onready var reserved_ammo_label: Label = %ReservedAmmoLabel

var reload_tween: Tween
var _player: PlayerController
var _weapon_controller: WeaponController
var _world_camera: Camera3D

func _ready() -> void:
	# Connect signals to update UI elements when values change
	EventBus.player_health_changed.connect(set_health_value)
	EventBus.player_armor_changed.connect(set_armor_value)
	EventBus.weapon_ammo_changed.connect(set_ammo_values)
	EventBus.weapon_chamber_status.connect(set_chamber_visual)
	EventBus.change_visibility_of_crosshair.connect(set_crosshair_visibility)
	EventBus.weapon_2d_ammo_visibility_changed.connect(set_2d_ammo_visibility)
	_resolve_crosshair_references()


func _process(_delta: float) -> void:
	_resolve_crosshair_references()
	if _weapon_controller == null or _world_camera == null or reticle_draw == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return

	var spread_degrees: float = rad_to_deg(_weapon_controller.get_effective_spread())
	var spread_edge_radians: float = deg_to_rad(clampf(spread_degrees * 3.0, 0.0, 80.0))
	var fov_radians: float = deg_to_rad(_world_camera.fov)
	var bloom_radius: float = tan(spread_edge_radians) * (
		viewport_size.y / (2.0 * tan(fov_radians / 2.0))
	)
	reticle_draw.set_bloom_radius(clampf(bloom_radius, 3.0, viewport_size.y * 0.25))

	var shoot_position: Node3D = _weapon_controller.shoot_position
	if shoot_position == null:
		return

	var fire_origin: Vector3 = shoot_position.global_position + _weapon_controller.shoot_position_offset
	var fire_direction: Vector3 = -shoot_position.global_transform.basis.z.normalized()
	var fire_range: float = (
		_weapon_controller.current_weapon.shoot_range
		if _weapon_controller.current_weapon != null
		else 100.0
	)
	var fire_endpoint: Vector3 = fire_origin + fire_direction * fire_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		fire_origin,
		fire_endpoint
	)
	var hit: Dictionary = _world_camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		fire_endpoint = hit.position
	if _world_camera.is_position_behind(fire_endpoint):
		return

	var camera_viewport_size: Vector2 = _world_camera.get_viewport().get_visible_rect().size
	if camera_viewport_size.x <= 0.0 or camera_viewport_size.y <= 0.0:
		return
	var projected_position: Vector2 = _world_camera.unproject_position(fire_endpoint)
	var ui_position: Vector2 = projected_position * viewport_size / camera_viewport_size
	var reticle_offset: Vector2 = ui_position - viewport_size * 0.5
	crosshair.offset_left = reticle_offset.x
	crosshair.offset_right = reticle_offset.x
	crosshair.offset_top = reticle_offset.y
	crosshair.offset_bottom = reticle_offset.y


func _resolve_crosshair_references() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		return

	if _weapon_controller == null or not is_instance_valid(_weapon_controller):
		_weapon_controller = _player.weapon_controller
	if _world_camera == null or not is_instance_valid(_world_camera):
		_world_camera = _player.get_node_or_null("CameraController/Cam") as Camera3D


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_K
	):
		$BuildMenu.toggle()
		get_viewport().set_input_as_handled()


func set_health_value(health: float, max_health: float) -> void:
	if health_bar:
		# print("Setting health value: ", health, " / ", max_health)
		health_bar.value = health
		health_bar.max_value = max_health
		if health_label:
			# remove decimal places from health value for display
			health_label.text = str(int(health))

func set_armor_value(armor: float, max_armor: float) -> void:
	if armor_bar:
		# print("Setting armor value: ", armor, " / ", max_armor)
		armor_bar.value = armor
		armor_bar.max_value = max_armor
		if armor_label:
			armor_label.text = str(int(armor))

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

func set_crosshair_visibility(_is_visible: bool) -> void:
	print("Setting crosshair visibility to: ", _is_visible)
	if crosshair:
		crosshair.visible = _is_visible

func set_2d_ammo_visibility(is_visible: bool) -> void:
	if ammo_container == null:
		return
	ammo_container.visible = is_visible
	for child: Node in ammo_container.find_children("*", "CanvasItem", true, false):
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null:
			canvas_item.visible = is_visible

func set_chamber_visual(is_chambered: bool) -> void:
	if not chamber_indicator: return
	
	# Green if a bullet is ready, Red if empty
	if is_chambered:
		chamber_indicator.color = Color("#00ff2a3d")
	else:
		chamber_indicator.color = Color("#ff002a3d")
# initialize the UI elements with default values
# func _ready() -> void:
