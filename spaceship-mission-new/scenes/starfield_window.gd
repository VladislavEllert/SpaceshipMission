extends Node2D

# Процедурная параллаксная звёздная панорама.
# Форма окна задаётся через polygon у родителя (Polygon2D).
# Звёзды автоматически вписываются в форму: область спавна = bounding box
# полигона, при отрисовке каждая звезда проверяется на попадание внутрь формы.
# Это значит — можешь редактировать вершины Polygon2D прямо в редакторе Godot
# (иллюминатор, трапеция, шестиугольник и т.д.), и звёзды подстроятся сами.

@export var star_count: int = 90

var _polygon: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2(0, 0, 420, 240)
var _stars: Array = []

func _ready() -> void:
	randomize()
	_recalc_from_parent()
	_spawn_stars()

func _recalc_from_parent() -> void:
	var parent := get_parent()
	if parent is Polygon2D and parent.polygon.size() >= 3:
		_polygon = parent.polygon
		var minp := _polygon[0]
		var maxp := _polygon[0]
		for p in _polygon:
			minp.x = min(minp.x, p.x)
			minp.y = min(minp.y, p.y)
			maxp.x = max(maxp.x, p.x)
			maxp.y = max(maxp.y, p.y)
		_bounds = Rect2(minp, maxp - minp)

func _spawn_stars() -> void:
	_stars.clear()
	for i in star_count:
		_stars.append(_make_star())

func _make_star() -> Dictionary:
	var layer: int = randi() % 3
	var speed: float
	var radius: float
	var brightness: float
	match layer:
		0:
			speed      = randf_range(2.0, 4.0)
			radius     = randf_range(0.6, 1.1)
			brightness = randf_range(0.25, 0.50)
		1:
			speed      = randf_range(5.0, 9.0)
			radius     = randf_range(1.0, 1.7)
			brightness = randf_range(0.50, 0.80)
		_:
			speed      = randf_range(10.0, 15.0)
			radius     = randf_range(1.4, 2.3)
			brightness = randf_range(0.80, 1.00)
	var x: float = _bounds.position.x + randf() * _bounds.size.x
	var y: float = _bounds.position.y + randf() * _bounds.size.y
	return {"pos": Vector2(x, y), "r": radius, "b": brightness, "s": speed}

func _process(delta: float) -> void:
	for s in _stars:
		s["pos"].x -= s["s"] * delta
		if s["pos"].x < _bounds.position.x - 3.0:
			s["pos"].x = _bounds.position.x + _bounds.size.x + 3.0
			s["pos"].y = _bounds.position.y + randf() * _bounds.size.y
	queue_redraw()

func _draw() -> void:
	if _polygon.size() < 3:
		return
	for s in _stars:
		# Рисуем звезду только если её центр внутри полигона окна.
		# Polygon2D сам закрашивает свою форму — stars-Node2D отрисовывает
		# поверх, а фильтр обрезает круги по форме.
		if Geometry2D.is_point_in_polygon(s["pos"], _polygon):
			draw_circle(s["pos"], s["r"], Color(1.0, 1.0, 1.0, s["b"]))
