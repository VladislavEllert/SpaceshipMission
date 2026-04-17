extends Node

# Этот файл — глобальный синглтон, доступен из любой сцены как GameState.xxx

var current_room: int = 1
var intro_finished: bool = false
var ball_cleaned: bool = false

# Room4 — робот
var robot_powered: bool = false
var panel_solved: bool = false
var panel_game_won: bool = false
var ship_panel_opened: bool = false
var ship_fully_solved: bool = false

# Реактор — единственное что нужно сохранять между комнатами
var reactor_colored: bool = false     # реактор починен инструментом в Room1
var reactor_picked_up: bool = false   # реактор забрали из Room1 в инвентарь
var reactor_installed: bool = false   # реактор установлен в Room3
var hidden_tool_taken: bool = false

# Питание — все мини-игры 3-й комнаты пройдены
var power_solved: bool = false

# Дверь разблокирована (все системы восстановлены)
var door_unlocked: bool = false

# Фон первой комнаты изменён (дверь открыта)
var room1_door_opened: bool = false

# Мини-игры
var puzzle_solved_15: bool = false
var flask_solved: bool = false
var platformer_solved: bool = false
var jumper_solved: bool = false
var laser_mirror_solved: bool = false
var pipe_game_solved: bool = false
var shell_game_solved: bool = false
var flow_connect_solved: bool = false

# Сундуки и инвентарь
var chest1_opened: bool = false
var chest2_opened: bool = false
var screen_unlocked: bool = false
var collected_items: Array = []
var inventory_items: Array = []

# Подсказки (мигающие полигоны-хинты)
var room4_polygon_clicked: bool = false

# -------------------------------------------------------
const SAVE_PATH := "user://save_game.cfg"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_room",       current_room)
	cfg.set_value("progress", "intro_finished",     intro_finished)
	cfg.set_value("progress", "ball_cleaned",       ball_cleaned)
	cfg.set_value("progress", "robot_powered",      robot_powered)
	cfg.set_value("progress", "panel_solved",       panel_solved)
	cfg.set_value("progress", "panel_game_won",     panel_game_won)
	cfg.set_value("progress", "ship_panel_opened",  ship_panel_opened)
	cfg.set_value("progress", "ship_fully_solved",  ship_fully_solved)
	cfg.set_value("progress", "reactor_colored",    reactor_colored)
	cfg.set_value("progress", "reactor_picked_up",  reactor_picked_up)
	cfg.set_value("progress", "reactor_installed",  reactor_installed)
	cfg.set_value("progress", "hidden_tool_taken",  hidden_tool_taken)
	cfg.set_value("progress", "power_solved",       power_solved)
	cfg.set_value("progress", "door_unlocked",      door_unlocked)
	cfg.set_value("progress", "room1_door_opened",  room1_door_opened)
	cfg.set_value("progress", "puzzle_solved_15",   puzzle_solved_15)
	cfg.set_value("progress", "flask_solved",       flask_solved)
	cfg.set_value("progress", "platformer_solved",  platformer_solved)
	cfg.set_value("progress", "jumper_solved",      jumper_solved)
	cfg.set_value("progress", "laser_mirror_solved",laser_mirror_solved)
	cfg.set_value("progress", "pipe_game_solved",   pipe_game_solved)
	cfg.set_value("progress", "shell_game_solved",  shell_game_solved)
	cfg.set_value("progress", "flow_connect_solved",flow_connect_solved)
	cfg.set_value("progress", "chest1_opened",      chest1_opened)
	cfg.set_value("progress", "chest2_opened",      chest2_opened)
	cfg.set_value("progress", "screen_unlocked",    screen_unlocked)
	cfg.set_value("progress", "collected_items",    collected_items)
	cfg.set_value("progress", "inventory_items",    inventory_items)
	cfg.set_value("progress", "room4_polygon_clicked", room4_polygon_clicked)
	cfg.save(SAVE_PATH)

func load_save() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	current_room       = cfg.get_value("progress", "current_room",       1)
	intro_finished     = cfg.get_value("progress", "intro_finished",     false)
	ball_cleaned       = cfg.get_value("progress", "ball_cleaned",       false)
	robot_powered      = cfg.get_value("progress", "robot_powered",      false)
	panel_solved       = cfg.get_value("progress", "panel_solved",       false)
	panel_game_won     = cfg.get_value("progress", "panel_game_won",     false)
	ship_panel_opened  = cfg.get_value("progress", "ship_panel_opened",  false)
	ship_fully_solved  = cfg.get_value("progress", "ship_fully_solved",  false)
	reactor_colored    = cfg.get_value("progress", "reactor_colored",    false)
	reactor_picked_up  = cfg.get_value("progress", "reactor_picked_up",  false)
	reactor_installed  = cfg.get_value("progress", "reactor_installed",  false)
	hidden_tool_taken  = cfg.get_value("progress", "hidden_tool_taken",  false)
	power_solved       = cfg.get_value("progress", "power_solved",       false)
	door_unlocked      = cfg.get_value("progress", "door_unlocked",      false)
	room1_door_opened  = cfg.get_value("progress", "room1_door_opened",  false)
	puzzle_solved_15   = cfg.get_value("progress", "puzzle_solved_15",   false)
	flask_solved       = cfg.get_value("progress", "flask_solved",       false)
	platformer_solved  = cfg.get_value("progress", "platformer_solved",  false)
	jumper_solved      = cfg.get_value("progress", "jumper_solved",      false)
	laser_mirror_solved= cfg.get_value("progress", "laser_mirror_solved",false)
	pipe_game_solved   = cfg.get_value("progress", "pipe_game_solved",   false)
	shell_game_solved  = cfg.get_value("progress", "shell_game_solved",  false)
	flow_connect_solved= cfg.get_value("progress", "flow_connect_solved",false)
	chest1_opened      = cfg.get_value("progress", "chest1_opened",      false)
	chest2_opened      = cfg.get_value("progress", "chest2_opened",      false)
	screen_unlocked    = cfg.get_value("progress", "screen_unlocked",    false)
	collected_items    = cfg.get_value("progress", "collected_items",    [])
	inventory_items    = cfg.get_value("progress", "inventory_items",    [])
	room4_polygon_clicked = cfg.get_value("progress", "room4_polygon_clicked", false)
	return true

func reset() -> void:
	# Удаляем файл сохранения
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save_game.cfg")
	# Сбрасываем все переменные в дефолт
	current_room        = 1
	intro_finished      = false
	ball_cleaned        = false
	robot_powered       = false
	panel_solved        = false
	panel_game_won      = false
	ship_panel_opened   = false
	ship_fully_solved   = false
	reactor_colored     = false
	reactor_picked_up   = false
	reactor_installed   = false
	hidden_tool_taken   = false
	power_solved        = false
	door_unlocked       = false
	room1_door_opened   = false
	puzzle_solved_15    = false
	flask_solved        = false
	platformer_solved   = false
	jumper_solved       = false
	laser_mirror_solved = false
	pipe_game_solved    = false
	shell_game_solved   = false
	flow_connect_solved = false
	chest1_opened       = false
	chest2_opened       = false
	screen_unlocked     = false
	collected_items     = []
	inventory_items     = []
	room4_polygon_clicked = false
