## LaserMirror.gd
## Мини-игра «Лазер и зеркала» — полностью процедурная отрисовка через _draw()
## Godot 4.4 | только касания (Button nodes) | landscape 1280×720
extends Node2D

# ── Сигналы для родительской сцены ───────────────────────────────────────────
signal puzzle_solved
signal minigame_closed

# ── Константы сетки ───────────────────────────────────────────────────────────
const CELL_SIZE := 100
const CELL_GAP  := 4
const STEP      := 104          # CELL_SIZE + CELL_GAP
const GRID_COLS := 6
const GRID_ROWS := 5
const GRID_OX   := 330          # (1280 - 6*104 + 4) / 2 = 330
const GRID_OY   := 110
const MAX_STEPS := 80

# ── Типы ячеек ────────────────────────────────────────────────────────────────
enum CellType { EMPTY, WALL, SOURCE, TARGET, MIRROR_45, MIRROR_135 }

# Направления луча (x = смещение по столбцу, y = смещение по строке)
const DIR_RIGHT := Vector2i( 1,  0)
const DIR_LEFT  := Vector2i(-1,  0)
const DIR_DOWN  := Vector2i( 0,  1)
const DIR_UP    := Vector2i( 0, -1)

const SOURCE_DIR := Vector2i(1, 0)   # лазер из SOURCE стреляет вправо

# ── Runtime-переменные ────────────────────────────────────────────────────────
var grid: Array = []            # grid[row][col] → CellType int
var rotatable: Dictionary = {}  # ключ Vector2i(col, row) → true
var laser_line: Line2D
var laser_glow: Line2D
var win_panel: Control
var _solved := false
var _source_pos := Vector2i(0, 0)  # x = col, y = row


# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_puzzle()              # 1. данные пазла
	_build_laser_lines()         # 2. Line2D (Node2D, не Control)
	_build_ui()                  # 3. фон, лейблы, win_panel
	_redraw_laser()              # 4. лазер
	queue_redraw()               # 5. перерисовка _draw()
	_create_all_touch_buttons()  # 6. ПОСЛЕДНИМ — кнопки поверх всего


# ── Инициализация пазла ───────────────────────────────────────────────────────

## Заполняет сетку и словарь вращаемых зеркал.
##
## Маршрут решения (все вращаемые в MIRROR_135 "\"):
##   SOURCE(0,0) →R→ \(2,0) ↓D→ \(2,2)fixed →R→ \(4,2) ↓D→ \(4,4) →R→ TARGET(5,4) ✓
##
## Начальное положение: все 3 вращаемых = MIRROR_45 "/"
##   Лазер сразу уходит вверх из (2,0) и покидает поле — пазл не решён.
func _setup_puzzle() -> void:
	grid.clear()
	for r in GRID_ROWS:
		var row_arr := []
		for c in GRID_COLS:
			row_arr.append(CellType.EMPTY)
		grid.append(row_arr)

	# Фиксированные ячейки
	grid[0][0] = CellType.SOURCE
	_source_pos  = Vector2i(0, 0)

	grid[1][1] = CellType.WALL           # декоративная стена, блокирует ложный путь

	grid[2][2] = CellType.MIRROR_135     # фиксированное \ зеркало (не вращается)

	grid[4][5] = CellType.TARGET

	# Вращаемые зеркала — изначально в неправильном положении (MIRROR_45 "/")
	var rot_positions := [Vector2i(2, 0), Vector2i(4, 2), Vector2i(4, 4)]
	for key in rot_positions:
		grid[key.y][key.x] = CellType.MIRROR_45   # key.x = col, key.y = row
		rotatable[key] = true


# ── Лазер ─────────────────────────────────────────────────────────────────────

## Создаём два Line2D: широкое свечение + тонкий яркий луч
func _build_laser_lines() -> void:
	laser_glow = Line2D.new()
	laser_glow.name = "LaserGlow"
	laser_glow.default_color = Color(0.0, 1.0, 0.8, 0.20)
	laser_glow.width = 14.0
	laser_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_glow.end_cap_mode   = Line2D.LINE_CAP_ROUND
	add_child(laser_glow)

	laser_line = Line2D.new()
	laser_line.name = "LaserLine"
	laser_line.default_color = Color(0.0, 1.0, 0.8, 1.0)
	laser_line.width = 4.0
	laser_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	add_child(laser_line)


## Трассирует луч по текущему состоянию сетки и обновляет Line2D
func _redraw_laser() -> void:
	var points: Array[Vector2] = []
	var cur := _source_pos   # x = col, y = row
	var dir := SOURCE_DIR
	var hit := false

	points.append(_cell_center(cur.x, cur.y))

	for _i in MAX_STEPS:
		var nc := cur.x + dir.x
		var nr := cur.y + dir.y

		# Луч вышел за пределы сетки
		if nc < 0 or nc >= GRID_COLS or nr < 0 or nr >= GRID_ROWS:
			points.append(_cell_center(nc, nr))
			break

		cur = Vector2i(nc, nr)
		points.append(_cell_center(cur.x, cur.y))

		var ctype: int = grid[cur.y][cur.x]

		match ctype:
			CellType.WALL:
				break

			CellType.TARGET:
				hit = true
				break

			CellType.MIRROR_45:
				# "/": RIGHT→UP, UP→RIGHT, LEFT→DOWN, DOWN→LEFT
				if   dir == DIR_RIGHT: dir = DIR_UP
				elif dir == DIR_UP:    dir = DIR_RIGHT
				elif dir == DIR_LEFT:  dir = DIR_DOWN
				elif dir == DIR_DOWN:  dir = DIR_LEFT

			CellType.MIRROR_135:
				# "\": RIGHT→DOWN, DOWN→RIGHT, LEFT→UP, UP→LEFT
				if   dir == DIR_RIGHT: dir = DIR_DOWN
				elif dir == DIR_DOWN:  dir = DIR_RIGHT
				elif dir == DIR_LEFT:  dir = DIR_UP
				elif dir == DIR_UP:    dir = DIR_LEFT

	laser_line.clear_points()
	laser_glow.clear_points()
	for p in points:
		laser_line.add_point(p)
		laser_glow.add_point(p)

	if hit and not _solved:
		_on_win()


## Возвращает центр ячейки в мировых координатах
func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		GRID_OX + col * STEP + CELL_SIZE * 0.5,
		GRID_OY + row * STEP + CELL_SIZE * 0.5
	)


# ── Интерфейс ─────────────────────────────────────────────────────────────────

## Создаём заголовок, подсказку, кнопку выхода и панель победы
## Фон рисуется в _draw() — до рендера дочерних узлов
func _build_ui() -> void:
	# Заголовок
	var title := Label.new()
	title.text = "ПЕРЕНАПРАВЬТЕ ЛУЧ К ЦЕЛИ"
	title.position = Vector2(290, 20)
	title.size = Vector2(700, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Подсказка
	var hint := Label.new()
	hint.text = "Нажми на зеркало со светлой рамкой, чтобы повернуть его"
	hint.position = Vector2(240, 62)
	hint.size = Vector2(800, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# Кнопка выхода ✕
	var exit_btn := Button.new()
	exit_btn.text = "✕"
	exit_btn.position = Vector2(1215, 8)
	exit_btn.size = Vector2(55, 42)
	exit_btn.add_theme_font_size_override("font_size", 22)
	exit_btn.pressed.connect(_on_exit)
	add_child(exit_btn)

	# ── Панель победы ──────────────────────────────────────────────────────
	win_panel = Control.new()
	win_panel.name = "WinPanel"
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.visible = false
	win_panel.z_index = 10
	add_child(win_panel)

	# Затемнение фона
	var win_bg := ColorRect.new()
	win_bg.color = Color(0, 0, 0, 0.78)
	win_bg.size = Vector2(1280, 720)
	win_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(win_bg)

	# Карточка
	var card := ColorRect.new()
	card.position = Vector2(340, 240)
	card.size = Vector2(600, 220)
	card.color = Color(0.051, 0.106, 0.165, 1.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(card)

	# Текст победы
	var win_lbl := Label.new()
	win_lbl.text = "СИСТЕМА АКТИВИРОВАНА"
	win_lbl.position = Vector2(300, 268)
	win_lbl.size = Vector2(680, 60)
	win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_lbl.add_theme_font_size_override("font_size", 36)
	win_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 1.0))
	win_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(win_lbl)

	# Иконка
	var wicon := Label.new()
	wicon.text = "◉"
	wicon.position = Vector2(300, 325)
	wicon.size = Vector2(680, 60)
	wicon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wicon.add_theme_font_size_override("font_size", 50)
	wicon.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4, 1.0))
	wicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(wicon)

	# Кнопка «Закрыть»
	var close_btn := Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.position = Vector2(440, 390)
	close_btn.size = Vector2(400, 60)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_on_exit)
	win_panel.add_child(close_btn)


## Создаём невидимые Button-узлы поверх каждой вращаемой ячейки.
## Вызывается ПОСЛЕДНИМ в _ready() — кнопки должны быть поверх всех других узлов.
func _create_all_touch_buttons() -> void:
	for pos2i in rotatable.keys():
		var col: int = pos2i.x
		var row: int = pos2i.y
		var btn := Button.new()
		btn.position = Vector2(GRID_OX + col * STEP, GRID_OY + row * STEP)
		btn.size = Vector2(CELL_SIZE, CELL_SIZE)
		btn.flat = true
		btn.modulate.a = 0.0                        # полностью прозрачная
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_cell_tapped.bind(col, row))
		add_child(btn)


# ── Обработка нажатий ─────────────────────────────────────────────────────────

## Переключаем зеркало и перерисовываем
func _on_cell_tapped(col: int, row: int) -> void:
	if _solved:
		return
	var cur: int = grid[row][col]
	if cur == CellType.MIRROR_45:
		grid[row][col] = CellType.MIRROR_135
	elif cur == CellType.MIRROR_135:
		grid[row][col] = CellType.MIRROR_45
	else:
		return
	queue_redraw()
	_redraw_laser()


# ── Победа и выход ────────────────────────────────────────────────────────────

## Вспышка лазера → пауза → панель победы + сигнал родителю
func _on_win() -> void:
	_solved = true
	var tw := create_tween()
	tw.tween_property(laser_line, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.10)
	tw.tween_property(laser_line, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.30)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	win_panel.visible = true
	emit_signal("puzzle_solved")


## Закрывает мини-игру (кнопка ✕ и кнопка «Закрыть»)
func _on_exit() -> void:
	emit_signal("minigame_closed")


# ── Процедурная отрисовка ─────────────────────────────────────────────────────

## Рисует фон сцены и все ячейки сетки.
## _draw() вызывается ДО рендера дочерних узлов (Labels, Buttons) — они будут поверх.
func _draw() -> void:
	# Фон сцены
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.039, 0.055, 0.102, 1.0))

	# Рамка вокруг всей сетки
	var grid_w := GRID_COLS * STEP - CELL_GAP
	var grid_h := GRID_ROWS * STEP - CELL_GAP
	draw_rect(
		Rect2(GRID_OX - 3, GRID_OY - 3, grid_w + 6, grid_h + 6),
		Color(0.0, 0.8, 1.0, 0.25),
		false, 2.0
	)

	for row in GRID_ROWS:
		for col in GRID_COLS:
			_draw_cell(col, row)


## Рисует одну ячейку: фон, рамку и содержимое
func _draw_cell(col: int, row: int) -> void:
	var tl     := Vector2(GRID_OX + col * STEP, GRID_OY + row * STEP)
	var center := tl + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	var ctype: int  = grid[row][col]
	var is_rot: bool = rotatable.has(Vector2i(col, row))

	# Цвет фона ячейки
	var bg_color: Color
	match ctype:
		CellType.SOURCE:
			bg_color = Color(0.051, 0.180, 0.102, 1.0)
		CellType.TARGET:
			bg_color = Color(0.180, 0.086, 0.020, 1.0)
		CellType.WALL:
			bg_color = Color(0.180, 0.060, 0.060, 1.0)
		CellType.MIRROR_45, CellType.MIRROR_135:
			if is_rot:
				bg_color = Color(0.051, 0.118, 0.220, 1.0)   # синеватый — вращаемое
			else:
				bg_color = Color(0.051, 0.086, 0.157, 1.0)   # обычный синий — фиксированное
		_:
			bg_color = Color(0.063, 0.086, 0.141, 1.0)

	draw_rect(Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), bg_color)

	# Рамка ячейки
	if is_rot:
		draw_rect(Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.0, 0.8, 1.0, 0.75), false, 3.0)
	else:
		draw_rect(Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.165, 0.251, 0.439, 1.0), false, 1.5)

	# Содержимое
	match ctype:
		CellType.WALL:
			_draw_wall(tl, center)
		CellType.SOURCE:
			_draw_source(tl, center)
		CellType.TARGET:
			_draw_target(tl, center)
		CellType.MIRROR_45:
			_draw_mirror(tl, center, true)
			if is_rot:
				_draw_rotate_icon(tl)
		CellType.MIRROR_135:
			_draw_mirror(tl, center, false)
			if is_rot:
				_draw_rotate_icon(tl)


## Стена: узор X
func _draw_wall(_tl: Vector2, center: Vector2) -> void:
	var half := 34.0
	var c := Color(0.416, 0.188, 0.188, 1.0)
	draw_line(center + Vector2(-half, -half), center + Vector2( half,  half), c, 5.0, true)
	draw_line(center + Vector2( half, -half), center + Vector2(-half,  half), c, 5.0, true)


## Источник лазера: светящийся круг + стрелка вправо
func _draw_source(_tl: Vector2, center: Vector2) -> void:
	draw_circle(center, 26.0, Color(0.0, 0.867, 0.267, 0.25))
	draw_circle(center, 18.0, Color(0.0, 0.867, 0.267, 1.0))
	draw_circle(center,  7.0, Color(0.8,  1.0,  0.8,  1.0))
	# Стрелка вправо
	var ax := center + Vector2(22.0, 0.0)
	var bx := center + Vector2(36.0, 0.0)
	draw_line(ax, bx, Color(1.0, 1.0, 1.0, 1.0), 3.0, true)
	draw_line(bx, bx + Vector2(-7.0, -5.0), Color(1.0, 1.0, 1.0, 1.0), 2.5, true)
	draw_line(bx, bx + Vector2(-7.0,  5.0), Color(1.0, 1.0, 1.0, 1.0), 2.5, true)


## Цель: концентрические кольца (мишень)
func _draw_target(_tl: Vector2, center: Vector2) -> void:
	draw_circle(center, 34.0, Color(0.502, 0.188, 0.0,  1.0))
	draw_circle(center, 24.0, Color(1.0,  0.267, 0.0,  1.0))
	draw_circle(center, 15.0, Color(1.0,  0.400, 0.0,  1.0))
	draw_circle(center,  6.0, Color(1.0,  0.733, 0.0,  1.0))


## Зеркало: диагональная линия со свечением и бликом
## is_45=true → "/" (MIRROR_45), is_45=false → "\" (MIRROR_135)
func _draw_mirror(tl: Vector2, _center: Vector2, is_45: bool) -> void:
	var pad := 15.0
	var p1: Vector2
	var p2: Vector2
	if is_45:
		p1 = tl + Vector2(pad,             CELL_SIZE - pad)   # нижний-левый
		p2 = tl + Vector2(CELL_SIZE - pad, pad)               # верхний-правый
	else:
		p1 = tl + Vector2(pad,             pad)               # верхний-левый
		p2 = tl + Vector2(CELL_SIZE - pad, CELL_SIZE - pad)   # нижний-правый

	draw_line(p1, p2, Color(0.533, 0.8, 1.0, 0.30), 10.0, true)   # свечение
	draw_line(p1, p2, Color(0.533, 0.8, 1.0, 1.0),   5.0, true)   # основная линия
	# Блик
	var perp := (p2 - p1).normalized().rotated(PI * 0.5) * 2.5
	var m1 := p1 + (p2 - p1) * 0.3 + perp
	var m2 := p1 + (p2 - p1) * 0.7 + perp
	draw_line(m1, m2, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)


## Иконка «можно повернуть»: дуга со стрелкой в правом верхнем углу ячейки
func _draw_rotate_icon(tl: Vector2) -> void:
	var ic := tl + Vector2(CELL_SIZE - 14.0, 14.0)
	var r := 7.0
	var color := Color(0.0, 0.8, 1.0, 0.9)
	draw_arc(ic, r, 0.5, TAU - 0.4, 18, color, 2.0)
	# Стрелка на конце дуги
	var end_a := TAU - 0.4
	var ep    := ic + Vector2(cos(end_a), sin(end_a)) * r
	var tang  := Vector2(-sin(end_a), cos(end_a)).normalized() * 5.0
	draw_line(ep, ep + tang + Vector2(-3.0, -2.0), color, 1.5)
	draw_line(ep, ep + tang + Vector2( 3.0, -2.0), color, 1.5)
