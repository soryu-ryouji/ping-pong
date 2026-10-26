class_name MultiballPowerup
extends PowerupDefinition


func apply(world: Variant, pickup_position: Vector2) -> void:
    if world.balls.is_empty():
        world.add_message(pickup_position, "MULTIBALL READY", color, 19, 1.0)
        return

    var originals: Array = world.balls.duplicate()
    var added := 0
    for source: BallData in originals:
        if world.balls.size() >= world.config.powerup_max_balls:
            break
        var offset := Vector2(
            world.rng.randf_range(-7.0, 7.0),
            world.rng.randf_range(-7.0, 7.0)
        )
        var direction := 1.0 if world.rng.randf() > 0.5 else -1.0
        var split_angle: float = world.rng.randf_range(0.38, 0.72) * direction
        var copy := source.copy_for_split(offset, split_angle, world.rng.randf_range(-1.0, 1.0))
        world.balls.append(copy)
        world.emit_event(GameEvent.Type.BALL_SPLIT, copy.position, color)
        added += 1

    world.notify_combo_pop()
    if added > 0:
        world.add_message(pickup_position + Vector2(0.0, -20.0), "BALLS ×2", color, 24, 1.0)
    else:
        world.add_message(pickup_position + Vector2(0.0, -20.0), "MAX BALLS", color, 18, 0.8)
