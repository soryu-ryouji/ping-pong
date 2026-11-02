class_name GameConfig
extends Resource

@export var screen_size := Vector2(720.0, 920.0)
@export var field_left := 34.0
@export var field_right := 686.0
@export var field_top := 108.0
@export var field_bottom := 852.0
@export var inner_left := 42.0
@export var inner_right := 678.0
@export var inner_top := 118.0
@export var paddle_y := 824.0
@export var paddle_width := 116.0
@export var paddle_height := 14.0

@export var initial_lives := 5
@export var random_seed := 0x5EEDC0DE
@export var base_ball_speed := 470.0
@export var wave_speed_increment := 18.0
@export var maximum_launch_balls := 7
@export var combo_multiball_limit := 6
@export var combo_first_multiball := 30
@export var combo_multiball_interval := 35

@export_range(0.0, 1.0) var powerup_drop_chance := 0.14
@export var powerup_pity_limit := 8
@export var powerup_max_active := 7
@export var powerup_max_balls := 24
@export var fire_drop_chance_multiplier := 0.72
@export var fire_duration := 6.0
@export var fire_charge_per_hit := 3.4

@export_file("*.txt") var level_manifest := "res://resources/levels/levels.txt"
@export var debug_tools := false
@export var powerups: PowerupCatalog
