## MirrorCell.gd
## Скрипт одной ячейки сетки: хранит тип, отображает нужный спрайт,
## обрабатывает касание для поворота зеркала.
extends Node2D

# Типы содержимого ячейки
enum CellType { EMPTY, MIRROR_45, MIRROR_135, SOURCE, TARGET, WALL }

# Сигнал о повороте зеркала — главная сцена пересчитывает лазер
signal mirror_rotated

# Текущий тип ячейки
var cell_type: CellType = CellType.EMPTY

# Размер ячейки в пикселях
const CELL_SIZE := 120.0

# Внутренние ссылки на узлы (создаются в _ready)
var _cell_bg: ColorRect
var _mirror_label: Label      # Заменяет спрайт зеркала текстовым символом
var _icon_label: Label        # Иконка источника / цели / стены
var _touch_area: Area2D
var _collision: CollisionShape2D
var _last_tap_frame: int = -1


func _ready() -> void:
	_build_nodes()


## Создаём все дочерние узлы программно — без зависимости от .tscn
func _build_nodes() -> void:
	# --- Фон ячейки ---
	_cell_bg = ColorRect.new()
	_cell_bg.name = "CellBg"
	_cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
	_cell_bg.position = Vector2(-CELL_SIZE / 2.0, -CELL_SIZE / 2.0)
	_cell_bg.color = Color("#1A2035")
	add_child(_cell_bg)

	# --- Метка для символа зеркала (/ или \) ---
	_mirror_label = Label.new()
	_mirror_label.name = "MirrorLabel"
	_mirror_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mirror_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mirror_label.size = Vector2(CELL_SIZE, CELL_SIZE)
	_mirror_label.position = Vector2(-CELL_SIZE / 2.0, -CELL_SIZE / 2.0)
	_mirror_label.add_theme_font_size_override("font_size", 64)
	_mirror_label.add_theme_color_override("font_color", Color("#88CCFF"))
	_mirror_label.visible = false
	add_child(_mirror_label)

	# --- Метка для иконки источника/цели/стены ---
	_icon_label = Label.new()
	_icon_label.name = "IconLabel"
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.size = Vector2(CELL_SIZE, CELL_SIZE)
	_icon_label.position = Vector2(-CELL_SIZE / 2.0, -CELL_SIZE / 2.0)
	_icon_label.add_theme_font_size_override("font_size", 48)
	_icon_label.visible = false
	add_child(_icon_label)

	# --- Зона касания (Area2D + CollisionShape2D) ---
	_touch_area = Area2D.new()
	_touch_area.name = "TouchArea"
	_touch_area.input_pickable = true
	add_child(_touch_area)

	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110.0, 110.0)
	_collision.shape = shape
	_touch_area.add_child(_collision)

	# Подключаем сигнал касания
	_touch_area.connect("input_event", Callable(self, "_on_touch_area_input_event"))


## Устанавливаем тип ячейки и обновляем внешний вид
func set_cell_type(type: CellType) -> void:
	cell_type = type
	_update_visuals()


## Обновляем цвет фона и видимость меток в зависимости от типа
func _update_visuals() -> void:
	# Сбрасываем все метки
	_mirror_label.visible = false
	_icon_label.visible = false

	match cell_type:
		CellType.EMPTY:
			_cell_bg.color = Color("#1A2035")
			_touch_area.input_pickable = false

		CellType.MIRROR_45:
			_cell_bg.color = Color("#1A2540")
			_mirror_label.text = "/"
			_mirror_label.visible = true
			_touch_area.input_pickable = true

		CellType.MIRROR_135:
			_cell_bg.color = Color("#1A2540")
			_mirror_label.text = "\\"
			_mirror_label.visible = true
			_touch_area.input_pickable = true

		CellType.SOURCE:
			_cell_bg.color = Color("#1A3A1A")
			_icon_label.text = "◉"
			_icon_label.add_theme_color_override("font_color", Color("#00FF88"))
			_icon_label.visible = true
			_touch_area.input_pickable = false

		CellType.TARGET:
			_cell_bg.color = Color("#3A1A0A")
			_icon_label.text = "◎"
			_icon_label.add_theme_color_override("font_color", Color("#FF8800"))
			_icon_label.visible = true
			_touch_area.input_pickable = false

		CellType.WALL:
			_cell_bg.color = Color("#3A1A1A")
			_icon_label.text = "▪"
			_icon_label.add_theme_color_override("font_color", Color("#664444"))
			_icon_label.visible = true
			_touch_area.input_pickable = false

	# Рисуем тонкую рамку через модуляцию (эмуляция через изменение размера не нужна —
	# рамку рисует сама LaserMirror.gd через draw_rect в _draw ячейки)
	queue_redraw()


## Рисуем рамку ячейки
func _draw() -> void:
	var half := CELL_SIZE / 2.0
	draw_rect(
		Rect2(-half, -half, CELL_SIZE, CELL_SIZE),
		Color("#2A3550"),
		false,   # filled = false → только контур
		2.0
	)


## Обработка касания на зоне Area2D
func _on_touch_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Принимаем и касание пальцем, и клик мышью (для отладки в редакторе)
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	var is_click: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed

	if not (is_touch or is_click):
		return

	var frame := Engine.get_process_frames()
	if frame == _last_tap_frame:
		return
	_last_tap_frame = frame

	# Переключаем зеркало между двумя состояниями
	if cell_type == CellType.MIRROR_45:
		cell_type = CellType.MIRROR_135
	elif cell_type == CellType.MIRROR_135:
		cell_type = CellType.MIRROR_45
	else:
		return  # Не зеркало — игнорируем

	_update_visuals()
	emit_signal("mirror_rotated")
