class_name GameEffects
extends RefCounted

const CYAN := Color("#78f4ff")
const CYAN_SOFT := Color("#3fc9dd")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")

var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var shake := 0.0
var flash_alpha := 0.0
var combo_pop := 0.0
var shake_offset := Vector2.ZERO


func _init() -> void:
    rng.seed = 0xA11CE55


func reset() -> void:
    particles.clear()
    floaters.clear()
    shake = 0.0
    flash_alpha = 0.0
    combo_pop = 0.0
    shake_offset = Vector2.ZERO


func update(delta: float, world: GameWorld) -> void:
    shake = move_toward(shake, 0.0, delta * 22.0)
    flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.9)
    combo_pop = move_toward(combo_pop, 0.0, delta * 5.0)
    shake_offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))

    for index in range(particles.size() - 1, -1, -1):
        var particle := particles[index]
        particle["life"] -= delta
        if particle["life"] <= 0.0:
            particles.remove_at(index)
            continue
        var velocity: Vector2 = particle["vel"]
        velocity.y += float(particle["gravity"]) * delta
        velocity *= exp(-float(particle["drag"]) * delta)
        particle["vel"] = velocity
        particle["pos"] += velocity * delta

    for index in range(floaters.size() - 1, -1, -1):
        var floater := floaters[index]
        floater["life"] -= delta
        if floater["life"] <= 0.0:
            floaters.remove_at(index)
        else:
            floater["pos"] += Vector2(0.0, -24.0 * delta)

    if world.state == GameWorld.State.PLAYING:
        for ball in world.balls:
            if world.is_fire_active() and rng.randf() <= 0.62:
                var side := Vector2(-ball.velocity.y, ball.velocity.x).normalized()
                emit_fire_ember(ball.position + side * rng.randf_range(-5.0, 5.0))
            if world.is_fire_active() or rng.randf() < 0.62:
                emit_ball_spark(ball, world.is_fire_active())


func handle_event(event: GameEvent, world: GameWorld) -> void:
    match event.type:
        GameEvent.Type.BALL_LAUNCHED:
            flash_alpha = maxf(flash_alpha, 0.08)
            emit_burst(event.position, event.color, 10, 90.0, 2.2, 90.0)
        GameEvent.Type.WALL_HIT:
            shake = maxf(shake, 1.4)
            emit_burst(event.position, event.color, 3, 55.0, 1.7, 40.0)
        GameEvent.Type.PADDLE_HIT:
            shake = maxf(shake, 2.8)
            flash_alpha = maxf(flash_alpha, 0.035)
            emit_burst(event.position + Vector2(0.0, 7.0), event.color, 12, 135.0, 2.8, 150.0)
        GameEvent.Type.BALL_LOST:
            shake = maxf(shake, 8.0)
            flash_alpha = maxf(flash_alpha, 0.10)
            emit_burst(event.position, event.color, 30, 230.0, 3.8, 360.0)
        GameEvent.Type.BRICK_HIT:
            shake = maxf(shake, 1.4)
            emit_burst(event.position, event.color.lightened(0.10), 5, 105.0, 2.1, 95.0)
        GameEvent.Type.BRICK_DESTROYED:
            combo_pop = 1.0
            var fire := world.is_fire_active()
            shake = maxf(shake, 3.8 if fire else 2.0)
            if fire:
                emit_burst(event.position, ORANGE, 20, 245.0, 3.4, 380.0)
                emit_burst(event.position, PINK, 10, 170.0, 2.5, 260.0)
            else:
                emit_burst(event.position, event.color.lightened(0.15), 14, 185.0, 3.0, 260.0)
                emit_burst(event.position, Color.WHITE, 3, 95.0, 1.8, 120.0)
        GameEvent.Type.POWERUP_DROPPED:
            emit_burst(event.position, event.color, 10, 105.0, 2.2, 80.0)
            add_floater(event.position + Vector2(0.0, -16.0), "POWER DROP", event.color, 12, 0.55)
        GameEvent.Type.POWERUP_COLLECTED:
            shake = maxf(shake, 4.5)
            flash_alpha = maxf(flash_alpha, 0.13)
            emit_burst(event.position, event.color, 26, 210.0, 3.5, 190.0)
            emit_burst(event.position, Color.WHITE, 7, 110.0, 1.8, 80.0)
        GameEvent.Type.SPEED_CHANGED:
            for ball in world.balls:
                emit_burst(ball.position, event.color, 10, 150.0, 2.5, 100.0)
        GameEvent.Type.FIRE_STARTED:
            combo_pop = 1.0
            flash_alpha = maxf(flash_alpha, 0.30)
            shake = maxf(shake, 7.0)
            for index in range(38):
                var position := Vector2(
                    rng.randf_range(world.config.inner_left, world.config.inner_right),
                    rng.randf_range(240.0, 780.0)
                )
                emit_fire_ember(position)
        GameEvent.Type.LEVEL_CLEARED:
            flash_alpha = maxf(flash_alpha, 0.22)
            shake = maxf(shake, 6.0)
        GameEvent.Type.LEVEL_STARTED:
            flash_alpha = maxf(flash_alpha, 0.18)
        GameEvent.Type.XP_LEVEL_UP:
            flash_alpha = maxf(flash_alpha, 0.12)
            shake = maxf(shake, 3.5)
            combo_pop = 1.0
            emit_burst(event.position, GOLD, 26, 190.0, 3.2, 120.0)
        GameEvent.Type.MESSAGE:
            add_floater(event.position, event.text, event.color, event.size, event.lifetime)
        GameEvent.Type.OBSTACLE_HIT:
            emit_burst(event.position, event.color, 7, 130.0, 2.4, 120.0)
        GameEvent.Type.BALL_SPLIT:
            emit_burst(event.position, event.color, 9, 125.0, 2.4, 80.0)
        GameEvent.Type.COMBO_POP:
            combo_pop = 1.0


func emit_burst(position: Vector2, color: Color, count: int, speed: float, size: float, gravity: float) -> void:
    for index in range(count):
        var angle := rng.randf_range(0.0, TAU)
        var magnitude := rng.randf_range(speed * 0.22, speed)
        var life := rng.randf_range(0.30, 0.82)
        particles.append({
            "pos": position + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
            "vel": Vector2(cos(angle), sin(angle)) * magnitude,
            "life": life,
            "max_life": life,
            "color": color,
            "size": rng.randf_range(1.1, size),
            "gravity": gravity,
            "drag": rng.randf_range(1.8, 4.2),
        })
    if particles.size() > 760:
        particles = particles.slice(particles.size() - 760)


func emit_ball_spark(ball: BallData, fire: bool) -> void:
    var direction := ball.velocity.normalized()
    var side := Vector2(-direction.y, direction.x)
    var life := rng.randf_range(0.16, 0.46)
    var color := GOLD.lerp(PINK, rng.randf()) if fire else CYAN.lerp(PINK, rng.randf_range(0.0, 0.35))
    particles.append({
        "pos": ball.position - direction * rng.randf_range(4.0, 12.0) + side * rng.randf_range(-4.0, 4.0),
        "vel": -direction * rng.randf_range(22.0, 90.0) + side * rng.randf_range(-34.0, 34.0),
        "life": life,
        "max_life": life,
        "color": color,
        "size": rng.randf_range(0.9, 2.4),
        "gravity": 18.0,
        "drag": rng.randf_range(1.0, 2.6),
    })


func emit_fire_ember(position: Vector2) -> void:
    var life := rng.randf_range(0.25, 0.7)
    var color: Color = GOLD
    var pick := rng.randi_range(0, 2)
    if pick == 1:
        color = ORANGE
    elif pick == 2:
        color = PINK
    particles.append({
        "pos": position,
        "vel": Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-80.0, 20.0)),
        "life": life,
        "max_life": life,
        "color": color,
        "size": rng.randf_range(1.2, 3.2),
        "gravity": -35.0,
        "drag": 1.4,
    })


func add_floater(position: Vector2, text: String, color: Color, size: int, lifetime: float) -> void:
    floaters.append({
        "pos": position,
        "text": text,
        "color": color,
        "size": size,
        "life": lifetime,
        "max_life": lifetime,
    })
    if floaters.size() > 55:
        floaters.remove_at(0)
