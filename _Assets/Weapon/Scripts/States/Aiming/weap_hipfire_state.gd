extends WeaponState

var press_start_time: int = 0
var is_pressing: bool = false
const HOLD_THRESHOLD_MS: int = 200 # 0.2 seconds = Hold

func _on_hipfire_state_state_entered() -> void:
	if weapon_controller:
		weapon_controller.aim_hipfire()
		is_pressing = false # Reset safety

func _on_hipfire_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
	
	# 1. Detect the exact millisecond the mouse is clicked
	if Input.is_action_just_pressed("combat_aim"):
		press_start_time = Time.get_ticks_msec()
		is_pressing = true

	if is_pressing:
		var hold_duration = Time.get_ticks_msec() - press_start_time
		
		# Rule A (HOLD): They held it past 200ms -> Go to Canted
		if hold_duration >= HOLD_THRESHOLD_MS:
			is_pressing = false
			weapon_controller.weapon_state_chart.send_event("onCanted")
			
		# Rule B (TAP): They let go BEFORE 200ms -> Go to ADS
		elif Input.is_action_just_released("combat_aim"):
			is_pressing = false
			weapon_controller.weapon_state_chart.send_event("onAiming")