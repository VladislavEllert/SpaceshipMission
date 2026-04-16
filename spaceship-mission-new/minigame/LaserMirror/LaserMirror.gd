## LaserMirror.gd
## Мини-игра «Лазер и зеркала» — 3 уровня, процедурная отрисовка через _draw()
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
var GRID_OX   : int = 330
var GRID_OY   : int = 110
const MAX_STEPS := 80

# ── Типы ячеек ────────────────────────────────────────────────────────────────
enum CellType { EMPTY, WALL, SOURCE, TARGET, MIRROR_45, MIRROR_135 }

# Направления луча
const DIR_RIGHT := Vector2i( 1,  0)
const DIR_LEFT  := Vector2i(-1,  0)
const DIR_DOWN  := Vector2i( 0,  1)
const DIR_UP    := Vector2i( 0, -1)
const SOURCE_DIR := Vector2i(1, 0)

# ── Runtime-переменные ────────────────────────────────────────────────────────
var grid: Array = []
var rotatable: Dictionary = {}
var laser_line: Line2D
var laser_glow: Line2D
var _solved := false
var _source_pos := Vector2i(0, 0)
var _current_level: int = 1
var _level_label: Label

# ── Текстуры ─────────────────────────────────────────────────────────────────
var _tex_bg: Texture2D
var _tex_cell_bg: Texture2D
var _tex_source: Texture2D
var _tex_target: Texture2D
var _tex_mirror_45: Texture2D
var _tex_mirror_135: Texture2D
var _tex_wall: Texture2D

@onready var _exit_button: TextureButton = $Exit


# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_tex_bg         = load("res://minigame/LaserMirror/assets/laser_game_bg.png")
	_tex_cell_bg    = load("res://minigame/LaserMirror/assets/cell_bg.png")
	_tex_source     = load("res://minigame/LaserMirror/assets/laser_source.png")
	_tex_target     = load("res://minigame/LaserMirror/assets/laser_target.png")
	_tex_mirror_45  = load("res://minigame/LaserMirror/assets/mirror_45.png")
	_tex_mirror_135 = load("res://minigame/LaserMirror/assets/mirror_135.png")
	_tex_wall       = load("res://minigame/LaserMirror/assets/wall.png")

	var vp_size := get_viewport_rect().size
	GRID_OX = int((vp_size.x - GRID_COLS * STEP + CELL_GAP) / 2.0)
	GRID_OY = int((vp_size.y - GRID_ROWS * STEP + CELL_GAP) / 2.0)
	_setup_puzzle()
	_build_laser_lines()
	_build_ui()
	_redraw_laser()
	queue_redraw()
	_create_all_touch_buttons()
	if not _exit_button.pressed.is_connected(_on_exit):
		_exit_button.pressed.connect(_on_exit)


# ── Инициализация пазла ───────────────────────────────────────────────────────

func _setup_puzzle() -> void:
	grid.clear()
	for r in GRID_ROWS:
		var row_arr := []
		for c in GRID_COLS:
			row_arr.append(CellType.EMPTY)
		grid.append(row_arr)

	match _current_level:
		1: _setup_level_1()
		2: _setup_level_2()
		3: _setup_level_3()


## УРОВЕНЬ 1 (3 вращаемых зеркала, все одного типа)
## Путь: SOURCE(0,0)→R→\(2,0)→D→\(2,2)→R→\(4,2)→D→\(4,4)→R→TARGET(5,4)
func _setup_level_1() -> void:
	grid[0][0] = CellType.SOURCE
	_source_pos  = Vector2i(0, 0)

	grid[1][1] = CellType.WALL

	grid[2][2] = CellType.MIRROR_135     # фиксированное \ — не вращается

	grid[4][5] = CellType.TARGET

	# Вращаемые — изначально MIRROR_45 "/", нужно повернуть в \ все три
	for key in [Vector2i(2, 0), Vector2i(4, 2), Vector2i(4, 4)]:
		grid[key.y][key.x] = CellType.MIRROR_45
		rotatable[key] = true


## УРОВЕНЬ 2 (5 вращаемых зеркал, смешанные стартовые позиции)
## Путь: SOURCE(0,0)→R→\(1,0)→D→\(1,2)→R→/(3,2)→U→/(3,1)→R→\(5,1)→D→TARGET(5,4)
func _setup_level_2() -> void:
	grid[0][0] = CellType.SOURCE
	_source_pos  = Vector2i(0, 0)

	grid[4][5] = CellType.TARGET

	# Стены-заглушки (не на пути решения)
	grid[0][2] = CellType.WALL
	grid[2][0] = CellType.WALL
	grid[0][4] = CellType.WALL

	# Вращаемые зеркала:
	# (col=1,row=0): нужно \, старт /
	grid[0][1] = CellType.MIRROR_45
	rotatable[Vector2i(1, 0)] = true

	# (col=1,row=2): нужно \, старт /
	grid[2][1] = CellType.MIRROR_45
	rotatable[Vector2i(1, 2)] = true

	# (col=3,row=2): нужно /, старт \
	grid[2][3] = CellType.MIRROR_135
	rotatable[Vector2i(3, 2)] = true

	# (col=3,row=1): нужно /, старт \
	grid[1][3] = CellType.MIRROR_135
	rotatable[Vector2i(3, 1)] = true

	# (col=5,row=1): нужно \, старт /
	grid[1][5] = CellType.MIRROR_45
	rotatable[Vector2i(5, 1)] = true


## УРОВЕНЬ 3 (5 вращаемых + 2 фиксированных, сложный маршрут)
## Путь: SOURCE(0,0)→R→fixed\(1,0)→D→\(1,3)→R→/(4,3)→U→/(4,1)→L→\(2,1)→U→fixed/(2,0)→R→\(5,0)→D→TARGET(5,4)
func _setup_level_3() -> void:
	grid[0][0] = CellType.SOURCE
	_source_pos  = Vector2i(0, 0)

	grid[4][5] = CellType.TARGET

	# Фиксированные зеркала (не вращаются)
	grid[0][1] = CellType.MIRROR_135   # fixed \
	grid[0][2] = CellType.MIRROR_45    # fixed /

	# Стены-заглушки
	grid[3][0] = CellType.WALL
	grid[4][0] = CellType.WALL
	grid[4][3] = CellType.WALL

	# Вращаемые зеркала:
	# (col=1,row=3): нужно \, старт /
	grid[3][1] = CellType.MIRROR_45
	rotatable[Vector2i(1, 3)] = true

	# (col=4,row=3): нужно /, старт \
	grid[3][4] = CellType.MIRROR_135
	rotatable[Vector2i(4, 3)] = true

	# (col=4,row=1): нужно /, старт \
	grid[1][4] = CellType.MIRROR_135
	rotatable[Vector2i(4, 1)] = true

	# (col=2,row=1): нужно \, старт /
	grid[1][2] = CellType.MIRROR_45
	rotatable[Vector2i(2, 1)] = true

	# (col=5,row=0): нужно \, старт /
	grid[0][5] = CellType.MIRROR_45
	rotatable[Vector2i(5, 0)] = true


# ── Лазер ─────────────────────────────────────────────────────────────────────

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


func _redraw_laser() -> void:
	var points: Array[Vector2] = []
	var cur := _source_pos
	var dir := SOURCE_DIR
	var hit := false

	points.append(_cell_center(cur.x, cur.y))

	for _i in MAX_STEPS:
		var nc := cur.x + dir.x
		var nr := cur.y + dir.y

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
				if   dir == DIR_RIGHT: dir = DIR_UP
				elif dir == DIR_UP:    dir = DIR_RIGHT
				elif dir == DIR_LEFT:  dir = DIR_DOWN
				elif dir == DIR_DOWN:  dir = DIR_LEFT

			CellType.MIRROR_135:
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


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		GRID_OX + col * STEP + CELL_SIZE * 0.5,
		GRID_OY + row * STEP + CELL_SIZE * 0.5
	)


# ── Интерфейс ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var vp_size := get_viewport_rect().size

	# Плашка под надпись с уровнем
	var badge_w := 240.0
	var badge_h := 44.0
	var badge_x := (vp_size.x - badge_w) / 2.0
	var badge_y := 12.0

	var badge_bg := ColorRect.new()
	badge_bg.color = Color(0.0, 0.08, 0.20, 0.88)
	badge_bg.position = Vector2(badge_x, badge_y)
	badge_bg.size = Vector2(badge_w, badge_h)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_bg)

	# Рамка плашки через Panel + StyleBoxFlat
	var badge_border := Panel.new()
	badge_border.position = Vector2(badge_x, badge_y)
	badge_border.size = Vector2(badge_w, badge_h)
	badge_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.0, 0.85, 1.0, 0.85)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	badge_border.add_theme_stylebox_override("panel", style)
	add_child(badge_border)

	_level_label = Label.new()
	_level_label.text = _level_text()
	_level_label.position = Vector2(badge_x, badge_y + 4.0)
	_level_label.size = Vector2(badge_w, badge_h - 4.0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)


func _level_text() -> String:
	return "УРОВЕНЬ  %d / 3" % _current_level


func _create_all_touch_buttons() -> void:
	for pos2i in rotatable.keys():
		var col: int = pos2i.x
		var row: int = pos2i.y
		var btn := Button.new()
		btn.position = Vector2(GRID_OX + col * STEP, GRID_OY + row * STEP)
		btn.size = Vector2(CELL_SIZE, CELL_SIZE)
		btn.flat = true
		btn.modulate.a = 0.0
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_cell_tapped.bind(col, row))
		add_child(btn)


# ── Обработка нажатий ─────────────────────────────────────────────────────────

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


# ── Победа и переход между уровнями ──────────────────────────────────────────

func _on_win() -> void:
	_solved = true
	var tw := create_tween()
	tw.tween_property(laser_line, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.10)
	tw.tween_property(laser_line, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.30)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	if _current_level < 3:
		_current_level += 1
		_load_next_level()
	else:
		emit_signal("puzzle_solved")


## Переход на следующий уровень без перезапуска сцены
func _load_next_level() -> void:
	_solved = false

	# Удаляем кнопки текущего уровня
	for child in get_children():
		if child is Button:
			child.queue_free()

	# Сбрасываем данные
	rotatable.clear()
	_setup_puzzle()

	# Обновляем метку уровня
	if _level_label:
		_level_label.text = _level_text()

	# Ждём один кадр (чтобы queue_free отработал)
	await get_tree().process_frame

	_redraw_laser()
	queue_redraw()
	_create_all_touch_buttons()


func _on_exit() -> void:
	emit_signal("minigame_closed")


# ── Процедурная отрисовка ─────────────────────────────────────────────────────

func _draw() -> void:
	var vp_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	if _tex_bg:
		draw_texture_rect(_tex_bg, vp_rect, false)
	else:
		draw_rect(vp_rect, Color(0.039, 0.055, 0.102, 1.0))

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


func _draw_cell(col: int, row: int) -> void:
	var tl     := Vector2(GRID_OX + col * STEP, GRID_OY + row * STEP)
	var center := tl + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	var ctype: int  = grid[row][col]
	var is_rot: bool = rotatable.has(Vector2i(col, row))
	var cell_rect := Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE))

	if _tex_cell_bg:
		draw_texture_rect(_tex_cell_bg, cell_rect, false)
	else:
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
					bg_color = Color(0.051, 0.118, 0.220, 1.0)
				else:
					bg_color = Color(0.051, 0.086, 0.157, 1.0)
			_:
				bg_color = Color(0.063, 0.086, 0.141, 1.0)
		draw_rect(cell_rect, bg_color)

	if is_rot:
		draw_rect(cell_rect, Color(0.0, 0.8, 1.0, 0.75), false, 3.0)
	else:
		draw_rect(cell_rect, Color(0.165, 0.251, 0.439, 1.0), false, 1.5)

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


func _draw_wall(tl: Vector2, center: Vector2) -> void:
	if _tex_wall:
		draw_texture_rect(_tex_wall, Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		var half := 34.0
		var c := Color(0.416, 0.188, 0.188, 1.0)
		draw_line(center + Vector2(-half, -half), center + Vector2( half,  half), c, 5.0, true)
		draw_line(center + Vector2( half, -half), center + Vector2(-half,  half), c, 5.0, true)


func _draw_source(tl: Vector2, center: Vector2) -> void:
	if _tex_source:
		draw_texture_rect(_tex_source, Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		draw_circle(center, 26.0, Color(0.0, 0.867, 0.267, 0.25))
		draw_circle(center, 18.0, Color(0.0, 0.867, 0.267, 1.0))
		draw_circle(center,  7.0, Color(0.8,  1.0,  0.8,  1.0))
		var ax := center + Vector2(22.0, 0.0)
		var bx := center + Vector2(36.0, 0.0)
		draw_line(ax, bx, Color(1.0, 1.0, 1.0, 1.0), 3.0, true)
		draw_line(bx, bx + Vector2(-7.0, -5.0), Color(1.0, 1.0, 1.0, 1.0), 2.5, true)
		draw_line(bx, bx + Vector2(-7.0,  5.0), Color(1.0, 1.0, 1.0, 1.0), 2.5, true)


func _draw_target(tl: Vector2, center: Vector2) -> void:
	if _tex_target:
		draw_texture_rect(_tex_target, Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		draw_circle(center, 34.0, Color(0.502, 0.188, 0.0,  1.0))
		draw_circle(center, 24.0, Color(1.0,  0.267, 0.0,  1.0))
		draw_circle(center, 15.0, Color(1.0,  0.400, 0.0,  1.0))
		draw_circle(center,  6.0, Color(1.0,  0.733, 0.0,  1.0))


func _draw_mirror(tl: Vector2, center: Vector2, is_45: bool) -> void:
	var tex := _tex_mirror_45 if is_45 else _tex_mirror_135
	if tex:
		draw_texture_rect(tex, Rect2(tl, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		var pad := 15.0
		var p1: Vector2
		var p2: Vector2
		if is_45:
			p1 = tl + Vector2(pad,             CELL_SIZE - pad)
			p2 = tl + Vector2(CELL_SIZE - pad, pad)
		else:
			p1 = tl + Vector2(pad,             pad)
			p2 = tl + Vector2(CELL_SIZE - pad, CELL_SIZE - pad)
		draw_line(p1, p2, Color(0.533, 0.8, 1.0, 0.30), 10.0, true)
		draw_line(p1, p2, Color(0.533, 0.8, 1.0, 1.0),   5.0, true)
		var perp := (p2 - p1).normalized().rotated(PI * 0.5) * 2.5
		var m1 := p1 + (p2 - p1) * 0.3 + perp
		var m2 := p1 + (p2 - p1) * 0.7 + perp
		draw_line(m1, m2, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)


func _draw_rotate_icon(tl: Vector2) -> void:
	var ic := tl + Vector2(CELL_SIZE - 14.0, 14.0)
	var r := 7.0
	var color := Color(0.0, 0.8, 1.0, 0.9)
	draw_arc(ic, r, 0.5, TAU - 0.4, 18, color, 2.0)
	var end_a := TAU - 0.4
	var ep    := ic + Vector2(cos(end_a), sin(end_a)) * r
	var tang  := Vector2(-sin(end_a), cos(end_a)).normalized() * 5.0
	draw_line(ep, ep + tang + Vector2(-3.0, -2.0), color, 1.5)
	draw_line(ep, ep + tang + Vector2( 3.0, -2.0), color, 1.5)
