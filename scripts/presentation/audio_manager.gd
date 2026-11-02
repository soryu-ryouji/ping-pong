class_name GameAudioManager
extends Node

var rng := RandomNumberGenerator.new()
var players: Array[AudioStreamPlayer] = []
var player_index := 0
var sounds: Dictionary = {}


func _ready() -> void:
    rng.seed = 0x50A11D
    sounds[GameEvent.Type.BALL_LAUNCHED] = synth_sound(360.0, 0.12, 0.30, 0.08, 1.4)
    sounds[GameEvent.Type.WALL_HIT] = synth_sound(210.0, 0.055, 0.20, 0.05, 2.6)
    sounds[GameEvent.Type.PADDLE_HIT] = synth_sound(360.0, 0.12, 0.30, 0.08, 1.4)
    sounds[GameEvent.Type.BALL_LOST] = synth_sound(150.0, 0.42, 0.28, 0.16, 0.8)
    sounds[GameEvent.Type.BRICK_HIT] = synth_sound(520.0, 0.065, 0.26, 0.14, 2.1)
    sounds[GameEvent.Type.BREAKABLE_WALL_HIT] = synth_sound(180.0, 0.07, 0.22, 0.22, 2.2)
    sounds[GameEvent.Type.BREAKABLE_WALL_DESTROYED] = synth_sound(300.0, 0.35, 0.30, 0.26, 1.4)
    sounds[GameEvent.Type.BRICK_DESTROYED] = synth_sound(760.0, 0.085, 0.34, 0.20, 1.9)
    sounds[GameEvent.Type.FIRE_STARTED] = synth_sound(260.0, 0.65, 0.26, 0.46, 0.55)
    sounds[GameEvent.Type.LEVEL_CLEARED] = synth_sound(980.0, 0.5, 0.24, 0.02, 0.7)
    sounds[GameEvent.Type.XP_LEVEL_UP] = synth_sound(880.0, 0.35, 0.28, 0.08, 1.1)
    sounds[GameEvent.Type.POWERUP_COLLECTED] = synth_sound(640.0, 0.28, 0.30, 0.10, 1.1)
    for index in range(10):
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        players.append(player)


func handle_event(event: GameEvent) -> void:
    if not sounds.has(event.type):
        return
    match event.type:
        GameEvent.Type.BALL_LAUNCHED:
            play_sound(event.type, -8.0, rng.randf_range(1.08, 1.20))
        GameEvent.Type.WALL_HIT:
            play_sound(event.type, -21.0, rng.randf_range(0.94, 1.08))
        GameEvent.Type.PADDLE_HIT:
            play_sound(event.type, -7.0, rng.randf_range(1.02, 1.13))
        GameEvent.Type.BALL_LOST:
            play_sound(event.type, -5.0, rng.randf_range(0.92, 1.02))
        GameEvent.Type.BRICK_HIT:
            play_sound(event.type, -15.0, rng.randf_range(0.86, 1.02))
        GameEvent.Type.BREAKABLE_WALL_HIT:
            play_sound(event.type, -16.0, rng.randf_range(0.90, 1.08))
        GameEvent.Type.BREAKABLE_WALL_DESTROYED:
            play_sound(event.type, -7.0, rng.randf_range(0.92, 1.02))
        GameEvent.Type.BRICK_DESTROYED:
            play_sound(event.type, -12.0, rng.randf_range(0.88, 1.18))
        GameEvent.Type.FIRE_STARTED:
            play_sound(event.type, -3.0, rng.randf_range(0.96, 1.04))
        GameEvent.Type.LEVEL_CLEARED:
            play_sound(event.type, -4.0)
        GameEvent.Type.XP_LEVEL_UP:
            play_sound(event.type, -5.0)
        GameEvent.Type.POWERUP_COLLECTED:
            play_sound(event.type, -4.0, event.value)


func play_sound(type: GameEvent.Type, volume_db: float, pitch := 1.0) -> void:
    if players.is_empty():
        return
    var player := players[player_index]
    player_index = (player_index + 1) % players.size()
    player.stream = sounds[type]
    player.volume_db = volume_db
    player.pitch_scale = pitch
    player.play()


func stop_all() -> void:
    for player in players:
        player.stop()
        player.stream = null


func synth_sound(frequency: float, duration: float, volume: float, noise_amount: float, decay: float) -> AudioStreamWAV:
    var sample_rate := 22050
    var sample_count := maxi(1, int(duration * sample_rate))
    var data := PackedByteArray()
    data.resize(sample_count * 2)
    for index in range(sample_count):
        var time := float(index) / float(sample_rate)
        var progress := float(index) / float(sample_count)
        var envelope := pow(maxf(0.0, 1.0 - progress), decay)
        var wave := sin(TAU * frequency * time)
        wave += sin(TAU * frequency * 2.02 * time) * 0.22
        wave += sin(TAU * frequency * 0.51 * time) * 0.18
        wave += sin(TAU * 13471.0 * time) * noise_amount * (0.30 + progress * 0.70)
        var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
        data.encode_s16(index * 2, sample)

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    return stream
