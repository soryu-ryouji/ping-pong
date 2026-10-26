class_name LevelGenerator
extends RefCounted


static func generate(definition: LevelDefinition, wave: int, rng: RandomNumberGenerator) -> Array[BrickData]:
    var result: Array[BrickData] = []
    var carved := {}
    for cell in definition.carved_cells:
        carved[cell] = true

    for row in range(definition.rows):
        for column in range(definition.columns):
            var cell := Vector2i(column, row)
            if carved.has(cell) or rng.randf() < definition.random_carve_chance:
                continue

            var rect := Rect2(
                definition.brick_origin + Vector2(column, row) * definition.brick_step,
                definition.brick_size
            )
            if _intersects_wall(rect, definition.walls):
                continue

            var hue := lerpf(
                definition.hue_start,
                definition.hue_end,
                float(row) / float(maxi(definition.rows - 1, 1))
            )
            hue = fmod(hue + rng.randf_range(-definition.hue_jitter, definition.hue_jitter) + 1.0, 1.0)
            var brick := BrickData.new()
            brick.rect = rect
            brick.color = Color.from_hsv(hue, 0.72, 0.93)
            result.append(brick)

    if wave > 1 and not result.is_empty():
        var precleared := mini(definition.later_wave_preclear_limit, result.size() / 4)
        for index in range(precleared):
            var pick := rng.randi_range(0, result.size() - 1)
            if result[pick].alive:
                result[pick].alive = false
    return result


static func _intersects_wall(rect: Rect2, walls: Array[Rect2]) -> bool:
    for wall in walls:
        if wall.grow(3.0).intersects(rect):
            return true
    return false
