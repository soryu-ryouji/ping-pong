class_name GameEvent
extends RefCounted

enum Type {
    BALL_LAUNCHED,
    WALL_HIT,
    PADDLE_HIT,
    BALL_LOST,
    BRICK_DESTROYED,
    POWERUP_DROPPED,
    POWERUP_COLLECTED,
    SPEED_CHANGED,
    FIRE_STARTED,
    FIRE_ENDED,
    LEVEL_CLEARED,
    LEVEL_STARTED,
    GAME_OVER,
    MESSAGE,
    OBSTACLE_HIT,
    BALL_SPLIT,
    COMBO_POP,
    RUN_RESET,
}

var type: Type
var position := Vector2.ZERO
var color := Color.WHITE
var value := 0.0
var text := ""
var size := 0
var lifetime := 0.0


func _init(event_type: Type, event_position := Vector2.ZERO, event_color := Color.WHITE) -> void:
    type = event_type
    position = event_position
    color = event_color
