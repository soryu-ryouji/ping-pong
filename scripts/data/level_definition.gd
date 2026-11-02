class_name LevelDefinition
extends Resource

const SYMBOL_PALETTE := [
    Color("#ffd56a"),
    Color("#ff8dd8"),
    Color("#78f4ff"),
    Color("#c9ff72"),
    Color("#ff9b45"),
    Color("#9b8cff"),
    Color("#5be3c1"),
    Color("#ff6b6b"),
    Color("#7dd3fc"),
]
const DIGIT_START := 49
const DIGIT_END := 57
const UPPER_START := 65
const UPPER_END := 90
const LOWER_START := 97
const LOWER_END := 122

@export var layout_file := ""
@export var display_name := ""
@export var rows := 0
@export var columns := 0
@export var brick_rows := 0
@export var brick_origin := Vector2(50.0, 128.0)
@export var brick_size := Vector2(34.0, 23.0)
@export var brick_step := Vector2(39.0, 29.0)
@export var hue_start := 0.155
@export var hue_end := 0.79
@export var hue_jitter := 0.012
@export var wall_thickness := 12.0
@export_range(0.0, 1.0) var random_carve_chance := 0.0
@export var grid: PackedStringArray = []
@export var symbol_colors: Dictionary = {}
@export var walls: Array[Rect2] = []


static func palette_color(symbol: String) -> Color:
    if symbol.is_empty():
        return Color.WHITE
    var code := symbol.unicode_at(0)
    var index := 0
    if code >= DIGIT_START and code <= DIGIT_END:
        index = code - DIGIT_START
    elif code >= UPPER_START and code <= UPPER_END:
        index = (code - UPPER_START) % SYMBOL_PALETTE.size()
    elif code >= LOWER_START and code <= LOWER_END:
        index = (code - LOWER_START) % SYMBOL_PALETTE.size()
    else:
        index = code % SYMBOL_PALETTE.size()
    return SYMBOL_PALETTE[index]
