## ShellGame.gd
## Mini-game "Find the Chip" (Shell Game) — 2×2 grid, arc-swap animation
## Godot 4.x | touch + mouse | landscape 1280×720
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────
signal minigame_completed(success: bool, difficulty: int)
signal minigame_cancelled()

# ── Enums ─────────────────────────────────────────────────────────────────────
enum Difficulty { EASY = 0, MEDIUM = 1, HARD = 2 }
enum Phase { IDLE, SHOW_ITEM, HIDE_ITEM, SHUFFLE, WAIT_FOR_CLICK, REVEAL }

# ── Config ────────────────────────────────────────────────────────────────────
const SWAP_COUNTS: Dictionary  = { 0: 4,    1: 8,    2: 14  }
const SWAP_DURATION: Dictionary = { 0: 0.6,  1: 0.35, 2: 0.2 }

const CONTAINER_SIZE := Vector2(200.0, 220.0)
const CONTAINER_HALF := Vector2(100.0, 110.0)
const CHIP_SIZE      := Vector2(100.0,  80.0)
const GRID_GAP_X     := 60.0
const GRID_GAP_Y     := 60.0
const ARC_HEIGHT     := 80.0
const LIFT_HEIGHT    := -90.0
const LIFT_DUR       := 0.4

# ── State ─────────────────────────────────────────────────────────────────────
var difficulty: Difficulty    = Difficulty.MEDIUM
var current_phase: Phase      = Phase.IDLE

var hidden_index: int         = 0      # container index that holds the chip
var is_animating: bool        = false
var can_click: bool           = false
var chip_visible: bool        = false

# slot_positions[slot]      = fixed world position of that grid cell centre
var slot_positions: Array     = []
# container_positions[cont] = current world position of container cont
var container_positions: Array = []
# container_lift[cont]      = current Y lift offset (negative = up)
var container_lift: Array     = [0.0, 0.0, 0.0, 0.0]

# logical_positions[slot]   = container index currently occupying that slot
var logical_positions: Array  = [0, 1, 2, 3]
# container_slot[cont]      = slot index currently occupied by that container
var container_slot: Array     = [0, 1, 2, 3]

var swap_queue: Array         = []
var result_correct: bool      = false
var result_container_tapped: int = -1

# ── Textures ──────────────────────────────────────────────────────────────────
var tex_closed:    Texture2D = null
var tex_open:      Texture2D = null
var tex_highlight: Texture2D = null
var tex_chip:      Texture2D = null
var tex_bg:        Texture2D = null
var tex_win:       Texture2D = null
var tex_lose:      Texture2D = null

# ── UI ────────────────────────────────────────────────────────────────────────
var ui_layer:     CanvasLayer = null
var phase_label:  Label       = null
var result_label: Label       = null
var start_btn:    Button      = null

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_slot_positions()
	container_positions = slot_positions.duplicate()
	_load_textures()
	_create_ui()

func _init_slot_positions() -> void:
	# Grid centred at (640, 320) — leaves room for labels above and below
	var cx := 640.0
	var cy := 320.0
	var hw  := (CONTAINER_SIZE.x + GRID_GAP_X) * 0.5
	var hh  := (CONTAINER_SIZE.y + GRID_GAP_Y) * 0.5
	slot_positions = [
		Vector2(cx - hw, cy - hh),  # 0 top-left
		Vector2(cx + hw, cy - hh),  # 1 top-right
		Vector2(cx - hw, cy + hh),  # 2 bottom-left
		Vector2(cx + hw, cy + hh),  # 3 bottom-right
	]

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

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# Phase label — top-centre
	phase_label = _make_label("", 38, Color.CYAN)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.anchors_preset = Control.PRESET_TOP_WIDE
	phase_label.offset_top    = 18.0
	phase_label.offset_bottom = 72.0
	ui_layer.add_child(phase_label)

	# Result label — centre-bottom overlay
	result_label = _make_label("", 54, Color(0.2, 1.0, 0.4))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	result_label.offset_top    = -110.0
	result_label.offset_bottom = -50.0
	result_label.modulate.a    = 0.0
	ui_layer.add_child(result_label)

	# Difficulty row — bottom-centre
	var diff_row := HBoxContainer.new()
	diff_row.anchors_preset = Control.PRESET_BOTTOM_WIDE
	diff_row.offset_top     = -48.0
	diff_row.offset_bottom  = -4.0
	diff_row.alignment      = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 20)
	ui_layer.add_child(diff_row)

	var diff_names := ["Easy", "Medium", "Hard"]
	for i in range(3):
		var btn := _make_button(diff_names[i], 26)
		var captured := i
		btn.pressed.connect(func(): _on_difficulty_pressed(captured))
		diff_row.add_child(btn)

	# START button — bottom-right
	start_btn = _make_button("START", 30)
	start_btn.custom_minimum_size = Vector2(160, 55)
	start_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	start_btn.offset_left   = -180.0
	start_btn.offset_right  = -10.0
	start_btn.offset_top    = -65.0
	start_btn.offset_bottom = -10.0
	start_btn.pressed.connect(start_game)
	ui_layer.add_child(start_btn)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	return lbl

func _make_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(130, 50)
	return btn

func _on_difficulty_pressed(d: int) -> void:
	difficulty = d as Difficulty

# ─────────────────────────────────────────────────────────────────────────────
# GAME FLOW (async chain)
# ─────────────────────────────────────────────────────────────────────────────

func start_game() -> void:
	# Reset visual state
	container_positions = slot_positions.duplicate()
	logical_positions   = [0, 1, 2, 3]
	container_slot      = [0, 1, 2, 3]
	container_lift      = [0.0, 0.0, 0.0, 0.0]
	chip_visible        = false
	can_click           = false
	result_label.modulate.a   = 0.0
	result_label.text         = ""
	result_container_tapped   = -1
	start_btn.visible         = false
	queue_redraw()

	hidden_index  = randi() % 4
	current_phase = Phase.SHOW_ITEM
	_set_phase_label("Remember!")

	_phase_show_item()   # async — fire and forget

func _phase_show_item() -> void:
	chip_visible = true
	queue_redraw()

	# Lift the correct container
	var tw := create_tween()
	tw.tween_method(_lift_setter.bind(hidden_index), 0.0, LIFT_HEIGHT, LIFT_DUR)
	await tw.finished

	# Hold for recognition
	await get_tree().create_timer(1.5).timeout

	# Lower and hide chip
	current_phase = Phase.HIDE_ITEM
	_set_phase_label("Watch!")

	var tw2 := create_tween()
	tw2.tween_method(_lift_setter.bind(hidden_index), LIFT_HEIGHT, 0.0, LIFT_DUR)
	await tw2.finished

	chip_visible = false
	queue_redraw()
	_phase_shuffle()

func _phase_shuffle() -> void:
	current_phase = Phase.SHUFFLE
	is_animating  = true

	var count := SWAP_COUNTS[difficulty] as int
	var dur   := SWAP_DURATION[difficulty] as float

	_build_swap_queue(count)

	for pair in swap_queue:
		await _swap_two(pair[0], pair[1], dur)

	_on_shuffle_done()

func _build_swap_queue(count: int) -> void:
	swap_queue = []
	var last_a := -1
	var last_b := -1
	for _k in range(count):
		var a := randi() % 4
		var b := randi() % 4
		# ensure a != b and not an immediate reverse of last swap
		var attempts := 0
		while b == a or (a == last_b and b == last_a):
			b = (b + 1) % 4
			if b == a:
				b = (b + 1) % 4
			attempts += 1
			if attempts > 8:
				break
		swap_queue.append([a, b])
		last_a = a
		last_b = b

func _swap_two(slot_i: int, slot_j: int, dur: float) -> void:
	var ci := logical_positions[slot_i]
	var cj := logical_positions[slot_j]
	var pi := slot_positions[slot_i]
	var pj := slot_positions[slot_j]
	# Arc midpoint elevated above the straight line
	var mid := (pi + pj) * 0.5 - Vector2(0.0, ARC_HEIGHT)

	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		container_positions[ci] = _bezier(pi, mid, pj, t)
		container_positions[cj] = _bezier(pj, mid, pi, t)
		queue_redraw()
	, 0.0, 1.0, dur)
	await tw.finished

	# Snap and update logical state
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
	_set_phase_label("Choose!")

# ── Lift helper used by tween_method.bind ─────────────────────────────────────
# tween_method passes the interpolated value as arg 0; bind appends idx as arg 1
func _lift_setter(val: float, idx: int) -> void:
	container_lift[idx] = val
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# CLICK / TOUCH
# ─────────────────────────────────────────────────────────────────────────────

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

	# Lift tapped container (and correct one if wrong)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_lift_setter.bind(result_container_tapped), 0.0, LIFT_HEIGHT, LIFT_DUR)
	if not correct and hidden_index != result_container_tapped:
		tw.tween_method(_lift_setter.bind(hidden_index), 0.0, LIFT_HEIGHT, LIFT_DUR)
	await tw.finished

	# Result label
	if correct:
		result_label.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
		result_label.text = "Correct!"
	else:
		result_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		result_label.text = "Wrong!"

	var fade := create_tween()
	fade.tween_property(result_label, "modulate:a", 1.0, 0.3)
	await fade.finished

	await get_tree().create_timer(2.5).timeout
	minigame_completed.emit(correct, difficulty)
	start_btn.visible = true

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
		for i in range(4):
			if _container_hit(i, touch_pos):
				on_container_clicked(i)
				get_viewport().set_input_as_handled()
				break

func _container_hit(idx: int, pos: Vector2) -> bool:
	# Use actual lifted position for hit-test; expand 20 px for fat-finger
	var center := container_positions[idx] + Vector2(0.0, container_lift[idx])
	var rect   := Rect2(center - CONTAINER_HALF, CONTAINER_SIZE).grow(20.0)
	return rect.has_point(pos)

# ─────────────────────────────────────────────────────────────────────────────
# DRAWING
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_chip()
	# Draw containers back-to-front (no depth sorting needed for flat layout)
	for i in range(4):
		_draw_container(i)

# ── Background ────────────────────────────────────────────────────────────────

func _draw_bg() -> void:
	if tex_bg:
		draw_texture_rect(tex_bg, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
		return
	# Fallback: dark sci-fi room
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.04, 0.04, 0.06))
	# Holographic grid
	var gc := Color(0.0, 1.0, 1.0, 0.04)
	for x in range(0, 1281, 40):
		draw_line(Vector2(x, 0), Vector2(x, 720), gc, 1.0)
	for y in range(0, 721, 40):
		draw_line(Vector2(0, y), Vector2(1280, y), gc, 1.0)
	# Table surface glow
	for k in range(6):
		var alpha := 0.06 * (6.0 - k)
		draw_rect(Rect2(0, 700 - k * 10, 1280, 10), Color(0.0, 0.5, 1.0, alpha))
	# Subtle fog edges
	for k in range(4):
		var a := 0.08 * (4.0 - k)
		draw_rect(Rect2(0,         0, 60 - k * 14, 720), Color(0.0, 0.0, 0.05, a))
		draw_rect(Rect2(1220 + k * 14, 0, 60 - k * 14, 720), Color(0.0, 0.0, 0.05, a))

# ── Chip ─────────────────────────────────────────────────────────────────────

func _draw_chip() -> void:
	if not chip_visible:
		return
	# Chip sits at the base of its container (unaffected by lift)
	var base   := container_positions[hidden_index]
	var chip_c := Vector2(base.x, base.y + CONTAINER_HALF.y - CHIP_SIZE.y * 0.5 - 4.0)

	if tex_chip:
		draw_texture_rect(tex_chip,
			Rect2(chip_c - CHIP_SIZE * 0.5, CHIP_SIZE), false)
		return
	# Fallback
	var r := Rect2(chip_c - CHIP_SIZE * 0.5, CHIP_SIZE)
	draw_rect(r, Color(0.0, 0.65, 0.75))
	draw_rect(r.grow(-5.0), Color(0.05, 0.9, 1.0))
	# Circuit lines
	var lc := Color(0.0, 0.3, 0.65)
	draw_line(chip_c + Vector2(-38, 0),   chip_c + Vector2(38, 0),   lc, 2.0)
	draw_line(chip_c + Vector2(0, -22),   chip_c + Vector2(0, 22),   lc, 2.0)
	draw_line(chip_c + Vector2(-38, -12), chip_c + Vector2(-20, -12), lc, 2.0)
	draw_line(chip_c + Vector2(20,  12),  chip_c + Vector2(38,  12),  lc, 2.0)
	draw_circle(chip_c, 8.0, Color(0.0, 1.0, 1.0))
	# Glow ring
	draw_arc(chip_c, 12.0, 0.0, TAU, 24, Color(0.0, 1.0, 1.0, 0.4), 3.0)

# ── Containers ────────────────────────────────────────────────────────────────

func _draw_container(idx: int) -> void:
	var center := container_positions[idx] + Vector2(0.0, container_lift[idx])
	var rect   := Rect2(center - CONTAINER_HALF, CONTAINER_SIZE)
	var is_open := container_lift[idx] < -20.0
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
	# Drop shadow
	draw_rect(rect.grow(3.0).move(Vector2(5.0, 7.0)), Color(0.0, 0.0, 0.0, 0.35))

	# Body
	draw_rect(rect, Color(0.10, 0.13, 0.17))
	# Inner top highlight
	draw_rect(Rect2(rect.position + Vector2(4.0, 4.0),
		Vector2(rect.size.x - 8.0, rect.size.y * 0.28)),
		Color(1.0, 1.0, 1.0, 0.04))

	# Neon edge trim
	var trim_col: Color = Color(0.65, 0.15, 1.0) if is_highlighted \
		else Color(0.0, 0.85, 1.0, 0.85)
	draw_rect(rect, trim_col, false, 2.5)

	# Outer glow when highlighted
	if is_highlighted:
		draw_rect(rect.grow(5.0), Color(0.6, 0.1, 1.0, 0.22), false, 5.0)
		draw_rect(rect.grow(11.0), Color(0.6, 0.1, 1.0, 0.09), false, 5.0)

	# Open-bottom cyan glow
	if is_open:
		var g := Rect2(rect.position.x + 8.0,
			rect.position.y + rect.size.y - 26.0,
			rect.size.x - 16.0, 20.0)
		draw_rect(g, Color(0.0, 1.0, 1.0, 0.45))

	# Wear scratches
	var wc := Color(1.0, 1.0, 1.0, 0.06)
	draw_line(center + Vector2(-50.0, -70.0), center + Vector2(-28.0, -38.0), wc, 1.5)
	draw_line(center + Vector2(24.0,  -88.0), center + Vector2(46.0,  -52.0), wc, 1.5)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_phase_label(text: String) -> void:
	if phase_label:
		phase_label.text = text
