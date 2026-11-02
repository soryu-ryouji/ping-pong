class_name GameWorld
extends RefCounted

const CYAN := Color("#78f4ff")
const CYAN_SOFT := Color("#3fc9dd")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")
const GREEN := Color("#c9ff72")
const DANGER := Color("#ff4d79")
const BLUE := Color("#4da3ff")

enum State { READY, PLAYING, CLEARED, GAME_OVER }

var config: GameConfig
var levels: Array[LevelDefinition] = []
var rng := RandomNumberGenerator.new()
var collision := CollisionSystem.new()
var events: Array[GameEvent] = []

var state := State.READY
var wave := 1
var level_index := 0
var loop_count := 1
var lives := 5
var lost_count := 0
var combo := 0
var next_life_reward_at := 30
var xp := 0.0
var xp_level := 1
var xp_required := 150.0
var xp_flash := 0.0
var remaining_bricks := 0
var total_bricks := 1
var clear_fraction := 0.0
var fire_energy := 0.0
var fire_time := 0.0
var respawn_timer := 0.0
var game_time := 0.0

var paddle_x := 360.0
var paddle_target_x := 360.0
var paddle_velocity := 0.0
var paddle_width := 116.0
var paddle_flash := 0.0
var balls: Array[BallData] = []
var bricks: Array[BrickData] = []
var walls: Array[Rect2] = []
var breakable_walls: Array[BreakableWallData] = []
var powerups: Array[PowerupData] = []
var powerup_pity := 0
var powerup_drop_counter := 0


func _init(game_config: GameConfig) -> void:
    config = game_config
    rng.seed = config.random_seed
    paddle_width = config.paddle_width
    paddle_flash = 0.0
    xp_level = 1
    xp_required = maxf(config.xp_required_base, 1.0)
    xp_flash = 0.0
    levels = LevelLoader.load_manifest(config.level_manifest, config)


func reset_run() -> void:
    rng.seed = config.random_seed
    wave = 1
    level_index = 0
    loop_count = 1
    lives = config.initial_lives
    lost_count = 0
    combo = 0
    next_life_reward_at = config.combo_first_life_reward
    xp = 0.0
    xp_level = 1
    xp_required = maxf(config.xp_required_base, 1.0)
    xp_flash = 0.0
    powerup_pity = 0
    powerup_drop_counter = 0
    fire_energy = 0.0
    fire_time = 0.0
    game_time = 0.0
    paddle_width = config.paddle_width
    paddle_flash = 0.0
    state = State.READY
    reset_ball_state()
    events.clear()
    emit_event(GameEvent.Type.RUN_RESET)
    build_level()


func build_level() -> void:
    var definition := current_level()
    if definition == null:
        bricks = []
        walls = []
        breakable_walls.clear()
        total_bricks = 1
        remaining_bricks = 0
        clear_fraction = 1.0
        return
    bricks = LevelGenerator.generate(definition, rng)
    walls = definition.walls.duplicate()
    breakable_walls.clear()
    var wall_hp := maxi(1, config.breakable_wall_hp)
    for rect in definition.breakable_walls:
        var wall := BreakableWallData.new()
        wall.rect = rect
        wall.hp = wall_hp
        wall.max_hp = wall_hp
        breakable_walls.append(wall)
    paddle_width = minf(paddle_width, paddle_max_width())
    paddle_target_x = _clamp_paddle_x(paddle_target_x)
    paddle_x = _clamp_paddle_x(paddle_x)
    total_bricks = maxi(bricks.size(), 1)
    remaining_bricks = 0
    for brick in bricks:
        if brick.alive:
            remaining_bricks += 1
    _update_clear_fraction()


func reset_ball_state() -> void:
    balls.clear()
    powerups.clear()
    paddle_x = config.screen_size.x * 0.5
    paddle_target_x = paddle_x
    paddle_velocity = 0.0
    respawn_timer = 0.0


func next_level(debug_jump := false) -> void:
    wave += 1
    if levels.is_empty():
        state = State.READY
        return
    level_index += 1
    if level_index >= levels.size():
        level_index = 0
        loop_count += 1
    _begin_level(debug_jump)


func jump_to_level(target_index: int) -> void:
    if levels.is_empty() or not config.debug_tools:
        return
    level_index = clampi(target_index, 0, levels.size() - 1)
    wave = (loop_count - 1) * levels.size() + level_index + 1
    _begin_level(true)


func previous_level_debug() -> void:
    if levels.is_empty() or not config.debug_tools:
        return
    if level_index == 0:
        level_index = levels.size() - 1
        loop_count = maxi(1, loop_count - 1)
    else:
        level_index -= 1
    wave = (loop_count - 1) * levels.size() + level_index + 1
    _begin_level(true)


func next_level_debug() -> void:
    if levels.is_empty() or not config.debug_tools:
        return
    next_level(true)


func restart_level_debug() -> void:
    if levels.is_empty() or not config.debug_tools:
        return
    _begin_level(true)


func _begin_level(debug_jump: bool) -> void:
    if debug_jump and state == State.GAME_OVER:
        lives = config.initial_lives
    combo = 0
    next_life_reward_at = config.combo_first_life_reward
    fire_energy = 0.0
    fire_time = 0.0
    build_level()
    reset_ball_state()
    state = State.READY
    var event := emit_event(GameEvent.Type.LEVEL_STARTED, Vector2(config.screen_size.x * 0.5, 350.0), CYAN)
    event.value = wave
    var definition := current_level()
    var title := "LEVEL %02d" % (level_index + 1)
    if definition != null and not definition.display_name.is_empty():
        title += "  " + definition.display_name.to_upper()
    add_message(event.position, title, CYAN, 26, 1.2)
    if debug_jump:
        add_message(event.position + Vector2(0.0, -34.0), "DEBUG JUMP", ORANGE, 16, 1.0)
    if level_index == 0 and loop_count > 1:
        add_message(event.position + Vector2(0.0, 34.0), "LOOP %02d" % loop_count, GOLD, 18, 1.4)


func primary_action() -> void:
    if state == State.READY:
        state = State.PLAYING
        launch_ball(false)
        add_message(Vector2(paddle_x, config.paddle_y - 52.0), "LAUNCH", CYAN, 18, 0.55)
    elif state == State.GAME_OVER:
        reset_run()
    elif state == State.CLEARED:
        next_level()


func step(delta: float) -> void:
    game_time += delta
    paddle_flash = maxf(0.0, paddle_flash - delta * 3.0)
    xp_flash = maxf(0.0, xp_flash - delta * 2.0)
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
        update_balls(delta, false)

    update_bricks(delta)


func set_paddle_target(screen_x: float) -> void:
    paddle_target_x = _clamp_paddle_x(screen_x)


func nudge_paddle(direction: float, delta: float) -> void:
    if absf(direction) <= 0.01:
        return
    paddle_target_x = _clamp_paddle_x(paddle_target_x + direction * paddle_move_speed() * delta)


func _clamp_paddle_x(value: float) -> float:
    var half_width := paddle_width * 0.5
    var min_x := config.inner_left + half_width + 5.0
    var max_x := config.inner_right - half_width - 5.0
    if min_x > max_x:
        return (config.inner_left + config.inner_right) * 0.5
    return clampf(value, min_x, max_x)


func update_paddle(delta: float) -> void:
    var previous := paddle_x
    paddle_x = move_toward(paddle_x, paddle_target_x, paddle_move_speed() * delta)
    paddle_velocity = (paddle_x - previous) / maxf(delta, 0.0001)


func launch_ball(extra: bool) -> void:
    if balls.size() >= config.maximum_launch_balls:
        return
    var speed := minf(config.base_ball_speed + float(wave - 1) * config.wave_speed_increment, config.max_ball_speed)
    var angle := rng.randf_range(0.42, 0.74) * (1.0 if rng.randf() > 0.5 else -1.0)
    if extra:
        speed += 28.0
        angle = rng.randf_range(0.45, 0.92) * (1.0 if rng.randf() > 0.5 else -1.0)
    var ball := BallData.new()
    ball.position = Vector2(paddle_x, config.paddle_y - 28.0)
    ball.velocity = Vector2(sin(angle), -cos(angle)) * speed
    ball.spin = rng.randf_range(-1.0, 1.0)
    ball.stuck_reference = ball.position
    balls.append(ball)
    emit_event(GameEvent.Type.BALL_LAUNCHED, ball.position, CYAN_SOFT)


func boost_ball_speed(ball: BallData, amount: float) -> void:
    var speed := ball.velocity.length()
    if speed <= 0.001:
        return
    var target := minf(speed + amount, config.max_ball_speed)
    if target <= speed:
        return
    ball.velocity = ball.velocity.normalized() * target


func update_balls(delta: float, handle_loss := true) -> void:
    for index in range(balls.size() - 1, -1, -1):
        var ball := balls[index]
        var lost := collision.step(self, ball, delta)
        if lost:
            var lost_position := ball.position
            balls.remove_at(index)
            if not handle_loss or state != State.PLAYING:
                continue
            lost_count += 1
            combo = 0
            next_life_reward_at = config.combo_first_life_reward
            _shrink_paddle_after_loss()
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
            ball.stuck_check += delta
            if ball.stuck_check >= 0.5:
                if ball.position.distance_squared_to(ball.stuck_reference) < 196.0:
                    ball.stuck_time += ball.stuck_check
                else:
                    ball.stuck_time = 0.0
                    ball.stuck_reference = ball.position
                ball.stuck_check = 0.0
            if ball.stuck_time >= 1.5:
                _rescue_stuck_ball(ball)


func _rescue_stuck_ball(ball: BallData) -> void:
    var speed := maxf(ball.velocity.length(), config.base_ball_speed)
    var angle := rng.randf_range(-0.68, 0.68)
    var x := clampf(
        ball.position.x,
        config.inner_left + ball.radius + 4.0,
        config.inner_right - ball.radius - 4.0
    )
    ball.position = Vector2(x, config.paddle_y - 24.0)
    ball.velocity = Vector2(sin(angle), -cos(angle)) * speed
    ball.trail.clear()
    ball.stuck_time = 0.0
    ball.stuck_check = 0.0
    ball.stuck_reference = ball.position
    add_message(ball.position, "BALL RESCUE", CYAN, 14, 0.7)


func _shrink_paddle_after_loss() -> void:
    var shrink := minf(config.paddle_shrink_per_loss, maxf(0.0, paddle_width - config.paddle_width))
    if shrink <= 0.0:
        return
    paddle_width -= shrink
    paddle_target_x = _clamp_paddle_x(paddle_target_x)
    paddle_x = _clamp_paddle_x(paddle_x)
    add_message(
        Vector2(paddle_x, config.paddle_y - 70.0),
        "WIDTH -%d" % int(round(shrink)),
        DANGER,
        14,
        0.6
    )


func xp_gain_for_combo(combo_value: int) -> float:
    return config.xp_base_gain + float(maxi(combo_value, 0)) * config.xp_combo_scale


func add_xp(amount: float) -> void:
    if amount <= 0.0:
        return
    xp += amount
    while xp >= xp_required:
        xp -= xp_required
        xp_level += 1
        xp_required = maxf(1.0, xp_required * maxf(config.xp_required_growth, 1.0))
        xp_flash = 1.0
        var event := emit_event(
            GameEvent.Type.XP_LEVEL_UP,
            Vector2(config.screen_size.x * 0.5, config.field_bottom - 8.0),
            GOLD
        )
        event.value = xp_level
        var reward_text := apply_level_up_reward(reward_for_level(xp_level))
        var label := "LEVEL UP"
        if not reward_text.is_empty():
            label += "  ·  " + reward_text
        add_message(
            Vector2(config.screen_size.x * 0.5, config.field_bottom - 60.0),
            label,
            GOLD,
            28,
            1.2
        )


func reward_for_level(level: int) -> UpgradeReward:
    if config.level_up_rewards.is_empty():
        return null
    var index := clampi(level - 2, 0, config.level_up_rewards.size() - 1)
    return config.level_up_rewards[index]


func apply_level_up_reward(reward: UpgradeReward = null) -> String:
    var chosen := reward if reward != null else reward_for_level(xp_level)
    if chosen == null:
        return ""
    return chosen.apply(self)


func double_balls(event_color: Color = CYAN) -> int:
    if balls.is_empty():
        return 0
    var originals: Array = balls.duplicate()
    var added := 0
    for source: BallData in originals:
        if balls.size() >= config.powerup_max_balls:
            break
        var offset := Vector2(
            rng.randf_range(-7.0, 7.0),
            rng.randf_range(-7.0, 7.0)
        )
        var direction := 1.0 if rng.randf() > 0.5 else -1.0
        var split_angle := rng.randf_range(0.38, 0.72) * direction
        var copy := source.copy_for_split(offset, split_angle, rng.randf_range(-1.0, 1.0))
        balls.append(copy)
        emit_event(GameEvent.Type.BALL_SPLIT, copy.position, event_color)
        added += 1
    return added


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
            if absf(item.position.x - paddle_x) <= paddle_width * 0.5 + 14.0:
                collect_powerup(item)
                powerups.remove_at(index)


func collect_powerup(item: PowerupData) -> void:
    var event := emit_event(GameEvent.Type.POWERUP_COLLECTED, item.position, item.definition.color)
    event.value = item.definition.pickup_pitch
    item.definition.apply(self, item.position)


func on_wall_hit(hit_position: Vector2) -> void:
    emit_event(GameEvent.Type.WALL_HIT, hit_position, CYAN_SOFT)


func on_paddle_hit(hit_position: Vector2) -> void:
    var old_width := paddle_width
    paddle_width = minf(paddle_width + config.paddle_grow_per_hit, paddle_max_width())
    paddle_flash = 1.0
    paddle_target_x = _clamp_paddle_x(paddle_target_x)
    paddle_x = _clamp_paddle_x(paddle_x)
    var event := emit_event(GameEvent.Type.PADDLE_HIT, hit_position, CYAN)
    event.value = paddle_width
    var gained := paddle_width - old_width
    var label := "WIDTH +%d" % int(round(gained))
    if gained < 0.01:
        label = "WIDTH MAX"
    add_message(hit_position + Vector2(0.0, -20.0), label, CYAN_SOFT, 13, 0.42)

    combo += 1
    notify_combo_pop()
    add_xp(xp_gain_for_combo(combo))
    while combo >= next_life_reward_at:
        next_life_reward_at += config.combo_life_reward_interval
        var reward_text := apply_level_up_reward(reward_for_level(xp_level))
        var reward_label := "COMBO REWARD"
        if not reward_text.is_empty():
            reward_label += "  ·  " + reward_text
        add_message(Vector2(paddle_x, config.paddle_y - 58.0), reward_label, GOLD, 20, 1.0)


func hit_breakable_wall(wall: BreakableWallData, ball_speed: float) -> bool:
    if not wall.alive:
        return false
    if ball_speed < config.breakable_wall_min_speed:
        wall.shake = maxf(wall.shake, 0.45)
        return false
    wall.hp -= 1
    wall.flash = 1.0
    wall.shake = 1.0
    var center := wall.rect.get_center()
    if wall.hp <= 0:
        wall.alive = false
        var destroyed := emit_event(GameEvent.Type.BREAKABLE_WALL_DESTROYED, center, GOLD)
        destroyed.value = wall.max_hp
        add_message(center, "WALL BREAK", GOLD, 20, 0.9)
        return true
    var hit := emit_event(GameEvent.Type.BREAKABLE_WALL_HIT, center, ORANGE)
    hit.value = wall.hp
    if wall.hp % 10 == 0:
        add_message(center, "WALL %d" % wall.hp, ORANGE, 13, 0.45)
    return false


func hit_brick(brick: BrickData, damage := 1) -> bool:
    if not brick.alive:
        return false
    brick.hp = maxi(0, brick.hp - maxi(damage, 1))
    brick.flash = 1.0
    brick.shake = 1.0
    if brick.hp > 0:
        var event := emit_event(GameEvent.Type.BRICK_HIT, brick.rect.get_center(), brick.color)
        event.value = brick.hp
        return false
    destroy_brick(brick)
    return true


func destroy_brick(brick: BrickData) -> void:
    if not brick.alive:
        return
    brick.alive = false
    brick.hp = 0
    brick.flash = 1.0
    brick.shake = 1.0
    remaining_bricks -= 1

    var center := brick.rect.get_center()
    var fire := is_fire_active()
    var gain := 2 if fire else 1

    var event := emit_event(GameEvent.Type.BRICK_DESTROYED, center, brick.color)
    event.value = gain
    event.size = brick.max_hp
    add_message(center, "+%d" % gain, brick.color.lightened(0.35), 14, 0.45)

    if fire:
        fire_energy = 100.0
    else:
        fire_energy = minf(100.0, fire_energy + config.fire_charge_per_hit)
    try_drop_powerup(center, fire)

    if fire_energy >= 100.0 and not fire:
        start_fire_rush()

    _update_clear_fraction()
    _check_level_clear()


func start_fire_rush() -> void:
    if fire_time > 0.0:
        return
    fire_time = config.fire_duration
    fire_energy = 100.0
    emit_event(GameEvent.Type.FIRE_STARTED, Vector2(config.screen_size.x * 0.5, 565.0), ORANGE)
    add_message(Vector2(config.screen_size.x * 0.5, 565.0), "FIRE RUSH", ORANGE, 34, 1.2)


func _update_clear_fraction() -> void:
    clear_fraction = 1.0 - float(remaining_bricks) / float(maxi(total_bricks, 1))


func _check_level_clear() -> void:
    if remaining_bricks <= 0:
        clear_level()


func clear_level() -> void:
    if state == State.CLEARED:
        return
    state = State.CLEARED
    clear_fraction = 1.0
    powerups.clear()
    emit_event(GameEvent.Type.LEVEL_CLEARED, Vector2(config.screen_size.x * 0.5, 330.0), GREEN)
    add_message(Vector2(config.screen_size.x * 0.5, 330.0), "LEVEL CLEAR", GREEN, 34, 1.5)


func ball_speed_color(speed: float) -> Color:
    var red_threshold := maxf(config.breakable_wall_min_speed, 1.0)
    if speed >= red_threshold:
        return DANGER
    if speed >= red_threshold * 0.78:
        return ORANGE
    if speed >= red_threshold * 0.55:
        return GOLD
    return BLUE


func ball_speed_intensity(speed: float) -> float:
    var red_threshold := maxf(config.breakable_wall_min_speed, 1.0)
    var span := maxf(config.max_ball_speed - red_threshold, 1.0)
    return clampf((speed - red_threshold) / span, 0.0, 1.0)


func ball_visual_scale(speed: float) -> float:
    var red_threshold := maxf(config.breakable_wall_min_speed, 1.0)
    var effective_speed := minf(speed, config.max_ball_speed)
    var steps := maxf(0.0, effective_speed - red_threshold) / 100.0
    return minf(1.0 + steps * 0.30, 2.5)


func ball_visual_color(speed: float) -> Color:
    return ball_speed_color(speed).lerp(Color.WHITE, ball_speed_intensity(speed) * 0.42)


func paddle_max_width() -> float:
    var inner_width := config.inner_right - config.inner_left
    var level := current_level()
    if level == null:
        return inner_width
    return minf(level.brick_wall_width(), inner_width)


func paddle_move_speed() -> float:
    var max_extra := maxf(paddle_max_width() - config.paddle_width, 1.0)
    var extra := maxf(paddle_width - config.paddle_width, 0.0)
    var growth := clampf(extra / max_extra, 0.0, 1.0)
    return lerpf(config.paddle_base_move_speed, config.paddle_min_move_speed, growth)


func current_level() -> LevelDefinition:
    if levels.is_empty() or level_index < 0 or level_index >= levels.size():
        return null
    return levels[level_index]


func next_level_index() -> int:
    if levels.is_empty():
        return 0
    return (level_index + 1) % levels.size()


func is_last_level() -> bool:
    return levels.is_empty() or level_index >= levels.size() - 1


func update_bricks(delta: float) -> void:
    for brick in bricks:
        if brick.flash > 0.0:
            brick.flash = maxf(0.0, brick.flash - delta * 5.0)
        if brick.shake > 0.0:
            brick.shake = maxf(0.0, brick.shake - delta * 8.0)
    for wall in breakable_walls:
        if wall.flash > 0.0:
            wall.flash = maxf(0.0, wall.flash - delta * 5.0)
        if wall.shake > 0.0:
            wall.shake = maxf(0.0, wall.shake - delta * 8.0)


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
