extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var music_volume: float = 0.8
var sfx_volume: float = 0.8

func _ready() -> void:
	music_player.volume_db = linear_to_db(music_volume)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	music_player.finished.connect(func(): music_player.play())
	if not music_player.playing:
		music_player.play()

func play_click() -> void:
	sfx_player.play()

func set_music_volume(value: float) -> void:
	music_volume = value
	music_player.volume_db = linear_to_db(value) if value > 0.001 else -80.0

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	sfx_player.volume_db = linear_to_db(value) if value > 0.001 else -80.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		music_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		music_player.stream_paused = false
