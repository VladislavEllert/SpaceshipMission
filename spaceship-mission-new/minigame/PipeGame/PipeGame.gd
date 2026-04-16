extends Node2D

signal puzzle_solved
signal puzzle_exit

const GRID_SIZE := 4
const TILE_SIZE := 130

# ── Pipe type IDs ──────────────────────────────────────────────────────────────
const STRAIGHT := 0  # pipe_straight.png — LEFT | RIGHT          at rot 0
const BEND     := 1  # pipe_bend.png     — RIGHT | BOTTOM        at rot 0
const TEE      := 2  # pipe_tee.png      — RIGHT | BOTTOM | LEFT at rot 0
const CROSS    := 3  # pipe_cross.png    — all four directions
const EMPTY    := 4  # empty.png         — no connections, never rotates

const PIPE_FILES := {
	STRAIGHT: "res://minigame/PipeGame/images/pipe_straight.png",
	BEND:     "res://minigame/PipeGame/images/pipe_bend.png",
	TEE:      "res://minigame/PipeGame/images/pipe_tee.png",
	CROSS:    "res://minigame/PipeGame/images/pipe_cross.png",
	EMPTY:    "res://minigame/PipeGame/images/empty.png",
}

# ── Direction bitmasks ─────────────────────────────────────────────────────────
const TOP    := 1
const RIGHT  := 2
const BOTTOM := 4
const LEFT   := 8

# ── Base connection masks at rotation step 0 ──────────────────────────────────
const BASE_MASKS := {
	STRAIGHT: 10,  # RIGHT(2) + LEFT(8)
	BEND:      6,  # RIGHT(2) + BOTTOM(4)  — pipe_bend.png opens RIGHT|BOTTOM at 0°
	TEE:      14,  # RIGHT(2) + BOTTOM(4) + LEFT(8)
	CROSS:    15,  # all four
	EMPTY:     0,
}

# ══════════════════════════════════════════════════════════════════════════════
# LEVEL DEFINITIONS
# Format per cell: [pipe_type, correct_rotation, start_rotation]
# ══════════════════════════════════════════════════════════════════════════════

# ── Level 1 ───────────────────────────────────────────────────────────────────
# Path (col,row): (0,1)→(0,2)→(1,2)→(1,3)→(2,3)→(3,3)→(3,2)
# Entry (0,1) LEFT, Exit (3,2) RIGHT — 7 non-empty cells
const LEVEL_1_LAYOUT := [
	[[4, 0, 0], [4, 0, 0], [4, 0, 0], [4, 0, 0]],
	[[1, 1, 3], [4, 0, 0], [4, 0, 0], [4, 0, 0]],
	[[1, 3, 1], [1, 1, 0], [4, 0, 0], [1, 0, 2]],
	[[4, 0, 0], [1, 3, 2], [0, 0, 1], [1, 2, 0]],
]
const LEVEL_1_ENTRY := Vector2i(0, 1)
const LEVEL_1_EXIT  := Vector2i(3, 2)

# ── Level 2 ───────────────────────────────────────────────────────────────────
# Snake path (col,row):
#   (0,0)→(1,0)→(2,0)→(3,0)→(3,1)→(2,1)→(1,1)→(0,1)→(0,2)→(1,2)→(2,2)→(3,2)→(3,3)
#   Plus branch: (1,1)↓(1,2) and (1,2) receives from both (0,2) and (1,1)
# Entry (0,0) LEFT, Exit (3,3) RIGHT — 13 non-empty cells, uses TEE pipes
#
# Mask verification:
#   (0,0) STRAIGHT rot0=10 LEFT|RIGHT        → LEFT(border)+RIGHT to (1,0)    ✓
#   (1,0) STRAIGHT rot0=10 LEFT|RIGHT        → LEFT to (0,0)+RIGHT to (2,0)   ✓
#   (2,0) STRAIGHT rot0=10 LEFT|RIGHT        → LEFT to (1,0)+RIGHT to (3,0)   ✓
#   (3,0) BEND rot1=12 BOTTOM|LEFT           → LEFT to (2,0)+DOWN to (3,1)    ✓
#   (3,1) BEND rot2=9 TOP|LEFT               → UP to (3,0)+LEFT to (2,1)      ✓
#   (2,1) STRAIGHT rot0=10 LEFT|RIGHT        → RIGHT to (3,1)+LEFT to (1,1)   ✓
#   (1,1) TEE rot0=14 RIGHT|BOTTOM|LEFT      → RIGHT to (2,1)+LEFT to (0,1)
#                                               +DOWN to (1,2)                 ✓
#   (0,1) BEND rot0=6 RIGHT|BOTTOM           → RIGHT to (1,1)+DOWN to (0,2)   ✓
#   (0,2) BEND rot3=3 TOP|RIGHT              → UP to (0,1)+RIGHT to (1,2)     ✓
#   (1,2) TEE rot2=11 TOP|RIGHT|LEFT         → LEFT to (0,2)+RIGHT to (2,2)
#                                               +UP to (1,1)                   ✓
#   (2,2) STRAIGHT rot0=10 LEFT|RIGHT        → LEFT to (1,2)+RIGHT to (3,2)   ✓
#   (3,2) BEND rot1=12 BOTTOM|LEFT           → LEFT to (2,2)+DOWN to (3,3)    ✓
#   (3,3) BEND rot3=3 TOP|RIGHT              → UP to (3,2)+RIGHT(border)      ✓
#
# All 13 non-empty cells reachable by flood fill from entry, exit reached.     ✓
const LEVEL_2_LAYOUT := [
	# row 0: STRAIGHT | STRAIGHT | STRAIGHT | BEND
	[[0, 0, 2], [0, 0, 1], [0, 0, 3], [1, 1, 3]],
	# row 1: BEND | TEE | STRAIGHT | BEND
	[[1, 0, 2], [2, 0, 2], [0, 0, 1], [1, 2, 0]],
	# row 2: BEND | TEE | STRAIGHT | BEND
	[[1, 3, 1], [2, 2, 0], [0, 0, 3], [1, 1, 3]],
	# row 3: empty | empty | empty | BEND
	[[4, 0, 0], [4, 0, 0], [4, 0, 0], [1, 3, 1]],
]
const LEVEL_2_ENTRY := Vector2i(0, 0)
const LEVEL_2_EXIT  := Vector2i(3, 3)

# ── Level 3 ───────────────────────────────────────────────────────────────────
# Full grid — all 16 cells filled. Complex network with CROSS intersections.
# Entry (0,0) LEFT, Exit (3,3) RIGHT
#
# Connection map (every cell connects to its listed neighbours):
#   (0,0) R→(1,0) B→(0,1)               = R|B|L(border)   = TEE rot0  (14)
#   (1,0) L→(0,0) R→(2,0)               = L|R              = STRAIGHT rot0 (10)
#   (2,0) L→(1,0) R→(3,0) B→(2,1)       = L|R|B            = TEE rot0  (14)
#   (3,0) L→(2,0) B→(3,1)               = L|B              = BEND rot1 (12)
#   (0,1) T→(0,0) R→(1,1) B→(0,2)       = T|R|B            = TEE rot3  (7)
#   (1,1) L→(0,1) R→(2,1) B→(1,2)       = L|R|B            = TEE rot0  (14)
#   (2,1) T→(2,0) L→(1,1) R→(3,1) B→(2,2)= all four        = CROSS     (15)
#   (3,1) T→(3,0) L→(2,1) B→(3,2)       = T|L|B            = TEE rot1  (13)
#   (0,2) T→(0,1) R→(1,2) B→(0,3)       = T|R|B            = TEE rot3  (7)
#   (1,2) T→(1,1) L→(0,2) R→(2,2)       = T|L|R            = TEE rot2  (11)
#   (2,2) T→(2,1) L→(1,2) R→(3,2) B→(2,3)= all four        = CROSS     (15)
#   (3,2) T→(3,1) L→(2,2) B→(3,3)       = T|L|B            = TEE rot1  (13)
#   (0,3) T→(0,2) R→(1,3)               = T|R              = BEND rot3 (3)
#   (1,3) L→(0,3) R→(2,3)               = L|R              = STRAIGHT rot0 (10)
#   (2,3) T→(2,2) L→(1,3) R→(3,3)       = T|L|R            = TEE rot2  (11)
#   (3,3) T→(3,2) L→(2,3) R(border)     = T|L|R            = TEE rot2  (11)
#
# All 16 cells reachable by flood fill from (0,0), exit (3,3) reached.         ✓
const LEVEL_3_LAYOUT := [
	# row 0: TEE | STRAIGHT | TEE | BEND
	[[2, 0, 2], [0, 0, 1], [2, 0, 3], [1, 1, 3]],
	# row 1: TEE | TEE | CROSS | TEE
	[[2, 3, 1], [2, 0, 3], [3, 0, 0], [2, 1, 3]],
	# row 2: TEE | TEE | CROSS | TEE
	[[2, 3, 0], [2, 2, 0], [3, 0, 0], [2, 1, 3]],
	# row 3: BEND | STRAIGHT | TEE | TEE
	[[1, 3, 1], [0, 0, 1], [2, 2, 0], [2, 2, 0]],
]
const LEVEL_3_ENTRY := Vector2i(0, 0)
const LEVEL_3_EXIT  := Vector2i(3, 3)

# ── All levels ────────────────────────────────────────────────────────────────
const LEVELS := [
	{ "layout": LEVEL_1_LAYOUT, "entry": LEVEL_1_ENTRY, "exit": LEVEL_1_EXIT },
	{ "layout": LEVEL_2_LAYOUT, "entry": LEVEL_2_ENTRY, "exit": LEVEL_2_EXIT },
	{ "layout": LEVEL_3_LAYOUT, "entry": LEVEL_3_ENTRY, "exit": LEVEL_3_EXIT },
]

# ── State ──────────────────────────────────────────────────────────────────────
var _current_level := 0
var _won: bool = false
var _entry_pos := Vector2i.ZERO
var _exit_pos  := Vector2i.ZERO
var _puzzle_layout: Array = []

var _grid_types: Array = []
var _grid_rots:  Array = []
var _tex_rects:  Array = []
var _textures:   Dictionary = {}

@onready var _grid_container: GridContainer = $GridContainer
@onready var _win_overlay:    Control       = $WinOverlay
@onready var _exit_button:    TextureButton = $TextureButton
@onready var _check_button:   Button        = $CheckButton
@onready var _red_arrow: Node2D            = $RedArrow

# Created in code so it always has a correct viewport-sized rect and sits on top.
var _red_flash: ColorRect
var _last_tap_frame: int = -1


# ── Life-cycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_win_overlay.z_index = 10  # draw above TextureRect background
	_win_overlay.set_deferred("size", get_viewport().get_visible_rect().size)
	if not _exit_button.pressed.is_connected(_on_exit_pressed):
		_exit_button.pressed.connect(_on_exit_pressed)
	if not _check_button.pressed.is_connected(_on_check_pressed):
		_check_button.pressed.connect(_on_check_pressed)
	_style_check_button()
	_style_win_panel()
	_load_textures()
	_load_level(_current_level)
	_create_red_flash()
	_animate_red_arrow()


func _on_exit_pressed() -> void:
	if _won:
		return
	puzzle_exit.emit()


# ── Textures ───────────────────────────────────────────────────────────────────
func _load_textures() -> void:
	for t in [STRAIGHT, BEND, TEE, CROSS, EMPTY]:
		_textures[t] = load(PIPE_FILES[t])


# ── Bitmask helpers ────────────────────────────────────────────────────────────
# Rotate mask 90° clockwise: TOP→RIGHT→BOTTOM→LEFT→TOP
func _rot_cw(mask: int) -> int:
	return ((mask << 1) | (mask >> 3)) & 0xF


# Effective bitmask for pipe_type after `steps` CW rotations.
func _get_mask(pipe_type: int, steps: int) -> int:
	var m: int = BASE_MASKS[pipe_type]
	for _i in steps:
		m = _rot_cw(m)
	return m


# ── Level loading ─────────────────────────────────────────────────────────────
func _load_level(level_idx: int) -> void:
	_won = false
	var level: Dictionary = LEVELS[level_idx]
	_puzzle_layout = level["layout"]
	_entry_pos = level["entry"]
	_exit_pos = level["exit"]
	_clear_grid()
	_setup_puzzle()
	_build_grid()
	_update_arrow_position()


func _clear_grid() -> void:
	_grid_types.clear()
	_grid_rots.clear()
	_tex_rects.clear()
	for child in _grid_container.get_children():
		child.queue_free()


# ── Puzzle setup ───────────────────────────────────────────────────────────────
func _setup_puzzle() -> void:
	var total := GRID_SIZE * GRID_SIZE
	_grid_types.resize(total)
	_grid_rots.resize(total)

	for r in GRID_SIZE:
		for c in GRID_SIZE:
			var idx  := r * GRID_SIZE + c
			var cell: Array = _puzzle_layout[r][c]
			_grid_types[idx] = cell[0]  # pipe type
			_grid_rots[idx]  = cell[2]  # start rotation (scrambled)


# ── Grid construction ──────────────────────────────────────────────────────────
func _build_grid() -> void:
	_grid_container.columns = GRID_SIZE

	for r in GRID_SIZE:
		for c in GRID_SIZE:
			var idx := r * GRID_SIZE + c

			var cell := Control.new()
			cell.custom_minimum_size   = Vector2(TILE_SIZE, TILE_SIZE)
			cell.size                  = Vector2(TILE_SIZE, TILE_SIZE)
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
			cell.clip_contents         = true

			var tex := TextureRect.new()
			tex.texture          = _textures[_grid_types[idx]]
			tex.expand_mode      = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.position         = Vector2.ZERO
			tex.size             = Vector2(TILE_SIZE, TILE_SIZE)
			tex.pivot_offset     = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			tex.rotation_degrees = _grid_rots[idx] * 90.0
			tex.mouse_filter     = Control.MOUSE_FILTER_IGNORE

			cell.add_child(tex)
			_grid_container.add_child(cell)
			_tex_rects.append(tex)

			cell.gui_input.connect(_on_cell_input.bind(idx))


# ── Red flash overlay (created in code, always last child = topmost) ──────────
func _create_red_flash() -> void:
	_red_flash = ColorRect.new()
	_red_flash.color = Color(1, 0, 0, 0.45)
	_red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red_flash.visible = false
	add_child(_red_flash)
	# PRESET_FULL_RECT only works when the parent is a Control.
	# PipeGame is Node2D, so set size explicitly from the viewport.
	var vp_size := get_viewport().get_visible_rect().size
	_red_flash.position = Vector2.ZERO
	_red_flash.size = vp_size


# ── Red arrow position ─────────────────────────────────────────────────────────
func _update_arrow_position() -> void:
	if _red_arrow == null:
		return
	var grid_top := _grid_container.offset_top
	var entry_y := grid_top + _entry_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	_red_arrow.position.y = entry_y


# ── Red arrow idle animation ───────────────────────────────────────────────────
func _animate_red_arrow() -> void:
	if _red_arrow == null:
		return
	var origin_x := _red_arrow.position.x
	var tween := create_tween().set_loops()
	tween.tween_property(_red_arrow, "position:x", origin_x + 8.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_red_arrow, "position:x", origin_x, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Check button circular style ────────────────────────────────────────────────
func _style_check_button() -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color              = Color(0.18, 0.55, 0.20)
	sn.corner_radius_top_left     = 28
	sn.corner_radius_top_right    = 28
	sn.corner_radius_bottom_left  = 28
	sn.corner_radius_bottom_right = 28
	_check_button.add_theme_stylebox_override("normal", sn)

	var sh: StyleBoxFlat = sn.duplicate()
	sh.bg_color = Color(0.25, 0.68, 0.28)
	_check_button.add_theme_stylebox_override("hover", sh)

	var sp: StyleBoxFlat = sn.duplicate()
	sp.bg_color = Color(0.10, 0.40, 0.14)
	_check_button.add_theme_stylebox_override("pressed", sp)

	_check_button.add_theme_color_override("font_color", Color(1, 1, 1))
	_check_button.add_theme_font_size_override("font_size", 28)


# ── Win overlay panel style ────────────────────────────────────────────────────
func _style_win_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	$WinOverlay/CenterContainer/PanelContainer.add_theme_stylebox_override("panel", sb)


# ── Input ──────────────────────────────────────────────────────────────────────
func _on_cell_input(event: InputEvent, idx: int) -> void:
	if _won:
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tapped = true
	if tapped:
		var frame := Engine.get_process_frames()
		if frame == _last_tap_frame:
			return
		_last_tap_frame = frame
		if _grid_types[idx] == EMPTY:
			return  # empty tiles cannot be rotated
		_grid_rots[idx]                  = (_grid_rots[idx] + 1) % 4
		_tex_rects[idx].rotation_degrees = _grid_rots[idx] * 90.0


# ── Check button: manual win trigger ──────────────────────────────────────────
func _on_check_pressed() -> void:
	if _won:
		return
	if _check_win_by_flow():
		_won = true
		if _current_level < LEVELS.size() - 1:
			_advance_to_next_level()
		else:
			_on_win()
	else:
		_red_flash.show()
		await get_tree().create_timer(1.0).timeout
		_red_flash.hide()


func _advance_to_next_level() -> void:
	# Brief green flash to indicate level completed
	var flash := ColorRect.new()
	flash.color = Color(0, 1, 0, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = true
	add_child(flash)
	var vp_size := get_viewport().get_visible_rect().size
	flash.position = Vector2.ZERO
	flash.size = vp_size
	await get_tree().create_timer(0.6).timeout
	flash.queue_free()
	_current_level += 1
	_load_level(_current_level)


func _on_win() -> void:
	set_process_input(false)
	puzzle_solved.emit()


# ── Win check: flood-fill from the entry cell ─────────────────────────────────
#
# A step from cell A to neighbour B is valid only when BOTH are true:
#   • A's current rotated mask opens in the direction toward B.
#   • B's current rotated mask opens back in the direction toward A.
#
# Two conditions must both pass:
#   1. The flood fill reaches _exit_pos (the exit border cell).
#   2. visited.size() == total number of non-empty tiles on the grid —
#      guarantees no disconnected pipe segment exists anywhere.
func _check_win_by_flow() -> bool:
	# Count every pipe tile (non-empty) on the grid.
	var pipe_count := 0
	for i in _grid_types.size():
		if _grid_types[i] != EMPTY:
			pipe_count += 1

	# Flood-fill from the entry cell.
	var visited: Dictionary = {}
	visited[_entry_pos] = true
	var queue: Array = [_entry_pos]

	var steps := [
		[Vector2i(0, -1), TOP,    BOTTOM],
		[Vector2i(1,  0), RIGHT,  LEFT  ],
		[Vector2i(0,  1), BOTTOM, TOP   ],
		[Vector2i(-1, 0), LEFT,   RIGHT ],
	]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var cur_idx  := cur.y * GRID_SIZE + cur.x
		# Always read _grid_rots (current player rotation), never correct rotation.
		var cur_mask := _get_mask(_grid_types[cur_idx], _grid_rots[cur_idx])

		for step in steps:
			# A must open toward B.
			if not (cur_mask & step[1]):
				continue
			var nxt: Vector2i = cur + step[0]
			# Stay inside the grid.
			if nxt.x < 0 or nxt.x >= GRID_SIZE or nxt.y < 0 or nxt.y >= GRID_SIZE:
				continue
			if visited.has(nxt):
				continue
			var nxt_idx := nxt.y * GRID_SIZE + nxt.x
			# Empty tiles are never part of the pipeline.
			if _grid_types[nxt_idx] == EMPTY:
				continue
			# B must open back toward A.
			var nxt_mask := _get_mask(_grid_types[nxt_idx], _grid_rots[nxt_idx])
			if not (nxt_mask & step[2]):
				continue
			visited[nxt] = true
			queue.append(nxt)

	# Condition 1: the exit border cell must be reachable from the entry.
	if not visited.has(_exit_pos):
		return false

	# Condition 2: every pipe tile must have been reached — no floating segments.
	if visited.size() != pipe_count:
		return false

	return true
