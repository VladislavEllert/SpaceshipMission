extends Control

func _ready() -> void:
	$Background/ResumeButton.pressed.connect(_on_resume_pressed)
	$Background/ResetButton.pressed.connect(_on_reset_pressed)
	$Background/QuitButton.pressed.connect(_on_quit_pressed)

	$Background/MusicSlider.value = AudioManager.music_volume
	$Background/SFXSlider.value = AudioManager.sfx_volume
	$Background/MusicSlider.value_changed.connect(AudioManager.set_music_volume)
	$Background/SFXSlider.value_changed.connect(AudioManager.set_sfx_volume)

func _on_resume_pressed() -> void:
	AudioManager.play_click()
	queue_free()

func _on_reset_pressed() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func _on_quit_pressed() -> void:
	GameState.save()
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
