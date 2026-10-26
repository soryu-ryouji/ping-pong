class_name PowerupDefinition
extends Resource

@export var id: StringName = &""
@export var display_name := "POWERUP"
@export var short_name := "POWER"
@export var color := Color.WHITE
@export_range(0.5, 2.0) var pickup_pitch := 1.0


func apply(_world: Variant, _pickup_position: Vector2) -> void:
    push_warning("Powerup '%s' has no effect implementation" % id)
