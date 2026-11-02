class_name GameHUD
extends CanvasLayer

const CYAN := Color("#78f4ff")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")
const GREEN := Color("#c9ff72")
const COMBO_LABEL_POSITION := Vector2(500, 16)

var world: GameWorld
var effects: GameEffects
var wave_label: Label
var title_label: Label
var combo_header: Label
var combo_label: Label
var clear_label: Label
var balls_label: Label
var lost_label: Label
var fire_label: Label
var status_label: Label
var status_hint: Label
var footer_hint: Label
var debug_label: Label
var xp_label: Label


func setup(game_world: GameWorld, game_effects: GameEffects) -> void:
    world = game_world
    effects = game_effects
    wave_label = make_label("LEVEL 01/01  ·  LOOP 01", Vector2(23, 8), Vector2(300, 25), 17, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
    title_label = make_label("LABYRINTH / RICOCHET", Vector2(42, 45), Vector2(430, 28), 19, Color("#b2c5d8"), HORIZONTAL_ALIGNMENT_LEFT)
    combo_header = make_label("COMBO  ·  XP +1.0", Vector2(300, 1), Vector2(180, 18), 12, Color("#b9974c"), HORIZONTAL_ALIGNMENT_RIGHT)
    combo_label = make_label("×0", COMBO_LABEL_POSITION, Vector2(190, 84), 42, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
    combo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    clear_label = make_label("0% CLEAR", Vector2(42, 78), Vector2(220, 24), 17, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
    balls_label = make_label("01 BALLS", Vector2(23, 860), Vector2(210, 32), 23, Color("#f0f7ff"), HORIZONTAL_ALIGNMENT_LEFT)
    lost_label = make_label("LOST 0", Vector2(270, 866), Vector2(180, 22), 14, Color("#d083ab"), HORIZONTAL_ALIGNMENT_CENTER)
    fire_label = make_label("FIRE CHARGE 0%", Vector2(460, 860), Vector2(230, 26), 17, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
    footer_hint = make_label("MOUSE / TOUCH / A D  ·  SPACE TO LAUNCH  ·  R TO RESTART", Vector2(23, 892), Vector2(674, 20), 11, Color("#506a80"), HORIZONTAL_ALIGNMENT_CENTER)
    debug_label = make_label("DEBUG  [ ] PREV/NEXT  ·  1-9 JUMP  ·  SHIFT+R RESTART LEVEL", Vector2(23, 824), Vector2(674, 18), 11, ORANGE, HORIZONTAL_ALIGNMENT_LEFT)
    xp_label = make_label("XP LV 1  0/150", Vector2(460, 824), Vector2(230, 18), 11, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
    status_label = make_label("", Vector2(100, 364), Vector2(520, 64), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    status_hint = make_label("", Vector2(100, 425), Vector2(520, 30), 14, Color("#9ab0c2"), HORIZONTAL_ALIGNMENT_CENTER)
    for label in [wave_label, title_label, combo_header, combo_label, clear_label, balls_label, lost_label, fire_label, status_label, status_hint, footer_hint, debug_label, xp_label]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    update_view()


func make_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
    var label := Label.new()
    label.text = text
    label.position = position
    label.size = size
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("#02060d"))
    label.add_theme_constant_override("outline_size", 4)
    add_child(label)
    return label


func update_view() -> void:
    if world == null:
        return
    var level := world.current_level()
    var level_count := maxi(world.levels.size(), 1)
    wave_label.text = "LEVEL %02d/%02d  ·  LOOP %02d" % [world.level_index + 1, level_count, world.loop_count]
    if level != null and not level.display_name.is_empty():
        title_label.text = "%s  ·  WAVE %02d" % [level.display_name.to_upper(), world.wave]
    else:
        title_label.text = "LABYRINTH / RICOCHET"
    combo_label.text = "×%d" % world.combo
    combo_label.add_theme_font_size_override("font_size", combo_font_size(world.combo))
    var combo_pop := effects.combo_pop
    combo_label.position = COMBO_LABEL_POSITION + Vector2(
        sin(world.game_time * 95.0) * 2.5 * combo_pop,
        cos(world.game_time * 71.0) * 1.8 * combo_pop
    )
    combo_label.pivot_offset = Vector2(combo_label.size.x - 10.0, combo_label.size.y)
    combo_label.scale = Vector2.ONE * (1.0 + combo_pop * 0.12)
    combo_header.text = "COMBO  ·  XP +%.1f" % world.xp_gain_for_combo(world.combo)
    xp_label.text = "XP LV %d  %d/%d" % [
        world.xp_level,
        int(round(world.xp)),
        int(round(world.xp_required))
    ]
    xp_label.add_theme_color_override("font_color", GOLD if world.xp_flash > 0.01 else CYAN)
    debug_label.visible = world.config.debug_tools
    clear_label.text = "%d%% CLEAR" % int(round(world.clear_fraction * 100.0))
    balls_label.text = "%02d BALLS" % maxi(1, world.balls.size()) if world.state == GameWorld.State.READY else "%02d BALLS" % world.balls.size()
    lost_label.text = "LIVES %d  ·  LOST %d" % [world.lives, world.lost_count]

    if world.is_fire_active():
        fire_label.text = "FIRE RUSH %.1fs" % world.fire_time
        fire_label.add_theme_color_override("font_color", ORANGE)
        combo_label.add_theme_color_override("font_color", ORANGE)
    else:
        fire_label.text = "FIRE CHARGE %d%%" % int(round(world.fire_energy))
        fire_label.add_theme_color_override("font_color", GOLD)
        combo_label.add_theme_color_override("font_color", GOLD)

    match world.state:
        GameWorld.State.READY:
            show_status("CLICK / SPACE TO LAUNCH", "MOVE  ·  MOUSE / A D / ARROW KEYS", CYAN)
        GameWorld.State.GAME_OVER:
            show_status("GAME OVER", "CLICK / SPACE TO RESTART", PINK)
        GameWorld.State.CLEARED:
            var next_hint := "CLICK / SPACE TO CONTINUE"
            if world.is_last_level():
                next_hint = "CLICK / SPACE TO LOOP"
            show_status("LEVEL CLEAR", next_hint, GREEN)
        GameWorld.State.PLAYING:
            status_label.visible = false
            status_hint.visible = false


func combo_font_size(combo_value: int) -> int:
    if combo_value >= 500:
        return 68
    if combo_value >= 200:
        return 64
    if combo_value >= 100:
        return 60
    if combo_value >= 50:
        return 55
    if combo_value >= 30:
        return 50
    if combo_value >= 10:
        return 46
    return 42


func show_status(title: String, hint: String, color: Color) -> void:
    status_label.text = title
    status_label.add_theme_color_override("font_color", color)
    status_hint.text = hint
    status_label.visible = true
    status_hint.visible = true
