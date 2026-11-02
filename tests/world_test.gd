extends SceneTree

var failures := 0


func _initialize() -> void:
    test_geometry()
    test_deterministic_simulation()
    test_wave_and_fire_state()
    test_level_cycle()
    test_debug_level_navigation()
    test_paddle_growth()
    test_paddle_move_speed()
    test_ball_bounce_speed_cap()
    test_paddle_shrink_on_loss()
    test_wall_penetration_resolution()
    test_breakable_wall_hp()
    test_breakable_wall_collision_speed()
    test_speed_powerup_uncapped()
    test_stuck_ball_rescue()
    test_xp_level_up()
    test_brick_hit_stages()
    quit(1 if failures > 0 else 0)


func test_geometry() -> void:
    var hit := CollisionGeometry.circle_rect_hit(Vector2(5.0, -2.0), 3.0, Rect2(0, 0, 10, 10))
    check(hit != null, "Expected circle/rect hit")
    if hit != null:
        check(hit.normal.is_equal_approx(Vector2.UP), "Expected top normal")
        check(is_equal_approx(hit.penetration, 1.0), "Expected penetration of 1")
    check(CollisionGeometry.circle_rect_hit(Vector2(-10, -10), 2.0, Rect2(0, 0, 10, 10)) == null, "Expected separated shapes")


func test_deterministic_simulation() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var first := GameWorld.new(config)
    var second := GameWorld.new(config)
    first.reset_run()
    second.reset_run()
    first.primary_action()
    second.primary_action()
    for index in range(180):
        first.step(1.0 / 60.0)
        second.step(1.0 / 60.0)
    check(first.balls.size() == second.balls.size(), "Deterministic ball count mismatch")
    check(first.powerups.size() == second.powerups.size(), "Deterministic drop count mismatch")
    check(first.remaining_bricks == second.remaining_bricks, "Deterministic brick count mismatch")
    if not first.balls.is_empty() and not second.balls.is_empty():
        check(first.balls[0].position.is_equal_approx(second.balls[0].position), "Deterministic ball position mismatch")
    if failures == 0:
        print("WORLD TEST geometry/determinism PASS")


func test_wave_and_fire_state() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    world.start_fire_rush()
    check(world.is_fire_active(), "Fire rush should be active")
    world.state = GameWorld.State.PLAYING
    world.step(config.fire_duration + 0.01)
    check(not world.is_fire_active(), "Fire rush should expire")
    check(world.fire_energy == 0.0, "Fire energy should reset after rush")


func test_level_cycle() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var level_count := world.levels.size()
    check(level_count >= 1, "Expected at least one loaded level")
    check(world.level_index == 0, "Run should start on the first level")
    check(world.loop_count == 1, "Run should start on loop 1")
    if level_count < 1:
        return

    for step_index in range(level_count):
        world.clear_level()
        world.step(3.0)
        check(
            world.level_index == (step_index + 1) % level_count,
            "Unexpected level index after clear"
        )
        check(world.wave == step_index + 2, "Wave counter did not advance")

    check(world.loop_count == 2, "Completing the last level should increment the loop count")
    check(world.current_level() != null, "Loop should return to a valid level")


func test_debug_level_navigation() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var level_count := world.levels.size()
    check(config.debug_tools, "Debug tools should be enabled in the dev config")
    check(level_count >= 1, "Expected at least one loaded level")
    if level_count < 1:
        return

    var target := mini(2, level_count - 1)
    world.jump_to_level(target)
    check(world.level_index == target, "Debug jump did not select the target level")
    check(world.wave == target + 1, "Debug jump did not set the wave counter")
    check(world.state == GameWorld.State.READY, "Debug jump should return to READY")
    check(world.balls.is_empty(), "Debug jump should clear active balls")

    if level_count > 1:
        world.previous_level_debug()
        var previous := (target - 1 + level_count) % level_count
        check(world.level_index == previous, "Debug previous level did not wrap correctly")
        check(world.wave == previous + 1, "Debug previous level did not update the wave counter")

    var input := PlayerInputController.new()
    var jump_key := InputEventKey.new()
    jump_key.pressed = true
    var key_target := mini(1, level_count - 1)
    jump_key.keycode = KEY_1 + key_target
    input.handle_event(jump_key, world)
    check(world.level_index == key_target, "Number key did not jump to the expected level")

    var next_key := InputEventKey.new()
    next_key.pressed = true
    next_key.keycode = KEY_BRACKETRIGHT
    input.handle_event(next_key, world)
    check(
        world.level_index == (key_target + 1) % level_count,
        "Right bracket did not advance the level"
    )

    var previous_key := InputEventKey.new()
    previous_key.pressed = true
    previous_key.keycode = KEY_BRACKETLEFT
    input.handle_event(previous_key, world)
    check(world.level_index == key_target, "Left bracket did not return to the previous level")

    world.state = GameWorld.State.PLAYING
    world.launch_ball(false)
    var restart_key := InputEventKey.new()
    restart_key.pressed = true
    restart_key.keycode = KEY_R
    restart_key.shift_pressed = true
    input.handle_event(restart_key, world)
    check(world.state == GameWorld.State.READY, "Shift+R should restart the current level")
    check(world.balls.is_empty(), "Shift+R should clear active balls")


func test_paddle_growth() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var max_width := world.paddle_max_width()
    check(is_equal_approx(world.paddle_width, config.paddle_width), "Paddle should start at base width")
    check(max_width > config.paddle_width, "Brick wall should allow some paddle growth")
    world.on_paddle_hit(Vector2(world.paddle_x, config.paddle_y))
    check(
        is_equal_approx(world.paddle_width, config.paddle_width + config.paddle_grow_per_hit),
        "Paddle should grow by the configured amount after a hit"
    )
    world.paddle_width = max_width - 1.0
    world.on_paddle_hit(Vector2(world.paddle_x, config.paddle_y))
    check(
        is_equal_approx(world.paddle_width, max_width),
        "Paddle width should cap at the brick wall width"
    )
    check(world.paddle_flash > 0.0, "Paddle hit should trigger the upgrade flash")
    world.reset_run()
    check(is_equal_approx(world.paddle_width, config.paddle_width), "Run reset should restore base paddle width")
    check(world.paddle_flash == 0.0, "Run reset should clear paddle flash")


func test_paddle_move_speed() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var base_speed := world.paddle_move_speed()
    check(is_equal_approx(base_speed, config.paddle_base_move_speed), "Paddle should start at base move speed")
    world.paddle_width = world.paddle_max_width()
    var wide_speed := world.paddle_move_speed()
    check(wide_speed < base_speed, "Wide paddle should move slower")
    check(is_equal_approx(wide_speed, config.paddle_min_move_speed), "Wide paddle should reach minimum move speed")
    world.paddle_width = config.paddle_width
    check(
        is_equal_approx(world.paddle_move_speed(), base_speed),
        "Shrinking paddle should restore base move speed"
    )


func test_ball_bounce_speed_cap() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    check(
        is_equal_approx(config.max_ball_speed, config.base_ball_speed * 3.0),
        "Maximum ball speed should be three times the base speed"
    )
    var ball := BallData.new()
    ball.velocity = Vector2(config.base_ball_speed, 0.0)
    var before := ball.velocity.length()
    world.boost_ball_speed(ball, config.bounce_speed_increment)
    check(ball.velocity.length() > before, "Bounce should increase ball speed")
    for index in range(1000):
        world.boost_ball_speed(ball, config.bounce_speed_increment)
    check(
        is_equal_approx(ball.velocity.length(), config.max_ball_speed),
        "Bounce speed should stop at the configured maximum"
    )


func test_paddle_shrink_on_loss() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    world.paddle_width = 200.0
    var speed_before := world.paddle_move_speed()
    var ball := BallData.new()
    ball.position = Vector2(world.paddle_x, config.field_bottom + 40.0)
    ball.velocity = Vector2(0.0, 100.0)
    world.balls.append(ball)
    world.state = GameWorld.State.PLAYING
    world.step(0.016)
    var expected := config.paddle_width + (200.0 - config.paddle_width) / 3.0
    check(is_equal_approx(world.paddle_width, expected), "Ball loss should remove two thirds of extra paddle width")
    check(world.paddle_move_speed() > speed_before, "Ball loss shrink should restore some paddle move speed")


func test_breakable_wall_hp() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var wall := BreakableWallData.new()
    wall.hp = config.breakable_wall_hp
    wall.max_hp = config.breakable_wall_hp
    check(
        not world.hit_breakable_wall(wall, config.breakable_wall_min_speed - 1.0),
        "Slow ball should not damage a breakable wall"
    )
    check(wall.hp == config.breakable_wall_hp, "Slow hit should not consume wall HP")
    for index in range(config.breakable_wall_hp - 1):
        world.hit_breakable_wall(wall, config.breakable_wall_min_speed)
    check(wall.alive, "Breakable wall should survive until the final hit")
    world.hit_breakable_wall(wall, config.breakable_wall_min_speed)
    check(not wall.alive, "Breakable wall should break after 99 qualifying hits")


func test_breakable_wall_collision_speed() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    world.breakable_walls.clear()
    var wall := BreakableWallData.new()
    wall.rect = Rect2(300.0, 300.0, 12.0, 100.0)
    wall.hp = 99
    wall.max_hp = 99
    world.breakable_walls.append(wall)

    var ball := BallData.new()
    ball.position = Vector2(294.0, 350.0)
    ball.velocity = Vector2(config.breakable_wall_min_speed - 1.0, 0.0)
    world.collision.collide_breakable_walls(world, ball)
    check(wall.hp == 99, "Below-threshold ball should not damage a breakable wall")

    ball.position = Vector2(294.0, 350.0)
    ball.velocity = Vector2(config.breakable_wall_min_speed, 0.0)
    world.collision.collide_breakable_walls(world, ball)
    check(wall.hp == 98, "Qualifying ball should damage a breakable wall")


func test_speed_powerup_uncapped() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var ball := BallData.new()
    ball.velocity = Vector2(config.max_ball_speed, 0.0)
    world.balls.append(ball)
    var speed_definition := config.powerups.get_definition(&"speed")
    check(speed_definition != null, "SPEED powerup should exist")
    if speed_definition != null:
        speed_definition.apply(world, Vector2.ZERO)
    check(
        ball.velocity.length() > config.max_ball_speed,
        "SPEED powerup should accelerate beyond the bounce cap"
    )
    var boosted_speed := ball.velocity.length()
    world.boost_ball_speed(ball, config.bounce_speed_increment)
    check(
        is_equal_approx(ball.velocity.length(), boosted_speed),
        "Bounce boost should not reduce an over-cap SPEED ball"
    )


func test_stuck_ball_rescue() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var ball := BallData.new()
    ball.position = Vector2(360.0, 400.0)
    ball.velocity = Vector2.ZERO
    ball.stuck_reference = ball.position
    ball.stuck_time = 2.0
    ball.stuck_check = 0.5
    world.balls.append(ball)
    world.state = GameWorld.State.PLAYING
    world.step(0.016)
    check(ball.position.y > 700.0, "Stuck ball should be moved back near the paddle")
    check(ball.velocity.y < 0.0, "Stuck ball should be relaunched upward")


func test_wall_penetration_resolution() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    world.walls.clear()
    world.walls.append(Rect2(300.0, 300.0, 20.0, 20.0))
    var ball := BallData.new()
    ball.position = Vector2(310.0, 310.0)
    ball.velocity = Vector2(100.0, 0.0)
    var before_speed := ball.velocity.length()
    world.collision.collide_walls(world, ball)
    check(not world.walls[0].has_point(ball.position), "Wall collision should push the ball out")
    check(ball.velocity.length() > before_speed, "Wall bounce should increase ball speed")


func test_xp_level_up() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    check(world.xp_level == 1, "XP should start at level 1")
    check(world.xp == 0.0, "XP should start empty")
    check(
        is_equal_approx(world.xp_required, config.xp_required_base),
        "First XP requirement should use the configured base"
    )
    check(
        world.xp_gain_for_combo(100) > world.xp_gain_for_combo(10),
        "Higher combo should grant more XP per hit"
    )
    world.primary_action()
    var balls_before := world.balls.size()
    var required := world.xp_required
    world.add_xp(required)
    check(world.xp_level == 2, "Filling the XP bar should level up")
    check(world.balls.size() == balls_before * 2, "XP level up should double current balls")
    check(world.xp_flash > 0.0, "XP level up should trigger the bar flash")
    check(world.xp_required > required, "Next XP requirement should increase")
    check(world.xp < world.xp_required, "XP remainder should be below the new requirement")
    world.reset_run()
    var xp_before := world.xp
    world.on_paddle_hit(Vector2(world.paddle_x, config.paddle_y))
    check(world.combo == 1, "Paddle catch should increment COMBO")
    check(world.xp > xp_before, "Paddle catch should grant XP")
    world.destroy_brick(world.bricks[0])
    check(world.combo == 1, "Brick destruction should not change paddle COMBO")
    world.reset_run()
    check(world.xp == 0.0 and world.xp_level == 1, "Run reset should clear XP progress")


func test_brick_hit_stages() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    var brick := BrickData.new()
    brick.max_hp = 3
    brick.hp = 3
    brick.color = Color.GREEN

    check(not world.hit_brick(brick, 1), "Three-HP brick should survive the first hit")
    check(brick.hp == 2, "Three-HP brick should drop to two HP")
    check(brick.shake > 0.0, "Brick hit should start shake")
    check(not world.hit_brick(brick, 1), "Three-HP brick should survive the second hit")
    check(brick.hp == 1, "Three-HP brick should drop to one HP")
    check(world.hit_brick(brick, 1), "Three-HP brick should break on the third hit")
    check(not brick.alive, "Broken brick should no longer be alive")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
