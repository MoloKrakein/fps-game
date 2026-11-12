class_name ActionTimeline extends RefCounted
## Runs ONE action at a time on a gameplay clock.
##
## Gameplay time is authoritative: the action lasts exactly `duration` seconds
## (already adjusted for skills) and fires its events at fixed fractions of that.
## Every event crossed in one tick fires in order, so even a 0-second action
## still runs mag_out -> mag_in -> finished.
##
## Do not start a new action from inside an event handler.

signal event(action: StringName, event_name: StringName)
signal finished(action: StringName)
signal cancelled(action: StringName, progress: float)

var action: StringName = &""
var duration: float = 0.0
var elapsed: float = 0.0
var running: bool = false

var _events: Array[ActionEvent] = []
var _next: int = 0
var _serial: int = 0 # bumps on start/stop/cancel so a running tick can notice


func start(def: ActionDef, target_duration: float) -> void:
	_serial += 1
	action = def.id
	_events.assign(def.events)
	_events.sort_custom(func(a: ActionEvent, b: ActionEvent) -> bool: return a.fraction < b.fraction)
	duration = maxf(target_duration, 0.0)
	elapsed = 0.0
	_next = 0
	running = true
	tick(0.0) # fraction-0 events fire now; zero-length actions finish now


func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(elapsed / duration, 0.0, 1.0)


## Fraction of a named event, or `fallback` when this action has no such event.
func fraction_of(event_name: StringName, fallback: float = 0.0) -> float:
	for ev: ActionEvent in _events:
		if ev.event_name == event_name:
			return ev.fraction
	return fallback


func tick(delta: float) -> void:
	if not running:
		return

	elapsed += delta
	var p: float = progress()
	var serial: int = _serial

	while _next < _events.size() and _events[_next].fraction <= p:
		var ev: ActionEvent = _events[_next]
		_next += 1
		event.emit(action, ev.event_name)
		if serial != _serial or not running:
			return # a handler stopped or replaced us

	if p >= 1.0:
		running = false
		finished.emit(action)


## Jump to the end: every remaining event fires, then `finished`.
func finish_now() -> void:
	if not running:
		return
	elapsed = maxf(elapsed, duration)
	tick(0.0)


## Abort without firing the remaining events. Emits `cancelled`.
func cancel() -> void:
	if not running:
		return
	running = false
	_serial += 1
	cancelled.emit(action, progress())


## Abort silently (no signals). Used when the model is being replaced.
func stop() -> void:
	running = false
	_serial += 1
