class_name CasingTube extends RefCounted
## Runtime state for weapons whose casings queue in a tube before leaving (FN F2000 style).
## Keep one per weapon in your shooter. Without a tube (tube_capacity <= 0) every shot ejects one.

var count: int = 0


## Call once per shot. Returns how many casings should be ejected right now.
func add_shot(profile: CasingEjectionProfile) -> int:
	if profile == null or profile.tube_capacity <= 0:
		return 1
	count += 1
	if count <= profile.tube_capacity:
		return 0
	var released: int = 1
	if randf() < profile.tube_extra_chance:
		released += 1
	released = mini(released, count)
	count -= released
	return released


## Empties the tube (reload, tipping the muzzle down, weapon swap). Returns how many fall out.
func flush() -> int:
	var n: int = count
	count = 0
	return n


func reset() -> void:
	count = 0
