class_name CollisionHit
extends RefCounted

var normal := Vector2.ZERO
var penetration := 0.0


func _init(hit_normal := Vector2.ZERO, hit_penetration := 0.0) -> void:
    normal = hit_normal
    penetration = hit_penetration
