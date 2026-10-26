class_name GameWorld
extends RefCounted

const CYAN := Color("#78f4ff")
const CYAN_SOFT := Color("#3fc9dd")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")
const GREEN := Color("#c9ff72")
const DANGER := Color("#ff4d79")

enum State { READY, PLAYING, CLEARED, GAME_OVER }

var config: GameConfig
var rng := RandomNumberGenerator.new()
var collision := CollisionSystem.new()
var events: Array[GameEvent] = []

var state := State.READY
var wave := 1
var lives := 5
var lost_count := 0
var combo := 0
var next_multiball_at := 30
var remaining_bricks := 0
var total_bricks := 1
var clear_fraction := 0.0
var fire_energy := 0.0
var fire_time := 0.0
var respawn_timer := 0.0
var state_timer := 0.0
var game_time := 0.0

var paddle_x := 360.0
var paddle_target_x := 360.0
var paddle_velocity := 0.0
var balls: Array[BallData] = []
var bricks: Array[BrickData] = []
var walls: Array[Rect2] = []
var powerups: Array[PowerupData] = []
var powerup_pity := 0
var powerup_drop_counter := 0


func _init(game_config: GameConfig) -> void:
    config = game_config
    rng.seed = config.random_seed


func reset_run() -> void:
    rng.seed = config.random_seed
    wave = 1
    lives = config.initial_lives
    lost_count = 0
    combo = 0
    next_multiball_at = config.combo_first_multiball
    powerup_pity = 0
    powerup_drop_counter = 0
    fire_energy = 0.0
    fire_time = 0.0
    game_time = 0.0
    state_timer = 0.0
    state = State.READY
    reset_ball_state()
    events.clear()
    emit_event(GameEvent.Type.RUN_RESET)
    build_level()


func build_level() -> void:
    bricks = LevelGenerator.generate(config.level, wave, rng)
    walls = config.level.walls.duplicate()
    total_bricks = maxi(bricks.size(), 1)
    remaining_bricks = 0
    for brick in bricks:
        if brick.alive:
            remaining_bricks += 1
    clear_fraction = 1.0 - float(remaining_bricks) / float(total_bricks)


func reset_ball_state() -> void:
    balls.clear()
    powerups.clear()
    paddle_x = config.screen_size.x * 0.5
    paddle_target_x = paddle_x
    paddle_velocity = 0.0
    respawn_timer = 0.0


func next_wave() -> void:
    wave += 1
    combo = 0
    next_multiball_at = config.combo_first_multiball
    fire_energy = 0.0
    fire_time = 0.0
    build_level()
    reset_ball_state()
    state = State.READY
    var event := emit_event(GameEvent.Type.WAVE_STARTED, Vector2(config.screen_size.x * 0.5, 350.0), CYAN)
    event.value = wave
    add_message(event.position, "WAVE %02d" % wave, CYAN, 28, 1.1)


func primary_action() -> void:
    if state == State.READY:
        state = State.PLAYING
        launch_ball(false)
        add_message(Vector2(paddle_x, config.paddle_y - 52.0), "LAUNCH", CYAN, 18, 0.55)
    elif state == State.GAME_OVER:
        reset_run()
    elif state == State.CLEARED:
        state_timer = 0.0


func step(delta: float) -> void:
    game_time += delta
    update_paddle(delta)

    if state == State.PLAYING:
        if fire_time > 0.0:
            fire_time = maxf(0.0, fire_time - delta)
            if fire_time <= 0.0:
                fire_energy = 0.0
                emit_event(GameEvent.Type.FIRE_ENDED)
                add_message(Vector2(config.screen_size.x * 0.5, 690.0), "FIRE RUSH END", ORANGE, 20, 0.8)

        if respawn_timer > 0.0:
            respawn_timer -= delta
            if respawn_timer <= 0.0 and balls.is_empty():
                state = State.READY
                add_message(Vector2(paddle_x, config.paddle_y - 54.0), "BALL %02d" % lives, CYAN, 18, 0.7)

        update_powerups(delta)
        update_balls(delta)
    elif state == State.CLEARED:
        state_timer -= delta
        if state_timer <= 0.0:
            next_wave()

    update_bricks(delta)


func set_paddle_target(screen_x: float) -> void:
    var half_width := config.paddle_width * 0.5
    paddle_target_x = clampf(
        screen_x,
        config.inner_left + half_width + 5.0,
        config.inner_right - half_width - 5.0
    )


func nudge_paddle(direction: float, delta: float) -> void:
    if absf(direction) <= 0.01:
        return
    var half_width := config.paddle_width * 0.5
    paddle_target_x = clampf(
        paddle_target_x + direction * 760.0 * delta,
        config.inner_left + half_width + 5.0,
        config.inner_right - half_width - 5.0
    )


func update_paddle(delta: float) -> void:
    var previous := paddle_x
    paddle_x = lerpf(paddle_x, paddle_target_x, 1.0 - exp(-18.0 * delta))
    paddle_velocity = (paddle_x - previous) / maxf(delta, 0.0001)


func launch_ball(extra: bool) -> void:
    if balls.size() >= config.maximum_launch_balls:
        return
    var speed := config.base_ball_speed + float(wave - 1) * config.wave_speed_increment
    var angle := rng.randf_range(0.42, 0.74) * (1.0 if rng.randf() > 0.5 else -1.0)
    if extra:
        speed += 28.0
        angle = rng.randf_range(0.45, 0.92) * (1.0 if rng.randf() > 0.5 else -1.0)
    var ball := BallData.new()
    ball.position = Vector2(paddle_x, config.paddle_y - 28.0)
    ball.velocity = Vector2(sin(angle), -cos(angle)) * speed
    ball.spin = rng.randf_range(-1.0, 1.0)
    balls.append(ball)
    emit_event(GameEvent.Type.BALL_LAUNCHED, ball.position, CYAN_SOFT)


func update_balls(delta: float) -> void:
    for index in range(balls.size() - 1, -1, -1):
        var ball := balls[index]
        var lost := collision.step(self, ball, delta)
        if lost:
            var lost_position := ball.position
            balls.remove_at(index)
            lost_count += 1
            combo = 0
            next_multiball_at = config.combo_first_multiball
            emit_event(GameEvent.Type.BALL_LOST, lost_position, DANGER)
            add_message(lost_position, "BALL LOST", DANGER, 18, 0.9)
            if balls.is_empty():
                powerups.clear()
                lives -= 1
                if lives > 0:
                    respawn_timer = 1.15
                else:
                    state = State.GAME_OVER
                    emit_event(GameEvent.Type.GAME_OVER)
                    add_message(Vector2(config.screen_size.x * 0.5, 390.0), "RUN COMPLETE", PINK, 26, 1.4)
        else:
            ball.trail.append(ball.position)
            while ball.trail.size() > 15:
                ball.trail.remove_at(0)


func try_drop_powerup(center: Vector2, fire: bool) -> void:
    if powerups.size() >= config.powerup_max_active:
        return
    powerup_pity += 1
    var chance := config.powerup_drop_chance * (config.fire_drop_chance_multiplier if fire else 1.0)
    if powerup_pity < config.powerup_pity_limit and rng.randf() > chance:
        return
    powerup_pity = 0
    var definition := config.powerups.definition_at(powerup_drop_counter)
    if definition == null:
        return
    powerup_drop_counter += 1
    _spawn_powerup(definition, center)


func spawn_powerup(powerup_id: StringName, center: Vector2, initial_velocity := Vector2.ZERO) -> PowerupData:
    var definition := config.powerups.get_definition(powerup_id)
    if definition == null:
        push_error("Unknown powerup: %s" % powerup_id)
        return null
    return _spawn_powerup(definition, center, initial_velocity)


func _spawn_powerup(definition: PowerupDefinition, center: Vector2, initial_velocity := Vector2.ZERO) -> PowerupData:
    var item := PowerupData.new()
    item.definition = definition
    item.position = center
    item.velocity = initial_velocity
    if initial_velocity == Vector2.ZERO:
        item.velocity = Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(72.0, 118.0))
    item.phase = rng.randf_range(0.0, TAU)
    powerups.append(item)
    emit_event(GameEvent.Type.POWERUP_DROPPED, center, definition.color)
    return item


func update_powerups(delta: float) -> void:
    for index in range(powerups.size() - 1, -1, -1):
        var item := powerups[index]
        item.age += delta
        item.velocity.y = minf(item.velocity.y + 92.0 * delta, 235.0)
        item.velocity.x *= exp(-0.8 * delta)
        item.position += item.velocity * delta

        if item.position.x < config.inner_left + 13.0:
            item.position.x = config.inner_left + 13.0
            item.velocity.x = absf(item.velocity.x) * 0.72
        elif item.position.x > config.inner_right - 13.0:
            item.position.x = config.inner_right - 13.0
            item.velocity.x = -absf(item.velocity.x) * 0.72

        if item.position.y > config.field_bottom + 30.0:
            powerups.remove_at(index)
            continue
        if item.position.y >= config.paddle_y - 24.0 and item.position.y <= config.paddle_y + 18.0:
            if absf(item.position.x - paddle_x) <= config.paddle_width * 0.5 + 14.0:
                collect_powerup(item)
                powerups.remove_at(index)


func collect_powerup(item: PowerupData) -> void:
    var event := emit_event(GameEvent.Type.POWERUP_COLLECTED, item.position, item.definition.color)
    event.value = item.definition.pickup_pitch
    item.definition.apply(self, item.position)


func on_wall_hit(hit_position: Vector2) -> void:
    emit_event(GameEvent.Type.WALL_HIT, hit_position, CYAN_SOFT)


func on_paddle_hit(hit_position: Vector2) -> void:
    emit_event(GameEvent.Type.PADDLE_HIT, hit_position, CYAN)
    add_message(hit_position + Vector2(0.0, -20.0), "+SPEED", CYAN_SOFT, 13, 0.42)


func destroy_brick(brick: BrickData) -> void:
    if not brick.alive:
        return
    brick.alive = false
    brick.flash = 1.0
    remaining_bricks -= 1

    var center := brick.rect.get_center()
    var fire := is_fire_active()
    var gain := 2 if fire else 1
    combo += gain

    var event := emit_event(GameEvent.Type.BRICK_DESTROYED, center, brick.color)
    event.value = gain
    add_message(center, "+%d" % gain, brick.color.lightened(0.35), 14, 0.45)
    if combo > 0 and combo % 10 == 0:
        add_message(center + Vector2(0.0, -18.0), "×%d" % combo, GOLD, 20, 0.70)

    if fire:
        fire_energy = 100.0
    else:
        fire_energy = minf(100.0, fire_energy + config.fire_charge_per_hit)
    try_drop_powerup(center, fire)

    while combo >= next_multiball_at and balls.size() < config.combo_multiball_limit:
        next_multiball_at += config.combo_multiball_interval
        launch_ball(true)
        add_message(Vector2(paddle_x, config.paddle_y - 58.0), "MULTIBALL", CYAN, 18, 0.8)

    if fire_energy >= 100.0 and not fire:
        start_fire_rush()

    clear_fraction = 1.0 - float(remaining_bricks) / float(total_bricks)
    if remaining_bricks <= 0:
        clear_level()


func start_fire_rush() -> void:
    if fire_time > 0.0:
        return
    fire_time = config.fire_duration
    fire_energy = 100.0
    emit_event(GameEvent.Type.FIRE_STARTED, Vector2(config.screen_size.x * 0.5, 565.0), ORANGE)
    add_message(Vector2(config.screen_size.x * 0.5, 565.0), "FIRE RUSH", ORANGE, 34, 1.2)


func clear_level() -> void:
    if state == State.CLEARED:
        return
    state = State.CLEARED
    state_timer = 2.35
    clear_fraction = 1.0
    powerups.clear()
    combo += 25
    emit_event(GameEvent.Type.WAVE_CLEARED, Vector2(config.screen_size.x * 0.5, 330.0), GREEN)
    add_message(Vector2(config.screen_size.x * 0.5, 330.0), "WAVE CLEAR", GREEN, 34, 1.5)
    add_message(Vector2(config.screen_size.x * 0.5, 376.0), "+25 BONUS", GOLD, 20, 1.4)


func update_bricks(delta: float) -> void:
    for brick in bricks:
        if brick.flash > 0.0:
            brick.flash = maxf(0.0, brick.flash - delta * 5.0)


func is_fire_active() -> bool:
    return fire_time > 0.0


func emit_event(event_type: GameEvent.Type, event_position := Vector2.ZERO, event_color := Color.WHITE) -> GameEvent:
    var event := GameEvent.new(event_type, event_position, event_color)
    events.append(event)
    return event


func add_message(event_position: Vector2, text: String, event_color: Color, size: int, lifetime: float) -> void:
    var event := emit_event(GameEvent.Type.MESSAGE, event_position, event_color)
    event.text = text
    event.size = size
    event.lifetime = lifetime


func notify_combo_pop() -> void:
    emit_event(GameEvent.Type.COMBO_POP)


func drain_events() -> Array[GameEvent]:
    var result := events.duplicate()
    events.clear()
    return result
