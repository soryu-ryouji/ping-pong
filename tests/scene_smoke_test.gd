extends SceneTree


func _initialize() -> void:
    call_deferred("run")


func run() -> void:
    var main = load("res://main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    if main.world == null or main.renderer == null or main.hud == null or main.audio == null:
        push_error("Main scene composition is incomplete")
        quit(1)
        return
    main.world.primary_action()
    await process_frame
    if main.world.balls.is_empty():
        push_error("Main scene did not launch a ball")
        quit(1)
        return
    print("SCENE SMOKE TEST PASS")
    main.audio.stop_all()
    main.queue_free()
    await process_frame
    quit(0)
