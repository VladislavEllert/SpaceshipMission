extends Node2D

signal go_left
signal go_right

var is_typing: bool = false
var full_text: String = ""
var current_index: int = 0
var current_messages: Array[String] = []

const TYPE_SPEED: float = 0.03

# --- Текстуры фона ---
const BG_DEFAULT   := preload("res://ImagesBackground/result_newfirstroom.png")
const BG_ALTERNATE := preload("res://ImagesBackground/result_newfirstroomopenwad.png")
const BG_DOOR_OPEN := preload("res://ImagesBackground/result_newFirstRoomOpenDoor.png")

# --- Текстуры реактора ---
const REACTOR_COLORED := preload("res://items/newreactorsec.png")

var bg_toggled: bool = false

# --- Сообщения для ScreenButton ---
var messages_no_card: Array[String] = [
	"🔒 Доступ ограничен. Для использования панели управления подтвердите личность — приложите карту доступа.",
]
var messages_with_card: Array[String] = [
	"✅ Карта принята. Личность подтверждена. Панель управления разблокирована.",
]
var messages_already_unlocked: Array[String] = [
	"✅ Панель управления разблокирована.",
]

# --- Сообщения для Stars ---
var messages_no_access: Array[String] = [
	"🚫 Нет доступа. Сначала подтвердите личность на панели управления.",
]
var messages_panel_done: Array[String] = [
	"✅ Корабль откалиброван. Навигационная система работает в штатном режиме.",
]

# --- Сообщения для реактора ---
var messages_reactor_no_tool: Array[String] = [
	"Реактор повреждён. Нужен подходящий инструмент.",
]
var messages_reactor_done: Array[String] = [
	"✅ Готово! Реактор восстановлен. Можно забрать его.",
]

var messages_door_locked: Array[String] = [
	"Дверь заблокирована",
]

var active_dialog: Panel = null
var active_label: RichTextLabel = null
var active_next: TextureButton = null

@onready var room_background: TextureRect    = $RoomBackground
@onready var screen_button: TextureButton    = $ScreenButton
@onready var screen_dialog: Panel            = $ScreenDialog
@onready var screen_label: RichTextLabel     = $ScreenDialog/DialogLabel
@onready var screen_next: TextureButton      = $ScreenDialog/NextButton
@onready var stars_button: TextureButton     = $Stars
@onready var stars_dialog: Panel             = $StarsDialog
@onready var stars_label: RichTextLabel      = $StarsDialog/DialogLabel
@onready var stars_next: TextureButton       = $StarsDialog/NextButton
@onready var bg_toggle_button: TextureButton = $BgToggleButton
@onready var hidden_button: TextureButton    = $HiddenButton
@onready var reactor: Sprite2D               = $Reactor
@onready var reactor_button: TextureButton   = $ReactorButton
@onready var door_button: TextureButton      = $Door

func _ready() -> void:
	if not $LeftArrow.pressed.is_connected(_on_left_pressed):
		$LeftArrow.pressed.connect(_on_left_pressed)
	if not $RightArrow.pressed.is_connected(_on_right_pressed):
		$RightArrow.pressed.connect(_on_right_pressed)
	if not screen_button.pressed.is_connected(_on_screen_pressed):
		screen_button.pressed.connect(_on_screen_pressed)
	screen_next.pressed.connect(func(): _on_next_pressed(screen_dialog))
	screen_next.visible = true
	if not stars_button.pressed.is_connected(_on_stars_pressed):
		stars_button.pressed.connect(_on_stars_pressed)
	stars_next.pressed.connect(func(): _on_next_pressed(stars_dialog))
	stars_next.visible = true
	if not bg_toggle_button.pressed.is_connected(_on_bg_toggle_pressed):
		bg_toggle_button.pressed.connect(_on_bg_toggle_pressed)
	if not hidden_button.pressed.is_connected(_on_hidden_button_pressed):
		hidden_button.pressed.connect(_on_hidden_button_pressed)
	if not reactor_button.pressed.is_connected(_on_reactor_pressed):
		reactor_button.pressed.connect(_on_reactor_pressed)
	if not door_button.pressed.is_connected(_on_door_pressed):
		door_button.pressed.connect(_on_door_pressed)

	screen_dialog.visible = false
	stars_dialog.visible = false
	hidden_button.visible = false

	# Если дверь открыта — меняем фон
	if GameState.room1_door_opened:
		room_background.texture = BG_DOOR_OPEN

	# Восстанавливаем только визуальное состояние реактора
	if GameState.reactor_picked_up:
		reactor.visible = false
		reactor_button.visible = false
	elif GameState.reactor_colored:
		reactor.texture = REACTOR_COLORED

	# Если предмет уже был взят ранее, скрытая кнопка больше не должна появляться
	if GameState.hidden_tool_taken:
		hidden_button.visible = false

# -------------------------------------------------------

func _on_left_pressed() -> void:
	AudioManager.play_click()
	emit_signal("go_left")

func _on_right_pressed() -> void:
	AudioManager.play_click()
	emit_signal("go_right")

# --- Переключение фона ---
func _on_bg_toggle_pressed() -> void:
	bg_toggled = not bg_toggled
	if bg_toggled:
		room_background.texture = BG_ALTERNATE
		if not GameState.hidden_tool_taken:
			hidden_button.visible = true
	else:
		room_background.texture = BG_DEFAULT
		hidden_button.visible = false

# --- Скрытая кнопка ---
func _on_hidden_button_pressed() -> void:
	if GameState.hidden_tool_taken:
		return

	GameState.hidden_tool_taken = true
	hidden_button.visible = false

	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game == null:
		return

	var inventory = main_game.get_node("UILayer/InventoryRoot")
	if not inventory.is_open:
		inventory._on_toggle_button_pressed()

	inventory.add_item("tool")

# --- Клик по реактору ---
func _on_reactor_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game == null:
		return
	var inventory = main_game.get_node("UILayer/InventoryRoot")

	# Реактор уже забрали
	if GameState.reactor_picked_up:
		return

	# Реактор ещё не починен
	if not GameState.reactor_colored:
		if inventory.get_selected_item_id() == "tool":
			GameState.reactor_colored = true
			reactor.texture = REACTOR_COLORED
			inventory.remove_item("tool")
			inventory.clear_selection()
			_open_screen_dialog(messages_reactor_done)
		else:
			_open_screen_dialog(messages_reactor_no_tool)
	else:
		# Починен — забираем в инвентарь
		GameState.reactor_picked_up = true
		reactor.visible = false
		reactor_button.visible = false
		if not inventory.is_open:
			inventory._on_toggle_button_pressed()
		inventory.add_item("reactor")

func _on_door_pressed() -> void:
	if GameState.door_unlocked:
		if GameState.room1_door_opened:
			# Открываем MeetTeam как инстанс внутри MainGame, по той же
			# схеме, что работает у всех мини-игр. change_scene_to_file
			# здесь на мобилке ломает инпут — тапы не долетают до Button'ов.
			var main_game := get_tree().get_first_node_in_group("MainGame")
			if main_game and main_game.has_method("open_meet_team"):
				main_game.open_meet_team()
			else:
				get_tree().change_scene_to_file("res://scenes/MeetTeam.tscn")
		else:
			GameState.room1_door_opened = true
			room_background.texture = BG_DOOR_OPEN
	else:
		_open_dialog(screen_dialog, screen_label, screen_next, messages_door_locked)

# DEBUG: ставит все флаги прогресса в "пройдено", открывает дверь визуально.
# После нажатия можно сразу тапнуть по двери — попадёшь в MeetTeam.


func _open_screen_dialog(messages: Array[String]) -> void:
	_open_dialog(screen_dialog, screen_label, screen_next, messages)

# -------------------------------------------------------

func _on_screen_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game == null:
		return
	if main_game.screen_unlocked:
		_open_dialog(screen_dialog, screen_label, screen_next, messages_already_unlocked)
		return
	var inventory = main_game.get_node("UILayer/InventoryRoot")
	if inventory.get_selected_item_id() == "keycard":
		inventory.remove_item("keycard")
		inventory.clear_selection()
		main_game.screen_unlocked = true
		_open_dialog(screen_dialog, screen_label, screen_next, messages_with_card)
	else:
		_open_dialog(screen_dialog, screen_label, screen_next, messages_no_card)

func _on_stars_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game == null:
		return
	if not main_game.screen_unlocked:
		_open_dialog(screen_dialog, screen_label, screen_next, messages_no_access)
		return
	if GameState.ship_fully_solved:
		_open_dialog(screen_dialog, screen_label, screen_next, messages_panel_done)
		return
	main_game.open_panel()

func _open_dialog(dialog: Panel, label: RichTextLabel, next_btn: TextureButton, messages: Array[String]) -> void:
	is_typing = false
	screen_dialog.visible = false
	stars_dialog.visible = false
	active_dialog = dialog
	active_label = label
	active_next = next_btn
	current_messages = messages
	current_index = 0
	dialog.visible = true
	_show_message(current_index)

func _show_message(index: int) -> void:
	full_text = current_messages[index]
	active_label.text = full_text
	active_label.visible_characters = 0
	active_next.visible = true
	is_typing = true
	_type_next_char()

func _type_next_char() -> void:
	if not is_typing:
		active_label.visible_characters = -1
		active_next.visible = true
		return
	if active_label.visible_characters >= active_label.get_total_character_count():
		is_typing = false
		active_next.visible = true
		return
	active_label.visible_characters += 1
	await get_tree().create_timer(TYPE_SPEED).timeout
	_type_next_char()

func _on_next_pressed(dialog: Panel) -> void:
	AudioManager.play_click()
	if is_typing:
		is_typing = false
		active_label.visible_characters = -1
		active_next.visible = true
		return
	current_index += 1
	if current_index >= current_messages.size():
		dialog.visible = false
		return
	_show_message(current_index)
