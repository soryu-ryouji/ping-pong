class_name CollisionGeometry
extends RefCounted


static func circle_rect_hit(center: Vector2, radius: float, rect: Rect2) -> CollisionHit:
    if not rect.grow(radius).has_point(center):
        return null

    var closest := Vector2(
        clampf(center.x, rect.position.x, rect.end.x),
        clampf(center.y, rect.position.y, rect.end.y)
    )
    var difference := center - closest
    var distance_squared := difference.length_squared()
    if distance_squared > radius * radius:
        return null
    if distance_squared > 0.0001:
        var distance := sqrt(distance_squared)
        return CollisionHit.new(difference / distance, radius - distance)

    var left := center.x - rect.position.x
    var right := rect.end.x - center.x
    var top := center.y - rect.position.y
    var bottom := rect.end.y - center.y
    var nearest := minf(minf(left, right), minf(top, bottom))
    if nearest == left:
        return CollisionHit.new(Vector2.LEFT, left + radius)
    if nearest == right:
        return CollisionHit.new(Vector2.RIGHT, right + radius)
    if nearest == top:
        return CollisionHit.new(Vector2.UP, top + radius)
    return CollisionHit.new(Vector2.DOWN, bottom + radius)
