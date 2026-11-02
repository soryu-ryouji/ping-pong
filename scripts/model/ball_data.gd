class_name BallData
extends RefCounted

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 7.0
var trail: Array[Vector2] = []
var spin := 0.0
var stuck_time := 0.0
var stuck_check := 0.0
var stuck_reference := Vector2.ZERO


func copy_for_split(offset: Vector2, split_angle: float, new_spin: float) -> BallData:
    var copy := BallData.new()
    copy.position = position + offset
    copy.velocity = velocity.rotated(split_angle)
    copy.radius = radius
    copy.spin = new_spin
    copy.stuck_reference = copy.position
    return copy
