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
            world.reset_run()
