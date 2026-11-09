class_name SpringUtil

static func apply(value: float, velocity: float, target: float, delta: float, stiffness: float, damping: float) -> Vector2:
    # Keep a frame hitch from injecting an excessively large spring impulse.
    var safe_delta: float = minf(maxf(delta, 0.0), 1.0 / 30.0)
    var force: float = (target - value) * stiffness
    velocity += force * safe_delta
    velocity *= maxf(1.0 - damping * safe_delta, 0.0)
    value += velocity * safe_delta
    return Vector2(value, velocity)

## Frame-rate independent spring. Same signature as apply(), but damping is
## exp(-c*dt) and the step is sub-divided, so the result no longer depends on FPS.
## Use this for anything that should feel identical at 60 and 144+ FPS.
static func apply_stable(value: float, velocity: float, target: float, delta: float, stiffness: float, damping: float) -> Vector2:
    var remaining: float = minf(maxf(delta, 0.0), 1.0 / 20.0)
    while remaining > 0.0:
        var dt: float = minf(remaining, 1.0 / 240.0)
        velocity += (target - value) * stiffness * dt
        velocity *= exp(-damping * dt)
        value += velocity * dt
        remaining -= dt
    return Vector2(value, velocity)