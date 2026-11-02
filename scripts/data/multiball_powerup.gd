class_name MultiballPowerup
extends PowerupDefinition


func apply(world: Variant, pickup_position: Vector2) -> void:
    if world.balls.is_empty():
        world.add_message(pickup_position, "MULTIBALL READY", color, 19, 1.0)
        return

    var added: int = world.double_balls(color)
    world.notify_combo_pop()
    if added > 0:
        world.add_message(pickup_position + Vector2(0.0, -20.0), "BALLS ×2", color, 24, 1.0)
    else:
        world.add_message(pickup_position + Vector2(0.0, -20.0), "MAX BALLS", color, 18, 0.8)
