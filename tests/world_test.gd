extends SceneTree

var failures := 0


func _initialize() -> void:
    test_geometry()
    test_deterministic_simulation()
    test_wave_and_fire_state()
    test_level_cycle()
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


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
