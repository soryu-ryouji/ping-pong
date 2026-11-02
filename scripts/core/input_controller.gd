class_name PlayerInputController
extends RefCounted


func update(delta: float, world: GameWorld) -> void:
    world.nudge_paddle(Input.get_axis("ui_left", "ui_right"), delta)


func handle_event(event: InputEvent, world: GameWorld) -> void:
    if event is InputEventMouseMotion:
        world.set_paddle_target(event.position.x)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        world.set_paddle_target(event.position.x)
        world.primary_action()
    elif event is InputEventScreenTouch:
        world.set_paddle_target(event.position.x)
        if event.pressed:
            world.primary_action()
    elif event is InputEventScreenDrag:
        world.set_paddle_target(event.position.x)

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            world.primary_action()
        elif event.keycode == KEY_R:
            if world.config.debug_tools and event.shift_pressed:
                world.restart_level_debug()
            else:
                world.reset_run()
        elif world.config.debug_tools:
            if event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_PAGEUP:
                world.previous_level_debug()
            elif event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_PAGEDOWN:
                world.next_level_debug()
            elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
                var target_index: int = event.keycode - KEY_1
                if target_index < world.levels.size():
                    world.jump_to_level(target_index)
