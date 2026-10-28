class_name SpringUtil

static func apply(value: float, velocity: float, target: float, delta: float, stiffness: float, damping: float) -> Vector2:
    # Keep a frame hitch from injecting an excessively large spring impulse.
    var safe_delta: float = minf(maxf(delta, 0.0), 1.0 / 30.0)
    var force: float = (target - value) * stiffness
    velocity += force * safe_delta
    velocity *= maxf(1.0 - damping * safe_delta, 0.0)
    value += velocity * safe_delta
    return Vector2(value, velocity)