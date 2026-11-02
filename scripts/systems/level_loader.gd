class_name LevelLoader
extends RefCounted

const COMMENT_PREFIXES := ["//", ";", "#"]


static func load_manifest(manifest_path: String) -> Array[LevelDefinition]:
    var result: Array[LevelDefinition] = []
    if manifest_path.is_empty():
        push_error("Level manifest path is empty")
        return result
    if not FileAccess.file_exists(manifest_path):
        push_error("Level manifest not found: %s" % manifest_path)
        return result

    var text := FileAccess.get_file_as_string(manifest_path)
    var base_dir := manifest_path.get_base_dir()
    for raw_line in text.split("\n"):
        var line := raw_line.strip_edges()
        if line.is_empty() or _is_comment(line):
            continue
        var level_path := line
        if not level_path.begins_with("res://") and not level_path.begins_with("user://"):
            level_path = base_dir.path_join(level_path)
        var definition := load_definition(level_path)
        if definition != null:
            result.append(definition)
    if result.is_empty():
        push_error("Level manifest has no valid levels: %s" % manifest_path)
    return result


static func load_definition(path: String) -> LevelDefinition:
    if not FileAccess.file_exists(path):
        push_error("Level file not found: %s" % path)
        return null
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Level file is empty: %s" % path)
        return null

    var definition := LevelDefinition.new()
    definition.layout_file = path
    var grid_lines: PackedStringArray = []
    var symbol_colors := {}
    var walls: Array[Rect2] = []
    var brick_symbols := 0
    var in_grid := false

    for raw_line in text.split("\n"):
        var stripped := raw_line.strip_edges()
        if not in_grid:
            if stripped.is_empty() or _is_comment(stripped):
                continue
            if stripped.to_lower() == "grid:":
                in_grid = true
                continue
            _parse_setting(definition, stripped, symbol_colors, walls)
            continue

        var grid_line := raw_line.strip_edges(false, true)
        if grid_line.strip_edges().is_empty() or _is_grid_comment(grid_line.strip_edges()):
            continue
        grid_lines.append(grid_line)

    if grid_lines.is_empty():
        push_error("Level has no grid: %s" % path)
        return null

    definition.rows = grid_lines.size()
    definition.columns = 0
    for line in grid_lines:
        definition.columns = maxi(definition.columns, line.length())
    definition.grid = grid_lines
    definition.symbol_colors = symbol_colors

    for row in range(definition.rows):
        for column in range(definition.columns):
            var symbol := _symbol_at(grid_lines[row], column)
            if symbol == "X" or symbol == "=":
                walls.append(Rect2(
                    definition.brick_origin + Vector2(column, row) * definition.brick_step,
                    definition.brick_size
                ))
    definition.walls = walls

    var playable_bricks := 0
    for row in range(definition.rows):
        for column in range(definition.columns):
            var symbol := _symbol_at(grid_lines[row], column)
            if symbol == "." or symbol == " " or symbol == "X" or symbol == "=":
                continue
            brick_symbols += 1
            var rect := Rect2(
                definition.brick_origin + Vector2(column, row) * definition.brick_step,
                definition.brick_size
            )
            if not _intersects_wall(rect, walls):
                playable_bricks += 1
    if brick_symbols == 0:
        push_error("Level has no brick symbols: %s" % path)
        return null
    if playable_bricks == 0:
        push_error("All bricks overlap walls: %s" % path)
        return null
    return definition


static func _parse_setting(
    definition: LevelDefinition,
    line: String,
    symbol_colors: Dictionary,
    walls: Array[Rect2]
) -> void:
    var separator := line.find("=")
    if separator < 0:
        separator = line.find(":")
    if separator < 0:
        push_warning("Ignored level setting without '=': %s" % line)
        return

    var key := line.substr(0, separator).strip_edges()
    var value := line.substr(separator + 1).strip_edges()
    var lower_key := key.to_lower()

    match lower_key:
        "name":
            definition.display_name = value
        "origin":
            definition.brick_origin = _parse_vector2(value, definition.brick_origin)
        "brick_size":
            definition.brick_size = _parse_vector2(value, definition.brick_size)
        "step":
            definition.brick_step = _parse_vector2(value, definition.brick_step)
        "hue_start":
            definition.hue_start = value.to_float()
        "hue_end":
            definition.hue_end = value.to_float()
        "hue_jitter":
            definition.hue_jitter = value.to_float()
        "random_carve_chance":
            definition.random_carve_chance = clampf(value.to_float(), 0.0, 1.0)
        "wall":
            var parts := _parse_floats(value)
            if parts.size() < 4:
                push_warning("Ignored wall setting, expected x,y,w,h: %s" % line)
            else:
                walls.append(Rect2(parts[0], parts[1], parts[2], parts[3]))
        _:
            if lower_key.begins_with("color.") and key.length() > 6:
                var symbol := key.substr(6)
                var color := Color.from_string(value, Color.TRANSPARENT)
                if color.a <= 0.0:
                    push_warning("Ignored color setting with invalid color: %s" % line)
                else:
                    symbol_colors[symbol] = color
            else:
                push_warning("Ignored unknown level setting: %s" % key)


static func _parse_vector2(value: String, fallback: Vector2) -> Vector2:
    var parts := _parse_floats(value)
    if parts.size() < 2:
        push_warning("Expected two numbers, got: %s" % value)
        return fallback
    return Vector2(parts[0], parts[1])


static func _parse_floats(value: String) -> PackedFloat32Array:
    var parts := value.replace(",", " ").replace("\t", " ").split(" ", false)
    var result := PackedFloat32Array()
    for part in parts:
        result.append(part.to_float())
    return result


static func _symbol_at(line: String, column: int) -> String:
    if column < 0 or column >= line.length():
        return "."
    return line[column]


static func _is_comment(line: String) -> bool:
    for prefix in COMMENT_PREFIXES:
        if line.begins_with(prefix):
            return true
    return false


static func _is_grid_comment(line: String) -> bool:
    return line.begins_with("//") or line.begins_with(";")


static func _intersects_wall(rect: Rect2, walls: Array[Rect2]) -> bool:
    for wall in walls:
        if wall.grow(3.0).intersects(rect):
            return true
    return false
