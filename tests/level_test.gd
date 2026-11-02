extends SceneTree

var failures := 0


func _initialize() -> void:
    test_manifest_and_parse()
    test_generation()
    if failures == 0:
        print("LEVEL TEST PASS")
    quit(1 if failures > 0 else 0)


func test_manifest_and_parse() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    check(config.level_manifest == "res://resources/levels/levels.txt", "Unexpected level manifest path")

    var levels := LevelLoader.load_manifest(config.level_manifest)
    check(levels.size() >= 1, "Level manifest should load at least one level")
    for definition in levels:
        check(definition.rows > 0, "Level has no rows: %s" % definition.layout_file)
        check(definition.columns > 0, "Level has no columns: %s" % definition.layout_file)
        check(definition.grid.size() == definition.rows, "Grid line count mismatch: %s" % definition.layout_file)
        for line in definition.grid:
            check(line.length() > 0, "Empty grid line in %s" % definition.layout_file)
            check(line.length() <= definition.columns, "Grid line wider than columns in %s" % definition.layout_file)

    var labyrinth := LevelLoader.load_definition("res://resources/levels/01_labyrinth.txt")
    check(labyrinth != null, "Labyrinth sample should load")
    if labyrinth != null:
        check(labyrinth.display_name == "Labyrinth", "Labyrinth name mismatch")
        check(labyrinth.walls.size() == 12, "Expected 12 freeform walls in Labyrinth")
        if not labyrinth.walls.is_empty():
            check(labyrinth.walls[0] == Rect2(166, 276, 12, 76), "Freeform wall parse mismatch")

    var corridors := LevelLoader.load_definition("res://resources/levels/02_corridors.txt")
    check(corridors != null, "Corridors sample should load")
    if corridors != null:
        check(corridors.walls.size() > 0, "Corridors should parse X cells as walls")
        check(corridors.symbol_colors.has("2"), "Corridors should parse color.2")
        if corridors.symbol_colors.has("2"):
            check(corridors.symbol_colors["2"] == Color("#ff6b6b"), "Corridors color.2 mismatch")


func test_generation() -> void:
    var config: GameConfig = load("res://resources/game_config.tres")
    var levels := LevelLoader.load_manifest(config.level_manifest)
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

    var labyrinth := LevelLoader.load_definition("res://resources/levels/01_labyrinth.txt")
    var labyrinth_colors := {}
    if labyrinth != null:
        for brick in LevelGenerator.generate(labyrinth, rng):
            labyrinth_colors[brick.color.to_html(false)] = true
    check(labyrinth_colors.size() >= 3, "Gradient bricks should produce multiple colors")

    var corridors := LevelLoader.load_definition("res://resources/levels/02_corridors.txt")
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


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
