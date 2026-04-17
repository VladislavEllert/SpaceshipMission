extends Polygon2D

# Мигающая красная подсказка поверх произвольной формы (Polygon2D).
# Пульсирует полупрозрачно-красным, пока игрок не кликнет внутри полигона —
# после первого клика плавно гаснет и больше не появляется (состояние
# сохраняется через GameState.room4_polygon_clicked).
#
# Клик НЕ поглощается: если под полигоном лежит кнопка/интерактив —
# она тоже получит своё событие.

const BLINK_ALPHA_LOW:  float = 0.05
const BLINK_ALPHA_HIGH: float = 0.35
const BLINK_PERIOD:     float = 0.9   # период фазы разгорания / угасания
const FADE_OUT_DURATION: float = 0.4

var _tween: Tween = null
var _clicked: bool = false

func _ready() -> void:
	color = Color(1.0, 0.1, 0.1, BLINK_ALPHA_LOW)
	if GameState.room4_polygon_clicked:
		_clicked = true
		color.a = 0.0
		return
	_start_blink()

func _start_blink() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_loops()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "color:a", BLINK_ALPHA_HIGH, BLINK_PERIOD)
	_tween.tween_property(self, "color:a", BLINK_ALPHA_LOW,  BLINK_PERIOD)

func _input(event: InputEvent) -> void:
	if _clicked:
		return
	if polygon.size() < 3:
		return
	var is_press: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		is_press = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		pos = event.position
	elif event is InputEventScreenTouch:
		is_press = event.pressed
		pos = event.position
	else:
		return
	if not is_press:
		return
	# Переводим координату клика в локальную систему полигона
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * pos
	if Geometry2D.is_point_in_polygon(local_pos, polygon):
		_on_first_click()

func _on_first_click() -> void:
	_clicked = true
	GameState.room4_polygon_clicked = true
	GameState.save()
	if _tween:
		_tween.kill()
		_tween = null
	var fade := create_tween()
	fade.set_ease(Tween.EASE_OUT)
	fade.set_trans(Tween.TRANS_SINE)
	fade.tween_property(self, "color:a", 0.0, FADE_OUT_DURATION)
