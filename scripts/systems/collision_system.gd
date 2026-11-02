class_name CollisionSystem
extends RefCounted


func step(world: Variant, ball: BallData, delta: float) -> bool:
    var config: GameConfig = world.config
    var speed := ball.velocity.length()
    var substeps := clampi(int(ceil(speed * delta / 4.5)), 1, 14)
    var sub_delta := delta / float(substeps)

    for _substep in range(substeps):
        ball.position += ball.velocity * sub_delta

        if ball.position.x - ball.radius < config.inner_left:
            ball.position.x = config.inner_left + ball.radius
            ball.velocity.x = absf(ball.velocity.x)
            world.boost_ball_speed(ball, config.bounce_speed_increment)
            world.on_wall_hit(ball.position)
        elif ball.position.x + ball.radius > config.inner_right:
            ball.position.x = config.inner_right - ball.radius
            ball.velocity.x = -absf(ball.velocity.x)
            world.boost_ball_speed(ball, config.bounce_speed_increment)
            world.on_wall_hit(ball.position)

        if ball.position.y - ball.radius < config.inner_top:
            ball.position.y = config.inner_top + ball.radius
            ball.velocity.y = absf(ball.velocity.y)
            world.boost_ball_speed(ball, config.bounce_speed_increment)
            world.on_wall_hit(ball.position)
        elif ball.position.y - ball.radius > config.field_bottom + 22.0:
            return true

        collide_paddle(world, ball)
        collide_walls(world, ball)
        collide_breakable_walls(world, ball)
        collide_bricks(world, ball)

        if absf(ball.velocity.y) < 92.0 and ball.velocity.length_squared() > 1.0:
            var target_speed := ball.velocity.length()
            ball.velocity.y = -92.0 if ball.velocity.y <= 0.0 else 92.0
            ball.velocity = ball.velocity.normalized() * target_speed
    return false


func collide_paddle(world: Variant, ball: BallData) -> void:
    if ball.velocity.y <= 0.0:
        return
    var config: GameConfig = world.config
    var paddle_rect := Rect2(
        world.paddle_x - world.paddle_width * 0.5,
        config.paddle_y - config.paddle_height * 0.5,
        world.paddle_width,
        config.paddle_height
    )
    var hit := CollisionGeometry.circle_rect_hit(ball.position, ball.radius, paddle_rect)
    if hit == null:
        return

    ball.position.y = paddle_rect.position.y - ball.radius - 0.2
    var relative := clampf((ball.position.x - world.paddle_x) / (world.paddle_width * 0.5), -1.0, 1.0)
    var incoming_speed := ball.velocity.length()
    var speed := maxf(incoming_speed + 7.0, 470.0)
    if incoming_speed <= config.max_ball_speed:
        speed = minf(speed, config.max_ball_speed)
    var angle := relative * 1.02
    var new_velocity := Vector2(sin(angle), -cos(angle)) * speed
    new_velocity.x += clampf(world.paddle_velocity * 0.10, -110.0, 110.0)

    var incoming_side := signf(ball.velocity.x)
    if absf(incoming_side) < 0.1:
        incoming_side = 1.0 if world.rng.randf() > 0.5 else -1.0
    var minimum_horizontal := speed * 0.17
    if absf(new_velocity.x) < minimum_horizontal:
        new_velocity.x = incoming_side * minimum_horizontal

    if new_velocity.length() > 0.001:
        ball.velocity = new_velocity.normalized() * speed
    else:
        ball.velocity = Vector2(incoming_side * speed * 0.2, -speed * 0.98).normalized() * speed
    world.on_paddle_hit(ball.position)


func collide_walls(world: Variant, ball: BallData) -> void:
    var config: GameConfig = world.config
    for wall: Rect2 in world.walls:
        var hit := CollisionGeometry.circle_rect_hit(ball.position, ball.radius, wall)
        if hit == null:
            continue
        ball.position += hit.normal * hit.penetration
        if ball.velocity.dot(hit.normal) < 0.0:
            ball.velocity = ball.velocity.bounce(hit.normal)
            world.boost_ball_speed(ball, config.bounce_speed_increment)
            world.emit_event(GameEvent.Type.OBSTACLE_HIT, ball.position + hit.normal * 3.0, Color("#a9c4d8"))
        break


func collide_breakable_walls(world: Variant, ball: BallData) -> bool:
    var config: GameConfig = world.config
    for wall: BreakableWallData in world.breakable_walls:
        if not wall.alive:
            continue
        var hit := CollisionGeometry.circle_rect_hit(ball.position, ball.radius, wall.rect)
        if hit == null:
            continue
        var hit_speed := ball.velocity.length()
        ball.position += hit.normal * hit.penetration
        if ball.velocity.dot(hit.normal) < 0.0:
            ball.velocity = ball.velocity.bounce(hit.normal)
            world.boost_ball_speed(ball, config.bounce_speed_increment)
            world.emit_event(GameEvent.Type.OBSTACLE_HIT, ball.position + hit.normal * 3.0, Color("#ffb45e"))
        world.hit_breakable_wall(wall, hit_speed)
        return true
    return false


func collide_bricks(world: Variant, ball: BallData) -> bool:
    var config: GameConfig = world.config
    var fire: bool = world.is_fire_active()
    for brick: BrickData in world.bricks:
        if not brick.alive:
            continue
        if not brick.rect.grow(ball.radius).has_point(ball.position):
            continue
        var hit := CollisionGeometry.circle_rect_hit(ball.position, ball.radius, brick.rect)
        if hit == null:
            continue

        if not fire:
            ball.position += hit.normal * hit.penetration
            if ball.velocity.dot(hit.normal) < 0.0:
                ball.velocity = ball.velocity.bounce(hit.normal)
                world.boost_ball_speed(ball, config.bounce_speed_increment)
        world.hit_brick(brick, 999 if fire else 1)
        if not fire:
            return true
    return false
