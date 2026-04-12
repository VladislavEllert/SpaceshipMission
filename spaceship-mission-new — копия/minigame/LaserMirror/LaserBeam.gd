## LaserBeam.gd
## Логика трассировки и отрисовки лазерного луча.
## Прикрепляется к LaserLayer (Node2D). Использует Line2D для визуализации.
extends Node2D

# Максимальное количество шагов трассировки (защита от зацикливания)
const MAX_STEPS := 50

# Константы направлений
const DIR_RIGHT  := Vector2i( 1,  0)
const DIR_LEFT   := Vector2i(-1,  0)
const DIR_DOWN   := Vector2i( 0,  1)
const DIR_UP     := Vector2i( 0, -1)

# Внутренние Line2D для основного луча и свечения
var _beam_line: Line2D
var _glow_line: Line2D


func _ready() -> void:
	_build_lines()


## Создаём два Line2D: широкий полупрозрачный (свечение) и тонкий яркий (луч)
func _build_lines() -> void:
	# --- Свечение (рисуется первым, под основным лучом) ---
	_glow_line = Line2D.new()
	_glow_line.name = "GlowLine"
	_glow_line.default_color = Color(0.0, 1.0, 1.0, 0.25)
	_glow_line.width = 18.0
	_glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow_line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	add_child(_glow_line)

	# --- Основной луч ---
	_beam_line = Line2D.new()
	_beam_line.name = "BeamLine"
	_beam_line.default_color = Color(0.0, 1.0, 1.0, 1.0)
	_beam_line.width = 6.0
	_beam_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	add_child(_beam_line)


## Трассирует луч по сетке и возвращает (points, reached_target).
## grid       — двумерный массив CellType (Array[Array])
## start_cell — стартовая позиция в координатах сетки (col, row)
## start_dir  — начальное направление (Vector2i)
## cell_size  — размер ячейки в px
## gap        — зазор между ячейками в px
## grid_origin— мировая позиция центра ячейки (0,0)
func trace(
	grid: Array,
	start_cell: Vector2i,
	start_dir: Vector2i,
	cell_size: float,
	gap: float,
	grid_origin: Vector2
) -> Dictionary:

	var points: Array[Vector2] = []
	var reached_target := false

	var pos  := start_cell   # текущая позиция в ячейках
	var dir  := start_dir    # текущее направление
	var rows: int = grid.size()
	var cols: int = grid[0].size() if rows > 0 else 0
	var step_size := cell_size + gap  # шаг в мировых координатах

	# Добавляем стартовую точку (центр ячейки-источника)
	points.append(_cell_to_world(pos, cell_size, gap, grid_origin))

	for _i in range(MAX_STEPS):
		# Делаем один шаг в текущем направлении
		pos = pos + dir

		# Луч вышел за пределы сетки
		if pos.x < 0 or pos.x >= cols or pos.y < 0 or pos.y >= rows:
			# Добавляем точку за краем, чтобы луч "упирался" в стену
			points.append(points[-1] + Vector2(dir) * step_size)
			break

		var world_pt := _cell_to_world(pos, cell_size, gap, grid_origin)
		points.append(world_pt)

		# Получаем тип текущей ячейки (enum int)
		var cell_val: int = grid[pos.y][pos.x]

		match cell_val:
			4:  # TARGET
				reached_target = true
				break

			5:  # WALL
				break  # луч останавливается

			1:  # MIRROR_45  /
				dir = _reflect_45(dir)

			2:  # MIRROR_135  \
				dir = _reflect_135(dir)

			_:
				pass  # EMPTY или SOURCE — луч идёт дальше

	return { "points": points, "reached_target": reached_target }


## Применяет трассировку и обновляет Line2D
func update_beam(
	grid: Array,
	start_cell: Vector2i,
	start_dir: Vector2i,
	cell_size: float,
	gap: float,
	grid_origin: Vector2
) -> bool:

	var result := trace(grid, start_cell, start_dir, cell_size, gap, grid_origin)
	var pts: Array[Vector2] = result["points"]

	# Передаём точки в оба Line2D
	_beam_line.clear_points()
	_glow_line.clear_points()
	for p in pts:
		_beam_line.add_point(p)
		_glow_line.add_point(p)

	return result["reached_target"]


## Очищает луч (например, до загрузки уровня)
func clear_beam() -> void:
	if _beam_line:
		_beam_line.clear_points()
	if _glow_line:
		_glow_line.clear_points()


# ---------------------------------------------------------------------------
# Вспомогательные методы
# ---------------------------------------------------------------------------

## Преобразует координаты ячейки (col, row) в мировые координаты центра
func _cell_to_world(cell: Vector2i, cell_size: float, gap: float, origin: Vector2) -> Vector2:
	var step := cell_size + gap
	return origin + Vector2(cell.x * step, cell.y * step)


## Отражение для зеркала MIRROR_45 (/)
## UP→RIGHT, RIGHT→UP, DOWN→LEFT, LEFT→DOWN
func _reflect_45(dir: Vector2i) -> Vector2i:
	match dir:
		DIR_RIGHT: return DIR_UP
		DIR_LEFT:  return DIR_DOWN
		DIR_UP:    return DIR_RIGHT
		DIR_DOWN:  return DIR_LEFT
		_:         return dir


## Отражение для зеркала MIRROR_135 (\)
## UP→LEFT, LEFT→UP, DOWN→RIGHT, RIGHT→DOWN
func _reflect_135(dir: Vector2i) -> Vector2i:
	match dir:
		DIR_RIGHT: return DIR_DOWN
		DIR_LEFT:  return DIR_UP
		DIR_UP:    return DIR_LEFT
		DIR_DOWN:  return DIR_RIGHT
		_:         return dir
