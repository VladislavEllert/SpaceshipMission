extends Node2D

signal puzzle_solved
signal puzzle_exit

const GRID_COLS : int = 5
const GRID_ROWS : int = 5
const CELL_SIZE : int = 100
const GRID_OFFSET_X : int = 390
const GRID_OFFSET_Y : int = 110

const COLOR_NONE   : int = 0
const COLOR_RED    : int = 1
const COLOR_BLUE   : int = 2
const COLOR_GREEN  : int = 3
const COLOR_YELLOW : int = 4
const COLOR_PURPLE : int = 5

var COLORS : Dictionary = {
	1: Color(0.0,  0.88, 0.82),   # бирюзовый
	2: Color(0.30, 0.62, 1.0),    # голубой
	3: Color(0.68, 0.76, 0.88),   # серебристо-серый
	4: Color(0.55, 0.42, 1.0),    # лавандово-фиолетовый
	5: Color(0.12, 0.92, 0.68),   # мятно-зелёный
}

var DOTS : Array = [
	[0, 0, 1], [4, 0, 1],
	[0, 1, 3], [1, 4, 3],
	[4, 1, 2], [3, 4, 2],
	[1, 1, 4], [3, 3, 4],
	[2, 4, 5], [1, 3, 5],
]

var _grid     : Array = []
var _dot_grid : Array = []
var _paths    : Dictionary = {}

var _drawing    : bool = false
var _draw_color : int  = 0

var _win_overlay : ColorRect = null
var _exit_button : TextureButton = null

# ── Инициализация ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_init_grid()

func _build_ui() -> void:
	# Кнопка выхода — та же стрелочка что во всей игре
	_exit_button = TextureButton.new()
	_exit_button.texture_normal = load("res://items/left-arrow.png")
	_exit_button.position = Vector2(105, 327)
	_exit_button.size = Vector2(50, 58)
	_exit_button.ignore_texture_size = true
	_exit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_exit_button.pressed.connect(_on_exit_pressed)
	add_child(_exit_button)

	# Заголовок
	var title := Label.new()
	title.text = "ВОССТАНОВЛЕНИЕ ЭНЕРГОЦЕПЕЙ"
	title.position = Vector2(330, 25)
	title.size = Vector2(620, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.6, 0.82, 1.0))
	add_child(title)

	# Win-оверлей — пустой невидимый, нужен только для блокировки ввода
	_win_overlay = ColorRect.new()
	_win_overlay.color = Color(0, 0, 0, 0.0)
	_win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_overlay.visible = false
	add_child(_win_overlay)

func _init_grid() -> void:
	_grid     = []
	_dot_grid = []
	_paths    = {}
	for r in range(GRID_ROWS):
		_grid.append([])
		_dot_grid.append([])
		for _c in range(GRID_COLS):
			_grid[r].append(0)
			_dot_grid[r].append(0)
	for dot in DOTS:
		_dot_grid[dot[1]][dot[0]] = dot[2]

# ── Ввод ───────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _win_overlay.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cell : Vector2i = _cell_at(event.position)
			if cell.x < 0:
				return
			var dot_c : int = _dot_grid[cell.y][cell.x]
			if dot_c != 0:
				_start_draw(cell, dot_c)
		else:
			_stop_draw()
	elif event is InputEventMouseMotion and _drawing:
		var cell : Vector2i = _cell_at(event.position)
		if cell.x >= 0:
			_extend_draw(cell)

func _cell_at(pos: Vector2) -> Vector2i:
	var lx : float = pos.x - GRID_OFFSET_X
	var ly : float = pos.y - GRID_OFFSET_Y
	var col : int = int(lx / CELL_SIZE)
	var row : int = int(ly / CELL_SIZE)
	if col >= 0 and col < GRID_COLS and row >= 0 and row < GRID_ROWS:
		return Vector2i(col, row)
	return Vector2i(-1, -1)

# ── Рисование пути ─────────────────────────────────────────────────────────────

func _start_draw(cell: Vector2i, color: int) -> void:
	_drawing    = true
	_draw_color = color
	_clear_color_path(color)
	_paths[color] = [[cell.x, cell.y]]
	_grid[cell.y][cell.x] = color
	queue_redraw()

func _clear_color_path(color: int) -> void:
	if color in _paths:
		for p in _paths[color]:
			if _dot_grid[p[1]][p[0]] == 0:
				_grid[p[1]][p[0]] = 0
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if _grid[r][c] == color and _dot_grid[r][c] == 0:
				_grid[r][c] = 0
	_paths.erase(color)

func _extend_draw(cell: Vector2i) -> void:
	if not _drawing or _draw_color == 0:
		return
	var path : Array = _paths.get(_draw_color, [])
	if path.is_empty():
		return

	var last : Vector2i = Vector2i(path.back()[0], path.back()[1])
	if cell == last:
		return
	if abs(cell.x - last.x) + abs(cell.y - last.y) != 1:
		return

	for i in range(path.size() - 1):
		if path[i][0] == cell.x and path[i][1] == cell.y:
			while path.size() > i + 1:
				var rem : Array = path.pop_back()
				if _dot_grid[rem[1]][rem[0]] == 0:
					_grid[rem[1]][rem[0]] = 0
			queue_redraw()
			return

	var dest_dot : int = _dot_grid[cell.y][cell.x]
	if dest_dot != 0 and dest_dot != _draw_color:
		return

	var dest_color : int = _grid[cell.y][cell.x]
	if dest_color != 0 and dest_color != _draw_color:
		_cut_path_from(dest_color, cell)

	path.append([cell.x, cell.y])
	_grid[cell.y][cell.x] = _draw_color
	queue_redraw()

func _cut_path_from(color: int, cell: Vector2i) -> void:
	if not (color in _paths):
		return
	var path : Array = _paths[color]
	for i in range(path.size()):
		if path[i][0] == cell.x and path[i][1] == cell.y:
			while path.size() > i:
				var rem : Array = path.pop_back()
				if _dot_grid[rem[1]][rem[0]] == 0:
					_grid[rem[1]][rem[0]] = 0
			return

func _stop_draw() -> void:
	_drawing    = false
	_draw_color = 0
	_check_win()

# ── Условие победы ─────────────────────────────────────────────────────────────

func _check_win() -> void:
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if _grid[r][c] == 0:
				return
	for color_id in COLORS.keys():
		var eps : Array = []
		for dot in DOTS:
			if dot[2] == color_id:
				eps.append(Vector2i(dot[0], dot[1]))
		if eps.size() != 2:
			continue
		if not _bfs_connected(color_id, eps[0], eps[1]):
			return
	_win_overlay.visible = true
	emit_signal("puzzle_solved")

func _bfs_connected(color: int, a: Vector2i, b: Vector2i) -> bool:
	var visited : Dictionary = {}
	visited[a] = true
	var queue : Array = [a]
	while not queue.is_empty():
		var cur : Vector2i = queue.pop_front()
		if cur == b:
			return true
		var dirs : Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for d in dirs:
			var nb : Vector2i = cur + d
			if nb.x >= 0 and nb.x < GRID_COLS and nb.y >= 0 and nb.y < GRID_ROWS:
				if _grid[nb.y][nb.x] == color and not (nb in visited):
					visited[nb] = true
					queue.append(nb)
	return false

# ── Выход ──────────────────────────────────────────────────────────────────────

func _on_exit_pressed() -> void:
	emit_signal("puzzle_exit")

# ── Рендеринг ─────────────────────────────────────────────────────────────────

func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		GRID_OFFSET_X + col * CELL_SIZE + CELL_SIZE * 0.5,
		GRID_OFFSET_Y + row * CELL_SIZE + CELL_SIZE * 0.5
	)

func _draw() -> void:
	var go : Vector2 = Vector2(GRID_OFFSET_X, GRID_OFFSET_Y)

	# Фон
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.04, 0.06, 0.11))

	# Панель за сеткой
	draw_rect(
		Rect2(go - Vector2(14, 14), Vector2(GRID_COLS * CELL_SIZE + 28, GRID_ROWS * CELL_SIZE + 28)),
		Color(0.08, 0.11, 0.19), true)
	draw_rect(
		Rect2(go - Vector2(14, 14), Vector2(GRID_COLS * CELL_SIZE + 28, GRID_ROWS * CELL_SIZE + 28)),
		Color(0.26, 0.38, 0.64), false, 2.5)

	# Клетки сетки
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var rect : Rect2 = Rect2(go + Vector2(c * CELL_SIZE, r * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			draw_rect(rect, Color(0.10, 0.13, 0.21), true)
			draw_rect(rect, Color(0.20, 0.26, 0.42), false, 1.0)

	# Соединения
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var cid : int = _grid[r][c]
			if cid == 0:
				continue
			var col : Color = COLORS[cid]
			var ctr : Vector2 = _cell_center(c, r)
			if c + 1 < GRID_COLS and _grid[r][c + 1] == cid:
				draw_line(ctr, _cell_center(c + 1, r), col, CELL_SIZE * 0.54)
			if r + 1 < GRID_ROWS and _grid[r + 1][c] == cid:
				draw_line(ctr, _cell_center(c, r + 1), col, CELL_SIZE * 0.54)

	# Кружки на заполненных клетках
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var cid : int = _grid[r][c]
			if cid == 0:
				continue
			draw_circle(_cell_center(c, r), CELL_SIZE * 0.27, COLORS[cid])

	# Точки-эндпоинты
	for dot in DOTS:
		var ctr : Vector2 = _cell_center(dot[0], dot[1])
		var col : Color   = COLORS[dot[2]]
		draw_circle(ctr, CELL_SIZE * 0.40, col)
		draw_circle(ctr, CELL_SIZE * 0.29, Color(0.04, 0.06, 0.11))
		draw_circle(ctr, CELL_SIZE * 0.20, col)
