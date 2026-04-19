extends Node2D

# Размер сетки — задаётся из panel_4.gd чтобы совпадать с экраном
var grid_w: float = 490.0
var grid_h: float = 400.0
const GRID_COLS: int = 9
const GRID_ROWS: int = 6
const GRID_COLOR: Color = Color(0.2, 1.0, 0.05, 0.8)
const LINE_WIDTH: float = 1.5

func set_grid_size(w: float, h: float) -> void:
	grid_w = w
	grid_h = h
	queue_redraw()

func _draw() -> void:
	var cell_w := grid_w / GRID_COLS
	var cell_h := grid_h / GRID_ROWS

	# Вертикальные линии
	for i in range(GRID_COLS + 1):
		var x := i * cell_w
		draw_line(Vector2(x, 0), Vector2(x, grid_h), GRID_COLOR, LINE_WIDTH)

	# Горизонтальные линии
	for i in range(GRID_ROWS + 1):
		var y := i * cell_h
		draw_line(Vector2(0, y), Vector2(grid_w, y), GRID_COLOR, LINE_WIDTH)
