class_name LevelLoader
extends RefCounted

const COMMENT_PREFIXES := ["//", ";", "#"]


static func load_manifest(manifest_path: String, config: GameConfig = null) -> Array[LevelDefinition]:
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
        if not FileAccess.file_exists(level_path) and level_path.get_extension().is_empty():
            var with_extension := level_path + ".txt"
            if FileAccess.file_exists(with_extension):
                level_path = with_extension
        var definition := load_definition(level_path, config)
        if definition != null:
            result.append(definition)
    if result.is_empty():
        push_error("Level manifest has no valid levels: %s" % manifest_path)
    return result


static func load_definition(path: String, config: GameConfig = null) -> LevelDefinition:
    if not FileAccess.file_exists(path):
        push_error("Level file not found: %s" % path)
        return null
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Level file is empty: %s" % path)
        return null

    var definition := LevelDefinition.new()
    definition.layout_file = path
    var layout_config: GameConfig = config if config != null else GameConfig.new()
    var grid_lines: PackedStringArray = []
    var symbol_colors := {}
    var walls: Array[Rect2] = []
    var thin_cells := {}
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
    definition.brick_rows = 0
    for row in range(definition.rows):
        var line := grid_lines[row]
        definition.columns = maxi(definition.columns, line.length())
        for column in range(line.length()):
            var symbol := line[column]
            if symbol == "." or symbol == " " or symbol == "X" or symbol == "=" or symbol == "+":
                continue
            definition.brick_rows = maxi(definition.brick_rows, row + 1)
    definition.grid = grid_lines
    definition.symbol_colors = symbol_colors
    if definition.auto_layout:
        if definition.fill_field:
            _apply_fill_layout(definition, layout_config)
        else:
            _apply_auto_layout(definition, layout_config)

    for row in range(definition.rows):
        for column in range(definition.columns):
            var symbol := _symbol_at(grid_lines[row], column)
            if symbol == "X" or symbol == "=":
                walls.append(Rect2(
                    definition.brick_origin + Vector2(column, row) * definition.brick_step,
                    definition.brick_size
                ))
            elif symbol == "+":
                thin_cells[Vector2i(column, row)] = true
    _append_thin_walls(definition, thin_cells, walls)
    definition.walls = walls

    var playable_bricks := 0
    for row in range(definition.rows):
        for column in range(definition.columns):
            var symbol := _symbol_at(grid_lines[row], column)
            if symbol == "." or symbol == " " or symbol == "X" or symbol == "=" or symbol == "+":
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
        "auto_layout":
            definition.auto_layout = _parse_bool(value)
        "fill_field":
            definition.fill_field = _parse_bool(value)
        "hue_start":
            definition.hue_start = value.to_float()
        "hue_end":
            definition.hue_end = value.to_float()
        "hue_jitter":
            definition.hue_jitter = value.to_float()
        "wall_thickness":
            definition.wall_thickness = maxf(2.0, value.to_float())
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


static func _parse_bool(value: String) -> bool:
    var normalized := value.strip_edges().to_lower()
    return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"


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


static func _apply_auto_layout(definition: LevelDefinition, config: GameConfig) -> void:
    if definition.columns <= 0 or definition.brick_rows <= 0:
        return
    var natural_width := float(definition.columns - 1) * definition.brick_step.x + definition.brick_size.x
    var natural_height := float(definition.brick_rows - 1) * definition.brick_step.y + definition.brick_size.y
    var natural_total_height := float(definition.rows - 1) * definition.brick_step.y + definition.brick_size.y
    var available_width := maxf(1.0, config.inner_right - config.inner_left - config.brick_area_margin * 2.0)
    var available_height := maxf(1.0, config.brick_area_max_height)
    var available_total_height := maxf(1.0, config.field_bottom - definition.brick_origin.y - 120.0)

    var scale := 1.0
    if natural_width > available_width:
        scale = minf(scale, available_width / natural_width)
    if natural_height > available_height:
        scale = minf(scale, available_height / natural_height)
    if natural_total_height > available_total_height:
        scale = minf(scale, available_total_height / natural_total_height)
    scale = clampf(scale, 0.2, 1.0)

    definition.brick_size *= scale
    definition.brick_step *= scale
    definition.wall_thickness = maxf(2.0, definition.wall_thickness * scale)

    var grid_width := float(definition.columns - 1) * definition.brick_step.x + definition.brick_size.x
    definition.brick_origin.x = config.inner_left + (config.inner_right - config.inner_left - grid_width) * 0.5


static func _apply_fill_layout(definition: LevelDefinition, config: GameConfig) -> void:
    if definition.columns <= 0 or definition.rows <= 0:
        return
    var old_size := definition.brick_size
    var old_step := definition.brick_step
    var size_ratio_x := old_size.x / maxf(old_step.x, 0.001)
    var size_ratio_y := old_size.y / maxf(old_step.y, 0.001)
    var area_left := config.inner_left
    var area_right := config.inner_right
    var area_top := definition.brick_origin.y
    var area_bottom := maxf(area_top + 1.0, config.brick_area_bottom)
    var available_width := maxf(1.0, area_right - area_left)
    var available_height := maxf(1.0, area_bottom - area_top)

    definition.brick_step = Vector2(
        available_width / float(definition.columns),
        available_height / float(definition.rows)
    )
    definition.brick_size = Vector2(
        definition.brick_step.x * size_ratio_x,
        definition.brick_step.y * size_ratio_y
    )
    definition.brick_origin = Vector2(
        area_left + (definition.brick_step.x - definition.brick_size.x) * 0.5,
        area_top + (definition.brick_step.y - definition.brick_size.y) * 0.5
    )
    var scale := minf(
        definition.brick_size.x / maxf(old_size.x, 0.001),
        definition.brick_size.y / maxf(old_size.y, 0.001)
    )
    definition.wall_thickness = maxf(2.0, definition.wall_thickness * scale)


static func _append_thin_walls(
    definition: LevelDefinition,
    thin_cells: Dictionary,
    walls: Array[Rect2]
) -> void:
    if thin_cells.is_empty():
        return
    var thickness := clampf(
        definition.wall_thickness,
        2.0,
        minf(definition.brick_size.x, definition.brick_size.y) * 0.8
    )
    var half_x := definition.brick_size.x * 0.5
    var half_y := definition.brick_size.y * 0.5
    var gap_x := maxf(0.0, definition.brick_step.x - definition.brick_size.x)
    var gap_y := maxf(0.0, definition.brick_step.y - definition.brick_size.y)
    var horizontal_walls: Array[Rect2] = []
    var vertical_walls: Array[Rect2] = []
    var square_walls: Array[Rect2] = []

    for cell: Vector2i in thin_cells.keys():
        var cell_rect := Rect2(
            definition.brick_origin + Vector2(cell.x, cell.y) * definition.brick_step,
            definition.brick_size
        )
        var center := cell_rect.get_center()
        var left := thin_cells.has(cell + Vector2i(-1, 0))
        var right := thin_cells.has(cell + Vector2i(1, 0))
        var up := thin_cells.has(cell + Vector2i(0, -1))
        var down := thin_cells.has(cell + Vector2i(0, 1))
        var horizontal := left or right
        var vertical := up or down

        if not horizontal and not vertical:
            square_walls.append(Rect2(
                center - Vector2(thickness, thickness) * 0.5,
                Vector2(thickness, thickness)
            ))
            continue

        if horizontal:
            var start_x := center.x - half_x if left or not vertical else center.x
            var end_x := center.x + half_x if right or not vertical else center.x
            if left:
                start_x -= gap_x * 0.5
            if right:
                end_x += gap_x * 0.5
            if end_x > start_x:
                horizontal_walls.append(Rect2(
                    Vector2(start_x, center.y - thickness * 0.5),
                    Vector2(end_x - start_x, thickness)
                ))

        if vertical:
            var start_y := center.y - half_y if up or not horizontal else center.y
            var end_y := center.y + half_y if down or not horizontal else center.y
            if up:
                start_y -= gap_y * 0.5
            if down:
                end_y += gap_y * 0.5
            if end_y > start_y:
                vertical_walls.append(Rect2(
                    Vector2(center.x - thickness * 0.5, start_y),
                    Vector2(thickness, end_y - start_y)
                ))

    walls.append_array(_merge_horizontal_walls(horizontal_walls))
    walls.append_array(_merge_vertical_walls(vertical_walls))
    walls.append_array(square_walls)


static func _merge_horizontal_walls(rects: Array[Rect2]) -> Array[Rect2]:
    if rects.is_empty():
        return rects
    var sorted: Array[Rect2] = rects.duplicate()
    sorted.sort_custom(_compare_horizontal)
    var result: Array[Rect2] = []
    for rect in sorted:
        if result.is_empty():
            result.append(rect)
            continue
        var last: Rect2 = result[result.size() - 1]
        if (
            absf(last.position.y - rect.position.y) < 0.1
            and absf(last.size.y - rect.size.y) < 0.1
            and rect.position.x <= last.end.x + 0.1
        ):
            last.size.x = maxf(last.end.x, rect.end.x) - last.position.x
            result[result.size() - 1] = last
        else:
            result.append(rect)
    return result


static func _merge_vertical_walls(rects: Array[Rect2]) -> Array[Rect2]:
    if rects.is_empty():
        return rects
    var sorted: Array[Rect2] = rects.duplicate()
    sorted.sort_custom(_compare_vertical)
    var result: Array[Rect2] = []
    for rect in sorted:
        if result.is_empty():
            result.append(rect)
            continue
        var last: Rect2 = result[result.size() - 1]
        if (
            absf(last.position.x - rect.position.x) < 0.1
            and absf(last.size.x - rect.size.x) < 0.1
            and rect.position.y <= last.end.y + 0.1
        ):
            last.size.y = maxf(last.end.y, rect.end.y) - last.position.y
            result[result.size() - 1] = last
        else:
            result.append(rect)
    return result


static func _compare_horizontal(a: Rect2, b: Rect2) -> bool:
    if absf(a.position.y - b.position.y) > 0.1:
        return a.position.y < b.position.y
    return a.position.x < b.position.x


static func _compare_vertical(a: Rect2, b: Rect2) -> bool:
    if absf(a.position.x - b.position.x) > 0.1:
        return a.position.x < b.position.x
    return a.position.y < b.position.y
