extends Node2D

# -----------------------------------------------------------------------------
# Ricochet Labyrinth - a self-contained neon breakout prototype.
# All art is drawn procedurally; there are no external asset dependencies.
# -----------------------------------------------------------------------------

const SCREEN_W := 720.0
const SCREEN_H := 920.0

const FIELD_LEFT := 34.0
const FIELD_RIGHT := 686.0
const FIELD_TOP := 108.0
const FIELD_BOTTOM := 852.0
const INNER_LEFT := 42.0
const INNER_RIGHT := 678.0
const INNER_TOP := 118.0
const PADDLE_Y := 824.0
const PADDLE_W := 116.0
const PADDLE_H := 14.0

const BRICK_COLS := 16
const BRICK_ROWS := 13
const BRICK_X := 50.0
const BRICK_Y := 128.0
const BRICK_W := 34.0
const BRICK_H := 23.0
const BRICK_STEP_X := 39.0
const BRICK_STEP_Y := 29.0

const CYAN := Color("#78f4ff")
const CYAN_SOFT := Color("#3fc9dd")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")
const GREEN := Color("#c9ff72")
const PURPLE := Color("#a58bff")
const MUTED := Color("#7790a8")
const DANGER := Color("#ff4d79")

const POWERUP_DROP_CHANCE := 0.14
const POWERUP_MAX_ACTIVE := 7
const POWERUP_MAX_BALLS := 24

var rng := RandomNumberGenerator.new()
var font: Font

# Game state.
var state := "ready"                # ready | playing | cleared | game_over
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

# Paddle and balls.
var paddle_x := 360.0
var paddle_target_x := 360.0
var paddle_velocity := 0.0
var balls: Array[Dictionary] = []

# World objects and effects.
var walls: Array[Rect2] = []
var bricks: Array[Dictionary] = []
var powerups: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var dust: Array[Vector3] = []
var powerup_pity := 0
var powerup_drop_counter := 0

var shake := 0.0
var flash_alpha := 0.0
var combo_pop := 0.0

# HUD.
var wave_label: Label
var title_label: Label
var combo_header: Label
var combo_label: Label
var clear_label: Label
var balls_label: Label
var lost_label: Label
var fire_label: Label
var status_label: Label
var status_hint: Label
var footer_hint: Label


# Tiny procedural sound bank. No external audio assets are required.
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index := 0
var sfx_hit: AudioStreamWAV
var sfx_wall: AudioStreamWAV
var sfx_paddle: AudioStreamWAV
var sfx_lost: AudioStreamWAV
var sfx_fire: AudioStreamWAV
var sfx_clear: AudioStreamWAV
var sfx_powerup: AudioStreamWAV




func _ready() -> void:
    rng.seed = 0x5EEDC0DE
    font = ThemeDB.fallback_font
    create_audio()
    create_walls()
    create_dust()
    create_ui()
    reset_run()


    queue_redraw()


func create_audio() -> void:
    sfx_hit = synth_sound(760.0, 0.085, 0.34, 0.20, 1.9)
    sfx_wall = synth_sound(210.0, 0.055, 0.20, 0.05, 2.6)
    sfx_paddle = synth_sound(360.0, 0.12, 0.30, 0.08, 1.4)
    sfx_lost = synth_sound(150.0, 0.42, 0.28, 0.16, 0.8)
    sfx_fire = synth_sound(260.0, 0.65, 0.26, 0.46, 0.55)
    sfx_clear = synth_sound(980.0, 0.5, 0.24, 0.02, 0.7)
    sfx_powerup = synth_sound(640.0, 0.28, 0.30, 0.10, 1.1)
    for i in range(10):
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        sfx_players.append(player)


func synth_sound(frequency: float, duration: float, volume: float, noise_amount: float, decay: float) -> AudioStreamWAV:
    var sample_rate := 22050
    var sample_count := maxi(1, int(duration * sample_rate))
    var data := PackedByteArray()
    data.resize(sample_count * 2)
    for i in range(sample_count):
        var t := float(i) / float(sample_rate)
        var progress := float(i) / float(sample_count)
        var envelope := pow(maxf(0.0, 1.0 - progress), decay)
        var wave := sin(TAU * frequency * t)
        wave += sin(TAU * frequency * 2.02 * t) * 0.22
        wave += sin(TAU * frequency * 0.51 * t) * 0.18
        wave += sin(TAU * 13471.0 * t) * noise_amount * (0.30 + progress * 0.70)
        var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, sample)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    return stream


func play_sfx(stream: AudioStreamWAV, volume_db: float, pitch: float = 1.0) -> void:
    if sfx_players.is_empty():
        return
    var player := sfx_players[sfx_index]
    sfx_index = (sfx_index + 1) % sfx_players.size()
    player.stream = stream
    player.volume_db = volume_db
    player.pitch_scale = pitch
    player.play()


func create_walls() -> void:
    walls = [
        Rect2(166.0, 276.0, 12.0, 76.0),
        Rect2(158.0, 318.0, 124.0, 12.0),
        Rect2(410.0, 318.0, 124.0, 12.0),
        Rect2(538.0, 274.0, 12.0, 82.0),
        Rect2(118.0, 510.0, 142.0, 12.0),
        Rect2(438.0, 510.0, 142.0, 12.0),
        Rect2(302.0, 466.0, 12.0, 90.0),
        Rect2(592.0, 466.0, 12.0, 90.0),
        Rect2(218.0, 642.0, 138.0, 12.0),
        Rect2(500.0, 642.0, 112.0, 12.0),
        Rect2(402.0, 598.0, 12.0, 94.0),
        Rect2(622.0, 590.0, 12.0, 96.0),
    ]


func create_dust() -> void:
    dust.clear()
    for i in range(95):
        dust.append(Vector3(
            rng.randf_range(FIELD_LEFT + 8.0, FIELD_RIGHT - 8.0),
            rng.randf_range(FIELD_TOP + 10.0, FIELD_BOTTOM - 6.0),
            rng.randf_range(0.06, 0.34)
        ))


func reset_run() -> void:
    wave = 1
    lives = 5
    lost_count = 0
    combo = 0
    next_multiball_at = 30
    powerup_pity = 0
    powerup_drop_counter = 0
    fire_energy = 0.0
    fire_time = 0.0
    state = "ready"
    paddle_x = 360.0
    paddle_target_x = 360.0
    paddle_velocity = 0.0
    balls.clear()
    powerups.clear()
    particles.clear()
    floaters.clear()
    respawn_timer = 0.0
    state_timer = 0.0
    build_level()


func build_level() -> void:
    bricks.clear()
    remaining_bricks = 0

    for row in range(BRICK_ROWS):
        for col in range(BRICK_COLS):
            var rect := Rect2(
                BRICK_X + col * BRICK_STEP_X,
                BRICK_Y + row * BRICK_STEP_Y,
                BRICK_W,
                BRICK_H
            )

            # Curated openings make the wall feel like a labyrinth rather than
            # a solid rectangle, while still keeping plenty of targets.
            var carve := false
            if row >= 2 and row <= 5 and (col == 7 or col == 8):
                carve = true
            if row >= 5 and row <= 8 and (col == 1 or col == 2 or col == 13 or col == 14):
                carve = true
            if row == 4 and (col == 3 or col == 12):
                carve = true
            if row == 7 and (col == 5 or col == 6 or col == 9 or col == 10):
                carve = true
            if rng.randf() < 0.034:
                carve = true
            if carve:
                continue

            var blocked := false
            for wall in walls:
                if wall.grow(3.0).intersects(rect):
                    blocked = true
                    break
            if blocked:
                continue

            var hue := lerpf(0.155, 0.79, float(row) / float(maxi(BRICK_ROWS - 1, 1)))
            hue = fmod(hue + rng.randf_range(-0.012, 0.012) + 1.0, 1.0)
            var color := Color.from_hsv(hue, 0.72, 0.93)

            bricks.append({
                "rect": rect,
                "color": color,
                "alive": true,
                "flash": 0.0,
            })
            remaining_bricks += 1

    total_bricks = maxi(remaining_bricks, 1)
    clear_fraction = 0.0

    # Small clear percentage on later waves so the HUD immediately shows
    # progress while the player gets oriented.
    if wave > 1:
        var precleared := mini(8, bricks.size() / 4)
        for i in range(precleared):
            var pick := rng.randi_range(0, bricks.size() - 1)
            if bricks[pick]["alive"]:
                bricks[pick]["alive"] = false
                remaining_bricks -= 1
        clear_fraction = 1.0 - float(remaining_bricks) / float(total_bricks)


func reset_ball_state() -> void:
    balls.clear()
    powerups.clear()
    paddle_x = 360.0
    paddle_target_x = 360.0
    paddle_velocity = 0.0
    respawn_timer = 0.0


func next_wave() -> void:
    wave += 1
    combo = 0
    next_multiball_at = 30
    fire_energy = 0.0
    fire_time = 0.0
    build_level()
    reset_ball_state()
    state = "ready"
    add_floater(Vector2(SCREEN_W * 0.5, 350.0), "WAVE %02d" % wave, CYAN, 28, 1.1)
    flash_alpha = maxf(flash_alpha, 0.18)


# -----------------------------------------------------------------------------
# Input
# -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        paddle_target_x = clampf(
            event.position.x,
            INNER_LEFT + PADDLE_W * 0.5 + 5.0,
            INNER_RIGHT - PADDLE_W * 0.5 - 5.0
        )
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        paddle_target_x = clampf(
            event.position.x,
            INNER_LEFT + PADDLE_W * 0.5 + 5.0,
            INNER_RIGHT - PADDLE_W * 0.5 - 5.0
        )
        primary_action()
    elif event is InputEventScreenTouch:
        paddle_target_x = clampf(
            event.position.x,
            INNER_LEFT + PADDLE_W * 0.5 + 5.0,
            INNER_RIGHT - PADDLE_W * 0.5 - 5.0
        )
        if event.pressed:
            primary_action()
    elif event is InputEventScreenDrag:
        paddle_target_x = clampf(
            event.position.x,
            INNER_LEFT + PADDLE_W * 0.5 + 5.0,
            INNER_RIGHT - PADDLE_W * 0.5 - 5.0
        )

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            primary_action()
        elif event.keycode == KEY_R:
            reset_run()


func primary_action() -> void:
    if state == "ready":
        state = "playing"
        launch_ball(false)
        flash_alpha = maxf(flash_alpha, 0.08)
        add_floater(Vector2(paddle_x, PADDLE_Y - 52.0), "LAUNCH", CYAN, 18, 0.55)
    elif state == "game_over":
        reset_run()
    elif state == "cleared":
        state_timer = 0.0


func launch_ball(extra: bool) -> void:
    if balls.size() >= 7:
        return
    var speed := 470.0 + float(wave - 1) * 18.0
    # Never launch straight up through the central lane. A definite side
    # angle makes the opening shot readable and guarantees it will seek bricks.
    var angle := rng.randf_range(0.42, 0.74) * (1.0 if rng.randf() > 0.5 else -1.0)
    if extra:
        speed += 28.0
        angle = rng.randf_range(0.45, 0.92) * (1.0 if rng.randf() > 0.5 else -1.0)
    var spawn_pos := Vector2(paddle_x, PADDLE_Y - 28.0)
    balls.append({
        "pos": spawn_pos,
        "vel": Vector2(sin(angle), -cos(angle)) * speed,
        "radius": 7.0,
        "trail": [] as Array[Vector2],
        "spin": rng.randf_range(-1.0, 1.0),
    })
    play_sfx(sfx_paddle, -8.0, rng.randf_range(1.08, 1.20))
    emit_burst(spawn_pos, CYAN_SOFT, 10, 90.0, 2.2, 90.0)


# -----------------------------------------------------------------------------
# Main update
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
    game_time += delta
    update_input(delta)
    update_paddle(delta)

    if state == "playing":
        if fire_time > 0.0:
            fire_time = maxf(0.0, fire_time - delta)
            if fire_time <= 0.0:
                fire_energy = 0.0
                add_floater(Vector2(SCREEN_W * 0.5, 690.0), "FIRE RUSH END", ORANGE, 20, 0.8)

        if respawn_timer > 0.0:
            respawn_timer -= delta
            if respawn_timer <= 0.0 and balls.is_empty():
                state = "ready"
                add_floater(Vector2(paddle_x, PADDLE_Y - 54.0), "BALL %02d" % lives, CYAN, 18, 0.7)

        update_powerups(delta)
        update_balls(delta)
    elif state == "cleared":
        state_timer -= delta
        if state_timer <= 0.0:
            next_wave()

    update_effects(delta)
    update_bricks(delta)
    update_ui()

    queue_redraw()


func update_input(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    if absf(direction) > 0.01:
        paddle_target_x = clampf(
            paddle_target_x + direction * 760.0 * delta,
            INNER_LEFT + PADDLE_W * 0.5 + 5.0,
            INNER_RIGHT - PADDLE_W * 0.5 - 5.0
        )


func update_paddle(delta: float) -> void:
    var previous := paddle_x
    paddle_x = lerpf(paddle_x, paddle_target_x, 1.0 - exp(-18.0 * delta))
    paddle_velocity = (paddle_x - previous) / maxf(delta, 0.0001)


func update_balls(delta: float) -> void:
    for i in range(balls.size() - 1, -1, -1):
        var ball := balls[i]
        if is_fire_active():
            emit_fire_ember(ball)
        var lost := step_ball(ball, delta)
        if lost:
            var lost_pos: Vector2 = ball["pos"]
            balls.remove_at(i)
            lost_count += 1
            combo = 0
            next_multiball_at = 30
            shake = maxf(shake, 8.0)
            flash_alpha = maxf(flash_alpha, 0.10)
            play_sfx(sfx_lost, -5.0, rng.randf_range(0.92, 1.02))
            emit_burst(lost_pos, DANGER, 30, 230.0, 3.8, 360.0)
            add_floater(lost_pos, "BALL LOST", DANGER, 18, 0.9)
            if balls.is_empty():
                powerups.clear()
                lives -= 1
                if lives > 0:
                    respawn_timer = 1.15
                else:
                    state = "game_over"
                    add_floater(Vector2(SCREEN_W * 0.5, 390.0), "RUN COMPLETE", PINK, 26, 1.4)
        else:
            var trail: Array = ball["trail"]
            trail.append(ball["pos"])
            while trail.size() > 15:
                trail.remove_at(0)
            if is_fire_active() or rng.randf() < 0.62:
                emit_ball_spark(ball)


func try_drop_powerup(center: Vector2, fire: bool) -> void:
    if powerups.size() >= POWERUP_MAX_ACTIVE:
        return
    powerup_pity += 1
    var chance := POWERUP_DROP_CHANCE * (0.72 if fire else 1.0)
    if powerup_pity < 8 and rng.randf() > chance:
        return

    powerup_pity = 0
    # Alternate the two effects so every run reliably demonstrates both kinds.
    var kind := "multiball" if powerup_drop_counter % 2 == 0 else "speed"
    powerup_drop_counter += 1
    var color := CYAN if kind == "multiball" else GOLD
    powerups.append({
        "pos": center,
        "vel": Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(72.0, 118.0)),
        "kind": kind,
        "color": color,
        "age": 0.0,
        "phase": rng.randf_range(0.0, TAU),
    })
    emit_burst(center, color, 10, 105.0, 2.2, 80.0)
    add_floater(center + Vector2(0.0, -16.0), "POWER DROP", color, 12, 0.55)


func update_powerups(delta: float) -> void:
    for i in range(powerups.size() - 1, -1, -1):
        var item := powerups[i]
        item["age"] = float(item["age"]) + delta
        var pos: Vector2 = item["pos"]
        var vel: Vector2 = item["vel"]
        vel.y = minf(vel.y + 92.0 * delta, 235.0)
        vel.x *= exp(-0.8 * delta)
        item["vel"] = vel
        pos += vel * delta

        if pos.x < INNER_LEFT + 13.0:
            pos.x = INNER_LEFT + 13.0
            vel.x = absf(vel.x) * 0.72
            item["vel"] = vel
        elif pos.x > INNER_RIGHT - 13.0:
            pos.x = INNER_RIGHT - 13.0
            vel.x = -absf(vel.x) * 0.72
            item["vel"] = vel
        item["pos"] = pos

        if pos.y > FIELD_BOTTOM + 30.0:
            powerups.remove_at(i)
            continue

        # The pickup hitbox is intentionally a little more forgiving than the
        # drawn gem so touch and fast drops both feel responsive.
        if pos.y >= PADDLE_Y - 24.0 and pos.y <= PADDLE_Y + 18.0:
            if absf(pos.x - paddle_x) <= PADDLE_W * 0.5 + 14.0:
                collect_powerup(item)
                powerups.remove_at(i)


func collect_powerup(item: Dictionary) -> void:
    var pos: Vector2 = item["pos"]
    var kind: String = item["kind"]
    var color: Color = item["color"]
    shake = maxf(shake, 4.5)
    flash_alpha = maxf(flash_alpha, 0.13)
    play_sfx(sfx_powerup, -4.0, 1.0 if kind == "multiball" else 1.24)
    emit_burst(pos, color, 26, 210.0, 3.5, 190.0)
    emit_burst(pos, Color.WHITE, 7, 110.0, 1.8, 80.0)

    if kind == "multiball":
        apply_multiball_powerup(pos)
    else:
        apply_speed_powerup(pos)


func apply_multiball_powerup(pickup_pos: Vector2) -> void:
    if balls.is_empty():
        add_floater(pickup_pos, "MULTIBALL READY", CYAN, 19, 1.0)
        return

    var originals := balls.duplicate()
    var added := 0
    for source in originals:
        if balls.size() >= POWERUP_MAX_BALLS:
            break
        var copy: Dictionary = source.duplicate(true)
        var copy_pos: Vector2 = source["pos"] + Vector2(
            rng.randf_range(-7.0, 7.0),
            rng.randf_range(-7.0, 7.0)
        )
        var split_angle := rng.randf_range(0.38, 0.72) * (1.0 if rng.randf() > 0.5 else -1.0)
        copy["pos"] = copy_pos
        copy["vel"] = (source["vel"] as Vector2).rotated(split_angle)
        copy["trail"] = [] as Array[Vector2]
        copy["spin"] = rng.randf_range(-1.0, 1.0)
        balls.append(copy)
        emit_burst(copy_pos, CYAN, 9, 125.0, 2.4, 80.0)
        added += 1

    combo_pop = 1.0
    if added > 0:
        add_floater(pickup_pos + Vector2(0.0, -20.0), "BALLS \u00d72", CYAN, 24, 1.0)
    else:
        add_floater(pickup_pos + Vector2(0.0, -20.0), "MAX BALLS", CYAN, 18, 0.8)


func apply_speed_powerup(pickup_pos: Vector2) -> void:
    for ball in balls:
        var vel: Vector2 = ball["vel"]
        var speed := vel.length()
        if speed < 0.001:
            continue
        var boosted_speed := minf(speed * 1.18, 980.0)
        ball["vel"] = vel.normalized() * boosted_speed
        emit_burst(ball["pos"], GOLD, 10, 150.0, 2.5, 100.0)

    combo_pop = 1.0
    add_floater(pickup_pos + Vector2(0.0, -20.0), "SPEED UP", GOLD, 24, 1.0)
    add_floater(Vector2(SCREEN_W * 0.5, 708.0), "+18% BALL SPEED", ORANGE, 15, 0.8)


func step_ball(ball: Dictionary, delta: float) -> bool:
    var speed: float = ball["vel"].length()
    var substeps := clampi(int(ceil(speed * delta / 4.5)), 1, 14)
    var sub_delta := delta / float(substeps)

    for s in range(substeps):
        ball["pos"] += ball["vel"] * sub_delta
        var pos: Vector2 = ball["pos"]
        var vel: Vector2 = ball["vel"]
        var radius: float = ball["radius"]

        # Outer arena walls.
        if pos.x - radius < INNER_LEFT:
            pos.x = INNER_LEFT + radius
            vel.x = absf(vel.x)
            on_wall_hit(pos)
        elif pos.x + radius > INNER_RIGHT:
            pos.x = INNER_RIGHT - radius
            vel.x = -absf(vel.x)
            on_wall_hit(pos)
        if pos.y - radius < INNER_TOP:
            pos.y = INNER_TOP + radius
            vel.y = absf(vel.y)
            on_wall_hit(pos)
        elif pos.y - radius > FIELD_BOTTOM + 22.0:
            ball["pos"] = pos
            ball["vel"] = vel
            return true

        ball["pos"] = pos
        ball["vel"] = vel
        collide_paddle(ball)
        collide_walls(ball)
        collide_bricks(ball)

        # Avoid perfectly horizontal balls getting trapped in a horizontal
        # corridor. Speed is preserved.
        var current_vel: Vector2 = ball["vel"]
        if absf(current_vel.y) < 92.0 and current_vel.length_squared() > 1.0:
            var target_speed := current_vel.length()
            current_vel.y = -92.0 if current_vel.y <= 0.0 else 92.0
            ball["vel"] = current_vel.normalized() * target_speed

    return false


func on_wall_hit(pos: Vector2) -> void:
    shake = maxf(shake, 1.4)
    play_sfx(sfx_wall, -21.0, rng.randf_range(0.94, 1.08))
    emit_burst(pos, CYAN_SOFT, 3, 55.0, 1.7, 40.0)


func collide_paddle(ball: Dictionary) -> void:
    var vel: Vector2 = ball["vel"]
    if vel.y <= 0.0:
        return
    var paddle_rect := Rect2(
        paddle_x - PADDLE_W * 0.5,
        PADDLE_Y - PADDLE_H * 0.5,
        PADDLE_W,
        PADDLE_H
    )
    var hit := circle_rect_hit(ball["pos"], ball["radius"], paddle_rect)
    if hit.is_empty():
        return

    var pos: Vector2 = ball["pos"]
    pos.y = paddle_rect.position.y - float(ball["radius"]) - 0.2
    ball["pos"] = pos

    var rel := clampf((pos.x - paddle_x) / (PADDLE_W * 0.5), -1.0, 1.0)
    var speed := clampf(vel.length() + 7.0, 470.0, 880.0)
    var angle := rel * 1.02
    var new_vel := Vector2(sin(angle), -cos(angle)) * speed
    new_vel.x += clampf(paddle_velocity * 0.10, -110.0, 110.0)

    # Preserve a little horizontal energy even on a dead-center return. This
    # prevents endless vertical loops between a flat barrier and the paddle.
    var incoming_side := signf(vel.x)
    if absf(incoming_side) < 0.1:
        incoming_side = 1.0 if rng.randf() > 0.5 else -1.0
    var min_horizontal := speed * 0.17
    if absf(new_vel.x) < min_horizontal:
        new_vel.x = incoming_side * min_horizontal

    if new_vel.length() > 0.001:
        ball["vel"] = new_vel.normalized() * speed
    else:
        ball["vel"] = Vector2(incoming_side * speed * 0.2, -speed * 0.98).normalized() * speed

    shake = maxf(shake, 2.8)
    flash_alpha = maxf(flash_alpha, 0.035)
    play_sfx(sfx_paddle, -7.0, rng.randf_range(1.02, 1.13))
    emit_burst(pos + Vector2(0.0, 7.0), CYAN, 12, 135.0, 2.8, 150.0)
    add_floater(pos + Vector2(0.0, -20.0), "+SPEED", CYAN_SOFT, 13, 0.42)


func collide_walls(ball: Dictionary) -> void:
    for wall in walls:
        var hit := circle_rect_hit(ball["pos"], ball["radius"], wall)
        if hit.is_empty():
            continue
        var normal: Vector2 = hit["normal"]
        var penetration: float = hit["penetration"]
        var vel: Vector2 = ball["vel"]
        if vel.dot(normal) < 0.0:
            ball["pos"] += normal * penetration
            vel = vel.bounce(normal)
            ball["vel"] = vel
            shake = maxf(shake, 2.5)
            emit_burst(ball["pos"] + normal * 3.0, Color("#a9c4d8"), 7, 130.0, 2.4, 120.0)
        break


func collide_bricks(ball: Dictionary) -> bool:
    var fire := is_fire_active()
    for brick in bricks:
        if not brick["alive"]:
            continue
        var rect: Rect2 = brick["rect"]
        if not rect.grow(float(ball["radius"])).has_point(ball["pos"]):
            continue
        var hit := circle_rect_hit(ball["pos"], ball["radius"], rect)
        if hit.is_empty():
            continue

        if not fire:
            var normal: Vector2 = hit["normal"]
            var penetration: float = hit["penetration"]
            var vel: Vector2 = ball["vel"]
            if vel.dot(normal) < 0.0:
                ball["pos"] += normal * penetration
                ball["vel"] = vel.bounce(normal)
        destroy_brick(brick)
        if not fire:
            return true
    return false


func destroy_brick(brick: Dictionary) -> void:
    if not brick["alive"]:
        return
    brick["alive"] = false
    brick["flash"] = 1.0
    remaining_bricks -= 1

    var rect: Rect2 = brick["rect"]
    var color: Color = brick["color"]
    var center := rect.get_center()
    var fire := is_fire_active()
    var gain := 2 if fire else 1

    combo += gain
    combo_pop = 1.0
    shake = maxf(shake, 2.0 if not fire else 3.8)

    if fire:
        fire_energy = 100.0
        emit_burst(center, ORANGE, 20, 245.0, 3.4, 380.0)
        emit_burst(center, PINK, 10, 170.0, 2.5, 260.0)
    else:
        fire_energy = minf(100.0, fire_energy + 3.4)
        emit_burst(center, color.lightened(0.15), 14, 185.0, 3.0, 260.0)
        emit_burst(center, Color.WHITE, 3, 95.0, 1.8, 120.0)

    play_sfx(sfx_hit, -12.0, rng.randf_range(0.88, 1.18))
    try_drop_powerup(center, fire)
    add_floater(center, "+%d" % gain, color.lightened(0.35), 14, 0.45)
    if combo > 0 and combo % 10 == 0:
        add_floater(center + Vector2(0.0, -18.0), "\u00d7%d" % combo, GOLD, 20, 0.70)

    while combo >= next_multiball_at and balls.size() < 6:
        next_multiball_at += 35
        launch_ball(true)
        add_floater(Vector2(paddle_x, PADDLE_Y - 58.0), "MULTIBALL", CYAN, 18, 0.8)

    if fire_energy >= 100.0 and not fire:
        start_fire_rush()

    clear_fraction = 1.0 - float(remaining_bricks) / float(total_bricks)
    if remaining_bricks <= 0:
        clear_level()


func start_fire_rush() -> void:
    if fire_time > 0.0:
        return
    fire_time = 6.0
    fire_energy = 100.0
    combo_pop = 1.0
    flash_alpha = maxf(flash_alpha, 0.30)
    shake = maxf(shake, 7.0)
    play_sfx(sfx_fire, -3.0, rng.randf_range(0.96, 1.04))
    add_floater(Vector2(SCREEN_W * 0.5, 565.0), "FIRE RUSH", ORANGE, 34, 1.2)
    for i in range(38):
        var pos := Vector2(rng.randf_range(INNER_LEFT, INNER_RIGHT), rng.randf_range(240.0, 780.0))
        emit_fire_ember_at(pos)


func clear_level() -> void:
    if state == "cleared":
        return
    state = "cleared"
    state_timer = 2.35
    clear_fraction = 1.0
    powerups.clear()
    combo += 25
    flash_alpha = maxf(flash_alpha, 0.22)
    shake = maxf(shake, 6.0)
    play_sfx(sfx_clear, -4.0, 1.0)
    add_floater(Vector2(SCREEN_W * 0.5, 330.0), "WAVE CLEAR", GREEN, 34, 1.5)
    add_floater(Vector2(SCREEN_W * 0.5, 376.0), "+25 BONUS", GOLD, 20, 1.4)


# -----------------------------------------------------------------------------
# Effects
# -----------------------------------------------------------------------------

func update_effects(delta: float) -> void:
    shake = move_toward(shake, 0.0, delta * 22.0)
    flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.9)
    combo_pop = move_toward(combo_pop, 0.0, delta * 5.0)

    for i in range(particles.size() - 1, -1, -1):
        var p := particles[i]
        p["life"] -= delta
        if p["life"] <= 0.0:
            particles.remove_at(i)
            continue
        var vel: Vector2 = p["vel"]
        vel.y += float(p["gravity"]) * delta
        vel *= exp(-float(p["drag"]) * delta)
        p["vel"] = vel
        p["pos"] += vel * delta

    for i in range(floaters.size() - 1, -1, -1):
        var f := floaters[i]
        f["life"] -= delta
        if f["life"] <= 0.0:
            floaters.remove_at(i)
        else:
            f["pos"] += Vector2(0.0, -24.0 * delta)


func update_bricks(delta: float) -> void:
    for brick in bricks:
        if brick["flash"] > 0.0:
            brick["flash"] = maxf(0.0, brick["flash"] - delta * 5.0)


func emit_burst(pos: Vector2, color: Color, count: int, speed: float, size: float, gravity: float) -> void:
    for i in range(count):
        var angle := rng.randf_range(0.0, TAU)
        var magnitude := rng.randf_range(speed * 0.22, speed)
        var life := rng.randf_range(0.30, 0.82)
        particles.append({
            "pos": pos + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
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


func emit_ball_spark(ball: Dictionary) -> void:
    var pos: Vector2 = ball["pos"]
    var vel: Vector2 = ball["vel"]
    var dir := vel.normalized()
    var side := Vector2(-dir.y, dir.x)
    var life := rng.randf_range(0.16, 0.46)
    var color: Color = GOLD.lerp(PINK, rng.randf()) if is_fire_active() else CYAN.lerp(PINK, rng.randf_range(0.0, 0.35))
    particles.append({
        "pos": pos - dir * rng.randf_range(4.0, 12.0) + side * rng.randf_range(-4.0, 4.0),
        "vel": -dir * rng.randf_range(22.0, 90.0) + side * rng.randf_range(-34.0, 34.0),
        "life": life,
        "max_life": life,
        "color": color,
        "size": rng.randf_range(0.9, 2.4),
        "gravity": 18.0,
        "drag": rng.randf_range(1.0, 2.6),
    })


func emit_fire_ember(ball: Dictionary) -> void:
    if rng.randf() > 0.62:
        return
    var pos: Vector2 = ball["pos"]
    var vel: Vector2 = ball["vel"]
    var side := Vector2(-vel.y, vel.x).normalized()
    var p := pos + side * rng.randf_range(-5.0, 5.0)
    emit_fire_ember_at(p)


func emit_fire_ember_at(pos: Vector2) -> void:
    var life := rng.randf_range(0.25, 0.7)
    var color: Color = GOLD
    var pick := rng.randi_range(0, 2)
    if pick == 1:
        color = ORANGE
    elif pick == 2:
        color = PINK
    particles.append({
        "pos": pos,
        "vel": Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-80.0, 20.0)),
        "life": life,
        "max_life": life,
        "color": color,
        "size": rng.randf_range(1.2, 3.2),
        "gravity": -35.0,
        "drag": 1.4,
    })


func add_floater(pos: Vector2, text: String, color: Color, size: int, lifetime: float) -> void:
    floaters.append({
        "pos": pos,
        "text": text,
        "color": color,
        "size": size,
        "life": lifetime,
        "max_life": lifetime,
    })
    if floaters.size() > 55:
        floaters.remove_at(0)


func is_fire_active() -> bool:
    return fire_time > 0.0


# -----------------------------------------------------------------------------
# Geometry helpers
# -----------------------------------------------------------------------------

func circle_rect_hit(center: Vector2, radius: float, rect: Rect2) -> Dictionary:
    if not rect.grow(radius).has_point(center):
        return {}
    var closest := Vector2(
        clampf(center.x, rect.position.x, rect.end.x),
        clampf(center.y, rect.position.y, rect.end.y)
    )
    var delta := center - closest
    var dist_sq := delta.length_squared()
    if dist_sq > radius * radius:
        return {}

    if dist_sq > 0.0001:
        var dist := sqrt(dist_sq)
        return {
            "normal": delta / dist,
            "penetration": radius - dist,
        }

    # Center is inside the rectangle. Push out through the nearest side.
    var left := center.x - rect.position.x
    var right := rect.end.x - center.x
    var top := center.y - rect.position.y
    var bottom := rect.end.y - center.y
    var nearest := minf(minf(left, right), minf(top, bottom))
    if nearest == left:
        return {"normal": Vector2.LEFT, "penetration": left + radius}
    elif nearest == right:
        return {"normal": Vector2.RIGHT, "penetration": right + radius}
    elif nearest == top:
        return {"normal": Vector2.UP, "penetration": top + radius}
    return {"normal": Vector2.DOWN, "penetration": bottom + radius}


# -----------------------------------------------------------------------------
# UI
# -----------------------------------------------------------------------------

func create_ui() -> void:
    wave_label = make_label("WAVE 01", Vector2(23, 8), Vector2(220, 25), 17, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
    title_label = make_label("LABYRINTH / RICOCHET", Vector2(42, 45), Vector2(430, 28), 19, Color("#b2c5d8"), HORIZONTAL_ALIGNMENT_LEFT)
    combo_header = make_label("COMBO", Vector2(500, 1), Vector2(190, 18), 12, Color("#b9974c"), HORIZONTAL_ALIGNMENT_RIGHT)
    combo_label = make_label("\u00d70", Vector2(500, 12), Vector2(190, 50), 42, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
    clear_label = make_label("0% CLEAR", Vector2(480, 62), Vector2(210, 24), 17, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
    balls_label = make_label("01 BALLS", Vector2(23, 860), Vector2(210, 32), 23, Color("#f0f7ff"), HORIZONTAL_ALIGNMENT_LEFT)
    lost_label = make_label("LOST 0", Vector2(270, 866), Vector2(180, 22), 14, Color("#d083ab"), HORIZONTAL_ALIGNMENT_CENTER)
    fire_label = make_label("FIRE CHARGE 0%", Vector2(460, 860), Vector2(230, 26), 17, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
    footer_hint = make_label("MOUSE / TOUCH / A D  \u00b7  SPACE TO LAUNCH  \u00b7  R TO RESTART", Vector2(23, 892), Vector2(674, 20), 11, Color("#506a80"), HORIZONTAL_ALIGNMENT_CENTER)

    status_label = make_label("", Vector2(100, 364), Vector2(520, 64), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    status_hint = make_label("", Vector2(100, 425), Vector2(520, 30), 14, Color("#9ab0c2"), HORIZONTAL_ALIGNMENT_CENTER)

    for label in [wave_label, title_label, combo_header, combo_label, clear_label, balls_label, lost_label, fire_label, status_label, status_hint, footer_hint]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func make_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.size = size
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("#02060d"))
    label.add_theme_constant_override("outline_size", 4)
    add_child(label)
    return label


func update_ui() -> void:
    wave_label.text = "WAVE %02d" % wave
    combo_label.text = "\u00d7%d" % combo
    clear_label.text = "%d%% CLEAR" % int(round(clear_fraction * 100.0))
    balls_label.text = "%02d BALLS" % maxi(1, balls.size()) if state == "ready" else "%02d BALLS" % balls.size()
    lost_label.text = "LOST %d" % lost_count
    combo_label.pivot_offset = Vector2(combo_label.size.x - 10.0, combo_label.size.y * 0.55)
    combo_label.scale = Vector2.ONE * (1.0 + combo_pop * 0.10)

    var fire_active := is_fire_active()
    if fire_active:
        fire_label.text = "FIRE RUSH %.1fs" % fire_time
        fire_label.add_theme_color_override("font_color", ORANGE)
        combo_label.add_theme_color_override("font_color", ORANGE)
    else:
        fire_label.text = "FIRE CHARGE %d%%" % int(round(fire_energy))
        fire_label.add_theme_color_override("font_color", GOLD)
        combo_label.add_theme_color_override("font_color", GOLD)

    if state == "ready":
        status_label.text = "CLICK / SPACE TO LAUNCH"
        status_label.add_theme_color_override("font_color", CYAN)
        status_hint.text = "MOVE  \u00b7  MOUSE / A D / ARROW KEYS"
        status_label.visible = true
        status_hint.visible = true
    elif state == "game_over":
        status_label.text = "GAME OVER"
        status_label.add_theme_color_override("font_color", PINK)
        status_hint.text = "CLICK / SPACE TO RESTART"
        status_label.visible = true
        status_hint.visible = true
    elif state == "cleared":
        status_label.text = "WAVE CLEAR"
        status_label.add_theme_color_override("font_color", GREEN)
        status_hint.text = "NEXT WAVE INCOMING"
        status_label.visible = true
        status_hint.visible = true
    else:
        status_label.visible = false
        status_hint.visible = false


# -----------------------------------------------------------------------------
# Drawing
# -----------------------------------------------------------------------------

func _draw() -> void:
    draw_background()

    var shake_amount := shake
    var sh := Vector2(
        rng.randf_range(-shake_amount, shake_amount),
        rng.randf_range(-shake_amount, shake_amount)
    )
    draw_set_transform(sh, 0.0, Vector2.ONE)

    draw_outer_frame()
    draw_grid()
    draw_bricks()
    draw_walls()
    draw_powerups()
    draw_trails()
    draw_particles()
    draw_paddle()
    draw_balls()
    draw_floaters()
    draw_bottom_meter()

    if is_fire_active():
        var fire_pulse := 0.018 + (sin(game_time * 8.0) * 0.5 + 0.5) * 0.018
        draw_rect(Rect2(FIELD_LEFT, FIELD_TOP, FIELD_RIGHT - FIELD_LEFT, FIELD_BOTTOM - FIELD_TOP), Color(1.0, 0.24, 0.08, fire_pulse), true)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    if state != "playing":
        var tint := Color(0.0, 0.01, 0.03, 0.22)
        draw_rect(Rect2(34, 108, 652, 744), tint, true)

    if flash_alpha > 0.001:
        draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.55, 0.86, 1.0, flash_alpha), true)


func draw_background() -> void:
    var bands := 28
    for i in range(bands):
        var t := float(i) / float(bands - 1)
        var col := Color("#071426").lerp(Color("#01030a"), t)
        draw_rect(Rect2(0.0, SCREEN_H * t, SCREEN_W, SCREEN_H / float(bands) + 1.0), col, true)

    # Faint arena atmosphere and static dust.
    for point in dust:
        draw_circle(Vector2(point.x, point.y), 0.8 + point.z * 1.2, Color(0.48, 0.78, 0.95, point.z * 0.42))

    # Corner vignette bars.
    draw_rect(Rect2(0, 0, SCREEN_W, 6), Color("#101c2c"), true)
    draw_rect(Rect2(0, SCREEN_H - 8, SCREEN_W, 8), Color("#120811"), true)


func draw_outer_frame() -> void:
    # Soft frame glow.
    draw_rect(Rect2(FIELD_LEFT - 10, FIELD_TOP - 12, 672, 760).grow(7), Color(0.26, 0.75, 0.9, 0.025), true)
    draw_rect(Rect2(FIELD_LEFT - 8, FIELD_TOP - 8, FIELD_RIGHT - FIELD_LEFT + 16, FIELD_BOTTOM - FIELD_TOP + 20), Color("#02060c"), true)

    # Arena floor.
    draw_rect(Rect2(FIELD_LEFT, FIELD_TOP, FIELD_RIGHT - FIELD_LEFT, FIELD_BOTTOM - FIELD_TOP), Color("#040b14"), true)
    draw_rect(Rect2(FIELD_LEFT + 4, FIELD_TOP + 4, FIELD_RIGHT - FIELD_LEFT - 8, FIELD_BOTTOM - FIELD_TOP - 8), Color(0.015, 0.035, 0.065, 0.46), true)

    # Metallic top rail.
    draw_rect(Rect2(28, FIELD_TOP - 10, 664, 11), Color("#536878"), true)
    draw_rect(Rect2(28, FIELD_TOP - 10, 664, 3), Color("#d5e5ee"), true)
    draw_rect(Rect2(28, FIELD_TOP - 1, 664, 3), Color("#1a2732"), true)
    draw_rect(Rect2(28, FIELD_TOP - 12, 664, 2), Color(0.52, 0.92, 1.0, 0.17), true)

    # Side rails.
    for side in [-1, 1]:
        var x := FIELD_LEFT - 8.0 if side < 0 else FIELD_RIGHT + 1.0
        draw_rect(Rect2(x - 2, FIELD_TOP - 4, 12, FIELD_BOTTOM - FIELD_TOP + 8), Color("#121e28"), true)
        draw_rect(Rect2(x, FIELD_TOP - 4, 8, FIELD_BOTTOM - FIELD_TOP + 8), Color("#718695"), true)
        draw_rect(Rect2(x + 2, FIELD_TOP - 4, 2, FIELD_BOTTOM - FIELD_TOP + 8), Color("#d1e1e9"), true)
        draw_rect(Rect2(x + 6, FIELD_TOP - 4, 2, FIELD_BOTTOM - FIELD_TOP + 8), Color("#2b3945"), true)

    # Bottom danger lip.
    draw_rect(Rect2(FIELD_LEFT, FIELD_BOTTOM, FIELD_RIGHT - FIELD_LEFT, 3), Color(1.0, 0.18, 0.38, 0.82), true)
    draw_rect(Rect2(FIELD_LEFT, FIELD_BOTTOM + 4, FIELD_RIGHT - FIELD_LEFT, 1), Color(1.0, 0.35, 0.55, 0.22), true)

    # Subtle inner border.
    draw_rect(Rect2(FIELD_LEFT + 7, FIELD_TOP + 2, FIELD_RIGHT - FIELD_LEFT - 14, FIELD_BOTTOM - FIELD_TOP - 8), Color(0.35, 0.85, 1.0, 0.08), false, 1.0)


func draw_grid() -> void:
    for x in range(74, 680, 42):
        draw_line(Vector2(x, FIELD_TOP + 14), Vector2(x, FIELD_BOTTOM - 2), Color(0.22, 0.55, 0.7, 0.028), 1.0)
    for y in range(142, 840, 42):
        draw_line(Vector2(FIELD_LEFT + 8, y), Vector2(FIELD_RIGHT - 8, y), Color(0.22, 0.55, 0.7, 0.024), 1.0)


func draw_bricks() -> void:
    for brick in bricks:
        if not brick["alive"]:
            continue
        var rect: Rect2 = brick["rect"]
        var color: Color = brick["color"]
        var flash: float = brick["flash"]
        var lit := color.lerp(Color.WHITE, flash * 0.7)

        # Neon bloom and a dark silhouette keep the blocks legible at 1x.
        draw_rect(rect.grow(5.0), Color(color.r, color.g, color.b, 0.035 + flash * 0.07), true)
        draw_rect(rect.grow(6.0), Color(color.r, color.g, color.b, 0.012 + flash * 0.05), true)
        draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.82), true)
        draw_rect(rect, lit.darkened(0.30), true)
        draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 4.0)), lit, true)
        draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(rect.size.x - 2.0, 2.0)), lit.lightened(0.38), true)
        draw_rect(Rect2(rect.position + Vector2(1.0, rect.size.y - 4.0), Vector2(rect.size.x - 2.0, 2.0)), lit.darkened(0.52), true)

        if flash > 0.02:
            draw_rect(rect, Color(1.0, 1.0, 1.0, flash * 0.55), true)


func draw_walls() -> void:
    for wall in walls:
        var glow := Color(0.55, 0.82, 1.0, 0.035)
        draw_rect(wall.grow(8.0), glow, true)
        draw_rect(wall.grow(2.0), Color(0.0, 0.0, 0.0, 0.65), true)
        draw_rect(wall, Color("#5e7181"), true)
        draw_rect(Rect2(wall.position + Vector2(1.0, 1.0), wall.size - Vector2(2.0, 2.0)), Color("#8599a9"), true)

        if wall.size.x >= wall.size.y:
            draw_line(wall.position + Vector2(2.0, 1.0), Vector2(wall.end.x - 2.0, wall.position.y + 1.0), Color("#d8e8f2"), 1.4, true)
            draw_line(wall.position + Vector2(2.0, wall.size.y - 2.0), Vector2(wall.end.x - 2.0, wall.end.y - 2.0), Color("#293845"), 1.4, true)
            draw_circle(wall.position + Vector2(wall.size.y * 0.5, wall.size.y * 0.5), wall.size.y * 0.48, Color("#718695"))
            draw_circle(Vector2(wall.end.x - wall.size.y * 0.5, wall.position.y + wall.size.y * 0.5), wall.size.y * 0.48, Color("#718695"))
        else:
            draw_line(wall.position + Vector2(1.0, 2.0), Vector2(wall.position.x + 1.0, wall.end.y - 2.0), Color("#d8e8f2"), 1.4, true)
            draw_line(wall.position + Vector2(wall.size.x - 2.0, 2.0), Vector2(wall.end.x - 2.0, wall.end.y - 2.0), Color("#293845"), 1.4, true)
            draw_circle(wall.position + Vector2(wall.size.x * 0.5, wall.size.x * 0.5), wall.size.x * 0.48, Color("#718695"))
            draw_circle(Vector2(wall.position.x + wall.size.x * 0.5, wall.end.y - wall.size.x * 0.5), wall.size.x * 0.48, Color("#718695"))


func draw_powerups() -> void:
    for item in powerups:
        var base: Vector2 = item["pos"]
        var age: float = item["age"]
        var phase: float = item["phase"]
        var kind: String = item["kind"]
        var color: Color = item["color"]
        var pos := base + Vector2(0.0, sin(age * 5.2 + phase) * 4.0)
        var pulse := sin(age * 8.0 + phase) * 0.5 + 0.5

        draw_circle(pos, 22.0 + pulse * 4.0, Color(color.r, color.g, color.b, 0.026))
        draw_circle(pos, 15.0 + pulse * 2.0, Color(color.r, color.g, color.b, 0.070))
        draw_arc(pos, 17.0 + pulse * 3.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.27), 1.4, true)

        var diamond := PackedVector2Array([
            pos + Vector2(0.0, -14.0),
            pos + Vector2(14.0, 0.0),
            pos + Vector2(0.0, 14.0),
            pos + Vector2(-14.0, 0.0),
        ])
        draw_colored_polygon(diamond, Color(0.012, 0.030, 0.052, 0.97))
        draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), color, 1.8, true)

        var inner := PackedVector2Array([
            pos + Vector2(0.0, -9.0),
            pos + Vector2(9.0, 0.0),
            pos + Vector2(0.0, 9.0),
            pos + Vector2(-9.0, 0.0),
        ])
        draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.18 + pulse * 0.09))

        if kind == "multiball":
            draw_circle(pos + Vector2(-4.2, -1.0), 2.7, Color.WHITE)
            draw_circle(pos + Vector2(4.2, 1.0), 2.7, color)
            if font != null:
                draw_string(font, pos + Vector2(-24.0, 26.0), "MULTI", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 9, Color(color.r, color.g, color.b, 0.82))
        else:
            for k in range(2):
                var x := pos.x - 6.0 + float(k) * 8.0
                var chevron := PackedVector2Array([
                    Vector2(x - 3.5, pos.y - 6.0),
                    Vector2(x + 2.0, pos.y),
                    Vector2(x - 3.5, pos.y + 6.0),
                ])
                draw_polyline(chevron, Color.WHITE if k == 0 else color, 2.3, true)
            if font != null:
                draw_string(font, pos + Vector2(-24.0, 26.0), "SPEED", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 9, Color(color.r, color.g, color.b, 0.82))


func draw_trails() -> void:
    for ball in balls:
        var trail: Array = ball["trail"]
        if trail.size() < 2:
            continue
        var fire := is_fire_active()
        for i in range(trail.size() - 1):
            var t := float(i) / float(maxi(trail.size() - 1, 1))
            var alpha := (0.18 + t * 0.82) * (1.0 if fire else 0.92)
            var width := 1.8 + t * (8.0 if fire else 6.5)
            var color := GOLD if fire else CYAN
            if not fire and i % 5 == 0:
                color = PINK.lerp(CYAN, 0.25)
            elif fire and i % 3 == 0:
                color = PINK

            # A wide colored bloom with a white-hot center reads like neon even
            # without a post-processing glow pass.
            draw_line(trail[i], trail[i + 1], Color(color.r, color.g, color.b, alpha * 0.22), width * 3.3, true)
            draw_line(trail[i], trail[i + 1], Color(color.r, color.g, color.b, alpha), width, true)
            draw_line(trail[i], trail[i + 1], Color(1.0, 1.0, 1.0, alpha * 0.58), maxf(1.0, width * 0.24), true)

            if i % 3 == 0:
                var dot_radius := 1.0 + t * 2.6
                draw_circle(trail[i], dot_radius * 2.8, Color(color.r, color.g, color.b, alpha * 0.045))
                draw_circle(trail[i], dot_radius, Color(color.r, color.g, color.b, alpha * 0.48))


func draw_particles() -> void:
    for p in particles:
        var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
        var color: Color = p["color"]
        var size: float = p["size"] * (0.45 + alpha * 0.55)
        draw_rect(Rect2(p["pos"] - Vector2(size, size) * 0.5, Vector2(size, size)), Color(color.r, color.g, color.b, alpha), true)


func draw_paddle() -> void:
    var half := PADDLE_W * 0.5
    var top := PADDLE_Y - PADDLE_H * 0.5
    var rect := Rect2(paddle_x - half, top, PADDLE_W, PADDLE_H)
    var fire := is_fire_active()
    var color := ORANGE if fire else CYAN

    # Wide soft glow.
    draw_rect(rect.grow(14.0), Color(color.r, color.g, color.b, 0.028), true)
    draw_rect(rect.grow(7.0), Color(color.r, color.g, color.b, 0.070), true)

    var body := Color("#54e4e6") if not fire else Color("#ffb04f")
    draw_rect(Rect2(rect.position.x + PADDLE_H * 0.5, rect.position.y, rect.size.x - PADDLE_H, rect.size.y), body, true)
    draw_circle(Vector2(rect.position.x + PADDLE_H * 0.5, rect.get_center().y), PADDLE_H * 0.5, body)
    draw_circle(Vector2(rect.end.x - PADDLE_H * 0.5, rect.get_center().y), PADDLE_H * 0.5, body)

    draw_rect(Rect2(rect.position.x + 8.0, rect.position.y + 2.0, rect.size.x - 16.0, 2.0), Color(0.92, 1.0, 1.0, 0.92), true)
    draw_rect(Rect2(rect.position.x + 12.0, rect.position.y + 6.0, rect.size.x - 24.0, 2.0), Color(color.r, color.g, color.b, 0.48), true)

    # Center energy strip and lower reflection.
    draw_line(Vector2(paddle_x - 18.0, rect.end.y + 1.0), Vector2(paddle_x + 18.0, rect.end.y + 1.0), Color(1.0, 1.0, 1.0, 0.60), 1.2, true)
    draw_line(Vector2(paddle_x - 26.0, rect.end.y + 5.0), Vector2(paddle_x + 26.0, rect.end.y + 5.0), Color(color.r, color.g, color.b, 0.18), 2.0, true)


func draw_balls() -> void:
    if state == "ready":
        var ready_pos := Vector2(paddle_x, PADDLE_Y - 28.0)
        draw_ball_glow(ready_pos, 6.0, CYAN, 0.8)
        return

    for ball in balls:
        var pos: Vector2 = ball["pos"]
        var radius: float = ball["radius"]
        var fire := is_fire_active()
        var color := GOLD if fire else CYAN
        draw_ball_glow(pos, radius, color, 1.0)

        if fire:
            draw_circle(pos, radius + 3.0, Color(PINK.r, PINK.g, PINK.b, 0.35))
        draw_circle(pos, radius + 1.2, color)
        draw_circle(pos, radius, Color("#f6ffff") if not fire else Color("#fff5dc"))
        draw_circle(pos + Vector2(-1.5, -1.5), maxf(1.2, radius * 0.34), Color.WHITE)
        draw_line(pos + Vector2(-2, -12), pos + Vector2(-2, -7), Color(color.r, color.g, color.b, 0.65), 1.0, true)
        draw_line(pos + Vector2(2, -12), pos + Vector2(2, -7), Color(color.r, color.g, color.b, 0.65), 1.0, true)


func draw_ball_glow(pos: Vector2, radius: float, color: Color, alpha: float) -> void:
    var pulse := 1.0 + sin(game_time * 7.0) * 0.08
    draw_circle(pos, radius * 7.0 * pulse, Color(color.r, color.g, color.b, 0.022 * alpha))
    draw_circle(pos, radius * 4.3 * pulse, Color(color.r, color.g, color.b, 0.055 * alpha))
    draw_circle(pos, radius * 2.8 * pulse, Color(color.r, color.g, color.b, 0.12 * alpha))


func draw_floaters() -> void:
    if font == null:
        return
    for floater in floaters:
        var life: float = floater["life"]
        var max_life: float = floater["max_life"]
        var alpha := clampf(life / max_life, 0.0, 1.0)
        var pos: Vector2 = floater["pos"]
        var color: Color = floater["color"]
        var size: int = floater["size"]
        draw_string(
            font,
            pos + Vector2(-70.0, 0.0),
            floater["text"],
            HORIZONTAL_ALIGNMENT_CENTER,
            140.0,
            size,
            Color(color.r, color.g, color.b, alpha)
        )


func draw_bottom_meter() -> void:
    var meter_rect := Rect2(24.0, 893.0, 672.0, 5.0)
    draw_rect(meter_rect, Color(0.07, 0.11, 0.17, 0.95), true)
    var fill := fire_time / 6.0 if is_fire_active() else fire_energy / 100.0
    fill = clampf(fill, 0.0, 1.0)
    var fill_color := ORANGE if is_fire_active() else GOLD
    draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * fill, meter_rect.size.y)), fill_color, true)
    draw_line(Vector2(meter_rect.position.x, meter_rect.position.y - 1.0), Vector2(meter_rect.end.x, meter_rect.position.y - 1.0), Color(0.6, 0.9, 1.0, 0.08), 1.0)
    for i in range(1, 10):
        var x := meter_rect.position.x + meter_rect.size.x * float(i) / 10.0
        draw_line(Vector2(x, meter_rect.position.y), Vector2(x, meter_rect.end.y), Color(0.0, 0.0, 0.0, 0.35), 1.0)





























