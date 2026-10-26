extends SceneTree

var failures := 0


func _initialize() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var world := GameWorld.new(config)
    world.reset_run()
    world.state = GameWorld.State.PLAYING
    world.launch_ball(false)
    check(world.balls.size() == 1, "Expected one launch ball")

    world.spawn_powerup(&"multiball", Vector2(world.paddle_x, config.paddle_y))
    world.update_powerups(0.016)
    check(world.powerups.is_empty(), "Multiball pickup was not collected")
    check(world.balls.size() == 2, "Multiball did not double active balls")

    var multiball := config.powerups.get_definition(&"multiball")
    multiball.apply(world, Vector2.ZERO)
    check(world.balls.size() == 4, "Second multiball did not double 2 -> 4")

    var speed_before := world.balls[0].velocity.length()
    world.spawn_powerup(&"speed", Vector2(world.paddle_x, config.paddle_y))
    world.update_powerups(0.016)
    var speed_after := world.balls[0].velocity.length()
    check(speed_after > speed_before, "Speed pickup did not increase ball speed")

    world.powerups.clear()
    world.powerup_pity = 0
    world.powerup_drop_counter = 0
    for index in range(16):
        world.try_drop_powerup(Vector2(300.0 + index, 300.0), false)
    check(world.powerups.size() >= 2, "Expected at least two pity drops")
    if world.powerups.size() >= 2:
        check(world.powerups[0].definition.id == &"multiball", "First drop should be multiball")
        check(world.powerups[1].definition.id == &"speed", "Second drop should be speed")

    if failures == 0:
        print("POWERUP TEST PASS balls=%d speed=%.1f->%.1f drops=%d" % [world.balls.size(), speed_before, speed_after, world.powerups.size()])
    quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
