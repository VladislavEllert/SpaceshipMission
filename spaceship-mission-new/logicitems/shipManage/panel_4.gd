extends Node2D

@onready var dialog_box: Panel = $DialogBox
@onready var dialog_label: RichTextLabel = $DialogBox/DialogLabel
@onready var next_button: TextureButton = $DialogBox/NextButton

const TYPE_SPEED: float = 0.035
var dialog_messages: Array[String] = [
	"Навигация корабля сбита",
	"Придеться откалибровать полет вручную...",
]
var dialog_index: int = 0
var is_typing: bool = false
var full_text: String = ""


# --- Константы первой мини-игры (экраны) ---
const CORRECT_LEFT: int = 160
const CORRECT_RIGHT: int = 70
const STEP: int = 10
const MAX_VAL: int = 180

# --- Константы второй мини-игры (вычисляются в _ready) ---
var SCREEN_LEFT: float = 455.0
var SCREEN_TOP: float = 130.0
var SCREEN_WIDTH: float = 490.0
var SCREEN_HEIGHT: float = 400.0

const ARROW_SPEED: float = 220.0
const DOT_SPEED_START: float = 110.0   # начальная скорость мяча
const DOT_SPEED_MAX: float = 260.0     # максимальная скорость
const DOT_ACCEL: float = 18.0          # плавный разгон за секунду
const DOT_SPEED_STEP: float = 55.0     # прибавка скорости после каждого касания
const CATCH_DISTANCE: float = 48.0     # увеличен — касание срабатывает надёжнее
const ESCAPE_FORCE: float = 210.0      # сила убегания мяча от стрелочки
const ESCAPE_RADIUS: float = 130.0     # радиус реакции мяча на стрелку
const BOUNCE_DAMPING: float = 0.88     # гашение скорости при отскоке от стены
const CATCH_COOLDOWN: float = 0.9      # задержка между засчитанными касаниями
const GRID_COLS: int = 8
const GRID_ROWS: int = 6

# --- Состояние первой игры ---
var left_value: int = 0
var right_value: int = 0

# --- Состояние второй игры ---
var joystick_active: bool = false
var arrow_pos: Vector2 = Vector2.ZERO
var dot_pos: Vector2 = Vector2.ZERO
var dot_vel: Vector2 = Vector2.ZERO    # вектор скорости мяча (инерция)
var dot_speed: float = DOT_SPEED_START
var catch_count: int = 0
var catch_cooldown_timer: float = 0.0  # таймер кулдауна касания
var game_won: bool = false
var joy_input: Vector2 = Vector2.ZERO
# Карта активных касаний: touch_index → позиция на экране.
# Нужна для мультитача — стандартная Control-система в Godot 4
# отслеживает только одно нажатие, из-за чего диагонали на мобильном
# не работали. Читаем события напрямую и смотрим, какие кнопки
# накрыли пальцы прямо сейчас.
var _active_touches: Dictionary = {}
const _MOUSE_TOUCH_ID: int = -1   # «индекс» для эмуляции мышью

# --- Ноды первой игры ---
@onready var left_screen: ColorRect = $LeftScreen
@onready var left_label: Label = $LeftLabel
@onready var left_plus: TextureButton = $LeftPlus
@onready var left_minus: TextureButton = $LeftMinus
@onready var right_screen: ColorRect = $RightScreen
@onready var right_label: Label = $RightLabel
@onready var right_plus: TextureButton = $RightPlus
@onready var right_minus: TextureButton = $RightMinus
@onready var back_button: TextureButton = $BackButton

# --- Ноды второй игры ---
@onready var joystick: Node2D = $Joystick
@onready var joy_up: TextureButton = $Joystick/JoyUp
@onready var joy_down: TextureButton = $Joystick/JoyDown
@onready var joy_left: TextureButton = $Joystick/JoyLeft
@onready var joy_right: TextureButton = $Joystick/JoyRight
@onready var screen_area: Node2D = $ScreenArea
@onready var screen_bg: ColorRect = $ScreenArea/ScreenBg
@onready var arrow: Sprite2D = $ScreenArea/Arrow
@onready var dot: Sprite2D = $ScreenArea/Dot
@onready var grid: Node2D = $ScreenArea/Grid

func _ready() -> void:
	# Размер и позиция экрана берутся из ColorRect screen_bg — он выставлен
	# в редакторе под видимую область экрана на текстуре фона панели.
	SCREEN_LEFT = screen_bg.position.x
	SCREEN_TOP = screen_bg.position.y
	SCREEN_WIDTH = screen_bg.size.x
	SCREEN_HEIGHT = screen_bg.size.y
	grid.position = screen_bg.position
	grid.set_grid_size(SCREEN_WIDTH, SCREEN_HEIGHT)
	if not left_plus.pressed.is_connected(_on_left_plus):
		left_plus.pressed.connect(_on_left_plus)
	if not left_minus.pressed.is_connected(_on_left_minus):
		left_minus.pressed.connect(_on_left_minus)
	if not right_plus.pressed.is_connected(_on_right_plus):
		right_plus.pressed.connect(_on_right_plus)
	if not right_minus.pressed.is_connected(_on_right_minus):
		right_minus.pressed.connect(_on_right_minus)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	left_screen.visible = false
	right_screen.visible = false
	_update_labels()

	joystick.visible = false
	screen_area.visible = false
	screen_bg.visible = false

	# Сигналы button_down/button_up намеренно не подключаем — многопальцевые
	# нажатия через них не проходят. Вся логика направления собирается из
	# _active_touches в _input / _refresh_joy_input.

	# Подключаемся к карт-вьюеру starmap — скрываем кнопку выхода пока открыта карта
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game:
		var card_viewer2 = main_game.get_node_or_null("UILayer/CardViewer2")
		if card_viewer2:
			card_viewer2.card_opened.connect(_on_starmap_opened)
			card_viewer2.card_closed.connect(_on_starmap_closed)

	if GameState.ship_fully_solved:
		left_screen.visible = true
		right_screen.visible = true
		left_screen.color = Color(0.0, 0.8, 0.2, 0.6)
		right_screen.color = Color(0.0, 0.8, 0.2, 0.6)
		screen_bg.visible = true
		screen_bg.color = Color(0.0, 1.0, 0.1, 0.3)
		game_won = true
		dialog_box.visible = false
		return  # ← диалог не показываем, игра не запускается заново
	if not next_button.pressed.is_connected(_on_dialog_next):
		next_button.pressed.connect(_on_dialog_next)
	next_button.visible = false
	dialog_label.text = ""
	dialog_box.visible = true
	_set_buttons_disabled(true)
	_show_dialog_message(0)


# --- Блокировка/разблокировка всех интерактивных кнопок ---
func _set_buttons_disabled(value: bool) -> void:
	left_plus.disabled = value
	left_minus.disabled = value
	right_plus.disabled = value
	right_minus.disabled = value
	back_button.disabled = value
	joy_up.disabled = value
	joy_down.disabled = value
	joy_left.disabled = value
	joy_right.disabled = value

func _input(event: InputEvent) -> void:
	if not joystick_active or game_won:
		return

	# Собираем активные касания в Dictionary, чтобы потом проверить,
	# какие D-pad кнопки сейчас прижаты (учитывая все пальцы сразу).
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = event.position
		else:
			_active_touches.erase(event.index)
		_refresh_joy_input()
	elif event is InputEventScreenDrag:
		_active_touches[event.index] = event.position
		_refresh_joy_input()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_active_touches[_MOUSE_TOUCH_ID] = event.position
			else:
				_active_touches.erase(_MOUSE_TOUCH_ID)
			_refresh_joy_input()
	elif event is InputEventMouseMotion:
		if _active_touches.has(_MOUSE_TOUCH_ID):
			_active_touches[_MOUSE_TOUCH_ID] = event.position
			_refresh_joy_input()

# Пересчитывает joy_input по всем активным касаниям. Один палец на Up + второй
# на Right даёт (1, -1) → диагональ.
func _refresh_joy_input() -> void:
	var new_input := Vector2.ZERO
	for pos in _active_touches.values():
		if _button_touched(joy_up, pos):
			new_input.y = -1
		if _button_touched(joy_down, pos):
			new_input.y = 1
		if _button_touched(joy_left, pos):
			new_input.x = -1
		if _button_touched(joy_right, pos):
			new_input.x = 1
	joy_input = new_input

func _button_touched(btn: TextureButton, pos: Vector2) -> bool:
	if btn == null or btn.disabled or not btn.visible:
		return false
	# get_global_rect() не учитывает поворот узла (JoyDown/Left/Right повёрнуты),
	# а у JoyUp стоит anchors_preset=Full Rect, из-за чего её size растянут почти
	# на весь экран. Решаем обе проблемы: переводим касание в локальные координаты
	# кнопки (это снимает поворот), и для размера берём размер текстуры, а не
	# раздутый size.
	var local := btn.get_global_transform_with_canvas().affine_inverse() * pos
	var hit_size := btn.size
	if btn.texture_normal != null:
		hit_size = btn.texture_normal.get_size()
	return Rect2(Vector2.ZERO, hit_size).has_point(local)

func _process(delta: float) -> void:
	if not joystick_active or game_won:
		return

	# --- Движение стрелочки ---
	if joy_input != Vector2.ZERO:
		arrow_pos += joy_input.normalized() * ARROW_SPEED * delta
		arrow_pos.x = clamp(arrow_pos.x, SCREEN_LEFT, SCREEN_LEFT + SCREEN_WIDTH)
		arrow_pos.y = clamp(arrow_pos.y, SCREEN_TOP, SCREEN_TOP + SCREEN_HEIGHT)
		arrow.position = arrow_pos

	# --- Физика мяча ---
	# Плавный разгон до текущей целевой скорости
	dot_speed = min(dot_speed + DOT_ACCEL * delta, DOT_SPEED_MAX)

	# Поведение убегания: мяч реагирует на стрелочку и уходит прочь
	var to_arrow := arrow_pos - dot_pos
	var dist := to_arrow.length()
	if dist < ESCAPE_RADIUS and dist > 1.0:
		var escape_dir := -to_arrow.normalized()
		# Сила убегания растёт по мере сближения (ближе → сильнее)
		var strength := (1.0 - dist / ESCAPE_RADIUS) * ESCAPE_FORCE
		dot_vel += escape_dir * strength * delta

	# Ограничиваем скорость
	var speed := dot_vel.length()
	if speed > dot_speed:
		dot_vel = dot_vel.normalized() * dot_speed
	elif speed < dot_speed * 0.4:
		# Если скорость слишком упала — подталкиваем
		var dir := dot_vel.normalized() if speed > 0.5 else Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		dot_vel = dir * dot_speed * 0.6

	dot_pos += dot_vel * delta

	# --- Реалистичный отскок от границ ---
	if dot_pos.x <= SCREEN_LEFT:
		dot_pos.x = SCREEN_LEFT
		dot_vel.x = abs(dot_vel.x) * BOUNCE_DAMPING
	elif dot_pos.x >= SCREEN_LEFT + SCREEN_WIDTH:
		dot_pos.x = SCREEN_LEFT + SCREEN_WIDTH
		dot_vel.x = -abs(dot_vel.x) * BOUNCE_DAMPING

	if dot_pos.y <= SCREEN_TOP:
		dot_pos.y = SCREEN_TOP
		dot_vel.y = abs(dot_vel.y) * BOUNCE_DAMPING
	elif dot_pos.y >= SCREEN_TOP + SCREEN_HEIGHT:
		dot_pos.y = SCREEN_TOP + SCREEN_HEIGHT
		dot_vel.y = -abs(dot_vel.y) * BOUNCE_DAMPING

	dot.position = dot_pos

	# --- Проверка касания с кулдауном ---
	catch_cooldown_timer -= delta
	if catch_cooldown_timer <= 0.0 and dist < CATCH_DISTANCE:
		_on_catch()

# --- Засчитываем касание ---
func _on_catch() -> void:
	catch_count += 1
	catch_cooldown_timer = CATCH_COOLDOWN

	# Вспышка мяча
	var tw := create_tween()
	tw.tween_property(dot, "modulate", Color(2.5, 2.0, 0.3, 1.0), 0.08)
	tw.tween_property(dot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

	# Мяч отскакивает прочь от стрелочки
	var bounce_dir := (dot_pos - arrow_pos).normalized()
	if bounce_dir.length() < 0.1:
		bounce_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	dot_speed = min(dot_speed + DOT_SPEED_STEP, DOT_SPEED_MAX)
	dot_vel = bounce_dir * dot_speed

	if catch_count >= 3:
		_on_game_won()

# --- Первая игра ---
func _on_left_plus() -> void:
	left_value = (left_value + STEP) % (MAX_VAL + STEP)
	_update_labels()
	_check_screens_win()

func _on_left_minus() -> void:
	left_value = (left_value - STEP + MAX_VAL + STEP) % (MAX_VAL + STEP)
	_update_labels()
	_check_screens_win()

func _on_right_plus() -> void:
	right_value = (right_value + STEP) % (MAX_VAL + STEP)
	_update_labels()
	_check_screens_win()

func _on_right_minus() -> void:
	right_value = (right_value - STEP + MAX_VAL + STEP) % (MAX_VAL + STEP)
	_update_labels()
	_check_screens_win()

func _update_labels() -> void:
	left_label.text = str(left_value)
	right_label.text = str(right_value)

func _check_screens_win() -> void:
	if left_value == CORRECT_LEFT and right_value == CORRECT_RIGHT:
		left_screen.visible = true
		right_screen.visible = true
		left_screen.color = Color(0.0, 0.8, 0.2, 0.6)
		right_screen.color = Color(0.0, 0.8, 0.2, 0.6)
		GameState.panel_solved = true
		_start_joystick_game()

func _start_joystick_game() -> void:
	joystick.visible = true
	screen_area.visible = true
	joystick_active = true
	_active_touches.clear()
	joy_input = Vector2.ZERO

	var center := Vector2(SCREEN_LEFT + SCREEN_WIDTH / 2.0, SCREEN_TOP + SCREEN_HEIGHT / 2.0)
	arrow_pos = center
	arrow.position = arrow_pos

	dot_pos = _random_far_pos(center)
	dot_vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * DOT_SPEED_START
	dot.position = dot_pos
	dot_speed = DOT_SPEED_START
	catch_cooldown_timer = 0.0

func _on_game_won() -> void:
	game_won = true
	joystick_active = false
	joy_input = Vector2.ZERO

	var center := Vector2(SCREEN_LEFT + SCREEN_WIDTH / 2.0, SCREEN_TOP + SCREEN_HEIGHT / 2.0)
	arrow_pos = center
	dot_pos = center
	arrow.position = center
	dot.position = center

	screen_bg.visible = true
	screen_bg.color = Color(0.0, 1.0, 0.1, 0.3)
	GameState.panel_game_won = true
	GameState.ship_fully_solved = true
	_check_door_unlocked()

	dialog_messages = ["Корабль откалиброван"]
	dialog_index = 0
	dialog_box.visible = true
	_set_buttons_disabled(true)
	_show_dialog_message(0)

func _random_far_pos(from: Vector2) -> Vector2:
	var pos: Vector2
	for _i in range(20):
		pos = Vector2(
			randf_range(SCREEN_LEFT + 40, SCREEN_LEFT + SCREEN_WIDTH - 40),
			randf_range(SCREEN_TOP + 40, SCREEN_TOP + SCREEN_HEIGHT - 40)
		)
		if pos.distance_to(from) > 150:
			return pos
	return pos

func _check_door_unlocked() -> void:
	if GameState.reactor_installed and GameState.power_solved and GameState.ship_fully_solved:
		GameState.door_unlocked = true

func _on_back_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game:
		main_game.close_panel()
		
		
func _show_dialog_message(index: int) -> void:
	full_text = dialog_messages[index]
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

func _on_dialog_next() -> void:
	if is_typing:
		is_typing = false
		dialog_label.visible_characters = -1
		next_button.visible = true
		return
	dialog_index += 1
	if dialog_index >= dialog_messages.size():
		dialog_box.visible = false
		_set_buttons_disabled(false)
		return
	_show_dialog_message(dialog_index)

# --- Скрытие/показ кнопки выхода при просмотре карты из инвентаря ---
func _on_starmap_opened() -> void:
	back_button.visible = false

func _on_starmap_closed() -> void:
	back_button.visible = true
