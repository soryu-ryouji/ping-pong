extends SceneTree


func _initialize() -> void:
    call_deferred("run")


func run() -> void:
    var main = load("res://main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    main.set_physics_process(false)
    main.world.state = GameWorld.State.PLAYING
    main.world.launch_ball(false)
    main.world.spawn_powerup(&"multiball", Vector2(250.0, 440.0), Vector2(-8.0, 95.0))
    main.world.spawn_powerup(&"speed", Vector2(470.0, 510.0), Vector2(10.0, 95.0))
    main.world.powerups[0].age = 0.0
    main.world.powerups[0].phase = 0.4
    main.world.powerups[1].age = 0.0
    main.world.powerups[1].phase = 1.7
    main.consume_events()
    main.hud.update_view()
    main.renderer.queue_redraw()
    await create_timer(0.45).timeout
    await RenderingServer.frame_post_draw
    var image: Image = main.get_viewport().get_texture().get_image()
    image.save_png(ProjectSettings.globalize_path("res://powerup_preview.png"))
    print("POWERUP PREVIEW frames drawn")
    quit(0)
