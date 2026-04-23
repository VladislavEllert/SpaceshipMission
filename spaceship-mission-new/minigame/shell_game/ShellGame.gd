## ShellGame.gd
## Mini-game "Find the Chip" (Shell Game) — 3 levels, arc-swap animation
## Godot 4.4 | touch + mouse | landscape 1280×720
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────
signal minigame_completed(success: bool, difficulty: int)
signal minigame_cancelled()

# ── Enums ─────────────────────────────────────────────────────────────────────
enum Phase { IDLE, SHOW_ITEM, HIDE_ITEM, SHUFFLE, WAIT_FOR_CLICK, REVEAL }

# ── Config ────────────────────────────────────────────────────────────────────
# Количество перестановок и контейнеров по уровням
const SWAP_COUNTS      := [8, 12, 16]
const CONTAINER_COUNTS := [4,  5,  6]
const SWAP_DURATION: float = 0.35

const CONTAINER_SIZE := Vector2(360.0, 220.0)
const CONTAINER_HALF := Vector2(180.0, 110.0)
const CHIP_SIZE      := Vector2(100.0,  80.0)
const GRID_GAP_X     := 28.0
const GRID_GAP_Y     := 40.0
const ARC_HEIGHT     := 80.0
const LIFT_HEIGHT    := -90.0
const LIFT_DUR       := 0.4

# ── Level state ───────────────────────────────────────────────────────────────
var _level: int         = 1
var container_count: int = 4   # обновляется при смене уровня

# ── Game state ────────────────────────────────────────────────────────────────
var current_phase: Phase   = Phase.IDLE
var hidden_index: int      = 0
var is_animating: bool     = false
var can_click: bool        = false
var _last_tap_frame: int   = -1
var chip_visible: bool     = false

# slot_positions[slot]      = fixed world centre of that grid cell
var slot_positions: Array  = []
# container_positions[cont] = current world centre of container cont
var container_positions: Array = []
# container_lift[cont]      = Y offset applied to drawing (negative = up)
var container_lift: Array  = []

# logical_positions[slot]   = container index currently in that slot
var logical_positions: Array = []
# container_slot[cont]      = slot currently occupied by that container
var container_slot: Array    = []

var swap_queue: Array            = []
var result_correct: bool         = false
var result_container_tapped: int = -1

# ── Textures ──────────────────────────────────────────────────────────────────
var tex_closed:    Texture2D = null
var tex_open:      Texture2D = null
var tex_highlight: Texture2D = null
var tex_chip:      Texture2D = null
var tex_bg:        Texture2D = null
var tex_win:       Texture2D = null
var tex_lose:      Texture2D = null

# ── UI nodes ─────────────────────────────────────────────────────────────────
@onready var phase_label:   Label         = $UILayer/PhaseLabel
@onready var start_btn:     Button        = $UILayer/StartButton
@onready var try_again_btn: Button        = $UILayer/TryAgainButton
@onready var exit_btn:      TextureButton = $Exit
var _phase_bg: Panel = null
@onready var _level_label: Label = $UILayer/LevelLabel

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	container_count = CONTAINER_COUNTS[_level - 1]
	_init_slot_positions()
	container_positions = slot_positions.duplicate()
	_reset_arrays()
	_load_textures()
	_build_phase_bg()
	if not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)

func _reset_arrays() -> void:
	logical_positions = []
	container_slot    = []
	container_lift    = []
	for i in container_count:
		logical_positions.append(i)
		container_slot.append(i)
		container_lift.append(0.0)

func _build_phase_bg() -> void:
	_phase_bg = Panel.new()
	_phase_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_phase_bg.offset_top    = 8.0
	_phase_bg.offset_bottom = 82.0
	_phase_bg.visible = false
	_phase_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.0, 0.06, 0.16, 0.88)
	style.border_color        = Color(0.0, 0.85, 1.0, 0.75)
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 0
	style.border_width_right  = 0
	_phase_bg.add_theme_stylebox_override("panel", style)

	$UILayer.add_child(_phase_bg)
	$UILayer.move_child(_phase_bg, 0)

func _level_text() -> String:
	return "УРОВЕНЬ %d / 3" % _level

func _on_exit_pressed() -> void:
	var main_game := get_tree().get_first_node_in_group("MainGame")
	if main_game and main_game.has_method("close_shell_game"):
		main_game.close_shell_game()
	else:
		get_tree().change_scene_to_file("res://scenes/Room3.tscn")

# Вычисляет позиции слотов для текущего container_count
func _init_slot_positions() -> void:
	var vp_size := get_viewport_rect().size
	var cx := vp_size.x / 2.0
	var cy := vp_size.y * 0.52
	var hh := (CONTAINER_SIZE.y + GRID_GAP_Y) * 0.5

	match container_count:
		4:  # 2×2
			slot_positions = _make_row(2, cx, cy - hh) + _make_row(2, cx, cy + hh)
		5:  # 2 сверху + 3 снизу
			slot_positions = _make_row(2, cx, cy - hh) + _make_row(3, cx, cy + hh)
		6:  # 3×2
			slot_positions = _make_row(3, cx, cy - hh) + _make_row(3, cx, cy + hh)

# Возвращает n центрированных позиций в строке
func _make_row(n: int, cx: float, y: float) -> Array:
	var row: Array = []
	var total_w := n * CONTAINER_SIZE.x + (n - 1) * GRID_GAP_X
	var start_x := cx - total_w / 2.0 + CONTAINER_SIZE.x / 2.0
	for i in n:
		row.append(Vector2(start_x + i * (CONTAINER_SIZE.x + GRID_GAP_X), y))
	return row

func _load_textures() -> void:
	var base := "res://minigame/shell_game/assets/"
	tex_closed    = _try_load(base + "container_closed.png")
	tex_open      = _try_load(base + "container_open.png")
	tex_highlight = _try_load(base + "container_highlight.png")
	tex_chip      = _try_load(base + "hidden_chip.png")
	tex_bg        = _try_load(base + "bg_shellgame.png")
	tex_win       = _try_load(base + "result_win.png")
	tex_lose      = _try_load(base + "result_lose.png")

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ─────────────────────────────────────────────────────────────────────────────
# GAME FLOW  (async coroutine chain)
# ─────────────────────────────────────────────────────────────────────────────

func start_game() -> void:
	container_positions  = slot_positions.duplicate()
	_reset_arrays()
	chip_visible         = false
	can_click            = false
	result_container_tapped = -1
	phase_label.text     = ""
	start_btn.visible    = false
	try_again_btn.visible = false
	queue_redraw()

	hidden_index  = randi() % container_count
	current_phase = Phase.SHOW_ITEM
	_phase_show_item()

# ── Phase: show chip ─────────────────────────────────────────────────────────

func _phase_show_item() -> void:
	chip_visible = true
	queue_redraw()

	var tw := create_tween()
	tw.tween_method(_lift_setter.bind(hidden_index), 0.0, LIFT_HEIGHT, LIFT_DUR)
	await tw.finished
	await get_tree().create_timer(1.5).timeout

	current_phase = Phase.HIDE_ITEM

	var tw2 := create_tween()
	tw2.tween_method(_lift_setter.bind(hidden_index), LIFT_HEIGHT, 0.0, LIFT_DUR)
	await tw2.finished

	chip_visible = false
	queue_redraw()
	_phase_shuffle()

# ── Phase: shuffle ───────────────────────────────────────────────────────────

func _phase_shuffle() -> void:
	current_phase = Phase.SHUFFLE
	is_animating  = true

	_build_swap_queue(SWAP_COUNTS[_level - 1])

	for pair in swap_queue:
		await _swap_two(int(pair[0]), int(pair[1]), SWAP_DURATION)

	_on_shuffle_done()

func _build_swap_queue(count: int) -> void:
	swap_queue = []
	var last_a := -1
	var last_b := -1
	for _k in range(count):
		var a := randi() % container_count
		var b := randi() % container_count
		var guard := 0
		while (b == a or (a == last_b and b == last_a)) and guard < 10:
			b = (b + 1) % container_count
			guard += 1
		swap_queue.append([a, b])
		last_a = a
		last_b = b

func _swap_two(slot_i: int, slot_j: int, dur: float) -> void:
	var ci  := int(logical_positions[slot_i])
	var cj  := int(logical_positions[slot_j])
	var pi  := slot_positions[slot_i] as Vector2
	var pj  := slot_positions[slot_j] as Vector2
	var mid := (pi + pj) * 0.5 - Vector2(0.0, ARC_HEIGHT)

	var animate_fn := func(t: float) -> void:
		container_positions[ci] = _bezier(pi, mid, pj, t)
		container_positions[cj] = _bezier(pj, mid, pi, t)
		queue_redraw()

	var tw := create_tween()
	tw.tween_method(animate_fn, 0.0, 1.0, dur)
	await tw.finished

	container_positions[ci]   = pj
	container_positions[cj]   = pi
	logical_positions[slot_i] = cj
	logical_positions[slot_j] = ci
	container_slot[ci]        = slot_j
	container_slot[cj]        = slot_i
	queue_redraw()

func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t

func _on_shuffle_done() -> void:
	is_animating  = false
	current_phase = Phase.WAIT_FOR_CLICK
	can_click     = true

# ── Lift helper ───────────────────────────────────────────────────────────────

func _lift_setter(val: float, idx: int) -> void:
	container_lift[idx] = val
	queue_redraw()

# ── Phase: reveal result ─────────────────────────────────────────────────────

func on_container_clicked(idx: int) -> void:
	if not can_click:
		return
	can_click               = false
	current_phase           = Phase.REVEAL
	result_container_tapped = idx
	result_correct          = (idx == hidden_index)
	_phase_reveal(result_correct)

func _phase_reveal(correct: bool) -> void:
	_set_phase_label("")
	chip_visible = true
	queue_redraw()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_lift_setter.bind(result_container_tapped), 0.0, LIFT_HEIGHT, LIFT_DUR)
	if not correct and hidden_index != result_container_tapped:
		tw.tween_method(_lift_setter.bind(hidden_index), 0.0, LIFT_HEIGHT, LIFT_DUR)
	await tw.finished

	_flash_result(correct)
	await get_tree().create_timer(2.5).timeout

	if not is_inside_tree():
		return

	minigame_completed.emit(correct, _level)

	if correct:
		if _level < 3:
			_advance_level()
		else:
			# Все 3 уровня пройдены — закрываем мини-игру
			var main_game := get_tree().get_first_node_in_group("MainGame")
			if main_game and main_game.has_method("close_shell_game"):
				main_game.close_shell_game()
			else:
				get_tree().change_scene_to_file("res://scenes/Room3.tscn")
	else:
		try_again_btn.visible = true

# Переход на следующий уровень без перезапуска сцены
func _advance_level() -> void:
	_level        += 1
	container_count = CONTAINER_COUNTS[_level - 1]
	_init_slot_positions()
	if _level_label:
		_level_label.text = _level_text()
	start_game()

# ─────────────────────────────────────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not can_click:
		return
	var touch_pos := Vector2.ZERO
	var fired     := false

	if event is InputEventScreenTouch and event.pressed:
		touch_pos = event.position
		fired     = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		touch_pos = event.position
		fired     = true

	if fired:
		var frame := Engine.get_process_frames()
		if frame == _last_tap_frame:
			return
		_last_tap_frame = frame
		for i in range(container_count):
			if _container_hit(i, touch_pos):
				on_container_clicked(i)
				get_viewport().set_input_as_handled()
				break

func _container_hit(idx: int, pos: Vector2) -> bool:
	var lift: float     = float(container_lift[idx])
	var center: Vector2 = container_positions[idx] as Vector2 + Vector2(0.0, lift)
	var rect := Rect2(center - CONTAINER_HALF - Vector2(20.0, 20.0),
					  CONTAINER_SIZE + Vector2(40.0, 40.0))
	return rect.has_point(pos)

# ─────────────────────────────────────────────────────────────────────────────
# DRAWING
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_chip()
	for i in range(container_count):
		_draw_container(i)

# ── Background ────────────────────────────────────────────────────────────────

func _draw_bg() -> void:
	var vp_size := get_viewport_rect().size
	if tex_bg:
		draw_texture_rect(tex_bg, Rect2(Vector2.ZERO, vp_size), false)
		return
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.04, 0.04, 0.06))
	var gc := Color(0.0, 1.0, 1.0, 0.04)
	for x in range(0, int(vp_size.x) + 1, 40):
		draw_line(Vector2(x, 0.0), Vector2(x, vp_size.y), gc, 1.0)
	for y in range(0, int(vp_size.y) + 1, 40):
		draw_line(Vector2(0.0, y), Vector2(vp_size.x, y), gc, 1.0)
	for k in range(6):
		var alpha := 0.06 * (6.0 - float(k))
		draw_rect(Rect2(0.0, vp_size.y - 20.0 - float(k) * 10.0, vp_size.x, 10.0), Color(0.0, 0.5, 1.0, alpha))

# ── Chip ──────────────────────────────────────────────────────────────────────

func _draw_chip() -> void:
	if not chip_visible:
		return
	var base   := container_positions[hidden_index] as Vector2
	var chip_c := Vector2(base.x, base.y + CONTAINER_HALF.y - CHIP_SIZE.y * 0.5 - 4.0)

	if tex_chip:
		draw_texture_rect(tex_chip, Rect2(chip_c - CHIP_SIZE * 0.5, CHIP_SIZE), false)
		return
	var r := Rect2(chip_c - CHIP_SIZE * 0.5, CHIP_SIZE)
	draw_rect(r, Color(0.0, 0.65, 0.75))
	draw_rect(r.grow(-5.0), Color(0.05, 0.9, 1.0))
	var lc := Color(0.0, 0.3, 0.65)
	draw_line(chip_c + Vector2(-38.0,   0.0), chip_c + Vector2(38.0,   0.0), lc, 2.0)
	draw_line(chip_c + Vector2(  0.0, -22.0), chip_c + Vector2( 0.0,  22.0), lc, 2.0)
	draw_line(chip_c + Vector2(-38.0, -12.0), chip_c + Vector2(-20.0,-12.0), lc, 2.0)
	draw_line(chip_c + Vector2( 20.0,  12.0), chip_c + Vector2(38.0,  12.0), lc, 2.0)
	draw_circle(chip_c, 8.0, Color(0.0, 1.0, 1.0))
	draw_arc(chip_c, 12.0, 0.0, TAU, 24, Color(0.0, 1.0, 1.0, 0.4), 3.0)

# ── Containers ────────────────────────────────────────────────────────────────

func _draw_container(idx: int) -> void:
	var lift: float     = float(container_lift[idx])
	var center: Vector2 = container_positions[idx] as Vector2 + Vector2(0.0, lift)
	var rect   := Rect2(center - CONTAINER_HALF, CONTAINER_SIZE)
	var is_open: bool  = lift < -20.0
	var is_highlighted := current_phase == Phase.REVEAL and (
		idx == result_container_tapped
		or (not result_correct and idx == hidden_index)
	)

	if is_highlighted and tex_highlight:
		draw_texture_rect(tex_highlight, rect, false)
	elif is_open and tex_open:
		draw_texture_rect(tex_open, rect, false)
	elif not is_open and tex_closed:
		draw_texture_rect(tex_closed, rect, false)
	else:
		_draw_container_fallback(center, rect, is_open, is_highlighted)

func _draw_container_fallback(
		center: Vector2, rect: Rect2,
		is_open: bool, is_highlighted: bool) -> void:
	var shadow := Rect2(rect.grow(3.0).position + Vector2(5.0, 7.0), rect.grow(3.0).size)
	draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(rect, Color(0.10, 0.13, 0.17))
	draw_rect(
		Rect2(rect.position + Vector2(4.0, 4.0), Vector2(rect.size.x - 8.0, rect.size.y * 0.28)),
		Color(1.0, 1.0, 1.0, 0.04))
	var trim_col := Color(0.65, 0.15, 1.0) if is_highlighted else Color(0.0, 0.85, 1.0, 0.85)
	draw_rect(rect, trim_col, false, 2.5)
	if is_highlighted:
		draw_rect(rect.grow(5.0),  Color(0.6, 0.1, 1.0, 0.22), false, 5.0)
		draw_rect(rect.grow(11.0), Color(0.6, 0.1, 1.0, 0.09), false, 5.0)
	if is_open:
		draw_rect(
			Rect2(rect.position.x + 8.0, rect.position.y + rect.size.y - 26.0,
				  rect.size.x - 16.0, 20.0),
			Color(0.0, 1.0, 1.0, 0.45))
	var wc := Color(1.0, 1.0, 1.0, 0.06)
	draw_line(center + Vector2(-50.0, -70.0), center + Vector2(-28.0, -38.0), wc, 1.5)
	draw_line(center + Vector2( 24.0, -88.0), center + Vector2( 46.0, -52.0), wc, 1.5)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _flash_result(correct: bool) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.7, 0.15, 0.0) if correct else Color(0.8, 0.05, 0.05, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(overlay)

	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.55, 0.25)
	tw.tween_property(overlay, "color:a", 0.0,  1.8)
	await tw.finished
	overlay.queue_free()

func _set_phase_label(text: String) -> void:
	if phase_label:
		phase_label.text = text
	if _phase_bg:
		_phase_bg.visible = text != ""
