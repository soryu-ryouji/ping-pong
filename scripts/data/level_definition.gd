class_name LevelDefinition
extends Resource

@export var rows := 13
@export var columns := 16
@export var brick_origin := Vector2(50.0, 128.0)
@export var brick_size := Vector2(34.0, 23.0)
@export var brick_step := Vector2(39.0, 29.0)
@export var random_carve_chance := 0.034
@export var carved_cells: Array[Vector2i] = []
@export var walls: Array[Rect2] = []
@export var hue_start := 0.155
@export var hue_end := 0.79
@export var hue_jitter := 0.012
@export var later_wave_preclear_limit := 8
