class_name SlideDriver extends RefCounted
## Drives the slide/bolt position from code.
##   value 0.0 = closed (Close_bolt pose)
##   value 1.0 = fully open (Open_bolt pose)
## `apply` receives the value every time it changes; WeaponActions points it at
## WeaponAnimation.set_slide_value(), which writes the BoltPosition blend.
##
## A new move always starts from the CURRENT value, so overlapping actions
## (rapid fire, reload during a return) never pop or stack.

## ease() curves. <1 = fast start (blowback / pulling), >1 = accelerating (snapping closed).
var back_curve: float = 0.35
var return_curve: float = 2.2

var value: float = 0.0
## While locked the slide is held open: shots and kicks are ignored until release().
var locked: bool = false
var lock_value: float = 1.0
var apply: Callable = Callable()

var _queue: Array[Dictionary] = []
var _from: float = 0.0
var _to: float = 0.0
var _dur: float = 0.0
var _curve: float = 1.0
var _t: float = 0.0
var _moving: bool = false


## Jump to a value with no motion (equip, weapon swap).
func snap(v: float) -> void:
	_queue.clear()
	_moving = false
	_write_value(v)


## Move to `target`. replace = true cancels whatever was queued or moving.
func move_to(target: float, duration: float, curve: float = 1.0, replace: bool = true) -> void:
	if replace:
		_queue.clear()
		_moving = false
	_queue.append({"target": target, "dur": duration, "curve": curve})
	if not _moving:
		_next()


## One shot cycle: blow back to `peak`, then return to closed.
## stay_open = true (last round): blow back and hold open.
func kick(peak: float, back_time: float, return_time: float, stay_open: bool = false) -> void:
	if locked:
		return
	move_to(peak, back_time, back_curve)
	if stay_open:
		locked = true
		lock_value = 1.0
		if absf(peak - lock_value) > 0.001:
			move_to(lock_value, return_time * 0.5, 1.0, false)
	else:
		move_to(0.0, return_time, return_curve, false)


## Hold the slide open at `at`.
func lock(at: float = 1.0, duration: float = 0.0) -> void:
	locked = true
	lock_value = at
	move_to(at, duration, 1.0)


## Let go of a lock. Does not move anything by itself; follow with move_to().
func release() -> void:
	locked = false


func tick(delta: float) -> void:
	if not _moving:
		# Pin the pose every frame so nothing else can silently reset the blend value.
		if apply.is_valid():
			apply.call(value)
		return
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0) # _dur > 0 here, see _next()
	_write_value(lerpf(_from, _to, ease(k, _curve)))
	if k >= 1.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_moving = false
		return
	var seg: Dictionary = _queue.pop_front()
	_from = value
	_to = float(seg["target"])
	_dur = maxf(float(seg["dur"]), 0.0)
	_curve = float(seg["curve"])
	_t = 0.0
	_moving = true
	if _dur <= 0.0:
		_write_value(_to)
		_next()


func _write_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	if apply.is_valid():
		apply.call(value)
