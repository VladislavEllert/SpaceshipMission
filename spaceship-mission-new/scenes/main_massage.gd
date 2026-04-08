
extends Control

@onready var story_label: RichTextLabel = $TextStart

var full_text: String = ""
var char_index: int = 0
var type_speed: float = 0.02

func _ready() -> void:
	# Строки статуса — меняются в зависимости от прогресса
	var nav     = "Навигация - настроена ✅" if GameState.ship_fully_solved else "Навигация - сбита ❌"
	var reactor = "Ядро - восстановлено ✅" if GameState.reactor_installed  else "Ядро - отказ ❌"
	var power   = "Питание - настроено ✅" if GameState.power_solved        else "Питание - отключено ❌"

	var door = "Дверь блока - разблокирована ✅" if GameState.room1_door_opened else "Дверь блока - заблокирована ❌"

	full_text = (
		"СТАТУС КОРАБЛЯ: КРИТИЧЕСКИЙ\n" +
		reactor + "\n" +
		power + "\n" +
		door + "\n" +
		nav + "\n" +
		"Последняя запись бортового дневника была сохранена в памяти робота ARIA ✅"
	)
	start_typing()

func start_typing() -> void:
	story_label.text = full_text
	story_label.visible_characters = 0
	_type_next_char()

func _type_next_char() -> void:
	if story_label.visible_characters >= story_label.get_total_character_count():
		return
	story_label.visible_characters += 1
	await get_tree().create_timer(type_speed).timeout
	_type_next_char()

func _close_message() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game:
		main_game.close_message4()

func _on_BackButton_pressed() -> void:
	AudioManager.play_click()
	_close_message()
