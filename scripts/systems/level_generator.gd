class_name LevelGenerator
extends RefCounted


static func generate(definition: LevelDefinition, rng: RandomNumberGenerator) -> Array[BrickData]:
    var result: Array[BrickData] = []
    if definition == null:
        return result

    for row in range(definition.rows):
        var line := definition.grid[row] if row < definition.grid.size() else ""
        for column in range(definition.columns):
            if column >= line.length():
                continue
            var symbol := line[column]
            if symbol == "." or symbol == " " or symbol == "X" or symbol == "=" or symbol == "+":
                continue
            if definition.random_carve_chance > 0.0 and rng.randf() < definition.random_carve_chance:
                continue

            var rect := Rect2(
                definition.brick_origin + Vector2(column, row) * definition.brick_step,
                definition.brick_size
            )
            if _intersects_wall(rect, definition.walls):
                continue

            var brick := BrickData.new()
            brick.rect = rect
            brick.color = _brick_color(definition, symbol, row, rng)
            result.append(brick)
    return result


static func _brick_color(
    definition: LevelDefinition,
    symbol: String,
    row: int,
    rng: RandomNumberGenerator
) -> Color:
    if definition.symbol_colors.has(symbol):
        return definition.symbol_colors[symbol]
    if symbol == "#":
        var hue := lerpf(
            definition.hue_start,
            definition.hue_end,
            float(row) / float(maxi(definition.brick_rows - 1, 1))
        )
        hue = fmod(hue + rng.randf_range(-definition.hue_jitter, definition.hue_jitter) + 1.0, 1.0)
        return Color.from_hsv(hue, 0.72, 0.93)
    return LevelDefinition.palette_color(symbol)


static func _intersects_wall(rect: Rect2, walls: Array[Rect2]) -> bool:
    for wall in walls:
        if wall.grow(3.0).intersects(rect):
            return true
    return false
