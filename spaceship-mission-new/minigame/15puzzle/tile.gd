extends Button

@export var number: int = 1
@export var board_path: NodePath

var board: Node
var index_in_board: int = 0

var _touch_start: Vector2 = Vector2.ZERO
var _touch_id: int = -1

const SWIPE_MIN: float = 20.0

func _ready() -> void:
	board = get_node(board_path)
	$NumberLabel.text = str(number)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_start = event.position
			_touch_id = event.index
			accept_event()
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_try_swipe(event.position - _touch_start)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start = event.position
		else:
			_try_swipe(event.position - _touch_start)
		accept_event()

func _try_swipe(delta: Vector2) -> void:
	if delta.length() < SWIPE_MIN:
		return
	var dir: Vector2i
	if abs(delta.x) >= abs(delta.y):
		dir = Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
	else:
		dir = Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
	board.on_tile_swiped(self, dir)
