extends Node

var config: GameConfig
var world: GameWorld
var effects: GameEffects
var renderer: GameRenderer
var hud: GameHUD
var audio: GameAudioManager
var input := PlayerInputController.new()


func _ready() -> void:
    config = load("res://resources/game_config.tres")
    assert(config != null, "Game config could not be loaded")
    assert(config.level != null, "Game config requires a level")
    assert(config.powerups != null, "Game config requires a powerup catalog")

    world = GameWorld.new(config)
    world.reset_run()
    effects = GameEffects.new()

    renderer = GameRenderer.new()
    add_child(renderer)
    renderer.setup(world, effects)

    audio = GameAudioManager.new()
    add_child(audio)

    hud = GameHUD.new()
    add_child(hud)
    hud.setup(world, effects)
    consume_events()


func _physics_process(delta: float) -> void:
    input.update(delta, world)
    world.step(delta)
    effects.update(delta, world)
    consume_events()
    hud.update_view()


func _unhandled_input(event: InputEvent) -> void:
    input.handle_event(event, world)
    consume_events()
    hud.update_view()


func _exit_tree() -> void:
    if audio != null:
        audio.stop_all()


func consume_events() -> void:
    for event in world.drain_events():
        if event.type == GameEvent.Type.RUN_RESET:
            effects.reset()
        effects.handle_event(event, world)
        audio.handle_event(event)
