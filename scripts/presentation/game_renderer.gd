class_name GameRenderer
extends Node2D

const CYAN := Color("#78f4ff")
const GOLD := Color("#ffd56a")
const ORANGE := Color("#ff9b45")
const PINK := Color("#ff8dd8")

var world: GameWorld
var effects: GameEffects
var config: GameConfig
var font: Font
var dust: Array[Vector3] = []
var visual_rng := RandomNumberGenerator.new()


func setup(game_world: GameWorld, game_effects: GameEffects) -> void:
    world = game_world
    effects = game_effects
    config = world.config
    font = ThemeDB.fallback_font
    visual_rng.seed = 0xD057
    create_dust()
    queue_redraw()


func _process(_delta: float) -> void:
    queue_redraw()


func create_dust() -> void:
    dust.clear()
    for index in range(95):
        dust.append(Vector3(
            visual_rng.randf_range(config.field_left + 8.0, config.field_right - 8.0),
            visual_rng.randf_range(config.field_top + 10.0, config.field_bottom - 6.0),
            visual_rng.randf_range(0.06, 0.34)
        ))


func _draw() -> void:
    if world == null:
        return
    draw_background()
    draw_set_transform(effects.shake_offset, 0.0, Vector2.ONE)
    draw_outer_frame()
    draw_grid()
    draw_bricks()
    draw_walls()
    draw_powerups()
    draw_trails()
    draw_particles()
    draw_paddle()
    draw_balls()
    draw_floaters()
    draw_bottom_meter()

    if world.is_fire_active():
        var pulse := 0.018 + (sin(world.game_time * 8.0) * 0.5 + 0.5) * 0.018
        draw_rect(field_rect(), Color(1.0, 0.24, 0.08, pulse), true)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if world.state != GameWorld.State.PLAYING:
        draw_rect(field_rect(), Color(0.0, 0.01, 0.03, 0.22), true)
    if effects.flash_alpha > 0.001:
        draw_rect(Rect2(Vector2.ZERO, config.screen_size), Color(0.55, 0.86, 1.0, effects.flash_alpha), true)


func field_rect() -> Rect2:
    return Rect2(
        config.field_left,
        config.field_top,
        config.field_right - config.field_left,
        config.field_bottom - config.field_top
    )


func draw_background() -> void:
    var bands := 28
    for index in range(bands):
        var ratio := float(index) / float(bands - 1)
        var color := Color("#071426").lerp(Color("#01030a"), ratio)
        draw_rect(Rect2(0.0, config.screen_size.y * ratio, config.screen_size.x, config.screen_size.y / float(bands) + 1.0), color, true)
    for point in dust:
        draw_circle(Vector2(point.x, point.y), 0.8 + point.z * 1.2, Color(0.48, 0.78, 0.95, point.z * 0.42))
    draw_rect(Rect2(0, 0, config.screen_size.x, 6), Color("#101c2c"), true)
    draw_rect(Rect2(0, config.screen_size.y - 8, config.screen_size.x, 8), Color("#120811"), true)


func draw_outer_frame() -> void:
    var field := field_rect()
    draw_rect(Rect2(config.field_left - 10, config.field_top - 12, 672, 760).grow(7), Color(0.26, 0.75, 0.9, 0.025), true)
    draw_rect(field.grow_individual(8, 8, 8, 12), Color("#02060c"), true)
    draw_rect(field, Color("#040b14"), true)
    draw_rect(field.grow(-4), Color(0.015, 0.035, 0.065, 0.46), true)

    draw_rect(Rect2(28, config.field_top - 10, 664, 11), Color("#536878"), true)
    draw_rect(Rect2(28, config.field_top - 10, 664, 3), Color("#d5e5ee"), true)
    draw_rect(Rect2(28, config.field_top - 1, 664, 3), Color("#1a2732"), true)
    draw_rect(Rect2(28, config.field_top - 12, 664, 2), Color(0.52, 0.92, 1.0, 0.17), true)

    for side in [-1, 1]:
        var x := config.field_left - 8.0 if side < 0 else config.field_right + 1.0
        draw_rect(Rect2(x - 2, config.field_top - 4, 12, field.size.y + 8), Color("#121e28"), true)
        draw_rect(Rect2(x, config.field_top - 4, 8, field.size.y + 8), Color("#718695"), true)
        draw_rect(Rect2(x + 2, config.field_top - 4, 2, field.size.y + 8), Color("#d1e1e9"), true)
        draw_rect(Rect2(x + 6, config.field_top - 4, 2, field.size.y + 8), Color("#2b3945"), true)

    draw_rect(Rect2(config.field_left, config.field_bottom, field.size.x, 3), Color(1.0, 0.18, 0.38, 0.82), true)
    draw_rect(Rect2(config.field_left, config.field_bottom + 4, field.size.x, 1), Color(1.0, 0.35, 0.55, 0.22), true)
    draw_rect(field.grow(-7), Color(0.35, 0.85, 1.0, 0.08), false, 1.0)


func draw_grid() -> void:
    for x in range(74, 680, 42):
        draw_line(Vector2(x, config.field_top + 14), Vector2(x, config.field_bottom - 2), Color(0.22, 0.55, 0.7, 0.028), 1.0)
    for y in range(142, 840, 42):
        draw_line(Vector2(config.field_left + 8, y), Vector2(config.field_right - 8, y), Color(0.22, 0.55, 0.7, 0.024), 1.0)


func draw_bricks() -> void:
    for brick in world.bricks:
        if not brick.alive and brick.flash <= 0.0:
            continue
        var rect := brick.rect
        if brick.shake > 0.0:
            var strength := 2.2 * brick.shake
            rect.position += Vector2(
                sin(world.game_time * 95.0 + brick.rect.position.x * 0.13) * strength,
                cos(world.game_time * 78.0 + brick.rect.position.y * 0.17) * strength * 0.7
            )
        var color := brick.color
        var flash := brick.flash
        var damage := 0.0
        if brick.max_hp > 1:
            damage = 1.0 - float(brick.hp) / float(brick.max_hp)
        var lit := color.lerp(Color.WHITE, flash * 0.7).darkened(damage * 0.18)
        draw_rect(rect.grow(5.0), Color(color.r, color.g, color.b, 0.035 + flash * 0.07), true)
        draw_rect(rect.grow(6.0), Color(color.r, color.g, color.b, 0.012 + flash * 0.05), true)
        draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.82), true)
        draw_rect(rect, lit.darkened(0.30), true)
        draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 4.0)), lit, true)
        draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(rect.size.x - 2.0, 2.0)), lit.lightened(0.38), true)
        draw_rect(Rect2(rect.position + Vector2(1.0, rect.size.y - 4.0), Vector2(rect.size.x - 2.0, 2.0)), lit.darkened(0.52), true)
        if brick.max_hp > 1:
            draw_brick_damage(rect, brick, damage)
        if flash > 0.02:
            draw_rect(rect, Color(1.0, 1.0, 1.0, flash * 0.55), true)


func draw_brick_damage(rect: Rect2, brick: BrickData, damage: float) -> void:
    var inner := rect.grow(-2.5)
    if inner.size.x > 0.0 and inner.size.y > 0.0:
        draw_rect(inner, Color(1.0, 1.0, 1.0, 0.14 - damage * 0.06), false, 1.0)
    for corner: Vector2 in [Vector2(0.16, 0.18), Vector2(0.84, 0.18), Vector2(0.16, 0.82), Vector2(0.84, 0.82)]:
        draw_circle(rect.position + rect.size * corner, 1.0, Color(1.0, 1.0, 1.0, 0.46 - damage * 0.18))

    var stages := brick.max_hp - brick.hp
    if stages <= 0:
        return
    var cracks: Array = [
        PackedVector2Array([Vector2(0.22, 0.08), Vector2(0.46, 0.50), Vector2(0.38, 0.94)]),
        PackedVector2Array([Vector2(0.78, 0.10), Vector2(0.58, 0.44), Vector2(0.72, 0.90)]),
        PackedVector2Array([Vector2(0.08, 0.62), Vector2(0.48, 0.56), Vector2(0.92, 0.46)]),
        PackedVector2Array([Vector2(0.50, 0.04), Vector2(0.44, 0.38), Vector2(0.56, 0.72)]),
    ]
    var count := mini(stages, cracks.size())
    var crack_color := Color(0.02, 0.02, 0.05, 0.70)
    for index in range(count):
        var points: PackedVector2Array = cracks[index]
        var p0 := rect.position + rect.size * points[0]
        var p1 := rect.position + rect.size * points[1]
        var p2 := rect.position + rect.size * points[2]
        draw_line(p0, p1, crack_color, 1.2, true)
        draw_line(p1, p2, crack_color, 1.2, true)

    if brick.hp == 1:
        draw_rect(rect.grow(0.5), Color(1.0, 0.92, 0.58, 0.72), false, 1.2)


func draw_walls() -> void:
    for wall in world.walls:
        draw_rect(wall.grow(8.0), Color(0.55, 0.82, 1.0, 0.035), true)
        draw_rect(wall.grow(2.0), Color(0.0, 0.0, 0.0, 0.65), true)
        draw_rect(wall, Color("#5e7181"), true)
        draw_rect(Rect2(wall.position + Vector2(1.0, 1.0), wall.size - Vector2(2.0, 2.0)), Color("#8599a9"), true)
        if wall.size.x >= wall.size.y:
            draw_line(wall.position + Vector2(2.0, 1.0), Vector2(wall.end.x - 2.0, wall.position.y + 1.0), Color("#d8e8f2"), 1.4, true)
            draw_line(wall.position + Vector2(2.0, wall.size.y - 2.0), Vector2(wall.end.x - 2.0, wall.end.y - 2.0), Color("#293845"), 1.4, true)
            draw_circle(wall.position + Vector2(wall.size.y * 0.5, wall.size.y * 0.5), wall.size.y * 0.48, Color("#718695"))
            draw_circle(Vector2(wall.end.x - wall.size.y * 0.5, wall.position.y + wall.size.y * 0.5), wall.size.y * 0.48, Color("#718695"))
        else:
            draw_line(wall.position + Vector2(1.0, 2.0), Vector2(wall.position.x + 1.0, wall.end.y - 2.0), Color("#d8e8f2"), 1.4, true)
            draw_line(wall.position + Vector2(wall.size.x - 2.0, 2.0), Vector2(wall.position.x + 1.0, wall.end.y - 2.0), Color("#293845"), 1.4, true)
            draw_circle(wall.position + Vector2(wall.size.x * 0.5, wall.size.x * 0.5), wall.size.x * 0.48, Color("#718695"))
            draw_circle(Vector2(wall.position.x + wall.size.x * 0.5, wall.end.y - wall.size.x * 0.5), wall.size.x * 0.48, Color("#718695"))


func draw_powerups() -> void:
    for item in world.powerups:
        var color := item.definition.color
        var position := item.position + Vector2(0.0, sin(item.age * 5.2 + item.phase) * 4.0)
        var pulse := sin(item.age * 8.0 + item.phase) * 0.5 + 0.5
        draw_circle(position, 22.0 + pulse * 4.0, Color(color.r, color.g, color.b, 0.026))
        draw_circle(position, 15.0 + pulse * 2.0, Color(color.r, color.g, color.b, 0.070))
        draw_arc(position, 17.0 + pulse * 3.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.27), 1.4, true)

        var diamond := PackedVector2Array([
            position + Vector2(0.0, -14.0), position + Vector2(14.0, 0.0),
            position + Vector2(0.0, 14.0), position + Vector2(-14.0, 0.0),
        ])
        draw_colored_polygon(diamond, Color(0.012, 0.030, 0.052, 0.97))
        draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), color, 1.8, true)
        var inner := PackedVector2Array([
            position + Vector2(0.0, -9.0), position + Vector2(9.0, 0.0),
            position + Vector2(0.0, 9.0), position + Vector2(-9.0, 0.0),
        ])
        draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.18 + pulse * 0.09))

        if item.definition.id == &"multiball":
            draw_circle(position + Vector2(-4.2, -1.0), 2.7, Color.WHITE)
            draw_circle(position + Vector2(4.2, 1.0), 2.7, color)
        elif item.definition.id == &"speed":
            for index in range(2):
                var x := position.x - 6.0 + float(index) * 8.0
                var chevron := PackedVector2Array([
                    Vector2(x - 3.5, position.y - 6.0), Vector2(x + 2.0, position.y),
                    Vector2(x - 3.5, position.y + 6.0),
                ])
                draw_polyline(chevron, Color.WHITE if index == 0 else color, 2.3, true)
        else:
            draw_circle(position, 3.0, color)
        if font != null:
            draw_string(font, position + Vector2(-30.0, 26.0), item.definition.short_name, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 9, Color(color.r, color.g, color.b, 0.82))


func draw_trails() -> void:
    for ball in world.balls:
        if ball.trail.size() < 2:
            continue
        var fire := world.is_fire_active()
        for index in range(ball.trail.size() - 1):
            var ratio := float(index) / float(maxi(ball.trail.size() - 1, 1))
            var alpha := (0.18 + ratio * 0.82) * (1.0 if fire else 0.92)
            var width := 1.8 + ratio * (8.0 if fire else 6.5)
            var color := GOLD if fire else CYAN
            if not fire and index % 5 == 0:
                color = PINK.lerp(CYAN, 0.25)
            elif fire and index % 3 == 0:
                color = PINK
            draw_line(ball.trail[index], ball.trail[index + 1], Color(color.r, color.g, color.b, alpha * 0.22), width * 3.3, true)
            draw_line(ball.trail[index], ball.trail[index + 1], Color(color.r, color.g, color.b, alpha), width, true)
            draw_line(ball.trail[index], ball.trail[index + 1], Color(1.0, 1.0, 1.0, alpha * 0.58), maxf(1.0, width * 0.24), true)
            if index % 3 == 0:
                var dot_radius := 1.0 + ratio * 2.6
                draw_circle(ball.trail[index], dot_radius * 2.8, Color(color.r, color.g, color.b, alpha * 0.045))
                draw_circle(ball.trail[index], dot_radius, Color(color.r, color.g, color.b, alpha * 0.48))


func draw_particles() -> void:
    for particle in effects.particles:
        var alpha := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
        var color: Color = particle["color"]
        var size: float = particle["size"] * (0.45 + alpha * 0.55)
        draw_rect(Rect2(particle["pos"] - Vector2(size, size) * 0.5, Vector2(size, size)), Color(color.r, color.g, color.b, alpha), true)


func draw_paddle() -> void:
    var half := world.paddle_width * 0.5
    var rect := Rect2(world.paddle_x - half, config.paddle_y - config.paddle_height * 0.5, world.paddle_width, config.paddle_height)
    var fire := world.is_fire_active()
    var max_extra := maxf(world.paddle_max_width() - config.paddle_width, 1.0)
    var extra := maxf(world.paddle_width - config.paddle_width, 0.0)
    var upgrade := clampf(sqrt(extra / max_extra), 0.0, 1.0)
    var color := (ORANGE if fire else CYAN).lerp(Color.WHITE, upgrade * 0.5)
    draw_rect(rect.grow(14.0), Color(color.r, color.g, color.b, 0.028), true)
    draw_rect(rect.grow(7.0), Color(color.r, color.g, color.b, 0.070), true)
    var body := Color("#ffb04f") if fire else Color("#54e4e6").lerp(Color("#f2ffff"), upgrade)
    if fire:
        body = body.lerp(Color.WHITE, upgrade * 0.35)
    body = body.lerp(Color.WHITE, world.paddle_flash * 0.5)
    draw_rect(Rect2(rect.position.x + config.paddle_height * 0.5, rect.position.y, rect.size.x - config.paddle_height, rect.size.y), body, true)
    draw_circle(Vector2(rect.position.x + config.paddle_height * 0.5, rect.get_center().y), config.paddle_height * 0.5, body)
    draw_circle(Vector2(rect.end.x - config.paddle_height * 0.5, rect.get_center().y), config.paddle_height * 0.5, body)
    draw_rect(Rect2(rect.position.x + 8.0, rect.position.y + 2.0, rect.size.x - 16.0, 2.0), Color(0.92, 1.0, 1.0, 0.92).lerp(Color.WHITE, upgrade * 0.5), true)
    draw_rect(Rect2(rect.position.x + 12.0, rect.position.y + 6.0, rect.size.x - 24.0, 2.0), Color(color.r, color.g, color.b, 0.48), true)
    draw_line(Vector2(world.paddle_x - 18.0, rect.end.y + 1.0), Vector2(world.paddle_x + 18.0, rect.end.y + 1.0), Color(1.0, 1.0, 1.0, 0.60), 1.2, true)
    draw_line(Vector2(world.paddle_x - 26.0, rect.end.y + 5.0), Vector2(world.paddle_x + 26.0, rect.end.y + 5.0), Color(color.r, color.g, color.b, 0.18), 2.0, true)
    if world.paddle_flash > 0.01:
        var pulse := world.paddle_flash
        draw_rect(rect.grow(10.0 + (1.0 - pulse) * 24.0), Color(color.r, color.g, color.b, 0.28 * pulse), false, 2.0)
        draw_rect(rect.grow(4.0 + (1.0 - pulse) * 10.0), Color(1.0, 1.0, 1.0, 0.14 * pulse), false, 1.0)


func draw_balls() -> void:
    if world.state == GameWorld.State.READY:
        draw_ball_glow(Vector2(world.paddle_x, config.paddle_y - 28.0), 6.0, CYAN, 0.8)
        return
    for ball in world.balls:
        var fire := world.is_fire_active()
        var color := GOLD if fire else CYAN
        draw_ball_glow(ball.position, ball.radius, color, 1.0)
        if fire:
            draw_circle(ball.position, ball.radius + 3.0, Color(PINK.r, PINK.g, PINK.b, 0.35))
        draw_circle(ball.position, ball.radius + 1.2, color)
        draw_circle(ball.position, ball.radius, Color("#fff5dc") if fire else Color("#f6ffff"))
        draw_circle(ball.position + Vector2(-1.5, -1.5), maxf(1.2, ball.radius * 0.34), Color.WHITE)
        draw_line(ball.position + Vector2(-2, -12), ball.position + Vector2(-2, -7), Color(color.r, color.g, color.b, 0.65), 1.0, true)
        draw_line(ball.position + Vector2(2, -12), ball.position + Vector2(2, -7), Color(color.r, color.g, color.b, 0.65), 1.0, true)


func draw_ball_glow(position: Vector2, radius: float, color: Color, alpha: float) -> void:
    var pulse := 1.0 + sin(world.game_time * 7.0) * 0.08
    draw_circle(position, radius * 7.0 * pulse, Color(color.r, color.g, color.b, 0.022 * alpha))
    draw_circle(position, radius * 4.3 * pulse, Color(color.r, color.g, color.b, 0.055 * alpha))
    draw_circle(position, radius * 2.8 * pulse, Color(color.r, color.g, color.b, 0.12 * alpha))


func draw_floaters() -> void:
    if font == null:
        return
    for floater in effects.floaters:
        var alpha := clampf(float(floater["life"]) / float(floater["max_life"]), 0.0, 1.0)
        var color: Color = floater["color"]
        draw_string(
            font,
            floater["pos"] + Vector2(-70.0, 0.0),
            floater["text"],
            HORIZONTAL_ALIGNMENT_CENTER,
            140.0,
            floater["size"],
            Color(color.r, color.g, color.b, alpha)
        )


func draw_bottom_meter() -> void:
    var meter_rect := Rect2(24.0, 893.0, 672.0, 5.0)
    draw_rect(meter_rect, Color(0.07, 0.11, 0.17, 0.95), true)
    var fill := world.fire_time / config.fire_duration if world.is_fire_active() else world.fire_energy / 100.0
    fill = clampf(fill, 0.0, 1.0)
    var fill_color := ORANGE if world.is_fire_active() else GOLD
    draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * fill, meter_rect.size.y)), fill_color, true)
    draw_line(Vector2(meter_rect.position.x, meter_rect.position.y - 1.0), Vector2(meter_rect.end.x, meter_rect.position.y - 1.0), Color(0.6, 0.9, 1.0, 0.08), 1.0)
    for index in range(1, 10):
        var x := meter_rect.position.x + meter_rect.size.x * float(index) / 10.0
        draw_line(Vector2(x, meter_rect.position.y), Vector2(x, meter_rect.end.y), Color(0.0, 0.0, 0.0, 0.35), 1.0)
