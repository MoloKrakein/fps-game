class_name VfxCurves extends RefCounted
## Small cached ramps and curves shared by the muzzle VFX, so nothing is built twice.

static var _cache: Dictionary = {}


## Alpha over a particle's life: quick fade in, a short hold, then fade out.
static func fade_ramp(fade_in: float = 0.06, hold_until: float = 0.4) -> GradientTexture1D:
	var key: String = "fade_%s_%s" % [fade_in, hold_until]
	if _cache.has(key):
		return _cache[key]
	var gradient := Gradient.new()                      # starts with two points: offset 0 and offset 1
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(fade_in, Color(1, 1, 1, 1))
	gradient.add_point(hold_until, Color(1, 1, 1, 0.7))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	_cache[key] = tex
	return tex


## For the muzzle flash: full brightness at the start, gone at the end.
static func flash_ramp() -> GradientTexture1D:
	if _cache.has("flash"):
		return _cache["flash"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.4, Color(1, 1, 1, 0.6))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	_cache["flash"] = tex
	return tex


## Scale over a particle's life: starts at start_scale, grows fast, then slows down.
static func grow_curve(start_scale: float = 0.4) -> CurveTexture:
	var key: String = "grow_%s" % start_scale
	if _cache.has(key):
		return _cache[key]
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, start_scale))
	curve.add_point(Vector2(0.3, lerpf(start_scale, 1.0, 0.75)))
	curve.add_point(Vector2(1.0, 1.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	_cache[key] = tex
	return tex
