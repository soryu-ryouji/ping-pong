extends SceneTree

func _initialize() -> void:
    var main = load("res://main.tscn").instantiate()
    root.add_child(main)
    main.state = "playing"
    main.launch_ball(false)

    if main.balls.size() != 1:
        push_error("Expected one launch ball")
        quit(1)
        return

    # Drop a multiball pickup directly onto the paddle and run one update.
    main.powerups.append({
        "pos": Vector2(main.paddle_x, main.PADDLE_Y),
        "vel": Vector2.ZERO,
        "kind": "multiball",
        "color": main.CYAN,
        "age": 0.0,
        "phase": 0.0,
    })
    main.update_powerups(0.016)
    if not main.powerups.is_empty():
        push_error("Multiball pickup was not collected")
        quit(1)
        return
    if main.balls.size() != 2:
        push_error("Multiball did not double active balls: %d" % main.balls.size())
        quit(1)
        return

    # Doubling again should turn 2 balls into 4.
    main.apply_multiball_powerup(Vector2.ZERO)
    if main.balls.size() != 4:
        push_error("Second multiball did not double 2 -> 4: %d" % main.balls.size())
        quit(1)
        return

    var speed_before: float = main.balls[0]["vel"].length()
    main.powerups.append({
        "pos": Vector2(main.paddle_x, main.PADDLE_Y),
        "vel": Vector2.ZERO,
        "kind": "speed",
        "color": main.GOLD,
        "age": 0.0,
        "phase": 0.0,
    })
    main.update_powerups(0.016)
    var speed_after: float = main.balls[0]["vel"].length()
    if speed_after <= speed_before:
        push_error("Speed pickup did not increase ball speed: %.1f -> %.1f" % [speed_before, speed_after])
        quit(1)
        return

    # Pity-based drop scheduling must expose both kinds, alternating.
    main.powerups.clear()
    main.powerup_pity = 0
    main.powerup_drop_counter = 0
    for i in range(16):
        main.try_drop_powerup(Vector2(300.0 + i, 300.0), false)
    if main.powerups.size() < 2:
        push_error("Expected at least two pity drops, got %d" % main.powerups.size())
        quit(1)
        return
    if main.powerups[0]["kind"] != "multiball" or main.powerups[1]["kind"] != "speed":
        push_error("Powerup kinds did not alternate: %s, %s" % [main.powerups[0]["kind"], main.powerups[1]["kind"]])
        quit(1)
        return

    print("POWERUP TEST PASS balls=%d speed=%.1f->%.1f drops=%d kinds=%s/%s" % [
        main.balls.size(),
        speed_before,
        speed_after,
        main.powerups.size(),
        main.powerups[0]["kind"],
        main.powerups[1]["kind"],
    ])
    quit(0)

