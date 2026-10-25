extends SceneTree

func _initialize() -> void:
    var main = load("res://main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    main.set_process(false)
    main.state = "playing"
    main.launch_ball(false)
    main.powerups.append({
        "pos": Vector2(250.0, 440.0),
        "vel": Vector2(-8.0, 95.0),
        "kind": "multiball",
        "color": main.CYAN,
        "age": 0.0,
        "phase": 0.4,
    })
    main.powerups.append({
        "pos": Vector2(470.0, 510.0),
        "vel": Vector2(10.0, 95.0),
        "kind": "speed",
        "color": main.GOLD,
        "age": 0.0,
        "phase": 1.7,
    })

    main.update_ui()
    main.queue_redraw()
    await create_timer(0.45).timeout
    await RenderingServer.frame_post_draw
    var image: Image = main.get_viewport().get_texture().get_image()
    image.save_png(ProjectSettings.globalize_path("res://powerup_preview.png"))
    print("POWERUP PREVIEW frames drawn")
    quit(0)



