class_name SpringUtil

static func apply(value: float, velocity: float, target: float, delta: float, stiffness: float, damping: float):
    var force = (target - value) * stiffness
    velocity += force * delta
    velocity *= 1.0 - damping * delta
    value += velocity * delta
    return Vector2(value, velocity)