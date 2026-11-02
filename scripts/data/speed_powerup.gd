class_name SpeedPowerup
extends PowerupDefinition

@export_range(1.0, 3.0) var multiplier := 1.18
@export var maximum_speed := 1410.0


func apply(world: Variant, pickup_position: Vector2) -> void:
    var speed_cap := minf(maximum_speed, world.config.max_ball_speed)
    for ball: BallData in world.balls:
        var speed := ball.velocity.length()
        if speed < 0.001:
            continue
        ball.velocity = ball.velocity.normalized() * minf(speed * multiplier, speed_cap)

    world.notify_combo_pop()
    world.emit_event(GameEvent.Type.SPEED_CHANGED, pickup_position, color)
    world.add_message(pickup_position + Vector2(0.0, -20.0), "SPEED UP", color, 24, 1.0)
    world.add_message(
        Vector2(world.config.screen_size.x * 0.5, 708.0),
        "+%d%% BALL SPEED" % int(round((multiplier - 1.0) * 100.0)),
        Color("#ff9b45"),
        15,
        0.8
    )
