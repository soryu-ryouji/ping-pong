extends SceneTree

var failures := 0


func _initialize() -> void:
    test_manifest_and_parse()
    test_generation()
    test_auto_layout()
    test_brick_hp()
    if failures == 0:
        print("LEVEL TEST PASS")
    quit(1 if failures > 0 else 0)


func test_manifest_and_parse() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    check(config.level_manifest == "res://resources/levels/levels.txt", "Unexpected level manifest path")

    var levels := LevelLoader.load_manifest(config.level_manifest, config)
    check(levels.size() >= 1, "Level manifest should load at least one level")
    for definition in levels:
        check(definition.rows > 0, "Level has no rows: %s" % definition.layout_file)
        check(definition.columns > 0, "Level has no columns: %s" % definition.layout_file)
        check(definition.grid.size() == definition.rows, "Grid line count mismatch: %s" % definition.layout_file)
        for line in definition.grid:
            check(line.length() > 0, "Empty grid line in %s" % definition.layout_file)
            check(line.length() <= definition.columns, "Grid line wider than columns in %s" % definition.layout_file)

    var labyrinth := LevelLoader.load_definition("res://resources/levels/01_labyrinth.txt", config)
    check(labyrinth != null, "Labyrinth sample should load")
    if labyrinth != null:
        check(labyrinth.display_name == "Labyrinth", "Labyrinth name mismatch")
        check(labyrinth.walls.size() > 0, "Labyrinth should have walls")
        check(labyrinth.wall_thickness == 12.0, "Labyrinth wall thickness mismatch")
        var thin_found := false
        for wall in labyrinth.walls:
            if is_equal_approx(minf(wall.size.x, wall.size.y), labyrinth.wall_thickness):
                thin_found = true
                break
        check(thin_found, "Labyrinth should generate thin + walls")

    var corridors := LevelLoader.load_definition("res://resources/levels/02_corridors.txt", config)
    check(corridors != null, "Corridors sample should load")
    if corridors != null:
        check(corridors.walls.size() > 0, "Corridors should parse + cells as walls")
        check(corridors.symbol_colors.has("2"), "Corridors should parse color.2")
        if corridors.symbol_colors.has("2"):
            check(corridors.symbol_colors["2"] == Color("#ff6b6b"), "Corridors color.2 mismatch")
        var horizontal_run := false
        var vertical_run := false
        for wall in corridors.walls:
            if is_equal_approx(wall.size.x, 151.0) and is_equal_approx(wall.size.y, 12.0):
                horizontal_run = true
            if is_equal_approx(wall.size.x, 12.0) and is_equal_approx(wall.size.y, 81.0):
                vertical_run = true
        check(horizontal_run, "Corridors horizontal + run should merge into one wall")
        check(vertical_run, "Corridors vertical + run should merge into one wall")


func test_generation() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var levels := LevelLoader.load_manifest(config.level_manifest, config)
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    for definition in levels:
        var bricks := LevelGenerator.generate(definition, rng)
        check(bricks.size() > 0, "Level generated no bricks: %s" % definition.layout_file)
        var overlap := false
        for brick in bricks:
            for wall in definition.walls:
                if wall.grow(3.0).intersects(brick.rect):
                    overlap = true
                    break
        check(not overlap, "Brick overlaps a wall in %s" % definition.layout_file)

    var labyrinth := LevelLoader.load_definition("res://resources/levels/01_labyrinth.txt", config)
    var labyrinth_colors := {}
    if labyrinth != null:
        for brick in LevelGenerator.generate(labyrinth, rng):
            labyrinth_colors[brick.color.to_html(false)] = true
    check(labyrinth_colors.size() >= 3, "Gradient bricks should produce multiple colors")

    var corridors := LevelLoader.load_definition("res://resources/levels/02_corridors.txt", config)
    var override_color := Color("#ff6b6b")
    var override_found := false
    if corridors != null:
        for brick in LevelGenerator.generate(corridors, rng):
            if brick.color == override_color:
                override_found = true
    check(override_found, "Explicit color.2 override was not applied")
    check(
        LevelDefinition.palette_color("2") == LevelDefinition.SYMBOL_PALETTE[1],
        "Digit palette mapping mismatch"
    )


func test_auto_layout() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var line := LevelLoader.load_definition("res://resources/levels/04_line.txt", config)
    check(line != null, "Line sample should load with auto layout")
    if line != null:
        check(line.columns == 24, "Line should keep its 24-column grid")
        check(line.fill_field, "Line should use fill layout")
        check(line.brick_size.x < 34.0, "Wide Level should scale bricks down")
        check(line.brick_origin.x >= config.inner_left - 0.01, "Auto layout should stay inside the field")
        var grid_right := line.brick_origin.x + float(line.columns - 1) * line.brick_step.x + line.brick_size.x
        check(grid_right <= config.inner_right + 0.01, "Auto layout should fit the right edge")
        check(absf(line.brick_origin.x - config.inner_left) < 5.0, "Fill layout should use the left edge")
        check(absf(grid_right - config.inner_right) < 5.0, "Fill layout should use the right edge")
        var grid_bottom := line.brick_origin.y + float(line.rows - 1) * line.brick_step.y + line.brick_size.y
        check(absf(grid_bottom - config.brick_area_bottom) < 5.0, "Fill layout should use the bottom edge")
        var overflow := false
        for wall in line.walls:
            if (
                wall.position.x < config.field_left - 0.01
                or wall.end.x > config.field_right + 0.01
                or wall.position.y < config.inner_top - 0.01
                or wall.end.y > config.field_bottom + 0.01
            ):
                overflow = true
                break
        check(not overflow, "Line walls should stay inside the play field")

    var labyrinth := LevelLoader.load_definition("res://resources/levels/01_labyrinth.txt", config)
    check(labyrinth != null, "Labyrinth sample should load")
    if labyrinth != null:
        check(is_equal_approx(labyrinth.brick_size.x, 34.0), "Standard-width Level should not scale")
        check(is_equal_approx(labyrinth.brick_size.y, 23.0), "Standard-height Level should not scale")


func test_brick_hp() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var armor := LevelLoader.load_definition("res://tests/fixtures/armor_level.txt", config)
    check(armor != null, "Armor fixture should load")
    if armor == null:
        return
    check(armor.brick_hp.get("8") == 3, "Armor fixture hp.8 mismatch")
    check(armor.brick_hp.get("5") == 2, "Armor fixture hp.5 mismatch")

    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var found_three := false
    var found_two := false
    for brick in LevelGenerator.generate(armor, rng):
        if brick.max_hp == 3:
            found_three = true
            check(brick.hp == 3, "Three-HP brick should start at full HP")
        elif brick.max_hp == 2:
            found_two = true
            check(brick.hp == 2, "Two-HP brick should start at full HP")
    check(found_three, "Armor fixture should generate a three-HP brick")
    check(found_two, "Armor fixture should generate a two-HP brick")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
