extends Node2D

signal go_left
signal go_right

# Сообщения до батарейки
var messages_no_power: Array[String] = [
	"Питание отключено, требуется альтернативный источник энергии.",
]

# Сообщения после батарейки
var messages_powered: Array[String] = [
	"7 часов и 23 минуты назад корабль вошёл в аномальную зону. Никто не успел среагировать. Всё произошло слишком быстро — сначала помехи на связи, потом один за другим начали гаснуть экраны.",
	"Команда пыталась стабилизировать системы вручную. Капитан Рейнс отдал приказ всем отступить в кормовой блок — думал, это временно. Дверь заблокировалась сама. Он этого не планировал.",
	"С тех пор они там. Кислорода осталось немного.",
	"Ты единственный, кто был вне блока в момент аварии. Единственный, кто может что-то сделать. Я не знаю, хватит ли времени — но другого варианта нет.",
]

var is_typing: bool = false
var full_text: String = ""
var current_index: int = 0
var current_messages: Array[String] = []

const TYPE_SPEED: float = 0.015

@onready var robot_button: TextureButton = $RobotButton
@onready var robot_dialog: Panel = $RobotDialog
@onready var dialog_label: RichTextLabel = $RobotDialog/DialogLabel
@onready var next_button: TextureButton = $RobotDialog/NextButton
@onready var ball_button: TextureButton = $BallButton

func _ready() -> void:
	if not $LeftArrow.pressed.is_connected(_on_left_pressed):
		$LeftArrow.pressed.connect(_on_left_pressed)
	if not $RightArrow.pressed.is_connected(_on_right_pressed):
		$RightArrow.pressed.connect(_on_right_pressed)
	if not robot_button.pressed.is_connected(_on_robot_pressed):
		robot_button.pressed.connect(_on_robot_pressed)
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not ball_button.pressed.is_connected(_on_ball_button_pressed):
		ball_button.pressed.connect(_on_ball_button_pressed)
	robot_dialog.visible = false
	next_button.visible = false

	# (SolvedBannerDoor удалён из сцены)

func _on_left_pressed() -> void:
	AudioManager.play_click()
	emit_signal("go_left")

func _on_right_pressed() -> void:
	AudioManager.play_click()
	emit_signal("go_right")

func _on_door_unlock_pressed() -> void:
	GameState.room1_door_opened = true

func _on_main_massage_button_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game:
		main_game.open_message4()

# --- Клик по шару ---
func _on_ball_button_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game:
		main_game.open_ball()

# --- Клик по роботу ---
func _on_robot_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")

	if not GameState.robot_powered and main_game != null:
		var inventory = main_game.get_node("UILayer/InventoryRoot")
		if inventory.get_selected_item_id() == "battery":
			GameState.robot_powered = true
			inventory.remove_item("battery")
			_open_dialog(messages_powered)
			return

	if GameState.robot_powered:
		_open_dialog(messages_powered)
	else:
		_open_dialog(messages_no_power)

# --- Показ диалога ---
func _open_dialog(messages: Array[String]) -> void:
	current_messages = messages
	current_index = 0
	robot_dialog.visible = true
	_show_message(current_index)

func _show_message(index: int) -> void:
	full_text = current_messages[index]
	dialog_label.text = full_text
	dialog_label.visible_characters = 0
	next_button.visible = true
	is_typing = true
	_type_next_char()

func _type_next_char() -> void:
	if not is_typing:
		dialog_label.visible_characters = -1
		next_button.visible = true
		return
	if dialog_label.visible_characters >= dialog_label.get_total_character_count():
		is_typing = false
		next_button.visible = true
		return
	dialog_label.visible_characters += 1
	await get_tree().create_timer(TYPE_SPEED).timeout
	_type_next_char()

func _on_next_pressed() -> void:
	AudioManager.play_click()
	if is_typing:
		is_typing = false
		dialog_label.visible_characters = -1
		next_button.visible = true
		return

	current_index += 1

	if current_index >= current_messages.size():
		robot_dialog.visible = false
		return

	_show_message(current_index)
